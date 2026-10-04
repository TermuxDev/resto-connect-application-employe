import 'package:flutter_test/flutter_test.dart';
import 'package:resto_terminal/domaine/texte.dart';

void main() {
  test('les nombres s\'accordent comme en français', () {
    expect(nombre(0, 'plat'), '0 plat');
    expect(nombre(1, 'plat'), '1 plat');
    expect(nombre(3, 'plat'), '3 plats');
    expect(nombre(2, 'repas', 'repas'), '2 repas');
  });
}
