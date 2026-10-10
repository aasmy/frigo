import 'package:flutter_test/flutter_test.dart';

import 'package:pantry_ai/core/models/enums.dart';
import 'package:pantry_ai/core/models/receipt_item.dart';
import 'package:pantry_ai/core/services/ai/mock_ai_service.dart';
import 'package:pantry_ai/core/services/ocr/mock_ocr_service.dart';

void main() {
  final ai = MockAiService(latency: Duration.zero);

  ReceiptItem? pick(List<ReceiptItem> items, String contains) {
    for (final i in items) {
      if (i.normalizedName.toLowerCase().contains(contains.toLowerCase())) {
        return i;
      }
    }
    return null;
  }

  test('Walmart receipt: messy abbreviations become real foods', () async {
    final ocr = MockOcrService(latency: Duration.zero)..useSample(0);
    final receipt =
        await ai.parseReceipt(ocrText: (await ocr.extractText()).rawText);

    expect(receipt.merchant, 'Walmart');
    expect(pick(receipt.items, 'banana')?.normalizedName, 'Bananas');
    expect(pick(receipt.items, 'milk')?.normalizedName, '2% Milk');
    expect(pick(receipt.items, 'avocado')?.normalizedName, 'Avocado');
    expect(pick(receipt.items, 'chicken')?.category, FoodCategory.meat);
    expect(pick(receipt.items, 'egg')?.normalizedName, 'Large Eggs');
    expect(pick(receipt.items, 'ground beef')?.normalizedName, 'Ground Beef');
    expect(pick(receipt.items, 'spinach')?.normalizedName, 'Baby Spinach');
    expect(pick(receipt.items, 'onion')?.normalizedName, 'Yellow Onions');

    // The store banner line is not treated as a grocery.
    expect(pick(receipt.items, 'walmart'), isNull);
    // Non-food stays non-food.
    expect(pick(receipt.items, 'soap')?.isFood, isFalse);

    final avocado =
        receipt.items.firstWhere((i) => i.normalizedName == 'Avocado');
    expect(avocado.quantity, 3);
    final milk = receipt.items.firstWhere((i) => i.normalizedName == '2% Milk');
    expect(milk.quantity, 4);
    expect(milk.unit, 'L');
  });

  test('Costco receipt: item codes + brands stripped', () async {
    final ocr = MockOcrService(latency: Duration.zero)..useSample(1);
    final receipt =
        await ai.parseReceipt(ocrText: (await ocr.extractText()).rawText);

    expect(receipt.merchant, 'Costco');
    expect(pick(receipt.items, 'spring mix')?.normalizedName, 'Spring Mix');
    expect(pick(receipt.items, 'rotisserie')?.normalizedName, 'Rotisserie Chicken');
    expect(pick(receipt.items, 'olive oil')?.normalizedName, 'Olive Oil');
    expect(pick(receipt.items, 'olive oil')?.brand, 'Kirkland Signature');
    expect(pick(receipt.items, 'greek yogurt')?.normalizedName, 'Greek Yogurt');
    expect(pick(receipt.items, 'salmon')?.normalizedName, 'Salmon Fillet');
    expect(pick(receipt.items, 'rice')?.normalizedName, 'Jasmine Rice');
    expect(pick(receipt.items, 'towel')?.isFood, isFalse);
    // Store address line "#128 SEATTLE" is dropped.
    expect(pick(receipt.items, 'seattle'), isNull);

    final rice =
        receipt.items.firstWhere((i) => i.normalizedName == 'Jasmine Rice');
    expect(rice.unit, 'kg');
    expect(rice.quantity, greaterThan(10));
  });

  test('Save-On receipt: fuzzy matching survives dropped letters', () async {
    final ocr = MockOcrService(latency: Duration.zero)..useSample(2);
    final receipt =
        await ai.parseReceipt(ocrText: (await ocr.extractText()).rawText);

    expect(pick(receipt.items, 'wheat bread')?.normalizedName, 'Whole Wheat Bread');
    expect(pick(receipt.items, 'butter')?.normalizedName, 'Butter');
    expect(pick(receipt.items, 'carrot')?.normalizedName, 'Carrots');
    expect(pick(receipt.items, 'apple')?.normalizedName, 'Apples');
    expect(pick(receipt.items, 'thigh')?.category, FoodCategory.meat);
    expect(pick(receipt.items, 'cheddar')?.normalizedName, 'Cheddar Cheese');
    expect(pick(receipt.items, 'penne')?.normalizedName, 'Penne Pasta');
    expect(pick(receipt.items, 'crushed')?.normalizedName, 'Crushed Tomatoes');
    expect(pick(receipt.items, 'garlic')?.normalizedName, 'Garlic');
    expect(pick(receipt.items, 'dish soap')?.isFood, isFalse);
  });

  test('normalizeName recognises a single messy token', () async {
    final r = await ai.normalizeName('CHKN BRST BNLS FAM PK');
    expect(r.normalizedName, 'Chicken Breast');
    expect(r.category, FoodCategory.meat);
    expect(r.confidence, greaterThan(0.7));
  });

  test('unknown item still classified as food with a clean name', () async {
    final r = await ai.normalizeName('QUINOA TRICOLOUR');
    expect(r.normalizedName.toLowerCase(), contains('quinoa'));
    expect(r.category, isNot(FoodCategory.other));
  });

  test('Superstore receipt: PLU codes, weight lines, footer all handled', () async {
    final raw = [
      'REAL CANADIAN',
      'SUPERSTORE',
      'RCSS 1518 METROTOWN',
      '4700 KINGSWAY AVE.',
      '',
      '27-PRODUCE',
      '06038387100 CORN BICOLOR      MRJ      6.00',
      '4053 LEMON                    MRJ      1.25',
      '4166 ONIONS SWEET             MRJ',
      '0.275 kg @ \$6.59/kg                    1.81',
      '(3)4959 MANGO RED             MRJ',
      '3 @ \$2.00                              6.00',
      '62930704011 MINI YLW POTATO   MRJ      6.00',
      '94664 TOV GH RED ORG          MRJ',
      '0.750 kg Gross',
      '-0.010 kg Tare =',
      '0.740 kg Net @ \$11.00/kg               8.14',
      'SUBTOTAL                              30.20',
      'TOTAL                                 30.20',
      'Account: MASTERCARD           CAD\$ 30.20',
      'Card Number: ***********7476 P',
      'DateTime: 26/08/29 20:57:59',
      'Ref. #: 132787',
      'Auth #: 04032Z',
      'A0000000041010 0000008001',
      'Retain this copy for statement',
      'validation',
      '*** CUSTOMER COPY ***',
    ].join('\n');

    final receipt = await ai.parseReceipt(ocrText: raw);

    expect(receipt.merchant, 'Real Canadian Superstore');
    expect(receipt.purchaseDate.year, 2026);
    expect(receipt.purchaseDate.month, 8);
    expect(receipt.purchaseDate.day, 29);

    // Exactly the 6 real groceries — no footer / payment junk.
    expect(receipt.items.length, 6);
    final names = receipt.items.map((i) => i.normalizedName).toSet();
    expect(names, containsAll(<String>['Lemon', 'Yellow Onions', 'Mango']));
    expect(names.any((n) => n.contains('Corn')), isTrue);
    expect(names.any((n) => n.contains('Potato')), isTrue);
    expect(names.any((n) => n.contains('Tomato')), isTrue);

    // Footer words never leak in as items.
    for (final bad in ['Card', 'Ref', 'Auth', 'Cad', 'Validation', 'Kingsway',
        'Kg', 'Tare', 'Gross', 'Mrj']) {
      expect(pick(receipt.items, bad), isNull, reason: '"$bad" leaked as an item');
    }

    // Weight continuation attached to the onions, not the lemon.
    final onions =
        receipt.items.firstWhere((i) => i.normalizedName == 'Yellow Onions');
    expect(onions.quantity, 275);
    expect(onions.unit, 'g');
    expect(onions.price, closeTo(1.81, 0.001));

    final mango = receipt.items.firstWhere((i) => i.normalizedName == 'Mango');
    expect(mango.quantity, 3);
  });

  test('handles messy OCR: split price lines + digit/letter confusion', () async {
    final messy = [
      'FRESHCO',
      '2891 MAIN ST',
      '',
      'BNN ORG',
      'l.28',
      'CHKN BRST BNLS',
      '    l2.93',
      'MLK 2%  4L',
      '6.49',
      'DOVE SOAP',
      '7.99',
      'EGGS LG l2PK',
      '4.79',
    ].join('\n');

    final receipt = await ai.parseReceipt(ocrText: messy);
    final names = receipt.items.map((i) => i.normalizedName).toList();
    expect(names, contains('Bananas'));
    expect(names, contains('Chicken Breast'));
    expect(names, contains('2% Milk'));
    expect(names, contains('Large Eggs'));
    expect(pick(receipt.items, 'soap')?.isFood, isFalse);

    // The wrapped, garbled "l2.93" price was repaired and attached to chicken.
    final chicken =
        receipt.items.firstWhere((i) => i.normalizedName == 'Chicken Breast');
    expect(chicken.price, closeTo(12.93, 0.001));
  });
}
