/// Mise en forme de l'adresse du serveur saisie par l'utilisateur.
library;

/// « 192.168.1.20:8000 » → « http://192.168.1.20:8000 ».
/// Le protocole est ajouté s'il manque ; les espaces, le chemin et la barre finale sont retirés.
/// Renvoie null si l'adresse est inutilisable.
String? normaliserAdresse(String saisie) {
  var adresse = saisie.trim();
  if (adresse.isEmpty) return null;
  if (!adresse.contains('://')) adresse = 'http://$adresse';

  final uri = Uri.tryParse(adresse);
  if (uri == null ||
      !const {'http', 'https'}.contains(uri.scheme) ||
      uri.host.isEmpty) {
    return null;
  }
  return Uri(
    scheme: uri.scheme,
    host: uri.host,
    port: uri.hasPort ? uri.port : null,
  ).toString();
}
