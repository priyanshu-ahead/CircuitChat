import 'package:intl/intl.dart';

/// Date/time formatting utilities (replaces moment.js).
extension AppDateTimeExtensions on DateTime {
  /// e.g. "2:30 PM"
  String get timeFormatted => DateFormat.jm().format(this);

  /// e.g. "Mon, Aug 21"
  String get shortDate => DateFormat('EEE, MMM d').format(this);

  /// e.g. "August 21, 2026"
  String get longDate => DateFormat('MMMM d, y').format(this);

  /// e.g. "21/08/2026"
  String get numericDate => DateFormat('dd/MM/yyyy').format(this);

  /// Chat list timestamp: "2:30 PM", "Yesterday", or "Mon"
  String get chatListTimestamp {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(year, month, day);
    final diff = today.difference(msgDay).inDays;
    if (diff == 0) return timeFormatted;
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return DateFormat.E().format(this); // Mon, Tue …
    return numericDate;
  }

  /// Returns "just now", "5 min ago", "2 hr ago", "3 days ago".
  String get timeAgo {
    final diff = DateTime.now().difference(this);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return shortDate;
  }

  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }

  bool get isYesterday {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return year == yesterday.year &&
        month == yesterday.month &&
        day == yesterday.day;
  }
}

/// Parse ISO-8601 string safely, returning null on failure.
DateTime? tryParseIso(String? value) {
  if (value == null || value.isEmpty) return null;
  return DateTime.tryParse(value);
}
