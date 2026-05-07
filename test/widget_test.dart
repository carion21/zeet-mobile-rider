// test/widget_test.dart
//
// Smoke test minimal — vérifie que les imports principaux compilent et que
// l'API publique de [Routes] expose les constantes attendues. Le scaffold
// originel (`tester.pumpWidget(const MyApp(...))`) ne fonctionne pas hors
// d'un environnement Firebase/TokenService initialisé. Pour des tests
// fonctionnels, voir les test files dédiés par feature dans `test/`.

import 'package:flutter_test/flutter_test.dart';

import 'package:rider/services/navigation_service.dart';

void main() {
  test('Routes exposent les constantes essentielles', () {
    expect(Routes.home, isA<String>());
    expect(Routes.login, isA<String>());
    expect(Routes.home, isNotEmpty);
    expect(Routes.login, isNotEmpty);
  });
}
