/// Pure text utilities behind the mock "receipt understanding" pipeline.
///
/// None of this touches Flutter — it's all deterministic string work so it can
/// be unit-tested and, later, mirrored server-side before an LLM ever runs.
library;

/// Token-level abbreviation expansions. Applied word-by-word to a cleaned,
/// upper-cased receipt line so "CHKN BRST BNLS" -> "chicken breast boneless".
const Map<String, String> kAbbreviations = {
  // proteins
  'chkn': 'chicken', 'chk': 'chicken', 'ckn': 'chicken', 'chick': 'chicken',
  'brst': 'breast', 'brs': 'breast', 'bst': 'breast', 'bnls': 'boneless',
  'bnlss': 'boneless', 'bls': 'boneless', 'skls': 'skinless', 'sknls': 'skinless',
  'thgh': 'thigh', 'thi': 'thigh', 'drmstk': 'drumstick', 'wng': 'wing',
  'grnd': 'ground', 'grd': 'ground', 'gr': 'ground', 'bf': 'beef',
  'gnd': 'ground', 'ln': 'lean', 'xln': 'extra lean', 'prk': 'pork',
  'sausg': 'sausage', 'saus': 'sausage', 'bcn': 'bacon', 'ham': 'ham',
  'trky': 'turkey', 'tky': 'turkey', 'slmn': 'salmon', 'slm': 'salmon',
  'shrmp': 'shrimp', 'shp': 'shrimp', 'tlpia': 'tilapia', 'cod': 'cod',
  'tuna': 'tuna', 'stk': 'steak', 'rst': 'roast', 'mnce': 'mince',
  // dairy & eggs
  'mlk': 'milk', 'mk': 'milk', 'chz': 'cheese', 'chs': 'cheese',
  'chee': 'cheese', 'chdr': 'cheddar', 'ched': 'cheddar', 'mozz': 'mozzarella',
  'moz': 'mozzarella', 'parm': 'parmesan', 'prm': 'parmesan', 'fta': 'feta',
  'ygrt': 'yogurt', 'yog': 'yogurt', 'ygt': 'yogurt', 'yghrt': 'yogurt',
  'grk': 'greek', 'crm': 'cream', 'crem': 'cream', 'sr': 'sour',
  'btr': 'butter', 'butr': 'butter', 'marg': 'margarine', 'egg': 'egg',
  'eggs': 'eggs', 'eg': 'egg', 'dzn': 'dozen', 'dz': 'dozen',
  // produce
  'org': 'organic', 'orgnc': 'organic', 'og': 'organic', 'whl': 'whole',
  'whle': 'whole', 'frsh': 'fresh', 'grn': 'green', 'ylw': 'yellow',
  'yel': 'yellow', 'rd': 'red', 'pot': 'potato', 'ptato': 'potato',
  'ptt': 'potato', 'tom': 'tomato', 'tmto': 'tomato', 'tmt': 'tomato',
  'onn': 'onion', 'onin': 'onion', 'oni': 'onion', 'garl': 'garlic',
  'grlc': 'garlic', 'glc': 'garlic', 'lttc': 'lettuce', 'let': 'lettuce',
  'rom': 'romaine', 'spnch': 'spinach', 'spn': 'spinach', 'spnc': 'spinach',
  'broc': 'broccoli', 'brcli': 'broccoli', 'brocc': 'broccoli',
  'cuke': 'cucumber', 'cuc': 'cucumber', 'ccmbr': 'cucumber',
  'carr': 'carrot', 'crt': 'carrot', 'crrt': 'carrot', 'ppr': 'pepper',
  'pepr': 'pepper', 'bell': 'bell', 'mshrm': 'mushroom', 'mush': 'mushroom',
  'mshr': 'mushroom', 'avo': 'avocado', 'avcd': 'avocado', 'avoc': 'avocado',
  'avcdo': 'avocado', 'bnn': 'banana', 'bnna': 'banana', 'ban': 'banana',
  'apl': 'apple', 'appl': 'apple', 'aple': 'apple', 'ornge': 'orange',
  'orng': 'orange', 'strw': 'strawberry', 'strwb': 'strawberry',
  'blbry': 'blueberry', 'blub': 'blueberry', 'rspbry': 'raspberry',
  'grpe': 'grape', 'grp': 'grape', 'lmn': 'lemon', 'lme': 'lime',
  'clntro': 'cilantro', 'prsly': 'parsley', 'gngr': 'ginger', 'kale': 'kale',
  'zuke': 'zucchini', 'zuc': 'zucchini', 'celry': 'celery', 'clry': 'celery',
  // pantry / grains
  'brd': 'bread', 'bred': 'bread', 'bgl': 'bagel', 'bun': 'bun',
  'tort': 'tortilla', 'trtla': 'tortilla', 'wht': 'wheat', 'ww': 'whole wheat',
  'rc': 'rice', 'jsmn': 'jasmine', 'bsmti': 'basmati', 'psta': 'pasta',
  'spght': 'spaghetti', 'spag': 'spaghetti', 'penne': 'penne',
  'mac': 'macaroni', 'ndl': 'noodle', 'crl': 'cereal', 'otml': 'oatmeal',
  'ots': 'oats', 'flr': 'flour', 'sgr': 'sugar', 'ol': 'oil', 'oil': 'oil',
  'olv': 'olive', 'vngr': 'vinegar', 'ktchp': 'ketchup', 'myo': 'mayonnaise',
  'mayo': 'mayonnaise', 'mstrd': 'mustard', 'pb': 'peanut butter',
  'jly': 'jelly', 'jam': 'jam', 'hny': 'honey', 'slsa': 'salsa',
  'sce': 'sauce', 'sauc': 'sauce', 'stk_broth': 'stock', 'brth': 'broth',
  'cnd': 'canned', 'bns': 'beans', 'chkpea': 'chickpea', 'lentl': 'lentil',
  // drinks
  'jce': 'juice', 'juic': 'juice', 'wtr': 'water', 'sprkl': 'sparkling',
  'sda': 'soda', 'pop': 'soda', 'coff': 'coffee', 'cfe': 'coffee', 'tea': 'tea',
  // frozen / prepared
  'frz': 'frozen', 'frzn': 'frozen', 'pzza': 'pizza', 'ngt': 'nugget',
  'ngget': 'nugget', 'ff': 'fries', 'vg': 'vegetable', 'veg': 'vegetable',
  'mxd': 'mixed',
  // sizes / descriptors kept as words
  'lg': 'large', 'xl': 'extra large', 'sm': 'small', 'md': 'medium',
  'fam': 'family', 'jmbo': 'jumbo', 'mini': 'mini', 'shrd': 'shredded',
  'slcd': 'sliced', 'diced': 'diced', 'unsltd': 'unsalted', 'sltd': 'salted',
  'smkd': 'smoked', 'blck': 'block', 'bkd': 'baked', 'crushd': 'crushed',
  'dcd': 'diced', 'chpd': 'chopped', 'bnch': 'bunch',
  // store-specific produce abbreviations
  'tov': 'tomato vine', 'grap': 'grape', 'bicolor': 'sweet', 'bicolour': 'sweet',
  'yl': 'yellow', 'russ': 'russet', 'engl': 'english',
  'seedls': 'seedless', 'sdls': 'seedless',
};

