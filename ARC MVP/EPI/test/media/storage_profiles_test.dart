import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/media/settings/storage_profiles.dart';

void main() {
  group('StorageProfile', () {
    test('should have correct default profiles', () {
      expect(StorageProfile.allProfiles, hasLength(3));
      
      final minimal = StorageProfile.minimal;
      expect(minimal.policy, equals(StoragePolicy.minimal));
      expect(minimal.displayName, equals('Space-Saver'));
      expect(minimal.keepThumbnails, isTrue);
      expect(minimal.keepFullResolution, isFalse);
      expect(minimal.enableEncryption, isFalse);

      final balanced = StorageProfile.balanced;
      expect(balanced.policy, equals(StoragePolicy.balanced));
      expect(balanced.keepAnalysisVariant, isTrue);
      expect(balanced.enableEncryption, isTrue);

      final hiFidelity = StorageProfile.hiFidelity;
      expect(hiFidelity.policy, equals(StoragePolicy.hiFidelity));
      expect(hiFidelity.keepFullResolution, isTrue);
      expect(hiFidelity.enableEncryption, isTrue);
    });

    test('should return correct profile for policy', () {
      final minimal = StorageProfile.forPolicy(StoragePolicy.minimal);
      expect(minimal.policy, equals(StoragePolicy.minimal));

      final balanced = StorageProfile.forPolicy(StoragePolicy.balanced);
      expect(balanced.policy, equals(StoragePolicy.balanced));

      final hiFidelity = StorageProfile.forPolicy(StoragePolicy.hiFidelity);
      expect(hiFidelity.policy, equals(StoragePolicy.hiFidelity));
    });
  });

  group('StorageSettings', () {
    test('should have correct default settings', () {
      const settings = StorageSettings.defaultSettings;
      
      expect(settings.globalDefault, equals(StoragePolicy.minimal));
      expect(settings.enableAutoOffload, isTrue);
      expect(settings.autoOffloadDays, equals(30));
      expect(settings.enableRetentionPruner, isTrue);
      
      // Check mode overrides
      expect(settings.modeOverrides[AppMode.personal], equals(StoragePolicy.minimal));
      expect(settings.modeOverrides[AppMode.firstResponder], equals(StoragePolicy.hiFidelity));
      expect(settings.modeOverrides[AppMode.coach], equals(StoragePolicy.hiFidelity));
    });

    test('should return correct policy for mode', () {
      const settings = StorageSettings.defaultSettings;
      
      expect(settings.getPolicyForMode(AppMode.personal), equals(StoragePolicy.minimal));
      expect(settings.getPolicyForMode(AppMode.firstResponder), equals(StoragePolicy.hiFidelity));
      expect(settings.getPolicyForMode(AppMode.coach), equals(StoragePolicy.hiFidelity));
    });

    test('should return correct profile for mode', () {
      const settings = StorageSettings.defaultSettings;
      
      final personalProfile = settings.getProfileForMode(AppMode.personal);
      expect(personalProfile.policy, equals(StoragePolicy.minimal));

      final firstResponderProfile = settings.getProfileForMode(AppMode.firstResponder);
      expect(firstResponderProfile.policy, equals(StoragePolicy.hiFidelity));

      final coachProfile = settings.getProfileForMode(AppMode.coach);
      expect(coachProfile.policy, equals(StoragePolicy.hiFidelity));
    });

    test('should support copyWith', () {
      const original = StorageSettings.defaultSettings;
      
      final modified = original.copyWith(
        globalDefault: StoragePolicy.balanced,
        enableAutoOffload: false,
        autoOffloadDays: 60,
      );

      expect(modified.globalDefault, equals(StoragePolicy.balanced));
      expect(modified.enableAutoOffload, isFalse);
      expect(modified.autoOffloadDays, equals(60));
      
      // Ensure other values remain unchanged
      expect(modified.enableRetentionPruner, equals(original.enableRetentionPruner));
      expect(modified.modeOverrides, equals(original.modeOverrides));
    });

    test('should preserve mode overrides in copyWith', () {
      const original = StorageSettings.defaultSettings;
      
      final newOverrides = {
        AppMode.personal: StoragePolicy.balanced,
        AppMode.firstResponder: StoragePolicy.balanced,
        AppMode.coach: StoragePolicy.minimal,
      };

      final modified = original.copyWith(modeOverrides: newOverrides);
      
      expect(modified.modeOverrides, equals(newOverrides));
      expect(modified.modeOverrides, isNot(same(newOverrides))); // Should be a copy
    });
  });

  group('StorageEstimate', () {
    test('should calculate sizes correctly', () {
      const estimate = StorageEstimate(
        totalFiles: 10,
        totalSizeBytes: 10485760, // 10MB
        thumbnailSizeBytes: 1048576, // 1MB
        transcriptSizeBytes: 524288, // 0.5MB
        analysisSizeBytes: 5242880, // 5MB
        fullResSizeBytes: 3670016, // ~3.5MB
      );

      expect(estimate.totalSizeMB, closeTo(10.0, 0.1));
      expect(estimate.thumbnailSizeMB, closeTo(1.0, 0.1));
      expect(estimate.transcriptSizeMB, closeTo(0.5, 0.1));
      expect(estimate.analysisSizeMB, closeTo(5.0, 0.1));
      expect(estimate.fullResSizeMB, closeTo(3.5, 0.1));
    });

    test('should format toString correctly', () {
      const estimate = StorageEstimate(
        totalFiles: 42,
        totalSizeBytes: 15728640, // ~15MB
        thumbnailSizeBytes: 0,
        transcriptSizeBytes: 0,
        analysisSizeBytes: 0,
        fullResSizeBytes: 0,
      );

      final string = estimate.toString();
      expect(string, contains('42'));
      expect(string, contains('15.0MB'));
    });
  });
}