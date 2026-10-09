import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tiffe/live/live_app.dart';

void main() {
  test('duplicate email suggests sign-in only when backend reports it', () {
    for (final code in ['user_already_exists', 'email_exists']) {
      expect(
        authErrorMessage(
          AuthApiException('hidden', code: code),
          registering: true,
        ),
        contains('Sign in instead'),
      );
    }
  });
  test('SMTP restriction does not pretend the account exists', () {
    final text = authErrorMessage(
      const AuthApiException('hidden', code: 'email_address_not_authorized'),
      registering: true,
    );
    expect(text, contains('cannot send confirmation emails'));
    expect(text, isNot(contains('already exists')));
  });
}