/// Brand tokens — captured separately, never part of the food name.
const Set<String> kBrands = {
  'gv', 'great value', 'ks', 'kirkland', 'kirkland signature', 'pc',
  "president's choice", 'presidents choice', 'no name', 'noname', 'compliments',
  'selection', 'kraft', 'heinz', 'nestle', 'danone', 'oikos', 'activia',
  'tropicana', 'minute maid', 'quaker', 'kellogg', 'kelloggs', 'general mills',
  'barilla', 'catelli', 'uncle bens', 'liberte', 'lactantia', 'neilson',
  'dempsters', 'wonder', 'villaggio', 'maple leaf', 'olymel', 'tyson', 'perdue',
  'hellmanns', 'frenchs', 'campbells', 'knorr', 'lipton', 'philadelphia',
  'cracker barrel', 'black diamond', 'armstrong', 'silk', 'almond breeze',
  'chobani', 'yoplait', 'dole', 'driscolls', 'becel', 'dairyland', 'saputo',
  'primo', 'aylmer', 'clover leaf', 'christie', 'dare', 'mccain', 'europes best',
};

/// Every individual word that appears in a brand name — stripped from the
/// token stream before food matching.
final Set<String> kBrandTokens = {
  for (final b in kBrands) ...b.split(' '),
  'ks', 'gv', 'pc',
};

/// Descriptor words that survive but shouldn't anchor a food match.
const Set<String> kStopwords = {
  'organic', 'fresh', 'large', 'small', 'medium', 'extra', 'family', 'value',
  'pack', 'size', 'club', 'natural', 'premium', 'classic', 'original', 'the',
  'of', 'in', 'with', 'and', 'no', 'low', 'reduced', 'lite', 'light', 'free',
  'new', 'select', 'choice', 'grade', 'each', 'assorted', 'brand', 'pk', 'ea',
  'ct', 'count', 'imported', 'local', 'product', 'approx', 'greenhouse', 'gh',
  'red', 'green', 'yellow', 'sweet', 'mini', 'baby', 'jumbo', 'whole', 'half',
};

