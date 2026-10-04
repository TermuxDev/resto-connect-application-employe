/// Client de l'API des terminaux (contrat : ARCHITECTURE.md, section 5).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// Pas de réseau, serveur injoignable ou trop lent : le terminal continue hors ligne.
class HorsLigne implements Exception {
  const HorsLigne();
}

/// Les jetons ne sont plus valables : il faut se reconnecter (les scans restent en attente).
class SessionExpiree implements Exception {
  const SessionExpiree();
}

/// Refus explicite du serveur, avec un message à afficher.
class RefusServeur implements Exception {
  const RefusServeur(this.message);
  final String message;
}

class ClientApi {
  ClientApi({required this.version});

  /// Version de l'application, transmise à chaque requête (suivi des déploiements côté serveur).
  final String version;
  String serveur = '';

  final _coffre = const FlutterSecureStorage();
  final _http = http.Client();
  static const _delai = Duration(seconds: 20);

  Future<bool> aUneSession() async =>
      await _coffre.read(key: 'refresh') != null;

  Future<void> oublierSession() => _coffre.deleteAll();

  Uri _adresse(String route, [Map<String, String>? parametres]) =>
      Uri.parse('$serveur$route').replace(queryParameters: parametres);

  // --- Routes ---

  Future<Map<String, dynamic>> connexion(
    String telephone,
    String motDePasse,
  ) async {
    final reponse = await _envoyer(
      () => _http.post(
        _adresse('/api/auth/token/'),
        headers: _entetes(),
        body: jsonEncode({'telephone': telephone, 'password': motDePasse}),
      ),
    );
    if (reponse.statusCode == 401) {
      throw const RefusServeur(
        'Identifiants incorrects. Utilisez le compte du terminal donné par le gérant.',
      );
    }
    if (reponse.statusCode == 429) {
      throw const RefusServeur(
        'Trop de tentatives. Réessayez dans une minute.',
      );
    }
    final donnees = _json(reponse);
    await _coffre.write(key: 'access', value: donnees['access'] as String);
    await _coffre.write(key: 'refresh', value: donnees['refresh'] as String);
    return donnees;
  }

  Future<Map<String, dynamic>> heure() async =>
      _json(await _envoyer(() => _http.get(_adresse('/api/heure/'))));

  Future<Map<String, dynamic>> charger(String? curseur) async => _json(
    await _authentifie(
      (entetes) => _http.get(
        _adresse(
          '/api/sync/pull/',
          curseur == null ? null : {'depuis': curseur},
        ),
        headers: entetes,
      ),
    ),
  );

  Future<Map<String, dynamic>> envoyer(Map<String, dynamic> lot) async => _json(
    await _authentifie(
      (entetes) => _http.post(
        _adresse('/api/sync/push/'),
        headers: entetes,
        body: jsonEncode(lot),
      ),
    ),
  );

  Future<List<int>> photo(String url) async => (await _authentifie(
    (entetes) => _http.get(Uri.parse(url), headers: entetes),
  )).bodyBytes;

  // --- Mécanique ---

  Map<String, String> _entetes([String? jeton]) => {
    'Content-Type': 'application/json',
    'X-Application-Version': version,
    if (jeton != null) 'Authorization': 'Bearer $jeton',
  };

  /// Requête authentifiée : en cas de jeton expiré, il est renouvelé une fois puis la requête est rejouée.
  Future<http.Response> _authentifie(
    Future<http.Response> Function(Map<String, String>) requete,
  ) async {
    var reponse = await _envoyer(
      () async => requete(_entetes(await _coffre.read(key: 'access'))),
    );
    if (reponse.statusCode == 401) {
      await _renouveler();
      reponse = await _envoyer(
        () async => requete(_entetes(await _coffre.read(key: 'access'))),
      );
    }
    if (reponse.statusCode == 401 || reponse.statusCode == 403) {
      throw const SessionExpiree();
    }
    return reponse;
  }

  Future<void> _renouveler() async {
    final refresh = await _coffre.read(key: 'refresh');
    if (refresh == null) throw const SessionExpiree();
    final reponse = await _envoyer(
      () => _http.post(
        _adresse('/api/auth/token/refresh/'),
        headers: _entetes(),
        body: jsonEncode({'refresh': refresh}),
      ),
    );
    if (reponse.statusCode != 200) throw const SessionExpiree();
    final donnees = _json(reponse);
    await _coffre.write(key: 'access', value: donnees['access'] as String);
    if (donnees['refresh'] != null) {
      await _coffre.write(key: 'refresh', value: donnees['refresh'] as String);
    }
  }

  Future<http.Response> _envoyer(
    Future<http.Response> Function() requete,
  ) async {
    if (serveur.isEmpty) {
      throw const RefusServeur('Indiquez l\'adresse du serveur.');
    }
    try {
      return await requete().timeout(_delai);
    } on SocketException {
      throw const HorsLigne();
    } on TimeoutException {
      throw const HorsLigne();
    } on http.ClientException {
      throw const HorsLigne();
    }
  }

  Map<String, dynamic> _json(http.Response reponse) {
    if (reponse.statusCode >= 500) {
      throw const RefusServeur(
        'Le serveur rencontre un problème. Réessayez dans quelques minutes.',
      );
    }
    if (reponse.statusCode >= 400) {
      throw const RefusServeur(
        'Le serveur a refusé l\'opération. Réessayez ; si cela continue, prévenez le gérant.',
      );
    }
    return jsonDecode(utf8.decode(reponse.bodyBytes)) as Map<String, dynamic>;
  }
}
