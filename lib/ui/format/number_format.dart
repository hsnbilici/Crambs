/// TR locale ondalık ayırıcı: ','.
/// <10 → 1 ondalık; 10-999 → int; 1000-1e33 → short scale; >1e33 → scientific.
/// Spec: docs/superpowers/specs/2026-04-17-sprint-a-vertical-slice-design.md §4.4
String fmt(double n) {
  if (n.isNaN || n.isInfinite) return '—';
  if (n == 0) return '0';
  final original = n;
  final sign = n < 0 ? '-' : '';
  var work = n.abs();
  String raw;
  if (work < 10) {
    raw = work.toStringAsFixed(1);
  } else if (work < 1000) {
    raw = work.floor().toString();
  } else {
    const units = [
      'K',
      'M',
      'B',
      'T',
      'Qa',
      'Qi',
      'Sx',
      'Sp',
      'Oc',
      'No',
      'Dc'
    ];
    var tier = 0;
    // Divide by 1000 up to 11 times (units.length times)
    // Use > 999.5 to handle floating-point rounding near 1000
    for (var i = 0; i < units.length && work > 999.5; i++) {
      work /= 1000;
      tier++;
    }
    if (tier >= units.length && work > 999.5) {
      final exp = original.abs().toStringAsExponential(2);
      return '$sign${exp.replaceAll('.', ',')}';
    }
    if (tier == 0) {
      // Shouldn't happen in this branch (work >= 1000), but be safe
      return '$sign${work.floor()}';
    }
    raw = '${work.toStringAsFixed(work >= 100 ? 1 : 2)}${units[tier - 1]}';
  }
  return '$sign${raw.replaceAll('.', ',')}';
}
