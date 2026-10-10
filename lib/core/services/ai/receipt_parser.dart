import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../models/enums.dart';
import '../../models/receipt_item.dart';
import 'food_knowledge_base.dart';
import 'text_normalizer.dart';

/// Structured result of reading a receipt.
class ReceiptParseResult {
  const ReceiptParseResult({
    required this.merchant,
    required this.date,
    required this.items,
  });

  final String merchant;
  final DateTime? date;
  final List<ReceiptItem> items;
}

/// Turns a raw OCR dump into structured, de-noised grocery items.
///
/// Rather than trying to understand every line, it first works out the *shape*
/// of the receipt — where the item list starts and ends — then classifies each
/// line inside that window as a product, a continuation of the product above
/// (weight / "N @ price" math), a department header, or junk. That structural
/// pass is what makes it survive very different receipt layouts.
class ReceiptParser {
  ReceiptParser([Uuid? uuid]) : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;

  /// Test-only: prints per-line classification.
  static bool debugTrace = false;

  // Footer starts here — nothing after this is a grocery.
  static final RegExp _footer = RegExp(
    r'\b(SUB\s*-?\s*TOTAL|TOTAL|BALANCE|AMOUNT\s+DUE|GRAND\s+TOTAL|CHANGE\s+DUE)\b',
    caseSensitive: false,
  );

  static const _departments = {
    'PRODUCE', 'GROCERY', 'DAIRY', 'DELI', 'MEAT', 'SEAFOOD', 'FISH', 'BAKERY',
    'FROZEN', 'PHARMACY', 'HABA', 'HEALTH', 'BEAUTY', 'HOUSEHOLD', 'GENERAL',
    'MERCHANDISE', 'LIQUOR', 'BEER', 'WINE', 'FLORAL', 'NATURAL', 'SNACKS',
    'BEVERAGES', 'PANTRY', 'PET', 'BULK', 'REFRIGERATED',
  };

  static const _taxCodes = {
    'M', 'R', 'J', 'H', 'P', 'G', 'X', 'O', 'N', 'F', 'T', 'W', 'A', 'S', 'D',
    'MRJ', 'MRj', 'HMRJ', 'MR', 'RJ', 'HM', 'FS', 'TF', 'HD', 'GST', 'PST',
    'HST', 'QST', 'FP', 'FPM',
  };

  static const _junkKeywords = [
    'RCSS', 'METROTOWN', 'KINGSWAY', 'OPTIMUM', 'POINTS', 'EARNED', 'REWARD',
    'PC FINANCIAL', 'PC MONEY', 'MONEY ACCOUNT', 'RETAIN', 'VALIDATION',
    'CUSTOMER COPY', 'THANK', 'APPROVED', 'TRANS.', 'TRANS ', 'ACCOUNT:',
    'ACCOUNT ', 'CARD TYPE', 'CARD NUMBER', 'CARD #', 'DATETIME', 'DATE:',
    'DATE ', 'TIME:', 'REF #', 'REF#', 'REF.', 'REF:', 'AUTH #', 'AUTH#',
    'AUTH:', 'AUTH.', 'CAD\$', 'CAD ', 'GST', 'PST', 'HST', 'QST',
    'ENTRY METHOD', 'CONTACTLESS', 'CHIP', ' PIN', 'TERMINAL', 'MERCHANT',
    'STORE #', 'STORE#', 'ST#', 'OP#', 'MANAGER', 'CASHIER', 'PHONE', 'TEL:',
    'TEL ', 'WWW', 'HTTP', '.COM', '.CA', 'SURVEY', 'ITEMS SOLD', '# ITEMS',
    'YOU COULD HAVE', 'PURCHASE', 'CHANGE', 'TENDER', 'ROUNDING', 'DEPOSIT',
    'ENVIRO', 'RECYCL', 'SUBTOTAL', 'PAYMENT', 'VISA', 'DEBIT', 'MASTERCARD',
    'MASTER CARD', 'AMEX', 'INTERAC', 'CREDIT', 'PC EXPRESS', 'LOYALTY',
    'MEMBER', 'SAVINGS', 'INVOICE', 'RECEIPT', 'COPY',
  ];

  static final RegExp _addressLine = RegExp(
    r'\b(AVE|AVENUE|BLVD|BOULEVARD|STREET|ST|RD|ROAD|DRIVE|DR|WAY|HWY|SUITE|UNIT|PLACE|PL|COURT|CRES)\b\.?\s*$',
    caseSensitive: false,
  );
  static final RegExp _masked = RegExp(r'[*x]{3,}', caseSensitive: false);
  static final RegExp _noLetters = RegExp(r'^[^A-Za-z]*$');
  static final RegExp _deptHeader =
      RegExp(r"^\d{0,3}\s*[-–—]?\s*[A-Z][A-Z &/.'’-]{2,}$");

