import 'package:flutter_test/flutter_test.dart';
import 'package:resto_terminal/domaine/adresse.dart';

void main() {
  test('le protocole est ajouté s\'il manque', () {
    expect(
      normaliserAdresse('192.168.100.32:8000'),
      'http://192.168.100.32:8000',
    );
    expect(normaliserAdresse('  resto.exemple.ci '), 'http://resto.exemple.ci');
  });

  test('une adresse complète est conservée, sans chemin ni barre finale', () {
    expect(
      normaliserAdresse('https://resto.exemple.ci/'),
      'https://resto.exemple.ci',
    );
    expect(
      normaliserAdresse('http://192.168.1.20:8000/gerant/'),
      'http://192.168.1.20:8000',
    );
  });

  test('une adresse inutilisable est refusée', () {
    expect(normaliserAdresse(''), isNull);
    expect(normaliserAdresse('ftp://serveur'), isNull);
    expect(normaliserAdresse('http://'), isNull);
  });
}