/// Lines that are receipt chrome, not products.
const List<String> kSkipLineKeywords = [
  'SUBTOTAL', 'SUB TOTAL', 'TOTAL', 'TAX', 'HST', 'GST', 'PST', 'QST',
  'BALANCE', 'TENDER', 'CHANGE', 'CASH', 'DEBIT', 'CREDIT', 'VISA',
  'MASTERCARD', 'MASTER CARD', 'AMEX', 'INTERAC', 'DISCOVER', 'APPROVAL',
  'APPROVED', 'AUTH', 'AID:', 'REF #', 'REF#', 'SEQ', 'BATCH', 'TERMINAL',
  'MERCHANT', 'CASHIER', 'ASSOCIATE', 'OPERATOR', 'THANK YOU', 'THANKS',
  'SURVEY', 'WWW.', 'HTTP', '.COM', 'CUSTOMER COPY', 'ROUNDING', 'ROUND',
  'LOYALTY', 'POINTS', 'REWARD', 'MEMBER', 'SAVINGS', 'YOU SAVED',
  'ITEMS SOLD', '# ITEMS', 'ITEM COUNT', 'RETURN POLICY', 'STORE #',
  'STORE#', 'ST#', 'OP#', 'TE#', 'TR#', 'TRANS', 'INVOICE', 'REGISTER',
  'SUPERCENTER', 'WHOLESALE', 'RECEIPT', 'PURCHASE', 'DATE:', 'TIME:',
  'SLIP', 'CARD #', 'CARDHOLDER', 'ENTRY METHOD', 'CHIP', 'CONTACTLESS',
  'PHONE', 'TEL:', 'MANAGER', 'DEPOSIT', 'ENVIRO', 'ECO FEE', 'BAG FEE',
];

/// Tokens that mark a line as non-food.
const List<String> kNonFoodKeywords = [
  'SOAP', 'SHAMPOO', 'CONDITIONER', 'DETERGENT', 'TOWEL', 'NAPKIN', 'FOIL',
  'PARCHMENT', 'ZIPLOC', 'BAGGIE', 'BATTERY', 'BATTERIES', 'TOOTHPASTE',
  'TOOTHBRUSH', 'FLOSS', 'TISSUE', 'KLEENEX', 'CLEANER', 'BLEACH', 'SPONGE',
  'SCRUB', 'DIAPER', 'WIPES', 'RAZOR', 'SHAVE', 'DEODORANT', 'LOTION',
  'MOISTURIZER', 'CANDLE', 'SARAN', 'GARBAGE', 'TRASH', 'LIGHTBULB', 'BULB',
  'LIGHTER', 'MATCHES', 'PENCIL', ' PEN ', 'NOTEBOOK', 'GIFT CARD', 'MAGAZINE',
  'FLOWERS', 'POTTING', 'ADVIL', 'TYLENOL', 'VITAMIN', 'SUPPLEMENT', 'MEDICINE',
  'BANDAGE', 'TAMPON', 'LITTER', 'DOG FOOD', 'CAT FOOD', 'WINDEX', 'PLEDGE',
  'SWIFFER', 'LYSOL', 'CLOROX', 'FEBREZE', 'TIDE', 'DAWN DISH', 'PLASTIC WRAP',
  'PAPER TOWEL', 'DISH SOAP', 'HAND SOAP', 'BODY WASH', 'SUNSCREEN',
];

final _priceLike = RegExp(r'-?\$?\d+\.\d{2}\b');
final _leadingItemCode = RegExp(r'^\s*(?:#?\d{4,}|[A-Z]?\d{5,})\s+');
// Only a *single* trailing uppercase letter is a tax flag (Walmart "F"/"N").
// Stripping 2–3 letters here would eat real words like "MIX", "OIL", "BLK".
final _trailingFlags = RegExp(r'\s+[A-Z]\s*$');
final _storeHeader = RegExp(r'^\s*#\s?\d');
final _weightAt = RegExp(
    r'(\d+(?:\.\d+)?)\s*(?:lb|lbs|kg|g)\b\s*@', caseSensitive: false);
final _nAtPrice = RegExp(r'(\d+(?:\.\d+)?)\s*@\s*\$?\d+\.\d{2}');
final _nForPrice =
    RegExp(r'(\d+)\s*(?:for|/)\s*\$?\d+\.\d{2}', caseSensitive: false);
