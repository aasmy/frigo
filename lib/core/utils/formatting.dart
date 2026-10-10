import 'package:intl/intl.dart';

/// Small formatting helpers shared across screens.
class Fmt {
  const Fmt._();

  static final _mdy = DateFormat('MMM d, yyyy');
  static final _md = DateFormat('MMM d');

  static String date(DateTime d) => _mdy.format(d);

  static String shortDate(DateTime d) => _md.format(d);

  static String relativeDay(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(d.year, d.month, d.day);
    final diff = target.difference(today).inDays;
    return switch (diff) {
      0 => 'Today',
      1 => 'Tomorrow',
      -1 => 'Yesterday',
      < 0 => '${-diff} days ago',
      < 7 => 'In $diff days',
      _ => _md.format(d),
    };
  }

  /// "just now" / "5 min ago" / "2 h ago" / a date.
  static String relativeTime(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inSeconds < 45) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} h ago';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return _md.format(t);
  }

  static String greeting([DateTime? now]) {
    final hour = (now ?? DateTime.now()).hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  static String quantity(double value, String unit) {
    final q = value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
    return unit.isEmpty ? q : '$q $unit';
  }
}
