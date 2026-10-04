/// Petits outils de rédaction des messages.
library;

/// « 0 plat », « 1 plat », « 3 plats » (en français, 0 et 1 sont au singulier).
String nombre(int n, String singulier, [String? pluriel]) =>
    '$n ${n.abs() > 1 ? (pluriel ?? '${singulier}s') : singulier}';
