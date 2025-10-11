import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// ECHO configuration manager
class EchoConfig {
  static EchoConfig? _instance;
  static EchoConfig get instance => _instance ??= EchoConfig._();
  
  EchoConfig._();

  EchoConfigData _config = EchoConfigData.defaultConfig();
  bool _isInitialized = false;

  /// Initialize ECHO configuration
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      final configFile = await _getConfigFile();
      
      if (await configFile.exists()) {
        final content = await configFile.readAsString();
        final json = jsonDecode(content);
        _config = EchoConfigData.fromJson(json);
        print('ECHO Config: Loaded configuration from file');
      } else {
        // Create default config file
        await _saveConfig();
        print('ECHO Config: Created default configuration file');
      }
      
      _isInitialized = true;
    } catch (e) {
      print('ECHO Config: Error initializing - $e');
      // Use default config on error
      _isInitialized = true;
    }
  }

  /// Get current configuration
  EchoConfigData get config => _config;

  /// Update configuration
  Future<void> updateConfig(EchoConfigData newConfig) async {
    _config = newConfig;
    await _saveConfig();
    print('ECHO Config: Configuration updated');
  }

  /// Switch provider
  Future<void> switchProvider(ProviderType provider, {Map<String, dynamic>? options}) async {
    _config.currentProvider = provider;
    if (options != null) {
      _config.providerOptions[provider.value] = options;
    }
    await _saveConfig();
    print('ECHO Config: Switched to provider ${provider.value}');
  }

  /// Get provider options
  Map<String, dynamic> getProviderOptions(ProviderType provider) {
    return _config.providerOptions[provider.value] ?? {};
  }

  /// Save configuration to file
  Future<void> _saveConfig() async {
    try {
      final configFile = await _getConfigFile();
      final json = jsonEncode(_config.toJson());
      await configFile.writeAsString(json);
    } catch (e) {
      print('ECHO Config: Error saving configuration - $e');
    }
  }

  /// Get configuration file path
  Future<File> _getConfigFile() async {
    final docsDir = await getApplicationDocumentsDirectory();
    return File(path.join(docsDir.path, 'echo.config.json'));
  }

  /// Reset to default configuration
  Future<void> resetToDefault() async {
    _config = EchoConfigData.defaultConfig();
    await _saveConfig();
    print('ECHO Config: Reset to default configuration');
  }
}

/// ECHO configuration data
class EchoConfigData {
  final ProviderType currentProvider;
  final Map<String, Map<String, dynamic>> providerOptions;
  final Map<String, dynamic> globalOptions;
  final bool enableRivetLite;
  final bool enableVeilAurora;
  final String version;

  EchoConfigData({
    required this.currentProvider,
    required this.providerOptions,
    required this.globalOptions,
    required this.enableRivetLite,
    required this.enableVeilAurora,
    required this.version,
  });

  /// Create default configuration
  factory EchoConfigData.defaultConfig() {
    return EchoConfigData(
      currentProvider: ProviderType.ruleBased,
      providerOptions: {
        'rule_based': {},
        'llama': {
          'modelPath': 'models/llama-3.2-3b-instruct.gguf',
          'contextSize': 2048,
          'threads': 4,
        },
        'ollama': {
          'host': 'http://localhost:11434',
          'model': 'llama3.2:3b',
        },
        'openai': {
          'apiKey': '',
          'model': 'gpt-3.5-turbo',
          'temperature': 0.7,
        },
        'mistral': {
          'apiKey': '',
          'model': 'mistral-small',
          'temperature': 0.7,
        },
      },
      globalOptions: {
        'maxTokens': 500,
        'temperature': 0.7,
        'topP': 0.9,
        'enableStreaming': true,
      },
      enableRivetLite: true,
      enableVeilAurora: true,
      version: '1.0.0',
    );
  }

  /// Create from JSON
  factory EchoConfigData.fromJson(Map<String, dynamic> json) {
    return EchoConfigData(
      currentProvider: ProviderType.fromString(json['currentProvider'] as String? ?? 'rule_based'),
      providerOptions: Map<String, Map<String, dynamic>>.from(
        json['providerOptions']?.map((key, value) => MapEntry(key, Map<String, dynamic>.from(value))) ?? {}
      ),
      globalOptions: Map<String, dynamic>.from(json['globalOptions'] ?? {}),
      enableRivetLite: json['enableRivetLite'] as bool? ?? true,
      enableVeilAurora: json['enableVeilAurora'] as bool? ?? true,
      version: json['version'] as String? ?? '1.0.0',
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'currentProvider': currentProvider.value,
      'providerOptions': providerOptions,
      'globalOptions': globalOptions,
      'enableRivetLite': enableRivetLite,
      'enableVeilAurora': enableVeilAurora,
      'version': version,
    };
  }

  /// Copy with new values
  EchoConfigData copyWith({
    ProviderType? currentProvider,
    Map<String, Map<String, dynamic>>? providerOptions,
    Map<String, dynamic>? globalOptions,
    bool? enableRivetLite,
    bool? enableVeilAurora,
    String? version,
  }) {
    return EchoConfigData(
      currentProvider: currentProvider ?? this.currentProvider,
      providerOptions: providerOptions ?? this.providerOptions,
      globalOptions: globalOptions ?? this.globalOptions,
      enableRivetLite: enableRivetLite ?? this.enableRivetLite,
      enableVeilAurora: enableVeilAurora ?? this.enableVeilAurora,
      version: version ?? this.version,
    );
  }
}

/// Provider types
enum ProviderType {
  ruleBased('rule_based'),
  llama('llama'),
  ollama('ollama'),
  openai('openai'),
  mistral('mistral');

  const ProviderType(this.value);
  final String value;

  static ProviderType fromString(String value) {
    switch (value) {
      case 'rule_based':
        return ProviderType.ruleBased;
      case 'llama':
        return ProviderType.llama;
      case 'ollama':
        return ProviderType.ollama;
      case 'openai':
        return ProviderType.openai;
      case 'mistral':
        return ProviderType.mistral;
      default:
        return ProviderType.ruleBased;
    }
  }
}

/// ECHO configuration presets
class EchoConfigPresets {
  /// Development preset (rule-based)
  static EchoConfigData development() {
    return EchoConfigData(
      currentProvider: ProviderType.ruleBased,
      providerOptions: {
        'rule_based': {},
      },
      globalOptions: {
        'maxTokens': 200,
        'temperature': 0.5,
        'enableStreaming': true,
      },
      enableRivetLite: false,
      enableVeilAurora: false,
      version: '1.0.0',
    );
  }

  /// Production preset (Ollama)
  static EchoConfigData production() {
    return EchoConfigData(
      currentProvider: ProviderType.ollama,
      providerOptions: {
        'ollama': {
          'host': 'http://localhost:11434',
          'model': 'llama3.2:3b',
        },
      },
      globalOptions: {
        'maxTokens': 500,
        'temperature': 0.7,
        'enableStreaming': true,
      },
      enableRivetLite: true,
      enableVeilAurora: true,
      version: '1.0.0',
    );
  }

  /// Cloud preset (OpenAI)
  static EchoConfigData cloud() {
    return EchoConfigData(
      currentProvider: ProviderType.openai,
      providerOptions: {
        'openai': {
          'apiKey': '',
          'model': 'gpt-3.5-turbo',
        },
      },
      globalOptions: {
        'maxTokens': 1000,
        'temperature': 0.7,
        'enableStreaming': true,
      },
      enableRivetLite: true,
      enableVeilAurora: true,
      version: '1.0.0',
    );
  }
}
