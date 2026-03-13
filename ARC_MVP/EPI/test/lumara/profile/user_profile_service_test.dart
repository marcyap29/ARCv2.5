// test/lumara/profile/user_profile_service_test.dart
// Phase 6: UserProfileService unit tests.
// Note: save/getProfile/deleteProfile require FlutterSecureStorage and are covered by integration tests
// or run on device; here we test isSensitive which does not touch storage.

import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/lumara/profile/user_profile_service.dart';

void main() {
  group('UserProfileService', () {
    test('isSensitive returns true for health_insurance_number and other sensitive keys', () {
      final service = UserProfileService.instance;
      expect(service.isSensitive('health_insurance_number'), true);
      expect(service.isSensitive('emergency_contact_name'), true);
      expect(service.isSensitive('emergency_contact_phone'), true);
      expect(service.isSensitive('full_name'), false);
      expect(service.isSensitive('email'), false);
      expect(service.isSensitive('address_city'), false);
    });
  });
}