  static final RegExp _leadingParenQty = RegExp(r'^\s*\((\d{1,3})\)\s*');
  static final RegExp _leadingCode = RegExp(r'^\s*#?\d{3,}\s+');
  static final RegExp _trailingPrice = RegExp(r'(\d+[.,]\d{2})\s*$');
  static final RegExp _weight =
      RegExp(r'(-?\d*\.?\d+)\s*(kg|lb|g)\b', caseSensitive: false);
  static final RegExp _rate =
      RegExp(r'@\s*\$?(\d+[.,]\d{2})\s*/\s*(kg|lb|ea)', caseSensitive: false);
  static final RegExp _nAt =
      RegExp(r'^\(?(\d+)\)?\s*@\s*\$?(\d+[.,]\d{2})', caseSensitive: false);

  ReceiptParseResult parse(String rawOcr) {
    final text = ReceiptTextTools.preprocessOcr(rawOcr);
    final lines =
        text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

    final merchant = _detectMerchant(lines);
    final date = _detectDate(lines);

    // 1. End of the item list = first totals/footer line.
    var end = lines.indexWhere((l) => _footer.hasMatch(l));
    if (end < 0) end = lines.length;

    // 2. Start of the item list = the line after the first department header,
    //    or the first line that looks like a priced product.
    var start = 0;
    final deptIdx = lines.take(end).toList().indexWhere(_isDepartmentHeader);
    if (deptIdx >= 0) {
      start = deptIdx + 1;
    } else {
      final firstItem = lines.take(end).toList().indexWhere(_looksLikeItem);
      if (firstItem > 0) start = firstItem;
    }

    final items = <ReceiptItem>[];
    for (var i = start; i < end; i++) {
      final line = lines[i];
      // Continuation first — a weight / "N @ price" line has no letters and
      // would otherwise be dropped as "junk".
      if (_isContinuation(line)) {
        if (debugTrace) debugPrint('CONT         $line');
        _applyContinuation(items, line);
        continue;
      }
      if (_isDepartmentHeader(line) || _isJunk(line) || _isTaxCodeOnly(line)) {
        if (debugTrace) debugPrint('SKIP(junk)   $line');
        continue;
      }
      final item = _parseItem(line);
      if (debugTrace) debugPrint('ITEM(${item?.normalizedName ?? "null"})  $line');
      if (item == null) continue;

      final dupe = items.indexWhere((e) =>
          e.normalizedName.toLowerCase() == item.normalizedName.toLowerCase() &&
          e.unit == item.unit);
      if (dupe >= 0) {
        items[dupe] =
            items[dupe].copyWith(quantity: items[dupe].quantity + item.quantity);
      } else {
        items.add(item);
      }
    }

    // 3. Final sanity filter — drop rows that are only units / noise words.
    final cleaned = items.where(_isPlausibleItem).toList();

    return ReceiptParseResult(merchant: merchant, date: date, items: cleaned);
  }

