import 'package:flutter_test/flutter_test.dart';
import 'package:resto_terminal/domaine/modeles.dart';
import 'package:resto_terminal/domaine/verification.dart';

// Restaurant à UTC+1 : 12h00 au restaurant = 11h00 UTC.
const parametres = Parametres(
  midiDebut: 11 * 60 + 30,
  midiFin: 13 * 60 + 30,
  soirDebut: 18 * 60 + 30,
  soirFin: 20 * 60 + 30,
  decalageMinutes: 60,
);
const terminalInternes = Terminal(id: 1, nom: 'A', typeVerifie: Statut.interne);
const terminalExternes = Terminal(id: 2, nom: 'B', typeVerifie: Statut.externe);

DateTime aHeureRestaurant(int heure, [int minute = 0, int jour = 3]) =>
    DateTime.utc(
      2026,
      10,
      jour,
      heure,
      minute,
    ).subtract(const Duration(minutes: 60));

Etudiant etudiant({
  Statut statut = Statut.interne,
  int solde = 0,
  DateTime? fin,
  bool bloquee = false,
}) => Etudiant(
  id: 1,
  qrJeton: 'RC-x',
  nom: 'Traore',
  prenom: 'Ali',
  statut: statut,
  soldePlats: solde,
  finAbonnement: fin,
  carteBloquee: bloquee,
  photoUrl: '',
  dateMaj: '',
);

Verdict verdict(
  Etudiant? e, {
  Terminal terminal = terminalInternes,
  DateTime? a,
  List<DateTime> repas = const [],
}) => verifier(
  etudiant: e,
  terminal: terminal,
  parametres: parametres,
  maintenant: a ?? aHeureRestaurant(12),
  repasDuJour: repas,
);

void main() {
  group('Toutes les cartes', () {
    test('carte inconnue', () => expect(verdict(null).motif, Motif.inconnu));
    test(
      'carte bloquée',
      () => expect(verdict(etudiant(bloquee: true)).motif, Motif.carteBloquee),
    );
    test('mauvais terminal', () {
      expect(
        verdict(etudiant(statut: Statut.externe)).motif,
        Motif.typeNonAccepte,
      );
    });
  });

  group('Internes (RG03)', () {
    test('servi le midi', () => expect(verdict(etudiant()).accepte, isTrue));
    test(
      'servi le soir',
      () =>
          expect(verdict(etudiant(), a: aHeureRestaurant(19)).accepte, isTrue),
    );
    test('refusé hors horaires', () {
      expect(
        verdict(etudiant(), a: aHeureRestaurant(16)).motif,
        Motif.horsHoraire,
      );
    });
    test(
      'refusé s\'il a déjà mangé ce midi (ici ou sur un autre terminal)',
      () {
        expect(
          verdict(etudiant(), repas: [aHeureRestaurant(11, 45)]).motif,
          Motif.dejaServi,
        );
      },
    );
    test('le repas du midi n\'empêche pas celui du soir', () {
      expect(
        verdict(
          etudiant(),
          a: aHeureRestaurant(19),
          repas: [aHeureRestaurant(12)],
        ).accepte,
        isTrue,
      );
    });
    test(
      'les créneaux suivent l\'heure du restaurant, pas celle du téléphone',
      () {
        // 11h40 UTC = 12h40 au restaurant : midi.
        expect(
          parametres.creneau(DateTime.utc(2026, 10, 3, 11, 40)),
          Creneau.midi,
        );
      },
    );
  });

  group('Externes (RG04)', () {
    final valide = DateTime.utc(2026, 10, 10);
    test('servi avec un solde et un abonnement valides', () {
      final v = verdict(
        etudiant(statut: Statut.externe, solde: 3, fin: valide),
        terminal: terminalExternes,
      );
      expect((v.accepte, v.detail), (true, 'Il lui reste 2 plats'));
    });
    test('servi même en dehors des créneaux', () {
      final e = etudiant(statut: Statut.externe, solde: 3, fin: valide);
      expect(
        verdict(e, terminal: terminalExternes, a: aHeureRestaurant(16)).accepte,
        isTrue,
      );
    });
    test('refusé sans plat', () {
      final e = etudiant(statut: Statut.externe, solde: 0, fin: valide);
      expect(verdict(e, terminal: terminalExternes).motif, Motif.soldeEpuise);
    });
    test('refusé avec une dette', () {
      final e = etudiant(statut: Statut.externe, solde: -2, fin: valide);
      expect(
        verdict(e, terminal: terminalExternes).detail,
        'Il doit 2 plats : à régler auprès du gérant.',
      );
    });
    test('valable jusqu\'au dernier jour inclus', () {
      final e = etudiant(
        statut: Statut.externe,
        solde: 5,
        fin: DateTime.utc(2026, 10, 3),
      );
      expect(
        verdict(e, terminal: terminalExternes, a: aHeureRestaurant(20)).accepte,
        isTrue,
      );
    });
    test('refusé le lendemain de la fin', () {
      final e = etudiant(
        statut: Statut.externe,
        solde: 5,
        fin: DateTime.utc(2026, 10, 2),
      );
      expect(
        verdict(e, terminal: terminalExternes).motif,
        Motif.abonnementExpire,
      );
    });
    test('refusé sans abonnement', () {
      final e = etudiant(statut: Statut.externe, solde: 5);
      expect(
        verdict(e, terminal: terminalExternes).motif,
        Motif.abonnementExpire,
      );
    });
  });

  test('journée du restaurant en UTC', () {
    final (debut, fin) = parametres.journee(
      DateTime.utc(2026, 10, 3, 23, 30),
    ); // 00h30 le 4 au restaurant
    expect(
      (debut, fin),
      (DateTime.utc(2026, 10, 3, 23), DateTime.utc(2026, 10, 4, 23)),
    );
  });
}
