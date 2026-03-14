// test/lumara/social/late_profile_service_test.dart
// Phase 7: LateProfileService — getOrCreateProfileId cache; getConnectedAccounts from mock; SocialAccount.fromJson.

import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/lumara/social/late_profile_service.dart';
import 'package:my_app/services/swarmspace/swarmspace_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  tearDown(() {
    LateProfileService.testInvoker = null;
  });

  group('SocialAccount.fromJson', () {
    test('parses id, platform, username, profileId', () {
      final a = SocialAccount.fromJson({
        'id': 'acc_123',
        'platform': 'linkedin',
        'username': 'johndoe',
        'profileId': 'prof_1',
      });
      expect(a.id, 'acc_123');
      expect(a.platform, 'linkedin');
      expect(a.username, 'johndoe');
      expect(a.profileId, 'prof_1');
    });

    test('parses _id, handle, profile_id variants', () {
      final a = SocialAccount.fromJson({
        '_id': 'acc_456',
        'platform': 'bluesky',
        'handle': '@user.bsky.social',
        'profile_id': 'prof_2',
      });
      expect(a.id, 'acc_456');
      expect(a.platform, 'bluesky');
      expect(a.username, '@user.bsky.social');
      expect(a.profileId, 'prof_2');
    });
  });

  group('LateProfileService', () {
    test('getOrCreateProfileId returns cached profileId when stored in prefs', () async {
      SharedPreferences.setMockInitialValues({'late_profile_id': 'cached_profile_xyz'});
      final profileId = await LateProfileService.instance.getOrCreateProfileId();
      expect(profileId, 'cached_profile_xyz');
    });

    test('getOrCreateProfileId creates and caches profile when prefs empty and invoker returns profile', () async {
      SharedPreferences.setMockInitialValues({});
      LateProfileService.testInvoker = (pluginId, params) async {
        expect(pluginId, 'social-publisher');
        expect(params['_action'], 'createProfile');
        return const SwarmSpaceResult(
          success: true,
          data: {'profile': {'_id': 'new_profile_123', 'name': 'LUMARA'}},
        );
      };
      // UserProfileService.instance.getField('preferred_name') is called and may throw in test env.
      final profileId = await LateProfileService.instance.getOrCreateProfileId();
      expect(profileId, 'new_profile_123');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('late_profile_id'), 'new_profile_123');
    }, skip: 'UserProfileService.getField requires Flutter binding (secure storage)');

    test('getConnectedAccounts returns correct SocialAccount list from mock response', () async {
      SharedPreferences.setMockInitialValues({'late_profile_id': 'prof_1'});
      LateProfileService.testInvoker = (pluginId, params) async {
        expect(pluginId, 'social-publisher');
        expect(params['_action'], 'accounts');
        expect(params['profileId'], 'prof_1');
        return const SwarmSpaceResult(
          success: true,
          data: {
            'accounts': [
              {'id': 'acc_1', 'platform': 'linkedin', 'username': 'jane', 'profileId': 'prof_1'},
              {'_id': 'acc_2', 'platform': 'bluesky', 'handle': '@jane.bsky.social', 'profile_id': 'prof_1'},
            ],
          },
        );
      };
      final accounts = await LateProfileService.instance.getConnectedAccounts();
      expect(accounts.length, 2);
      expect(accounts[0].id, 'acc_1');
      expect(accounts[0].platform, 'linkedin');
      expect(accounts[0].username, 'jane');
      expect(accounts[1].id, 'acc_2');
      expect(accounts[1].platform, 'bluesky');
      expect(accounts[1].username, '@jane.bsky.social');
    });

    test('getConnectedAccounts returns empty list when invoker returns failure', () async {
      SharedPreferences.setMockInitialValues({'late_profile_id': 'prof_1'});
      LateProfileService.testInvoker = (_, __) async =>
          const SwarmSpaceResult(success: false, error: 'Network error');
      final accounts = await LateProfileService.instance.getConnectedAccounts();
      expect(accounts, isEmpty);
    });
  });
}
