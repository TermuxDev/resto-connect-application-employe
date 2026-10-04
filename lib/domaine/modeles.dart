/// Modèles métier du terminal, alignés sur l'API du serveur (ARCHITECTURE.md, section 5).
library;

enum Statut {
  interne('INTERNE', 'interne', 'internes'),
  externe('EXTERNE', 'externe', 'externes');

  const Statut(this.code, this.libelle, this.pluriel);
  final String code;
  final String libelle;
  final String pluriel;

  static Statut depuisCode(String code) =>
      values.firstWhere((s) => s.code == code);
}

enum Creneau {
  midi('MIDI', 'midi', 'ce midi'),
  soir('SOIR', 'soir', 'ce soir'),
  libre('LIBRE', 'service libre', 'aujourd\'hui');

  const Creneau(this.code, this.libelle, this.moment);
  final String code;
  final String libelle;

  /// « ce midi », « ce soir » : pour les phrases adressées à l'employé.
  final String moment;

  static Creneau depuisCode(String code) =>
      values.firstWhere((c) => c.code == code);
}

enum Motif {
  dejaServi('DEJA_SERVI', 'Déjà servi'),
  horsHoraire('HORS_HORAIRE', 'Pas l\'heure du repas'),
  soldeEpuise('SOLDE_EPUISE', 'Plus de plats'),
  abonnementExpire('ABONNEMENT_EXPIRE', 'Abonnement terminé'),
  carteBloquee('CARTE_BLOQUEE', 'Carte bloquée'),
  typeNonAccepte('TYPE_NON_ACCEPTE', 'Mauvais comptoir'),
  inconnu('INCONNU', 'Carte non reconnue');

  const Motif(this.code, this.libelle);
  final String code;
  final String libelle;
}

/// Le terminal connecté : il contrôle un seul type d'étudiant.
class Terminal {
  const Terminal({
    required this.id,
    required this.nom,
    required this.typeVerifie,
  });

  factory Terminal.depuisJson(Map<String, dynamic> json) => Terminal(
    id: json['id'] as int,
    nom: json['nom'] as String,
    typeVerifie: Statut.depuisCode(json['type_verifie'] as String),
  );

  final int id;
  final String nom;
  final Statut typeVerifie;

  Map<String, dynamic> versJson() => {
    'id': id,
    'nom': nom,
    'type_verifie': typeVerifie.code,
  };
}

/// Horaires des créneaux, exprimés en minutes depuis minuit à l'heure du restaurant.
class Parametres {
  const Parametres({
    required this.midiDebut,
    required this.midiFin,
    required this.soirDebut,
    required this.soirFin,
    required this.decalageMinutes,
  });

  factory Parametres.depuisJson(Map<String, dynamic> json) => Parametres(
    midiDebut: _minutes(json['midi_debut'] as String),
    midiFin: _minutes(json['midi_fin'] as String),
    soirDebut: _minutes(json['soir_debut'] as String),
    soirFin: _minutes(json['soir_fin'] as String),
    decalageMinutes: json['decalage_minutes'] as int? ?? 0,
  );

  final int midiDebut;
  final int midiFin;
  final int soirDebut;
  final int soirFin;

  /// Décalage du fuseau du restaurant par rapport à UTC.
  final int decalageMinutes;

  static int _minutes(String heure) {
    final morceaux = heure.split(':');
    return int.parse(morceaux[0]) * 60 + int.parse(morceaux[1]);
  }

  static String _texte(int minutes) =>
      '${(minutes ~/ 60).toString().padLeft(2, '0')}h${(minutes % 60).toString().padLeft(2, '0')}';

  Map<String, dynamic> versJson() => {
    'midi_debut': '${midiDebut ~/ 60}:${midiDebut % 60}',
    'midi_fin': '${midiFin ~/ 60}:${midiFin % 60}',
    'soir_debut': '${soirDebut ~/ 60}:${soirDebut % 60}',
    'soir_fin': '${soirFin ~/ 60}:${soirFin % 60}',
    'decalage_minutes': decalageMinutes,
  };

  /// L'heure « murale » du restaurant, quel que soit le fuseau réglé sur le téléphone.
  DateTime heureRestaurant(DateTime instant) =>
      instant.toUtc().add(Duration(minutes: decalageMinutes));

  /// Créneau en cours à cet instant, ou null en dehors des horaires.
  Creneau? creneau(DateTime instant) {
    final heure = heureRestaurant(instant);
    final minutes = heure.hour * 60 + heure.minute;
    if (minutes >= midiDebut && minutes <= midiFin) return Creneau.midi;
    if (minutes >= soirDebut && minutes <= soirFin) return Creneau.soir;
    return null;
  }

  /// Début et fin (en UTC) de la journée du restaurant qui contient cet instant.
  (DateTime, DateTime) journee(DateTime instant) {
    final heure = heureRestaurant(instant);
    final debut = DateTime.utc(
      heure.year,
      heure.month,
      heure.day,
    ).subtract(Duration(minutes: decalageMinutes));
    return (debut, debut.add(const Duration(days: 1)));
  }