final _packSize = RegExp(
    r'(\d+(?:\.\d+)?)\s?(pk|pack|ct|count|dozen|doz|dz|l|ml|kg|g|lb|lbs|oz|gal|qt|pt)\b',
    caseSensitive: false);
final _leadingCount = RegExp(r'^(\d{1,2})\s+(?=[a-z])', caseSensitive: false);

/// A parsed quantity + unit lifted off a receipt line.
class QuantityGuess {
  const QuantityGuess(this.quantity, this.unit, {this.explicit = false});
  final double quantity;
  final String unit;

  /// True when the receipt actually stated an amount (vs. our default of 1).
  final bool explicit;
}

final _numericToken = RegExp(r'(?<![A-Za-z])[\$OolIiSB\d][\dOolIiSB.,]{2,}(?![A-Za-z])');
final _bareaPrice = RegExp(r'^\$?\d{1,4}[.,]\d{2}$');

class ReceiptTextTools {
  const ReceiptTextTools._();

  /// Clean a raw OCR dump before line parsing: normalise whitespace, fix the
  /// classic digit/letter confusions *inside number-looking tokens only*, drop
  /// currency symbols, and re-attach a price that OCR split onto its own line.
  static String preprocessOcr(String raw) {
    final lines = raw
        .replaceAll('\r', '\n')
        .split('\n')
        .map((l) => l.replaceAll('\t', ' ').replaceAll(RegExp(r' {2,}'), ' ').trim())
        .map(_fixNumericTokens) // repair l2.9S -> 12.95 etc first
        .where((l) => l.isNotEmpty)
        .toList();

    // Then re-join a lone price line onto the previous product line.
    final joined = <String>[];
    for (final line in lines) {
      if (_bareaPrice.hasMatch(line) &&
          joined.isNotEmpty &&
          RegExp(r'[A-Za-z]{3,}').hasMatch(joined.last) &&
          !_priceLike.hasMatch(joined.last)) {
        joined[joined.length - 1] = '${joined.last}  $line';
      } else {
        joined.add(line);
      }
    }
    return joined.join('\n');
  }

  static String _fixNumericTokens(String line) {
    return line.replaceAllMapped(_numericToken, (m) {
      final t = m[0]!;
      final digits = t.replaceAll(RegExp(r'[.,\$]'), '');
      final letters = digits.replaceAll(RegExp(r'\d'), '');
      // Only "repair" when the token is overwhelmingly numeric already.
      if (digits.isEmpty || letters.length > digits.length - letters.length) {
        return t;
      }
      return t
          .replaceAll('\$', '')
          .replaceAll(RegExp(r'[Oo]'), '0')
          .replaceAll(RegExp(r'[lIi]'), '1')
          .replaceAll('S', '5')
          .replaceAll('B', '8')
          .replaceAll(',', '.');
    });
  }

  static bool isChromeLine(String upperLine) =>
      kSkipLineKeywords.any(upperLine.contains) ||
      _storeHeader.hasMatch(upperLine);

  static bool looksNonFood(String upperLine) =>
      kNonFoodKeywords.any(upperLine.contains);

  /// Strip item codes, prices, discount lines and trailing tax flags.
  static String stripNoise(String line) {
    var s = line.replaceFirst(_leadingItemCode, '');
    s = s.replaceAll(_priceLike, ' ');
    s = s.replaceAll(RegExp(r'@\s*/?\s*(lb|kg|g|ea)\b', caseSensitive: false), ' ');
    s = s.replaceAll(RegExp(r'[*#@]'), ' ');
    s = s.replaceAll(_trailingFlags, ' ');
    // Drop a trailing bare count / weight number left after price removal
    // ("AVOCADO 3" -> "AVOCADO"), but keep tokens with letters ("4L").
    s = s.replaceAll(RegExp(r'\s+\d+(?:\.\d+)?\s*$'), ' ');
    s = s.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
    return s;
  }

