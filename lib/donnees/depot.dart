/// Accès à la base locale : étudiants, services, passages et réglages.
library;

import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../domaine/modeles.dart';

class Depot {
  Depot(this._base);

  final Database _base;

  // --- Réglages (clé / valeur) ---

  Future<String?> lire(String cle) async {
    final lignes = await _base.query(
      'reglages',
      where: 'cle = ?',
      whereArgs: [cle],
    );
    return lignes.isEmpty ? null : lignes.first['valeur']! as String;
  }

  Future<void> ecrire(String cle, String? valeur) async {
    if (valeur == null) {
      await _base.delete('reglages', where: 'cle = ?', whereArgs: [cle]);
    } else {
      await _base.insert('reglages', {
        'cle': cle,
        'valeur': valeur,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<Terminal?> terminal() async {
    final texte = await lire('terminal');
    return texte == null
        ? null
        : Terminal.depuisJson(jsonDecode(texte) as Map<String, dynamic>);
  }

  Future<Parametres?> parametres() async {
    final texte = await lire('parametres');
    return texte == null
        ? null
        : Parametres.depuisJson(jsonDecode(texte) as Map<String, dynamic>);
  }

  // --- Étudiants ---

  Future<Etudiant?> etudiantParQr(String qr) async {
    final lignes = await _base.query(
      'etudiants',
      where: 'qr_jeton = ?',
      whereArgs: [qr],
    );
    return lignes.isEmpty ? null : Etudiant.depuisLigne(lignes.first);
  }

  Future<int> nombreEtudiants() async =>
      Sqflite.firstIntValue(
        await _base.rawQuery('SELECT COUNT(*) FROM etudiants'),
      ) ??
      0;

  /// Remplace les fiches reçues du serveur ; la photo locale est conservée tant qu'elle n'est pas renouvelée.
  Future<void> enregistrerEtudiants(List<Etudiant> etudiants) async {
    final lot = _base.batch();
    for (final etudiant in etudiants) {
      // Un même QR ne peut appartenir qu'à un étudiant : l'ancien porteur (carte renouvelée) est retiré.
      lot.delete(
        'etudiants',
        where: 'qr_jeton = ? AND id != ?',
        whereArgs: [etudiant.qrJeton, etudiant.id],
      );
      // « Insérer sinon mettre à jour », compatible avec le SQLite des anciens Android (sans UPSERT).
      final ligne = etudiant.versLigne();
      lot.insert(
        'etudiants',
        ligne,
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      lot.update('etudiants', ligne, where: 'id = ?', whereArgs: [etudiant.id]);
    }
    await lot.commit(noResult: true);
  }

  /// Supprime les étudiants qui ne font plus partie de ceux contrôlés par ce terminal.
  Future<List<String>> garderSeulement(Set<int> idsActifs) async {
    final absents = (await _base.query(
      'etudiants',
      columns: ['id', 'photo_chemin'],
    )).where((ligne) => !idsActifs.contains(ligne['id'])).toList();
    for (final ligne in absents) {
      await _base.delete(
        'etudiants',
        where: 'id = ?',
        whereArgs: [ligne['id']],
      );
    }
    return [
      for (final ligne in absents)
        if (ligne['photo_chemin'] != null) ligne['photo_chemin']! as String,
    ];
  }

  /// Enregistre la nouvelle photo et renvoie le chemin de l'ancienne (à supprimer).
  Future<String?> enregistrerPhoto(int etudiant, String photoChemin) async {
    final lignes = await _base.query(
      'etudiants',
      columns: ['photo_chemin'],
      where: 'id = ?',
      whereArgs: [etudiant],
    );
    await _base.update(
      'etudiants',
      {'photo_chemin': photoChemin},
      where: 'id = ?',
      whereArgs: [etudiant],
    );
    final ancienne = lignes.isEmpty
        ? null
        : lignes.first['photo_chemin'] as String?;
    return ancienne == photoChemin ? null : ancienne;
  }

  /// La photo a été retirée sur le serveur : on l'oublie et on renvoie le fichier local à supprimer.
  Future<String?> oublierPhoto(int etudiant) async {
    final lignes = await _base.query(
      'etudiants',
      columns: ['photo_chemin'],
      where: 'id = ?',
      whereArgs: [etudiant],
    );
    await _base.update(
      'etudiants',
      {'photo_chemin': null},
      where: 'id = ?',
      whereArgs: [etudiant],
    );
    return lignes.isEmpty ? null : lignes.first['photo_chemin'] as String?;
  }

  Future<void> retirerUnPlat(int etudiant) => _base.rawUpdate(
    'UPDATE etudiants SET solde_plats = solde_plats - 1 WHERE id = ?',
    [etudiant],
  );

  // --- Repas du jour ---

  /// Repas servis à cet étudiant entre [debut] et [fin], ici et sur les autres terminaux.
  Future<List<DateTime>> repasEntre(
    int etudiant,
    DateTime debut,
    DateTime fin,
  ) async {
    final bornes = [etudiant, debut.toIso8601String(), fin.toIso8601String()];
    final lignes = await _base.rawQuery(
      '''SELECT date_heure FROM passages WHERE etudiant = ? AND accepte = 1 AND date_heure >= ? AND date_heure < ?
         UNION ALL
         SELECT date_heure FROM servis_ailleurs WHERE etudiant = ? AND date_heure >= ? AND date_heure < ?''',
      [...bornes, ...bornes],
    );
    return [
      for (final ligne in lignes)
        DateTime.parse(ligne['date_heure']! as String),
    ];
  }

  Future<void> remplacerServisAilleurs(List<(int, DateTime)> servis) async {
    final lot = _base.batch()..delete('servis_ailleurs');
    for (final (etudiant, dateHeure) in servis) {
      lot.insert('servis_ailleurs', {
        'etudiant': etudiant,
        'date_heure': dateHeure.toUtc().toIso8601String(),
      });
    }
    await lot.commit(noResult: true);
  }

  // --- Services et passages ---

  Future<Service?> serviceOuvert() async {
    final lignes = await _base.query(
      'services',
      where: 'cloture IS NULL',
      orderBy: 'ouverture DESC',
      limit: 1,
    );
    return lignes.isEmpty ? null : Service.depuisLigne(lignes.first);
  }

  Future<void> ouvrirService(Service service) => _base.insert('services', {
    'id': service.id,
    'creneau': service.creneau.code,
    'ouverture': service.ouverture.toUtc().toIso8601String(),
  });

  /// La clôture doit être renvoyée au serveur : le service repasse « à envoyer ».
  Future<void> cloturerService(String id, DateTime cloture) => _base.update(
    'services',
    {'cloture': cloture.toUtc().toIso8601String(), 'envoye': 0},
    where: 'id = ?',
    whereArgs: [id],
  );

  /// Enregistre un repas validé (les colonnes `accepte` / `motif_refus` de la version 1 ne servent plus).
  Future<void> enregistrerRepas(Passage repas) => _base.insert('passages', {
    'id': repas.id,
    'service': repas.service,
    'etudiant': repas.etudiant,
    'date_heure': repas.dateHeure.toUtc().toIso8601String(),
    'accepte': 1,
  });

  Future<int> servisDuService(String service) async =>
      Sqflite.firstIntValue(
        await _base.rawQuery(
          'SELECT COUNT(*) FROM passages WHERE service = ? AND accepte = 1',
          [service],
        ),
      ) ??
      0;

  Future<int> passagesEnAttente() async =>
      Sqflite.firstIntValue(
        await _base.rawQuery('SELECT COUNT(*) FROM passages WHERE envoye = 0'),
      ) ??
      0;

  /// Lot à envoyer au serveur, au format de l'API (`POST /api/sync/push/`).
  Future<Map<String, dynamic>> lotAEnvoyer() async {
    final services = await _base.query('services', where: 'envoye = 0');
    final passages = await _base.query(
      'passages',
      where: 'envoye = 0 AND accepte = 1',
      limit: 5000,
    );
    return {
      'services': [
        for (final s in services)
          {
            'id': s['id'],
            'creneau': s['creneau'],
            'ouverture': s['ouverture'],
            'cloture': s['cloture'],
          },
      ],
      'passages': [
        for (final p in passages)
          {
            'id': p['id'],
            'service': p['service'],
            'etudiant': p['etudiant'],
            'date_heure': p['date_heure'],
          },
      ],
    };
  }

  Future<void> marquerEnvoyes(Map<String, dynamic> lot) async {
    final lotSql = _base.batch();
    for (final service in lot['services'] as List<dynamic>) {
      lotSql.update(
        'services',
        {'envoye': 1},
        where: 'id = ?',
        whereArgs: [(service as Map)['id']],
      );
    }
    for (final passage in lot['passages'] as List<dynamic>) {
      lotSql.update(
        'passages',
        {'envoye': 1},
        where: 'id = ?',
        whereArgs: [(passage as Map)['id']],
      );
    }
    await lotSql.commit(noResult: true);
  }

  // --- Écran « Envois » ---

  /// Repas validés mais pas encore envoyés au serveur, du plus récent au plus ancien.
  Future<List<RepasEnAttente>> repasEnAttente() async {
    final lignes = await _base.rawQuery('''
      SELECT e.prenom, e.nom, p.date_heure FROM passages p
      LEFT JOIN etudiants e ON e.id = p.etudiant
      WHERE p.envoye = 0 ORDER BY p.date_heure DESC''');
    return [
      for (final ligne in lignes)
        (
          nom: ligne['prenom'] == null
              ? 'Étudiant retiré de la liste'
              : '${ligne['prenom']} ${ligne['nom']}',
          dateHeure: DateTime.parse(ligne['date_heure']! as String).toLocal(),
        ),
    ];
  }

  Future<void> noterSynchronisation(Synchronisation synchro) async {
    await _base.insert('synchronisations', synchro.versLigne());
    // On ne garde que les 100 dernières.
    await _base.rawDelete(
      'DELETE FROM synchronisations WHERE id NOT IN '
      '(SELECT id FROM synchronisations ORDER BY id DESC LIMIT 100)',
    );
  }

  Future<List<Synchronisation>> synchronisations() async => [
    for (final ligne in await _base.query(
      'synchronisations',
      orderBy: 'id DESC',
      limit: 50,
    ))
      Synchronisation.depuisLigne(ligne),
  ];

  /// Nettoyage : les passages envoyés de plus de 7 jours ne servent plus au terminal.
  Future<void> purgerAnciens(DateTime limite) async {
    final date = limite.toUtc().toIso8601String();
    await _base.delete(
      'passages',
      where: 'envoye = 1 AND date_heure < ?',
      whereArgs: [date],
    );
    await _base.delete(
      'services',
      where:
          'envoye = 1 AND cloture IS NOT NULL AND cloture < ? AND id NOT IN (SELECT service FROM passages)',
      whereArgs: [date],
    );
  }

  /// Changement de terminal, ou de type d'étudiants contrôlés : on repart d'une liste vide.
  /// Les repas en attente d'envoi ne sont pas touchés. Renvoie les photos à supprimer.
  Future<List<String>> viderDonneesDuTerminal() async {
    final photos = await _base.query(
      'etudiants',
      columns: ['photo_chemin'],
      where: 'photo_chemin IS NOT NULL',
    );
    final lot = _base.batch()
      ..delete('etudiants')
      ..delete('servis_ailleurs')
      ..delete(
        'reglages',
        where: 'cle IN (?, ?, ?)',
        whereArgs: ['curseur', 'terminal', 'parametres'],
      );
    await lot.commit(noResult: true);
    return [for (final ligne in photos) ligne['photo_chemin']! as String];
  }
}
