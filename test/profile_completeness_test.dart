import 'package:encore/services/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const complete = <String, dynamic>{
    'fullName': 'John Doe',
    'username': '_johndoe',
    'email': 'john@university.edu',
    'registrationNumber': '20211234567',
    'department': 'CSC',
    'faculty': 'SICT',
    'role': 'Student',
    'level': '400 Level',
    'onboardingComplete': true,
  };

  test('a fully written profile is complete', () {
    expect(AuthService.isProfileComplete(complete), isTrue);
  });

  test('a legacy profile without the onboarding marker is complete', () {
    final legacy = Map<String, dynamic>.of(complete)
      ..remove('onboardingComplete');
    expect(AuthService.isProfileComplete(legacy), isTrue);
  });

  test('missing or unfinished profiles are rejected', () {
    expect(AuthService.isProfileComplete(null), isFalse);
    expect(AuthService.isProfileComplete(const {}), isFalse);
    expect(
      AuthService.isProfileComplete({...complete, 'onboardingComplete': false}),
      isFalse,
    );
  });

  test('profiles missing any core detail are rejected', () {
    for (final field in [
      'fullName',
      'username',
      'email',
      'registrationNumber',
      'department',
      'role',
      'level',
    ]) {
      final partial = Map<String, dynamic>.of(complete)..remove(field);
      expect(
        AuthService.isProfileComplete(partial),
        isFalse,
        reason: 'missing $field should be incomplete',
      );
      expect(
        AuthService.isProfileComplete({...complete, field: '  '}),
        isFalse,
        reason: 'blank $field should be incomplete',
      );
    }
  });
}
