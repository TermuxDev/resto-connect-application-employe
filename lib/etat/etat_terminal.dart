/// État de l'application : ce que les écrans affichent et les actions qu'ils déclenchent.
library;

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../config/configuration.dart';
import '../domaine/adresse.dart';
import '../domaine/modeles.dart';
import '../domaine/texte.dart';
import '../domaine/verification.dart';
import '../domaine/version.dart';
import '../donnees/client_api.dart';
import '../donnees/depot.dart';
import '../synchronisation/synchroniseur.dart';

enum Phase { demarrage, connexion, miseAJourRequise, accueil, service }

class EtatTerminal extends ChangeNotifier {
  EtatTerminal({required Depot depot, required ClientApi api})
    : _depot = depot,
      _api = api,
      _synchroniseur = Synchroniseur(depot, api);

  final Depot _depot;
  final ClientApi _api;
  final Synchroniseur _synchroniseur;
  static const _uuid = Uuid();

  Phase phase = Phase.demarrage;
  Terminal? terminal;
  Parametres? parametres;
  Service? service;
  int etudiantsCharges = 0;
  int enAttente = 0;
  int servisDuService = 0;
  DateTime? derniereSynchro;

  /// Écart entre l'horloge du téléphone et celle du serveur (null tant qu'inconnu).
  Duration? ecartHorloge;
  String? versionMinimale;
  bool occupe = false;
  bool horsLigne = false;

  String get version => _api.version;
  String get serveur => _api.serveur;
  bool get pret =>
      terminal != null && parametres != null && etudiantsCharges > 0;
  bool get horlogeDereglee => (ecartHorloge?.inMinutes.abs() ?? 0) >= 3;

  // --- Démarrage et connexion ---

  Future<void> demarrer() async {
    final enregistree =
        await _depot.lire('serveur') ?? Configuration.serveurParDefaut;
    _api.serveur = normaliserAdresse(enregistree) ?? '';
    terminal = await _depot.terminal();
    service = await _depot.serviceOuvert();
    await _rafraichirCompteurs();

    if (!await _api.aUneSession() || terminal == null) {
      phase = Phase.connexion;
    } else {
      // Un service resté ouvert s'affiche sur l'accueil, prêt à être repris ou terminé.
      phase = Phase.accueil;
      notifyListeners();
      // Mise à jour automatique au démarrage (si le réseau le permet) : un changement fait
      // par le gérant (type d'étudiants, nouvelles inscriptions, recharges) est pris en compte.
      await _controlerServeur();
      if (!horsLigne && phase == Phase.accueil) await rechercherMisesAJour();
    }
    notifyListeners();
  }

  /// Renvoie un message d'erreur à afficher, ou null si la connexion a réussi.
  Future<String?> connecter(
    String serveur,
    String telephone,
    String motDePasse,
  ) async {
    final adresse = normaliserAdresse(serveur);
    if (adresse == null) return _adresseInvalide;
    return _action(() async {
      _api.serveur = adresse;
      await _depot.ecrire('serveur', adresse);
      final reponse = await _api.connexion(telephone.trim(), motDePasse);
      final nouveau = Terminal.depuisJson(
        reponse['terminal'] as Map<String, dynamic>,
      );

      // Un autre terminal sur ce téléphone : on repart de sa propre liste d'étudiants.
      if (terminal != null && terminal!.id != nouveau.id) {
        await _synchroniseur.reinitialiser();
      }
      terminal = nouveau;
      phase = Phase.accueil;
      await _controlerServeur();
      await _synchroniser();
    });
  }

  /// Une déconnexion n'est possible qu'une fois tous les scans envoyés.
  Future<String?> deconnecter() async {
    if (enAttente > 0) {
      return 'Envoyez d\'abord les ${nombre(enAttente, 'repas', 'repas')} en attente (menu « Envois »).';
    }
    if (service != null) return 'Terminez d\'abord le service en cours.';
    await _api.oublierSession();
    phase = Phase.connexion;
    notifyListeners();
    return null;
  }

  /// Heure du serveur (écart d'horloge) et version minimale exigée.
  Future<void> _controlerServeur() async {
    try {
      final reponse = await _api.heure();
      ecartHorloge = DateTime.now().toUtc().difference(
        DateTime.parse(reponse['heure'] as String),
      );
      versionMinimale = reponse['version_min_application'] as String?;
      if (versionMinimale != null &&
          estPlusAncienne(version, versionMinimale!)) {
        phase = Phase.miseAJourRequise;
      }
      horsLigne = false;
    } on HorsLigne {
      horsLigne = true;
    }
  }

  // --- Synchronisation ---

  /// Bouton « Rechercher les mises à jour ». Renvoie un message à afficher.
  Future<String?> rechercherMisesAJour() async {
    String? resultat;
    final erreur = await _action(() async {
      await _controlerServeur();
      resultat = await _synchroniser();
    });
    return erreur ?? resultat;
  }

