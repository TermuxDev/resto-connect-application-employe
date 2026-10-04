/// Échanges avec le serveur : on ENVOIE d'abord les scans, puis on CHARGE les données à jour.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as chemin;
import 'package:path_provider/path_provider.dart';

import '../domaine/modeles.dart';
import '../donnees/client_api.dart';
import '../donnees/depot.dart';

class Bilan {
  const Bilan({
    required this.envoyes,
    required this.etudiantsMisAJour,
    required this.fraudes,
    this.nouveauType,
  });
  final int envoyes;
  final int etudiantsMisAJour;
  final int fraudes;

  /// Renseigné quand le gérant a changé le type d'étudiants contrôlés par ce terminal.
  final Statut? nouveauType;
}

class Synchroniseur {
  Synchroniseur(this._depot, this._api);

  final Depot _depot;
  final ClientApi _api;

  /// Chaque tentative est inscrite dans l'historique des envois, qu'elle réussisse ou non.
  Future<Bilan> synchroniser() async {
    var envoyes = 0;
    try {
      final (nombre, fraudes) = await _envoyer();
      envoyes = nombre;
      final (misAJour, nouveauType) = await _charger();
      await _depot.purgerAnciens(
        DateTime.now().subtract(const Duration(days: 7)),
      );
      await _depot.ecrire(
        'derniere_synchro',
        DateTime.now().toUtc().toIso8601String(),
      );
      await _depot.noterSynchronisation(
        Synchronisation(
          date: DateTime.now(),
          reussie: true,
          envoyes: envoyes,
          fiches: misAJour,
          fraudes: fraudes,
        ),
      );
      return Bilan(
        envoyes: envoyes,
        etudiantsMisAJour: misAJour,
        fraudes: fraudes,
        nouveauType: nouveauType,
      );
    } on Exception catch (erreur) {
      await _depot.noterSynchronisation(
        Synchronisation(
          date: DateTime.now(),
          reussie: false,
          envoyes: envoyes,
          message: switch (erreur) {
            HorsLigne() => 'pas de connexion au serveur',
            SessionExpiree() => 'il faut se reconnecter',
            RefusServeur(:final message) => message,
            _ => 'problème inattendu',
          },
        ),
      );
      rethrow;
    }
  }

  /// Push par lots de 5 000 : un lot n'est marqué « envoyé » qu'après la réponse du serveur.
  /// En cas de coupure, il sera renvoyé sans risque (le serveur ignore les doublons).
  Future<(int, int)> _envoyer() async {
    var envoyes = 0;
    var fraudes = 0;
    while (true) {
      final lot = await _depot.lotAEnvoyer();
      final passages = (lot['passages'] as List<dynamic>).length;
      if (passages == 0 && (lot['services'] as List<dynamic>).isEmpty) break;
      final bilan = await _api.envoyer(lot);
      await _depot.marquerEnvoyes(lot);
      envoyes += passages;
      fraudes += bilan['fraudes_detectees'] as int? ?? 0;
      if (passages < 5000) break;
    }
    return (envoyes, fraudes);
  }

  /// Vide la liste locale (autre terminal, ou type d'étudiants changé). Les repas en attente sont gardés.
  Future<void> reinitialiser() async =>
      _supprimer(await _depot.viderDonneesDuTerminal());

  Future<(int, Statut?)> _charger() async {
    final ancien = await _depot.terminal();
    var donnees = await _api.charger(await _depot.lire('curseur'));

    // Le gérant a changé le type contrôlé (internes <-> externes) : le chargement « depuis la dernière fois »
    // ne contiendrait pas tous les étudiants du nouveau type. On repart d'une liste vide et on charge tout.
    final recu = Terminal.depuisJson(
      donnees['terminal'] as Map<String, dynamic>,
    );
    final nouveauType = ancien != null && ancien.typeVerifie != recu.typeVerifie
        ? recu.typeVerifie
        : null;
    if (nouveauType != null) {
      await reinitialiser();
      donnees = await _api.charger(null);
    }

    final etudiants = [
      for (final json in donnees['etudiants'] as List<dynamic>)
        Etudiant.depuisApi(json as Map<String, dynamic>),
    ];

    await _depot.enregistrerEtudiants(etudiants);
    final photosObsoletes = await _depot.garderSeulement({
      ...(donnees['ids_actifs'] as List<dynamic>).cast<int>(),
    });
    await _depot.remplacerServisAilleurs([
      for (final repas in donnees['servis_aujourdhui'] as List<dynamic>)
        (
          (repas as Map)['etudiant'] as int,
          DateTime.parse(repas['date_heure'] as String),
        ),
    ]);
    await _depot.ecrire('parametres', jsonEncode(donnees['parametres']));
    await _depot.ecrire('terminal', jsonEncode(donnees['terminal']));

    await _telechargerPhotos(etudiants);
    await _supprimer(photosObsoletes);
    // Le curseur n'avance qu'une fois tout enregistré : un chargement interrompu sera repris en entier.
    await _depot.ecrire('curseur', donnees['curseur'] as String);
    return (etudiants.length, nouveauType);
  }

  /// Photos des fiches modifiées, 4 à la fois. Une photo manquante n'empêche pas la synchronisation.
  Future<void> _telechargerPhotos(List<Etudiant> etudiants) async {
    final dossier = Directory(
      chemin.join((await getApplicationSupportDirectory()).path, 'photos'),
    );
    await dossier.create(recursive: true);
    for (var i = 0; i < etudiants.length; i += 4) {
      await Future.wait(
        etudiants.skip(i).take(4).map((etudiant) async {
          // Pas (ou plus) de photo : on retire l'ancienne, l'écran affichera les initiales.
          if (!etudiant.aUnePhoto) {
            final ancienne = await _depot.oublierPhoto(etudiant.id);
            if (ancienne != null) await _supprimer([ancienne]);
            return;
          }
          try {
            // Nom unique par version de la fiche : l'écran n'affiche jamais une ancienne photo en cache.
            final version = etudiant.dateMaj.replaceAll(RegExp(r'\D'), '');
            final fichier = File(
              chemin.join(dossier.path, '${etudiant.id}_$version.jpg'),
            );
            await fichier.writeAsBytes(await _api.photo(etudiant.photoUrl));
            final ancienne = await _depot.enregistrerPhoto(
              etudiant.id,
              fichier.path,
            );
            if (ancienne != null) await _supprimer([ancienne]);
          } on Exception {
            // Photo indisponible : l'étudiant reste vérifiable, sans photo.
          }
        }),
      );
    }
  }

  Future<void> _supprimer(List<String> fichiers) async {
    for (final fichier in fichiers) {
      try {
        await File(fichier).delete();
      } on FileSystemException {
        // Déjà supprimé.
      }
    }
  }
}
