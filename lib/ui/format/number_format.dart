/// TR locale ondalık ayırıcı: ','.
/// <10 → 1 ondalık; 10-999 → int; 1000-1e33 → short scale; >1e33 → scientific.
/// Spec: docs/superpowers/specs/2026-04-17-sprint-a-vertical-slice-design.md §4.4
String fmt(double n) {
  if (n.isNaN || n.isInfinite) return '—';
  if (n == 0) return '0';
  final sign = n < 0 ? '-' : '';
  var work = n.abs();
  String raw;
  if (work < 10) {
    raw = work.toStringAsFixed(1);
  } else if (work < _kTierThreshold) {
    raw = work.floor().toString();
  } else {
    const units = [
      'K', 'M', 'B', 'T', 'Qa', 'Qi', 'Sx', 'Sp', 'Oc', 'No', 'Dc', //
    ];
    var tier = 0;
    // Float precision: repeated /1000 drifts — 1e33 after 11 steps ≈ 999.9999.
    // _kTierThreshold absorbs that drift consistently on both gates.
    while (tier < units.length && work >= _kTierThreshold) {
      work /= 1000;
      tier++;
    }
    if (work >= _kTierThreshold) {
      final exp = n.abs().toStringAsExponential(2);
      return '$sign${exp.replaceAll('.', ',')}';
    }
    raw = '${work.toStringAsFixed(work >= 100 ? 1 : 2)}${units[tier - 1]}';
  }
  return '$sign${raw.replaceAll('.', ',')}';
}

const double _kTierThreshold = 999.5;