  Future<String> _synchroniser() async {
    final bilan = await _synchroniseur.synchroniser();
    parametres = await _depot.parametres();
    terminal = await _depot.terminal();
    horsLigne = false;
    await _rafraichirCompteurs();
    final envoyes = bilan.envoyes > 0
        ? ' ${nombre(bilan.envoyes, 'repas envoyé', 'repas envoyés')}.'
        : '';
    if (bilan.nouveauType != null) {
      return 'Ce terminal contrôle maintenant les ${bilan.nouveauType!.pluriel} : '
          'la liste des étudiants a été rechargée.$envoyes';
    }
    return 'Tout est à jour.$envoyes';
  }

  // --- Service ---

  Future<void> demarrerService() async {
    final maintenant = DateTime.now();
    final creneau = terminal!.typeVerifie == Statut.externe
        ? Creneau.libre
        : parametres!.creneau(maintenant) ?? _prochainCreneau(maintenant);
    service = Service(id: _uuid.v4(), creneau: creneau, ouverture: maintenant);
    await _depot.ouvrirService(service!);
    servisDuService = 0;
    phase = Phase.service;
    notifyListeners();
  }

  Creneau _prochainCreneau(DateTime instant) {
    final heure = parametres!.heureRestaurant(instant);
    return heure.hour * 60 + heure.minute < parametres!.soirDebut &&
            heure.hour * 60 + heure.minute > parametres!.midiFin
        ? Creneau.soir
        : Creneau.midi;
  }

  /// Revenir au menu sans terminer le service : il reste ouvert et peut être repris.
  void retourMenu() {
    phase = Phase.accueil;
    notifyListeners();
  }

  void reprendreService() {
    phase = Phase.service;
    notifyListeners();
  }

  /// Étape 1 du scan : vérifier, SANS rien enregistrer. Le repas n'est compté qu'à la validation.
  Future<Verdict> verifierQr(String qr) async {
    final maintenant = DateTime.now();
    final etudiant = await _depot.etudiantParQr(qr.trim());
    final (debut, fin) = parametres!.journee(maintenant);
    return verifier(
      etudiant: etudiant,
      terminal: terminal!,
      parametres: parametres!,
      maintenant: maintenant,
      repasDuJour: etudiant == null
          ? const []
          : await _depot.repasEntre(etudiant.id, debut, fin),
    );
  }

  /// Étape 2 : l'employé appuie sur « Valider ». La vérification est REFAITE à cet instant
  /// (solde et repas à jour) : un second badge du même étudiant ne peut pas passer.
  Future<Verdict> validerRepas(Verdict verdict) async {
    if (_validationEnCours || !verdict.accepte) return verdict;
    _validationEnCours = true;
    try {
      final controle = await verifierQr(verdict.etudiant!.qrJeton);
      if (!controle.accepte) return controle;

      final etudiant = controle.etudiant!;
      await _depot.enregistrerRepas(
        Passage(
          id: _uuid.v4(),
          service: service!.id,
          etudiant: etudiant.id,
          dateHeure: DateTime.now(),
        ),
      );
      if (etudiant.statut == Statut.externe) {
        await _depot.retirerUnPlat(etudiant.id);
      }
      await _rafraichirCompteurs();
      notifyListeners();
      return controle;
    } finally {
      _validationEnCours = false;
    }
  }

  bool _validationEnCours = false;

  /// Bouton « Terminer le service » : clôture, puis tentative d'envoi.
  /// Hors ligne, les repas restent en attente et partiront au prochain envoi.
  Future<String?> terminerService() async {
    await _depot.cloturerService(service!.id, DateTime.now());
    service = null;
    phase = Phase.accueil;
    notifyListeners();
    return rechercherMisesAJour();
  }

  // --- Écran « Envois » ---

  Future<List<RepasEnAttente>> repasEnAttente() => _depot.repasEnAttente();

  Future<List<Synchronisation>> historiqueDesEnvois() =>
      _depot.synchronisations();

  // --- Outils ---

  Future<void> _rafraichirCompteurs() async {
    parametres = await _depot.parametres();
    etudiantsCharges = await _depot.nombreEtudiants();
    enAttente = await _depot.passagesEnAttente();
    servisDuService = service == null
        ? 0
        : await _depot.servisDuService(service!.id);
    final synchro = await _depot.lire('derniere_synchro');
    derniereSynchro = synchro == null
        ? null
        : DateTime.parse(synchro).toLocal();
  }

  static const _adresseInvalide =
      'Adresse du serveur invalide. Exemple : http://192.168.1.20:8000';

  /// Exécute une action réseau ; renvoie un message d'erreur lisible, ou null si tout s'est bien passé.
  Future<String?> _action(Future<void> Function() action) async {
    occupe = true;
    notifyListeners();
    try {
      await action();
      return null;
    } on HorsLigne {
      horsLigne = true;
      return 'Pas de connexion au serveur. Vous pouvez continuer à servir : les repas seront envoyés plus tard.';
    } on SessionExpiree {
      phase = Phase.connexion;
      return 'Reconnectez-vous pour continuer. Les repas en attente sont gardés sur le téléphone.';
    } on RefusServeur catch (refus) {
      return refus.message;
    } on FormatException {
      return _adresseInvalide;
    } on Exception {
      // Filet de sécurité : jamais de plantage, toujours un message lisible.
      return 'Un problème est survenu. Réessayez ; s\'il continue, prévenez le gérant.';
    } finally {
      occupe = false;
      await _rafraichirCompteurs();
      notifyListeners();
    }
  }
}
