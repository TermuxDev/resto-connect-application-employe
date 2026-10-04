import 'package:flutter_test/flutter_test.dart';
import 'package:resto_terminal/domaine/modeles.dart';

Map<String, dynamic> fiche({Object? photo}) => {
  'id': 1,
  'qr_jeton': 'RC-x',
  'nom': 'Traore',
  'prenom': 'Ali',
  'statut': 'EXTERNE',
  'solde_plats': 12,
  'fin_abonnement': '2026-10-31',
  'carte_bloquee': false,
  'photo': photo,
  'date_maj': '2026-10-04T10:00:00Z',
};

void main() {
  test('un étudiant sans photo est accepté (photo facultative)', () {
    final etudiant = Etudiant.depuisApi(fiche());
    expect(etudiant.aUnePhoto, isFalse);
    expect(etudiant.versLigne()['photo_url'], '');
  });

  test('un étudiant avec photo garde son adresse', () {
    final etudiant = Etudiant.depuisApi(
      fiche(photo: 'http://serveur/api/etudiants/1/photo/'),
    );
    expect(etudiant.aUnePhoto, isTrue);
  });

  test(
    'les champs inconnus envoyés par un serveur plus récent sont ignorés',
    () {
      final etudiant = Etudiant.depuisApi({
        ...fiche(),
        'nouveau_champ': 'valeur',
      });
      expect(etudiant.nomComplet, 'Ali Traore');
    },
  );
}
