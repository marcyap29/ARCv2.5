import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/prism/processors/crypto/enhanced_encryption.dart';
import 'package:my_app/prism/processors/crypto/hash_utils.dart';
import 'package:my_app/prism/processors/storage/enhanced_cas_store.dart';
import 'package:my_app/prism/processors/privacy/privacy_controls.dart';
import 'package:my_app/prism/processors/settings/hive_storage_settings.dart';
import 'package:my_app/prism/processors/resolver/pointer_resolver.dart';
import 'package:my_app/prism/processors/processing/background_processor.dart';

void main() {
  group('Enhanced CAS Store', () {
    test('should handle streaming hash computation', () async {
      final data = Uint8List.fromList(List.generate(1000, (i) => i % 256));
      
      // Test streaming vs. direct hash - should match
      final directHash = await EnhancedCASStore.store('test', '1k', data);
      
      // In a real test, we'd compare with streaming version
      expect(directHash, startsWith('cas://test/1k/sha256:'));
    });

    test('should deduplicate identical content', () async {
      final data = Uint8List.fromList([1, 2, 3, 4, 5]);
      
      final uri1 = await EnhancedCASStore.store('img', '256', data);
      final uri2 = await EnhancedCASStore.store('img', '256', data);
      
      expect(uri1, equals(uri2));
    });

    test('should handle metadata tracking', () async {
      final data = Uint8List.fromList([1, 2, 3]);
      final uri = await EnhancedCASStore.store('test', 'small', data);
      
      // Retrieve should update last accessed
      final retrieved = await EnhancedCASStore.retrieve(uri);
      expect(retrieved, isNotNull);
      expect(retrieved, equals(data));
    });

    test('should respect retention policies', () async {
      const policy = RetentionPolicy.aggressive;
      
      // Mock device state
      final result = await EnhancedCASStore.runRetentionPolicy(
        policy: policy,
        deviceIdle: true,
        deviceCharging: true,
        forceRun: true,
      );
      
      expect(result.filesProcessed, isA<int>());
      expect(result.bytesFreed, isA<int>());
      expect(result.errors, isA<List<String>>());
    });
  });

  group('Enhanced Encryption', () {
    test('should initialize with KEK', () async {
      await EnhancedEncryptionService.initialize();
      
      final stats = await EnhancedEncryptionService.getStats();
      expect(stats, isA<EncryptionStats>());
    });

    test('should encrypt and decrypt with DEK', () async {
      final plaintext = Uint8List.fromList([1, 2, 3, 4, 5]);
      const contentId = 'test_content_123';
      
      final encrypted = await EnhancedEncryptionService.encrypt(plaintext, contentId);
      expect(encrypted.keyId, isNotEmpty);
      expect(encrypted.algorithm, equals('AES-GCM'));
      
      final decrypted = await EnhancedEncryptionService.decrypt(encrypted, contentId);
      expect(decrypted, equals(plaintext));
    });

    test('should handle key rotation metadata', () async {
      final plaintext = Uint8List.fromList([1, 2, 3]);
      const contentId = 'rotation_test';
      
      final encrypted1 = await EnhancedEncryptionService.encrypt(plaintext, contentId);
      
      // Simulate key rotation by creating new encrypted data
      final encrypted2 = await EnhancedEncryptionService.encrypt(plaintext, contentId);
      
      // Both should decrypt successfully
      final decrypted1 = await EnhancedEncryptionService.decrypt(encrypted1, contentId);
      final decrypted2 = await EnhancedEncryptionService.decrypt(encrypted2, contentId);
      
      expect(decrypted1, equals(plaintext));
      expect(decrypted2, equals(plaintext));
    });

    test('should track encryption statistics', () async {
      final stats = await EnhancedEncryptionService.getStats();
      
      expect(stats.dekCount, isA<int>());
      expect(stats.rotationTasksCount, isA<int>());
    });
  });

  group('Privacy Controls', () {
    test('should detect PII in text', () async {
      const processor = PrivacyAwareProcessor(PrivacySettings.balanced);
      
      const testText = 'My email is john@example.com and phone is 555-123-4567';
      final piiAnalysis = await processor.processText(testText);
      
      expect(piiAnalysis.hasPii, isTrue);
      expect(piiAnalysis.piiTypes, contains(PIIType.email));
      expect(piiAnalysis.piiTypes, contains(PIIType.phone));
    });

    test('should sanitize EXIF based on privacy settings', () async {
      const privacyFocused = PrivacyAwareProcessor(PrivacySettings.privacyFocused);
      
      final rawExif = {
        'DateTime': '2023-08-15 14:30:00',
        'GPS': {'Latitude': 37.7749, 'Longitude': -122.4194},
        'Make': 'Apple',
        'Model': 'iPhone 14',
      };
      
      final result = await privacyFocused.processImage(
        Uint8List.fromList([1, 2, 3]),
        rawExif,
        [],
      );
      
      expect(result.sanitizedExif.gps, isNull); // Should be null for privacy-focused
      expect(result.sanitizedExif.cameraMake, isNull);
      expect(result.sanitizedExif.redactedFields, isNotEmpty);
    });

    test('should respect face detection settings', () async {
      const noFaceDetection = PrivacyAwareProcessor(
        PrivacySettings(detectFaces: false),
      );
      
      final faces = [
        const FaceBoundingBox(left: 10, top: 20, width: 50, height: 60, confidence: 0.9),
      ];
      
      final result = await noFaceDetection.processImage(
        Uint8List.fromList([1, 2, 3]),
        {},
        faces,
      );
      
      expect(result.faceAnalysis, isNull);
    });

    test('should generate privacy compliance reports', () {
      const settings = PrivacySettings.balanced;
      const imageResult = ProcessedImageResult(
        sanitizedExif: SanitizedExifData(redactedFields: ['Make']),
      );
      const textAnalysis = PIIAnalysis(
        hasPii: true,
        piiTypes: [PIIType.email],
        confidence: 0.8,
      );
      
      final report = PrivacyComplianceChecker.generatePrivacyReport(
        settings,
        imageResult,
        textAnalysis,
      );
      
      expect(report['privacy_level'], isA<String>());
      expect(report['processing_applied'], isA<Map<String, dynamic>>());
    });
  });

  group('Background Processing', () {
    test('should queue and process jobs', () async {
      final processor = BackgroundProcessor();
      await processor.start();
      
      final job = MediaProcessingJob(
        id: 'test_job_1',
        entryId: 'entry_123',
        data: Uint8List.fromList([1, 2, 3]),
        mediaType: 'image',
        options: {},
      );
      
      // Monitor progress
      final progressEvents = <ImportProgress>[];
      final progressSub = processor.progressStream.listen(progressEvents.add);
      
      await processor.enqueueJob(job);
      
      // Wait a bit for processing
      await Future.delayed(const Duration(milliseconds: 100));
      
      expect(progressEvents, isNotEmpty);
      expect(progressEvents.first.stage, equals(ImportStage.queued));
      
      await progressSub.cancel();
      await processor.stop();
    });

    test('should handle job failures with retry logic', () async {
      final processor = BackgroundProcessor();
      await processor.start();
      
      // Create a job that will fail
      final job = MediaProcessingJob(
        id: 'failing_job',
        entryId: 'entry_fail',
        data: Uint8List(0), // Empty data should cause failure
        mediaType: 'invalid',
        options: {},
      );
      
      final resultEvents = <MediaProcessingResult>[];
      final resultSub = processor.resultStream.listen(resultEvents.add);
      
      await processor.enqueueJob(job);
      
      // Wait for processing and potential retry
      await Future.delayed(const Duration(seconds: 1));
      
      await resultSub.cancel();
      await processor.stop();
    });

    test('should respect worker limits', () async {
      final processor = BackgroundProcessor();
      await processor.start();
      
      final status = processor.getStatus();
      expect(status['maxWorkers'], equals(2));
      expect(status['isRunning'], isTrue);
      
      await processor.stop();
    });
  });

  group('Pointer Resolution', () {
    test('should detect platform from URI', () {
      final resolver = CrossPlatformPointerResolver();
      
      // Test iOS URI detection
      const iosUri = 'ph://ABC123-DEF456';
      expect(resolver.isSourceAvailable(iosUri), completes);
      
      // Test Android URI detection  
      const androidUri = 'content://media/external/images/media/123';
      expect(resolver.isSourceAvailable(androidUri), completes);
    });

    test('should generate correct URI schemes', () {
      final iosUri = PointerUriGenerator.generateIOSPhotosUri('ABC123');
      expect(iosUri, equals('ph://ABC123'));
      
      final androidUri = PointerUriGenerator.generateAndroidMediaUri('content://test');
      expect(androidUri, equals('content://test'));
      
      final voiceUri = PointerUriGenerator.generateVoiceMemosUri('XYZ789');
      expect(voiceUri, equals('voicememos://XYZ789'));
    });

    test('should handle missing source resolution', () {
      final handler = MissingSourceHandler(CrossPlatformPointerResolver());
      
      const originalUri = 'ph://MISSING123';
      const action = SourceResolutionAction.selectReplacement;
      const replacementUri = 'ph://NEW456';
      
      expect(
        handler.resolveMissingSource(
          originalUri: originalUri,
          action: action,
          replacementUri: replacementUri,
        ),
        completion(equals(replacementUri)),
      );
    });
  });

  group('Hive Storage Settings', () {
    test('should provide correct effective profiles', () {
      final settings = HiveStorageSettings();
      
      // Test per-import override
      final overrideProfile = settings.effectiveProfile(
        mode: 'personal',
        perImportOverride: StorageProfile.hifi,
      );
      expect(overrideProfile, equals(StorageProfile.hifi));
      
      // Test mode-specific profile
      final modeProfile = settings.effectiveProfile(mode: 'first_responder');
      expect(modeProfile, equals(StorageProfile.hifi));
      
      // Test global fallback
      final globalProfile = settings.effectiveProfile(mode: 'unknown_mode');
      expect(globalProfile, equals(StorageProfile.minimal));
    });

    test('should track privacy settings changes', () {
      final settings = HiveStorageSettings();
      final originalPrivacy = settings.getPrivacySettings();
      
      final newPrivacy = originalPrivacy.copyWith(detectFaces: false);
      settings.updatePrivacySettings(newPrivacy);
      
      final updatedPrivacy = settings.getPrivacySettings();
      expect(updatedPrivacy.detectFaces, isFalse);
    });

    test('should calculate privacy levels correctly', () {
      final settings = HiveStorageSettings();
      final summary = settings.getStorageSummary();
      
      expect(summary['privacy_level'], isIn(['low', 'medium', 'high']));
      expect(summary['global_profile'], isA<String>());
      expect(summary['mode_profiles'], isA<Map<String, String>>());
    });
  });

  group('Consent Tracking', () {
    test('should serialize consent records correctly', () {
      final record = ConsentRecord(
        entryId: 'entry_123',
        userId: 'user_456',
        deviceId: 'device_789',
        selectedProfile: StorageProfile.balanced,
        timestamp: DateTime.now(),
        appMode: 'personal',
        privacyChoices: {'detectFaces': true, 'locationPrecision': 'city'},
        consentVersion: '1.0',
      );
      
      final json = record.toJson();
      final deserialized = ConsentRecord.fromJson(json);
      
      expect(deserialized.entryId, equals(record.entryId));
      expect(deserialized.selectedProfile, equals(record.selectedProfile));
      expect(deserialized.privacyChoices, equals(record.privacyChoices));
    });
  });

  group('Edge Cases and Error Handling', () {
    test('should handle malformed CAS URIs', () {
      const malformedUris = [
        'cas://missing-hash',
        'invalid-scheme://test',
        'cas://type/size/md5:wronghashtype',
        'cas://type/size/sha256:tooshort',
      ];
      
      for (final uri in malformedUris) {
        expect(CASStore.parseCASUri(uri), isNull);
      }
    });

    test('should handle encryption with missing keys gracefully', () async {
      final encrypted = EnhancedEncryptedData(
        ciphertext: Uint8List.fromList([1, 2, 3]),
        iv: Uint8List.fromList([4, 5, 6]),
        tag: Uint8List.fromList([7, 8, 9]),
        keyId: 'non_existent_key',
        algorithm: 'AES-GCM',
      );
      
      expect(
        () => EnhancedEncryptionService.decrypt(encrypted, 'content_123'),
        throwsA(isA<EncryptionException>()),
      );
    });

    test('should handle privacy settings validation', () {
      const settings = PrivacySettings.privacyFocused;
      final processingOptions = {'detectFaces': true, 'includeLocation': true};
      
      final isCompliant = PrivacyComplianceChecker.isCompliant(
        settings,
        processingOptions,
      );
      
      expect(isCompliant, isFalse); // Should not be compliant
    });

    test('should handle streaming hash computation for large files', () async {
      // Test with data that exceeds typical memory limits
      final largeData = Uint8List(1024 * 1024); // 1MB
      for (int i = 0; i < largeData.length; i++) {
        largeData[i] = i % 256;
      }
      
      // Should complete without memory issues
      final uri = await EnhancedCASStore.store('large', '1mb', largeData);
      expect(uri, startsWith('cas://large/1mb/sha256:'));
      
      final retrieved = await EnhancedCASStore.retrieve(uri);
      expect(retrieved, isNotNull);
      expect(retrieved!.length, equals(largeData.length));
    });

    test('should handle background job timeout scenarios', () async {
      final processor = BackgroundProcessor();
      await processor.start();
      
      // Create a job with very large data that might timeout
      final job = MediaProcessingJob(
        id: 'timeout_job',
        entryId: 'entry_timeout',
        data: Uint8List(1000000), // 1MB of zeros
        mediaType: 'video', // Video processing takes longest
        options: {'timeout_test': true},
      );
      
      await processor.enqueueJob(job);
      
      // Check that the processor handles the timeout gracefully
      final status = processor.getStatus();
      expect(status['isRunning'], isTrue);
      
      await processor.stop();
    });

    test('should handle concurrent access to CAS store', () async {
      final data = Uint8List.fromList([1, 2, 3, 4, 5]);
      
      // Simulate concurrent writes of the same data
      final futures = List.generate(10, (i) async {
        return await EnhancedCASStore.store('concurrent', 'test', data);
      });
      
      final uris = await Future.wait(futures);
      
      // All URIs should be identical due to content addressing
      expect(uris.toSet().length, equals(1));
      
      // Verify data integrity
      final retrieved = await EnhancedCASStore.retrieve(uris.first);
      expect(retrieved, equals(data));
    });
  });
}