  String horaires(Creneau creneau) => switch (creneau) {
    Creneau.midi => '${_texte(midiDebut)} – ${_texte(midiFin)}',
    Creneau.soir => '${_texte(soirDebut)} – ${_texte(soirFin)}',
    Creneau.libre => 'Toute la journée',
  };
}

class Etudiant {
  const Etudiant({
    required this.id,
    required this.qrJeton,
    required this.nom,
    required this.prenom,
    required this.statut,
    required this.soldePlats,
    required this.finAbonnement,
    required this.carteBloquee,
    required this.photoUrl,
    required this.dateMaj,
    this.photoChemin,
  });

  factory Etudiant.depuisApi(Map<String, dynamic> json) => Etudiant(
    id: json['id'] as int,
    qrJeton: json['qr_jeton'] as String,
    nom: json['nom'] as String,
    prenom: json['prenom'] as String,
    statut: Statut.depuisCode(json['statut'] as String),
    soldePlats: json['solde_plats'] as int,
    finAbonnement: json['fin_abonnement'] == null
        ? null
        : DateTime.parse(json['fin_abonnement'] as String),
    carteBloquee: json['carte_bloquee'] as bool,
    photoUrl: json['photo'] as String,
    dateMaj: json['date_maj'] as String,
  );

  factory Etudiant.depuisLigne(Map<String, Object?> ligne) => Etudiant(
    id: ligne['id']! as int,
    qrJeton: ligne['qr_jeton']! as String,
    nom: ligne['nom']! as String,
    prenom: ligne['prenom']! as String,
    statut: Statut.depuisCode(ligne['statut']! as String),
    soldePlats: ligne['solde_plats']! as int,
    finAbonnement: ligne['fin_abonnement'] == null
        ? null
        : DateTime.parse(ligne['fin_abonnement']! as String),
    carteBloquee: ligne['carte_bloquee'] == 1,
    photoUrl: ligne['photo_url']! as String,
    dateMaj: ligne['date_maj']! as String,
    photoChemin: ligne['photo_chemin'] as String?,
  );

  final int id;
  final String qrJeton;
  final String nom;
  final String prenom;
  final Statut statut;
  final int soldePlats;

  /// Dernier jour de validité de l'abonnement (externes), inclus.
  final DateTime? finAbonnement;
  final bool carteBloquee;
  final String photoUrl;
  final String dateMaj;
  final String? photoChemin;

  String get nomComplet => '$prenom $nom';

  Map<String, Object?> versLigne() => {
    'id': id,
    'qr_jeton': qrJeton,
    'nom': nom,
    'prenom': prenom,
    'statut': statut.code,
    'solde_plats': soldePlats,
    'fin_abonnement': finAbonnement?.toIso8601String().substring(0, 10),
    'carte_bloquee': carteBloquee ? 1 : 0,
    'photo_url': photoUrl,
    'date_maj': dateMaj,
  };
}

class Service {
  const Service({
    required this.id,
    required this.creneau,
    required this.ouverture,
    this.cloture,
  });

  factory Service.depuisLigne(Map<String, Object?> ligne) => Service(
    id: ligne['id']! as String,
    creneau: Creneau.depuisCode(ligne['creneau']! as String),
    ouverture: DateTime.parse(ligne['ouverture']! as String),
    cloture: ligne['cloture'] == null
        ? null
        : DateTime.parse(ligne['cloture']! as String),
  );

  final String id;
  final Creneau creneau;
  final DateTime ouverture;
  final DateTime? cloture;
}

/// Un repas servi et validé au comptoir (les refus ne sont pas enregistrés).
class Passage {
  const Passage({
    required this.id,
    required this.service,
    required this.etudiant,
    required this.dateHeure,
  });

  final String id;
  final String service;
  final int etudiant;
  final DateTime dateHeure;
}

/// Une tentative d'envoi au serveur, réussie ou non (écran « Envois »).
class Synchronisation {
  const Synchronisation({
    required this.date,
    required this.reussie,
    this.envoyes = 0,
    this.fiches = 0,
    this.fraudes = 0,
    this.message,
  });

  factory Synchronisation.depuisLigne(Map<String, Object?> ligne) =>
      Synchronisation(
        date: DateTime.parse(ligne['date']! as String).toLocal(),
        reussie: ligne['reussie'] == 1,
        envoyes: ligne['envoyes']! as int,
        fiches: ligne['fiches']! as int,
        fraudes: ligne['fraudes']! as int,
        message: ligne['message'] as String?,
      );

  final DateTime date;
  final bool reussie;
  final int envoyes;
  final int fiches;
  final int fraudes;
  final String? message;

  Map<String, Object?> versLigne() => {
    'date': date.toUtc().toIso8601String(),
    'reussie': reussie ? 1 : 0,
    'envoyes': envoyes,
    'fiches': fiches,
    'fraudes': fraudes,
    'message': message,
  };
}

/// Un repas validé mais pas encore envoyé au serveur.
typedef RepasEnAttente = ({String nom, DateTime dateHeure});
