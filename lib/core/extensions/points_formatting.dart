// lib/core/extensions/points_formatting.dart

/// ════════════════════════════════════════════════════════════════════
/// Points Display Formatting
///
/// Backend stores point amounts as Decimal(7, 3) — up to 3 fractional
/// digits. The UI must always normalize to exactly 2 decimals
/// (e.g. 92.6234 → "92.62", 92 → "92.00").
///
/// This is the *single source of truth* for points display.
/// Never call `.toString()` or `.toStringAsFixed(n)` on points directly
/// in widgets — always use `.asPoints`.
///
/// Ref (Dart core):
///   https://api.dart.dev/stable/dart-core/num/toStringAsFixed.html
/// ════════════════════════════════════════════════════════════════════

extension PointsFormatting on num {
  /// Value formatted with exactly 2 decimal places.
  ///
  ///   92.6234.asPoints   // "92.62"
  ///   92.asPoints        // "92.00"
  ///   (-3.5).asPoints    // "-3.50"
  String get asPoints => toStringAsFixed(2);

  /// Number + the Arabic suffix "نقطة".
  String get asPointsWithLabel => '${toStringAsFixed(2)} نقطة';
}

/// Safe variant for nullable numeric values (API aggregates can be null).
extension PointsFormattingNullable on num? {
  String get asPoints => (this ?? 0).toStringAsFixed(2);
  String get asPointsWithLabel => '${(this ?? 0).toStringAsFixed(2)} نقطة';
}

/// Prisma's `Decimal` type serializes to JSON as a String by default
/// (e.g. `"92.625"`). This variant normalizes raw API strings so callers
/// don't need to `double.parse` at every use site.
extension PointsFromString on String? {
  String get asPoints {
    final raw = this;
    if (raw == null || raw.isEmpty) return '0.00';
    final parsed = double.tryParse(raw);
    return (parsed ?? 0).toStringAsFixed(2);
  }

  String get asPointsWithLabel => '$asPoints نقطة';
}