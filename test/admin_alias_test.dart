import 'package:flutter_test/flutter_test.dart';
import 'package:tiffe/live/backend.dart';

void main() {
  test('admin alias is scoped to staff sign-in only', () {
    expect(
      BackendConfig.loginEmail(' admin ', admin: true),
      BackendConfig.ownerEmail.isEmpty ? 'admin' : BackendConfig.ownerEmail,
    );
    expect(
      BackendConfig.loginEmail('ADMIN', admin: true),
      BackendConfig.ownerEmail.isEmpty ? 'ADMIN' : BackendConfig.ownerEmail,
    );
    expect(BackendConfig.loginEmail('admin', admin: false), 'admin');
    expect(
      BackendConfig.loginEmail('staff@example.com', admin: true),
      'staff@example.com',
    );
  });
}
