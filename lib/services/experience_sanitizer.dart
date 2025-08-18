// lib/services/experience_sanitizer.dart
import 'package:intl/intl.dart';

class ExperienceSanitizer {
  /// Public: sanitize any incoming "experience" list into a predictable shape.
  static List<Map<String, dynamic>> sanitizeList(dynamic expData) {
    if (expData is! List) return [];

    return expData.map<Map<String, dynamic>>((raw) {
      final m = (raw is Map) ? Map<String, dynamic>.from(raw) : <String, dynamic>{};

      final title     = _s(m['title']);
      final company   = _s(m['company']);
      final location  = _s(m['location']);
      final start     = _s(m['startDate']);
      final end       = _s(m['endDate']);
      final duration  = _s(m['duration']);
      final details   = _normalizePoints(m['details']);

      // If dates missing but a single "dates"/"dateRange" exists, try to split it.
      final dateRange = _s(m['dates'].toString().isNotEmpty ? m['dates'] : m['dateRange']);
      final parsed = _maybeSplitDateRange(dateRange);
      final startFinal = start.isNotEmpty ? start : parsed.$1;
      final endFinal   = end.isNotEmpty   ? end   : parsed.$2;

      final displayDates = _formatDateRange(startFinal, endFinal);
      final displayDuration = duration.isNotEmpty ? duration : _computeDuration(startFinal, endFinal);

      return {
        'title': title,
        'company': company,
        'location': location,
        'startDate': startFinal,
        'endDate': endFinal,
        'duration': displayDuration,
        'details': details,
        'dates': displayDates, // convenience for UI/PDF
      }..removeWhere((k, v) => (v is String && v.trim().isEmpty) || (v is List && v.isEmpty));
    }).toList();
  }

  // ---------------- helpers ----------------

  static String _s(dynamic v) => (v ?? '').toString().trim();

  static List<String> _normalizePoints(dynamic details) {
    if (details is List) {
      return details
          .map((e) => e?.toString().trim() ?? '')
          .where((e) => e.isNotEmpty)
          .toList();
    }
    if (details is String && details.trim().isNotEmpty) return [details.trim()];
    return <String>[];
  }

  /// Try to split "Jan 2020 – Mar 2024" or "2020 - 2023"
  static (String, String) _maybeSplitDateRange(String range) {
    if (range.isEmpty) return ('', '');
    final r = range.replaceAll('—', '-').replaceAll('–', '-');
    final parts = r.split('-').map((e) => e.trim()).toList();
    if (parts.length == 2) {
      return (parts[0], parts[1]);
    }
    return ('', '');
  }

  /// Try to parse a wide range of human date formats to yyyy-MM
  static DateTime? _tryParse(String s) {
    if (s.isEmpty) return null;

    final candidates = <String>[
      'MMM yyyy', 'MMMM yyyy',
      'MM/yyyy', 'yyyy-MM', 'yyyy/MM',
      'yyyy',
    ];

    // quick fixes
    var str = s.replaceAll(RegExp(r'[^a-zA-Z0-9/ \-]'), '').trim();
    if (RegExp(r'^\d{4}$').hasMatch(str)) {
      // year only
      return DateTime(int.parse(str), 1, 1);
    }

    for (final f in candidates) {
      try {
        return DateFormat(f).parseStrict(str);
      } catch (_) {}
    }
    return null;
  }

  static String _formatDateRange(String start, String end) {
    if (start.isEmpty && end.isEmpty) return '';
    final s = _tryParse(start);
    final e = _tryParse(end);

    String fmt(DateTime d) {
      // Jan 2020
      return DateFormat('MMM yyyy').format(d);
    }

    if (s == null && e == null) {
      // fallback to raw strings
      if (start.isEmpty) return end;
      if (end.isEmpty) return start;
      return '$start – $end';
    }
    if (s != null && e == null) return fmt(s);
    if (s == null && e != null) return fmt(e);
    return '${fmt(s!)} – ${fmt(e!)}';
  }

  static String _computeDuration(String start, String end) {
    final s = _tryParse(start);
    final e = _tryParse(end) ?? DateTime.now();
    if (s == null) return '';

    int months = (e.year - s.year) * 12 + (e.month - s.month);
    if (months < 0) return '';

    final y = months ~/ 12;
    final m = months % 12;

    if (y > 0 && m > 0) return '$y yr ${m} mo';
    if (y > 0) return y == 1 ? '1 yr' : '$y yrs';
    if (m > 0) return m == 1 ? '1 mo' : '$m mo';
    return '';
  }
}