  // ---------------------------------------------------------------------------
  // line classification
  // ---------------------------------------------------------------------------
  bool _isDepartmentHeader(String line) {
    final u = line.toUpperCase().trim();
    if (!_deptHeader.hasMatch(u)) return false;
    final words = u
        .replaceAll(RegExp(r'[^A-Z ]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 1)
        .toSet();
    return words.any(_departments.contains);
  }

  bool _isJunk(String line) {
    final u = line.toUpperCase();
    if (ReceiptTextTools.isChromeLine(u)) return true;
    if (_junkKeywords.any(u.contains)) return true;
    if (_masked.hasMatch(line)) return true;
    if (_noLetters.hasMatch(line)) return true;
    if (_addressLine.hasMatch(u) && RegExp(r'\d').hasMatch(u)) return true;
    // EMV / auth data: a single long alphanumeric token, digit-heavy, no price.
    if (!line.contains(' ') &&
        RegExp(r'^[A-Z0-9]{12,}$').hasMatch(line) &&
        RegExp(r'\d').allMatches(line).length >= line.length * 0.4) {
      return true;
    }
    return false;
  }

  /// A line with a real product name (letters) and either a price or an
  /// item code — used only to locate where the list begins.
  bool _looksLikeItem(String line) {
    if (_isJunk(line) || _isDepartmentHeader(line)) return false;
    if (!RegExp(r'[A-Za-z]{3,}').hasMatch(line)) return false;
    final hasPrice = RegExp(r'\d+[.,]\d{2}').hasMatch(line);
    final hasCode = _leadingCode.hasMatch(line) || _leadingParenQty.hasMatch(line);
    return hasPrice || hasCode;
  }

  /// True when the line carries no product name, only weight / price math that
  /// belongs to the item above it.
  bool _isContinuation(String line) {
    final u = line.toUpperCase();
    final hasWeight = RegExp(r'\d\s*(KG|LB|G)\b').hasMatch(u);
    final hasAtPrice = RegExp(r'@\s*\$?\d').hasMatch(line);
    final hasGrossTareNet = RegExp(r'\b(GROSS|TARE|NET)\b').hasMatch(u);
    if (!hasWeight && !hasAtPrice && !hasGrossTareNet) return false;

    var s = ' $u ';
    for (final w in ['KG', 'LB', 'ML', 'EA', 'NET', 'GROSS', 'TARE']) {
      s = s.replaceAll(RegExp('\\b$w\\b'), ' ');
    }
    // No real word left → it's just math for the item above.
    return s.replaceAll(RegExp(r'[^A-Z]'), '').length < 3;
  }

  bool _isTaxCodeOnly(String line) {
    final tokens = line
        .toUpperCase()
        .replaceAll(_trailingPrice, '')
        .split(RegExp(r'\s+'))
        .where((t) => RegExp(r'[A-Z]').hasMatch(t))
        .toList();
    return tokens.isNotEmpty && tokens.every(_taxCodes.contains);
  }

  bool _isPlausibleItem(ReceiptItem i) {
    final n = i.normalizedName.trim();
    if (n.length < 2) return false;
    final words = n
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 1 && !_taxCodes.contains(w.toUpperCase()))
        .toList();
    if (words.isEmpty) return false;
    const noise = {
      'kg', 'lb', 'net', 'gross', 'tare', 'each', 'ea', 'item', 'items',
      'card', 'number', 'ref', 'auth', 'cad', 'usd', 'validation', 'copy',
      'total', 'change', 'balance', 'subtotal',
    };
    return words.any((w) => !noise.contains(w));
  }

  // ---------------------------------------------------------------------------
  // item building
  // ---------------------------------------------------------------------------
  ReceiptItem? _parseItem(String rawLine) {
    final upper = rawLine.toUpperCase();
    if (!RegExp(r'[A-Za-z]{2,}').hasMatch(rawLine)) return null;

    double? parenQty;
    var work = rawLine;

    final pq = _leadingParenQty.firstMatch(work);
    if (pq != null) {
      parenQty ??= double.tryParse(pq.group(1)!);
      parenQty = double.tryParse(pq.group(1)!);
      work = work.substring(pq.end);
    }
    work = work.replaceFirst(_leadingCode, '');

    final price = _priceOf(rawLine);
    // Drop every price token and the "@ 1.29" unit-price clause, then any
    // trailing tax-code flags ("F", "MRJ").
    work = work
        .replaceAll(RegExp(r'@\s*\$?\d+[.,]\d{2}'), ' ')
        .replaceAll(RegExp(r'\d+[.,]\d{2}'), ' ')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();
    work = _stripTrailingTaxCodes(work);

    if (!RegExp(r'[A-Za-z]{2,}').hasMatch(work)) return null;

    final brand = ReceiptTextTools.extractBrand(work.toLowerCase());
    var tokens = ReceiptTextTools.tokenize(work);
    if (tokens.isNotEmpty && RegExp(r'^\d+$').hasMatch(tokens.first)) {
      tokens = tokens.sublist(1);
    }
    tokens = tokens
        .where((t) => !kBrandTokens.contains(t) && t != '%' && t.length > 1)
        .toList();
    if (tokens.isEmpty) return null;

    final expanded = ReceiptTextTools.expand(tokens);
    final nonFoodHint = ReceiptTextTools.looksNonFood(upper);
    final match = nonFoodHint ? null : FoodKnowledgeBase.recognise(expanded);

    final qtyGuess = ReceiptTextTools.quantity(rawLine);
    final baseQty = parenQty ?? (qtyGuess.explicit ? qtyGuess.quantity : 1);

    if (match != null) {
      final entry = match.entry;
      String unit;
      double quantity;
      if (qtyGuess.explicit && qtyGuess.unit != 'piece') {
        unit = qtyGuess.unit;
        quantity = _round(qtyGuess.quantity);
      } else if (_massUnits.contains(entry.unit)) {
        unit = 'package';
        quantity = parenQty ?? 1;
      } else {
        unit = entry.unit;
        quantity = _round(baseQty);
      }
      return ReceiptItem(
        id: _uuid.v4(),
        rawName: work.isEmpty ? rawLine.trim() : work,
        normalizedName: entry.name,
        brand: brand,
        category: entry.category,
        quantity: quantity,
        unit: unit,
        isFood: true,
        confidence: match.confidence,
        price: price,
        storageLocation: entry.storage,
      );
    }

    final meaningful = expanded
        .where((t) => !kStopwords.contains(t) && !RegExp(r'^\d').hasMatch(t))
        .toList();
    final displayName = ReceiptTextTools.titleCase(
        (meaningful.isEmpty ? expanded : meaningful).take(4).join(' '));
    if (displayName.trim().isEmpty) return null;

    if (nonFoodHint) {
      return ReceiptItem(
        id: _uuid.v4(),
        rawName: work,
        normalizedName: displayName,
        brand: brand,
        category: FoodCategory.other,
        quantity: _round(baseQty),
        unit: qtyGuess.explicit ? qtyGuess.unit : 'piece',
        isFood: false,
        confidence: 0.9,
        price: price,
        storageLocation: StorageLocation.pantry,
      );
    }

    final category = FoodKnowledgeBase.guessCategory(expanded);
    return ReceiptItem(
      id: _uuid.v4(),
      rawName: work,
      normalizedName: displayName,
      brand: brand,
      category: category,
      quantity: _round(baseQty),
      unit: qtyGuess.explicit ? qtyGuess.unit : _defaultUnitFor(category),
      isFood: true,
      confidence: 0.55,
      price: price,
      storageLocation: _storageFor(category),
    );
  }

  void _applyContinuation(List<ReceiptItem> items, String line) {
    if (items.isEmpty) return;
    final u = line.toUpperCase();
    // Gross / Tare lines are intermediate — the Net line has the real number.
    if ((u.contains('GROSS') || u.contains('TARE')) && !u.contains('NET')) {
      return;
    }

    final last = items.last;
    double? qty;
    String? unit;
    double? price = _priceOf(line);

    final nAt = _nAt.firstMatch(line.trim());
    if (nAt != null) {
      qty = double.tryParse(nAt.group(1)!);
      final each = double.tryParse(nAt.group(2)!.replaceAll(',', '.'));
      if (price == null && qty != null && each != null) price = qty * each;
    } else {
      // Prefer the number attached to "Net", else the first weight on the line.
      final netM = RegExp(r'(-?\d*\.?\d+)\s*(kg|lb|g)\s*net',
              caseSensitive: false)
          .firstMatch(line);
      final wM = netM ?? _weight.firstMatch(line);
      if (wM != null) {
        final value = double.tryParse(wM.group(1)!) ?? 0;
        final u2 = wM.group(2)!.toLowerCase();
        final grams = switch (u2) {
          'kg' => value * 1000,
          'lb' => value * 453.592,
          _ => value,
        };
        if (grams > 0 && grams < 1000) {
          qty = double.parse(grams.toStringAsFixed(0));
          unit = 'g';
        } else if (grams >= 1000) {
          qty = double.parse((grams / 1000).toStringAsFixed(2));
          unit = 'kg';
        }
        if (price == null) {
          final rateM = _rate.firstMatch(line);
          final rate =
              rateM == null ? null : double.tryParse(rateM.group(1)!.replaceAll(',', '.'));
          if (rate != null) price = (grams / 1000) * rate;
        }
      }
    }

    items[items.length - 1] = last.copyWith(
      quantity: qty != null ? _round(qty) : last.quantity,
      unit: unit ?? last.unit,
      price: price ?? last.price,
    );
  }

  String _stripTrailingTaxCodes(String s) {
    var parts = s.trim().split(RegExp(r'\s+'));
    while (parts.length > 1) {
      final last = parts.last.toUpperCase();
      final isCode = _taxCodes.contains(last) ||
          (RegExp(r'^[A-Z]{1,2}$').hasMatch(last));
      if (!isCode) break;
      parts = parts.sublist(0, parts.length - 1);
    }
    return parts.join(' ');
  }

  // ---------------------------------------------------------------------------
  // merchant + date
  // ---------------------------------------------------------------------------
  static const Map<String, String> _merchants = {
    'REAL CANADIAN SUPERSTORE': 'Real Canadian Superstore',
    'REAL CANADIAN': 'Real Canadian Superstore',
    'SUPERSTORE': 'Real Canadian Superstore',
    'RCSS': 'Real Canadian Superstore',
    'SAVE-ON-FOODS': 'Save-On-Foods',
    'SAVE ON FOODS': 'Save-On-Foods',
    'WHOLE FOODS': 'Whole Foods Market',
    'TRADER JOE': "Trader Joe's",
    'NO FRILLS': 'No Frills',
    'WAL-MART': 'Walmart',
    'WALMART': 'Walmart',
    'COSTCO': 'Costco',
    'SAFEWAY': 'Safeway',
    'FRESHCO': 'FreshCo',
    'LOBLAWS': 'Loblaws',
    'SOBEYS': 'Sobeys',
    'T&T': 'T&T Supermarket',
    'H MART': 'H Mart',
    'ALDI': 'Aldi',
    'KROGER': 'Kroger',
    'TARGET': 'Target',
    'PUBLIX': 'Publix',
    'WEGMANS': 'Wegmans',
    'TRADER': "Trader Joe's",
    'IGA': 'IGA',
    'METRO': 'Metro',
  };

  String _detectMerchant(List<String> lines) {
    final keys = _merchants.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final line in lines.take(12)) {
      final u = line.toUpperCase();
      for (final k in keys) {
        if (RegExp(r'(^|\b)' + RegExp.escape(k) + r'(\b|$)').hasMatch(u)) {
          return _merchants[k]!;
        }
      }
    }
    for (final line in lines.take(6)) {
      if (line.length > 3 &&
          RegExp(r'^[A-Za-z][A-Za-z .&\-]+$').hasMatch(line) &&
          !ReceiptTextTools.isChromeLine(line.toUpperCase()) &&
          !_isDepartmentHeader(line)) {
        return ReceiptTextTools.titleCase(line);
      }
    }
    return 'Grocery store';
  }

