/// Règles du bip vert / bip rouge, appliquées hors ligne.
///
/// Elles reproduisent les règles du serveur (ETUDESYSTEME.md, RG03 à RG06) : toute évolution
/// d'un côté doit être reportée de l'autre. Ce fichier ne dépend d'aucune base ni d'aucun écran,
/// il est entièrement couvert par test/verification_test.dart.
library;

import 'modeles.dart';
import 'texte.dart';

class Verdict {
  const Verdict.accepte(this.etudiant, this.detail) : motif = null;
  const Verdict.refuse(this.motif, {this.etudiant, this.detail});

  final Etudiant? etudiant;
  final Motif? motif;
  final String? detail;

  bool get accepte => motif == null;
}

/// Décide si l'étudiant peut être servi.
///
/// [repasDuJour] : instants des repas déjà servis aujourd'hui à cet étudiant,
/// sur ce terminal et sur les autres (d'après le dernier chargement).
Verdict verifier({
  required Etudiant? etudiant,
  required Terminal terminal,
  required Parametres parametres,
  required DateTime maintenant,
  required Iterable<DateTime> repasDuJour,
}) {
  if (etudiant == null) {
    return const Verdict.refuse(
      Motif.inconnu,
      detail:
          'Cette carte n\'est pas dans la liste. Mettez à jour la liste ou envoyez l\'étudiant voir le gérant.',
    );
  }
  if (etudiant.carteBloquee) {
    return Verdict.refuse(
      Motif.carteBloquee,
      etudiant: etudiant,
      detail: 'Envoyez l\'étudiant voir le gérant.',
    );
  }
  if (etudiant.statut != terminal.typeVerifie) {
    return Verdict.refuse(
      Motif.typeNonAccepte,
      etudiant: etudiant,
      detail:
          'Étudiant ${etudiant.statut.libelle} : il doit passer au comptoir des ${etudiant.statut.pluriel}.',
    );
  }

  return switch (etudiant.statut) {
    Statut.interne => _verifierInterne(
      etudiant,
      parametres,
      maintenant,
      repasDuJour,
    ),
    Statut.externe => _verifierExterne(etudiant, parametres, maintenant),
  };
}

/// RG03 — Un repas le midi, un repas le soir.
Verdict _verifierInterne(
  Etudiant etudiant,
  Parametres parametres,
  DateTime maintenant,
  Iterable<DateTime> repas,
) {
  final creneau = parametres.creneau(maintenant);
  if (creneau == null) {
    return Verdict.refuse(
      Motif.horsHoraire,
      etudiant: etudiant,
      detail:
          'Repas servis de ${parametres.horaires(Creneau.midi)} et de ${parametres.horaires(Creneau.soir)}.',
    );
  }
  if (repas.any((r) => parametres.creneau(r) == creneau)) {
    return Verdict.refuse(
      Motif.dejaServi,
      etudiant: etudiant,
      detail: 'Il a déjà mangé ${creneau.moment}.',
    );
  }
  return Verdict.accepte(etudiant, 'Repas du ${creneau.libelle}');
}

/// RG04 — 1 scan = 1 plat, tant qu'il reste des plats et que l'abonnement est valide.
Verdict _verifierExterne(
  Etudiant etudiant,
  Parametres parametres,
  DateTime maintenant,
) {
  final fin = etudiant.finAbonnement;
  if (fin == null) {
    return Verdict.refuse(
      Motif.abonnementExpire,
      etudiant: etudiant,
      detail: 'Pas d\'abonnement : à recharger auprès du gérant.',
    );
  }
  final aujourdhui = parametres.heureRestaurant(maintenant);
  if (DateTime.utc(
    aujourdhui.year,
    aujourdhui.month,
    aujourdhui.day,
  ).isAfter(DateTime.utc(fin.year, fin.month, fin.day))) {
    return Verdict.refuse(
      Motif.abonnementExpire,
      etudiant: etudiant,
      detail: 'Terminé le ${_date(fin)} : à recharger auprès du gérant.',
    );
  }
  if (etudiant.soldePlats <= 0) {
    final detail = etudiant.soldePlats < 0
        ? 'Il doit ${nombre(-etudiant.soldePlats, 'plat')} : à régler auprès du gérant.'
        : 'Abonnement à recharger auprès du gérant.';
    return Verdict.refuse(
      Motif.soldeEpuise,
      etudiant: etudiant,
      detail: detail,
    );
  }
  final reste = etudiant.soldePlats - 1;
  return Verdict.accepte(
    etudiant,
    reste == 0
        ? 'C\'était son dernier plat'
        : 'Il lui reste ${nombre(reste, 'plat')}',
  );
}

String _date(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
