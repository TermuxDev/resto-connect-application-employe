/// Comparaison de versions « MAJEURE.MINEURE.CORRECTIF » (le numéro de build est ignoré).
library;

bool estPlusAncienne(String installee, String minimale) {
  final a = _parties(installee);
  final b = _parties(minimale);
  for (var i = 0; i < 3; i++) {
    if (a[i] != b[i]) return a[i] < b[i];
  }
  return false;
}

List<int> _parties(String version) {
  final nombres = version
      .split('+')
      .first
      .split('.')
      .map((p) => int.tryParse(p) ?? 0)
      .toList();
  return [...nombres, 0, 0, 0].take(3).toList();
}
