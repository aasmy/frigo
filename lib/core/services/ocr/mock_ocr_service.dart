import 'dart:math';

import 'ocr_service.dart';

/// Returns one of a handful of realistic messy receipts. Rotates between
/// samples so repeated scans during a demo don't feel identical.
class MockOcrService implements OcrService {
  MockOcrService({this.latency = const Duration(milliseconds: 900)});

  final Duration latency;
  int _cursor = 0;

  static const List<String> _samples = [
    '''
WALMART
SUPERCENTER
STORE 3284  MANAGER TANYA
08/24/2026  14:32

BNN ORG           1.28 F
MLK 2% 4L         6.49 F
AVOCADO 3 @ 1.29  3.87 F
CHK BRST BNLS     12.93 F
DOVE SOAP         7.99
EGGS LG 12PK      4.79 F
GRND BEEF 1LB     6.24 F
SPINACH BAG       3.49 F
ROMA TOM          2.11 F
YEL ONION 3LB     2.97 F

SUBTOTAL         55.16
TAX               0.80
TOTAL            55.96
VISA             55.96
''',
    '''
COSTCO WHOLESALE
#128 SEATTLE
08/28/2026

96716 ORG SPRING MIX     6.99
40483 ROTISSERIE CHICK   4.99
30669 KS OLIVE OIL       17.89
9211 BANANAS             1.99
1607 LARGE EGGS 24CT     6.79
93677 KS GREEK YOGURT    5.99
40506 SALMON FILLET      21.44
30217 JASMINE RICE 25LB  18.99
PAPER TOWELS             19.99

SUBTOTAL               131.05
TAX                      0.00
TOTAL                  131.05
''',
    '''
SAVE-ON-FOODS
#2241  BURNABY BC
2026-08-17  6:14 PM

WHL WHT BREAD        3.29
BUTTER SLTD 454G     5.49
CARROTS 2LB          2.29
GALA APPLE           4.12
CHKN THIGH BNLS      9.87
CHDR CHEESE BLCK     7.99
PASTA PENNE 900G     2.49
CRUSHD TOM 796ML     1.89
GARLIC               0.79
CILANTRO BUNCH       1.29
DISH SOAP            4.49

TOTAL              55.68
DEBIT              55.68
''',
  ];

  @override
  Future<OcrResult> extractText({String? imagePath}) async {
    await Future<void>.delayed(latency);
    final text = _samples[_cursor % _samples.length];
    _cursor++;
    return OcrResult(
      rawText: text.trim(),
      blockCount: text.trim().split('\n').where((l) => l.trim().isNotEmpty).length,
    );
  }

  /// Test hook: force a specific sample.
  void useSample(int index) => _cursor = index;

  static String randomSample() => _samples[Random().nextInt(_samples.length)];
}
