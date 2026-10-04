/// Configuration fixée à la compilation.
///
/// Exemple pour une version de production :
///   flutter build apk --release --dart-define=SERVEUR=https://resto.exemple.ci
library;

abstract final class Configuration {
  /// Adresse du serveur proposée au premier lancement (modifiable sur l'écran de connexion).
  /// Par défaut : le PC de développement vu depuis l'émulateur Android.
  static const serveurParDefaut = String.fromEnvironment(
    'SERVEUR',
    defaultValue: '192.168.100.32:8000',
  );

  /// Contact du support, affiché dans l'écran « Aide ».
  static const contactSupport = 'termuxdev225@gmail.com';

  /// Durée d'affichage du résultat d'un scan avant de reprendre la lecture.
  static const dureeResultatAccepte = Duration(milliseconds: 1600);
  static const dureeResultatRefuse = Duration(milliseconds: 2800);

  /// Un même QR relu dans ce délai est ignoré (la caméra lit plusieurs fois par seconde).
  static const antiRebond = Duration(seconds: 3);
}
