import 'package:flutter_test/flutter_test.dart';

import 'package:sambahub/app/app.dart';

void main() {
  test('SambaHubApp pode ser instanciado', () {
    const app = SambaHubApp();

    expect(app, isA<SambaHubApp>());
  });
}
