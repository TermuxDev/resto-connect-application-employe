/// Base SQLite locale : le terminal y travaille hors ligne.
///
/// RÈGLE POUR LES MISES À JOUR EN PRODUCTION
/// - Ne JAMAIS modifier une migration déjà publiée : en ajouter une nouvelle à la fin de [migrations].
/// - Une migration ne doit jamais supprimer de passages ou de services non envoyés (`envoye = 0`).
/// - La version de la base est simplement le nombre de migrations.
library;

import 'package:path/path.dart' as chemin;
import 'package:sqflite/sqflite.dart';

const migrations = <List<String>>[
  // 1 — Version initiale (application 1.0.0).
  [
    '''CREATE TABLE etudiants (
         id INTEGER PRIMARY KEY,
         qr_jeton TEXT NOT NULL UNIQUE,
         nom TEXT NOT NULL,
         prenom TEXT NOT NULL,
         statut TEXT NOT NULL,
         solde_plats INTEGER NOT NULL,
         fin_abonnement TEXT,
         carte_bloquee INTEGER NOT NULL,
         photo_url TEXT NOT NULL,
         photo_chemin TEXT,
         date_maj TEXT NOT NULL)''',
    '''CREATE TABLE services (
         id TEXT PRIMARY KEY,
         creneau TEXT NOT NULL,
         ouverture TEXT NOT NULL,
         cloture TEXT,
         envoye INTEGER NOT NULL DEFAULT 0)''',
    '''CREATE TABLE passages (
         id TEXT PRIMARY KEY,
         service TEXT NOT NULL REFERENCES services(id),
         etudiant INTEGER,
         date_heure TEXT NOT NULL,
         accepte INTEGER NOT NULL,
         motif_refus TEXT,
         envoye INTEGER NOT NULL DEFAULT 0)''',
    'CREATE INDEX passages_etudiant ON passages(etudiant, date_heure)',
    // Repas servis aujourd'hui sur les autres terminaux (remplacés à chaque chargement).
    'CREATE TABLE servis_ailleurs (etudiant INTEGER NOT NULL, date_heure TEXT NOT NULL)',
    'CREATE TABLE reglages (cle TEXT PRIMARY KEY, valeur TEXT NOT NULL)',
  ],
  // 2 — Historique des envois ; les refus ne sont plus enregistrés (1.0.0, phase de test).
  [
    '''CREATE TABLE synchronisations (
         id INTEGER PRIMARY KEY AUTOINCREMENT,
         date TEXT NOT NULL,
         reussie INTEGER NOT NULL,
         envoyes INTEGER NOT NULL DEFAULT 0,
         fiches INTEGER NOT NULL DEFAULT 0,
         fraudes INTEGER NOT NULL DEFAULT 0,
         message TEXT)''',
    // Les refus n'ont plus de valeur (ni au comptoir, ni pour le gérant) : seuls les repas servis restent.
    'DELETE FROM passages WHERE accepte = 0',
  ],
];

Future<Database> ouvrirBaseLocale() async {
  return openDatabase(
    chemin.join(await getDatabasesPath(), 'resto_terminal.db'),
    version: migrations.length,
    onCreate: (base, version) => _appliquer(base, 0, version),
    onUpgrade: _appliquer,
  );
}

Future<void> _appliquer(Database base, int depuis, int jusqua) async {
  await base.transaction((transaction) async {
    for (final migration in migrations.sublist(depuis, jusqua)) {
      for (final requete in migration) {
        await transaction.execute(requete);
      }
    }
  });
}
