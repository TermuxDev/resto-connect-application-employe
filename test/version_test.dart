import 'package:flutter_test/flutter_test.dart';
import 'package:resto_terminal/domaine/version.dart';

void main() {
  test('une version plus ancienne que la minimale est détectée', () {
    expect(estPlusAncienne('1.0.0', '1.1.0'), isTrue);
    expect(estPlusAncienne('1.9.3', '2.0.0'), isTrue);
    expect(estPlusAncienne('1.2.9', '1.10.0'), isTrue);
  });

  test('une version égale ou plus récente est acceptée', () {
    expect(estPlusAncienne('1.1.0', '1.1.0'), isFalse);
    expect(estPlusAncienne('1.1.0+7', '1.1.0'), isFalse);
    expect(estPlusAncienne('2.0.0', '1.9.9'), isFalse);
  });
}