  /// Pull a quantity + unit from the raw line (before noise stripping so the
  /// "@", "for" and weight cues are still present).
  static QuantityGuess quantity(String rawLine) {
    final lower = rawLine.toLowerCase();

    final weight = _weightAt.firstMatch(lower);
    if (weight != null) {
      final value = double.tryParse(weight.group(1)!) ?? 1;
      final unit = lower.contains('kg') ? 'kg' : (lower.contains(' g') ? 'g' : 'lb');
      return _toMetricMass(value, unit);
    }

    final nAt = _nAtPrice.firstMatch(lower);
    if (nAt != null) {
      return QuantityGuess(
          double.tryParse(nAt.group(1)!) ?? 1, 'piece', explicit: true);
    }

    final nFor = _nForPrice.firstMatch(lower);
    if (nFor != null) {
      return QuantityGuess(
          double.tryParse(nFor.group(1)!) ?? 1, 'piece', explicit: true);
    }

    final pack = _packSize.firstMatch(lower);
    if (pack != null) {
      final value = double.tryParse(pack.group(1)!) ?? 1;
      final unit = pack.group(2)!.toLowerCase();
      return switch (unit) {
        'pk' || 'pack' || 'ct' || 'count' => QuantityGuess(value, 'piece', explicit: true),
        'dozen' || 'doz' || 'dz' => QuantityGuess(value * 12, 'piece', explicit: true),
        'l' => QuantityGuess(value, 'L', explicit: true),
        'ml' => QuantityGuess(value / 1000, 'L', explicit: true),
        'gal' => QuantityGuess(value * 3.785, 'L', explicit: true),
        'qt' => QuantityGuess(value * 0.946, 'L', explicit: true),
        'pt' => QuantityGuess(value * 0.473, 'L', explicit: true),
        'kg' => QuantityGuess(value, 'kg', explicit: true),
        'g' => QuantityGuess(value, 'g', explicit: true),
        'lb' || 'lbs' => _toMetricMass(value, 'lb'),
        'oz' => _toMetricMass(value, 'oz'),
        _ => const QuantityGuess(1, 'piece'),
      };
    }

    final lead = _leadingCount.firstMatch(rawLine);
    if (lead != null) {
      final n = double.tryParse(lead.group(1)!) ?? 1;
      if (n >= 1 && n <= 30) {
        return QuantityGuess(n, 'piece', explicit: true);
      }
    }

    return const QuantityGuess(1, 'piece');
  }

  static QuantityGuess _toMetricMass(double value, String unit) {
    final grams = switch (unit) {
      'lb' => value * 453.592,
      'oz' => value * 28.35,
      'kg' => value * 1000,
      _ => value,
    };
    if (grams >= 1000) {
      return QuantityGuess(
          double.parse((grams / 1000).toStringAsFixed(2)), 'kg', explicit: true);
    }
    return QuantityGuess(
        double.parse(grams.toStringAsFixed(0)), 'g', explicit: true);
  }

  /// Split into lower-case word tokens, dropping the leading count token.
  static List<String> tokenize(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9%\s]'), ' ')
      .split(RegExp(r'\s+'))
      .where((t) => t.isNotEmpty)
      .toList();

  /// Expand abbreviations token-by-token; a mapped value may itself be two
  /// words ("whole wheat"), which we flatten back into the token list.
  static List<String> expand(List<String> tokens) {
    final out = <String>[];
    for (final t in tokens) {
      final mapped = kAbbreviations[t];
      if (mapped != null) {
        out.addAll(mapped.split(' '));
      } else {
        out.add(t);
      }
    }
    return out;
  }

  static const Map<String, String> _brandDisplay = {
    'gv': 'Great Value',
    'ks': 'Kirkland Signature',
    'pc': "President's Choice",
    'kirkland': 'Kirkland Signature',
  };

  /// Best-effort brand: the first brand phrase found in the token stream.
  static String? extractBrand(String cleanedLower) {
    for (final b in kBrands) {
      final re = RegExp(r'\b' + RegExp.escape(b) + r'\b');
      if (re.hasMatch(cleanedLower)) return _brandDisplay[b] ?? _titleCase(b);
    }
    return null;
  }

  /// Damerau-lite Levenshtein, capped for speed.
  static int editDistance(String a, String b) {
    if (a == b) return 0;
    if ((a.length - b.length).abs() > 2) return 3;
    final prev = List<int>.generate(b.length + 1, (i) => i);
    final curr = List<int>.filled(b.length + 1, 0);
    for (var i = 1; i <= a.length; i++) {
      curr[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        curr[j] = [
          curr[j - 1] + 1,
          prev[j] + 1,
          prev[j - 1] + cost,
        ].reduce((x, y) => x < y ? x : y);
      }
      for (var j = 0; j <= b.length; j++) {
        prev[j] = curr[j];
      }
    }
    return prev[b.length];
  }

  static bool fuzzyContains(Iterable<String> tokens, String target) {
    for (final t in tokens) {
      if (t == target) return true;
      if (t.length >= 4 && target.length >= 4 && editDistance(t, target) <= 1) {
        return true;
      }
    }
    return false;
  }

  static String titleCase(String input) => _titleCase(input);
}

String _titleCase(String input) => input
    .split(RegExp(r'\s+'))
    .where((w) => w.isNotEmpty)
    .map((w) => w.length == 1
        ? w.toUpperCase()
        : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
    .join(' ');