  DateTime? _detectDate(List<String> lines) {
    final now = DateTime.now();
    final candidates = <DateTime>[];
    final re = RegExp(r'(\d{2,4})[-/.](\d{1,2})[-/.](\d{2,4})');
    for (final line in lines) {
      for (final m in re.allMatches(line)) {
        final a = int.tryParse(m.group(1)!) ?? 0;
        final b = int.tryParse(m.group(2)!) ?? 0;
        final c = int.tryParse(m.group(3)!) ?? 0;
        for (final d in _interpretations(a, b, c)) {
          if (d != null &&
              d.isBefore(now.add(const Duration(days: 2))) &&
              d.isAfter(now.subtract(const Duration(days: 730)))) {
            candidates.add(d);
          }
        }
      }
    }
    if (candidates.isEmpty) return null;
    candidates.sort((x, y) =>
        (now.difference(x)).abs().compareTo((now.difference(y)).abs()));
    return candidates.first;
  }

  List<DateTime?> _interpretations(int a, int b, int c) {
    DateTime? make(int y, int mo, int d) {
      if (y < 100) y += 2000;
      if (mo < 1 || mo > 12 || d < 1 || d > 31) return null;
      try {
        final dt = DateTime(y, mo, d);
        return (dt.month == mo && dt.day == d) ? dt : null;
      } catch (_) {
        return null;
      }
    }

    return [
      make(a, b, c), // YYYY/MM/DD or YY/MM/DD
      make(c, b, a), // DD/MM/YYYY
      make(c, a, b), // MM/DD/YYYY
    ];
  }

  // ---------------------------------------------------------------------------
  // small shared bits
  // ---------------------------------------------------------------------------
  static const _massUnits = {'g', 'kg', 'mL', 'L'};

  double? _priceOf(String line) {
    final m = RegExp(r'(\d+[.,]\d{2})').allMatches(line).toList();
    if (m.isEmpty) return null;
    return double.tryParse(m.last.group(1)!.replaceAll(',', '.'));
  }

  double _round(double v) => (v * 100).round() / 100;

  String _defaultUnitFor(FoodCategory c) => switch (c) {
        FoodCategory.meat => 'package',
        FoodCategory.dairy => 'piece',
        FoodCategory.produce => 'piece',
        FoodCategory.grains => 'package',
        FoodCategory.bakery => 'loaf',
        FoodCategory.frozen => 'bag',
        _ => 'piece',
      };

  StorageLocation _storageFor(FoodCategory c) => switch (c) {
        FoodCategory.meat || FoodCategory.dairy => StorageLocation.fridge,
        FoodCategory.produce => StorageLocation.fridge,
        FoodCategory.frozen => StorageLocation.freezer,
        FoodCategory.bakery => StorageLocation.counter,
        _ => StorageLocation.pantry,
      };
}
