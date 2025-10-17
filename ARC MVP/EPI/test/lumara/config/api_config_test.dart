import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/lumara/config/api_config.dart';

void main() {
  group('LumaraAPIConfig Model Registry', () {
    group('isValidModelId', () {
      test('returns true for valid model IDs', () {
        expect(LumaraAPIConfig.isValidModelId('Llama-3.2-3b-Instruct-Q4_K_M.gguf'), true);
        expect(LumaraAPIConfig.isValidModelId('Qwen3-4B-Instruct-2507-Q4_K_S.gguf'), true);
      });

      test('returns false for invalid model IDs', () {
        expect(LumaraAPIConfig.isValidModelId('google_gemma-3n-E2B-it-Q6_K_L.gguf'), false);
        expect(LumaraAPIConfig.isValidModelId('invalid-model-id'), false);
        expect(LumaraAPIConfig.isValidModelId(''), false);
      });
    });

    group('getProviderForModel', () {
      test('returns correct provider for valid model IDs', () {
        expect(LumaraAPIConfig.getProviderForModel('Llama-3.2-3b-Instruct-Q4_K_M.gguf'), 'llama3b');
        expect(LumaraAPIConfig.getProviderForModel('Qwen3-4B-Instruct-2507-Q4_K_S.gguf'), 'qwen4b');
      });

      test('returns null for invalid model IDs', () {
        expect(LumaraAPIConfig.getProviderForModel('google_gemma-3n-E2B-it-Q6_K_L.gguf'), null);
        expect(LumaraAPIConfig.getProviderForModel('invalid-model-id'), null);
        expect(LumaraAPIConfig.getProviderForModel(''), null);
      });
    });

    group('Model Registry Constants', () {
      test('registry contains expected models', () {
        // Access the private registry through reflection or make it public for testing
        // For now, we test the public methods that use the registry
        expect(LumaraAPIConfig.isValidModelId('Llama-3.2-3b-Instruct-Q4_K_M.gguf'), true);
        expect(LumaraAPIConfig.isValidModelId('Qwen3-4B-Instruct-2507-Q4_K_S.gguf'), true);
      });

      test('registry does not contain removed models', () {
        expect(LumaraAPIConfig.isValidModelId('google_gemma-3n-E2B-it-Q6_K_L.gguf'), false);
      });
    });
  });

  group('LumaraAPIConfig Integration', () {
    late LumaraAPIConfig config;

    setUp(() {
      config = LumaraAPIConfig.instance;
    });

    test('can be instantiated', () {
      expect(config, isA<LumaraAPIConfig>());
    });

    test('has model registry methods', () {
      expect(LumaraAPIConfig.isValidModelId, isA<Function>());
      expect(LumaraAPIConfig.getProviderForModel, isA<Function>());
    });
  });
}
