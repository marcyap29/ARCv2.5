import 'package:json_annotation/json_annotation.dart';

part 'storage_profiles.g.dart';

enum StoragePolicy {
  @JsonValue('minimal')
  minimal,
  @JsonValue('balanced')
  balanced,
  @JsonValue('hiFidelity')
  hiFidelity,
}

enum AppMode {
  @JsonValue('personal')
  personal,
  @JsonValue('firstResponder')
  firstResponder,
  @JsonValue('coach')
  coach,
}

@JsonSerializable()
class StorageProfile {
  final StoragePolicy policy;
  final String displayName;
  final String description;
  final bool keepThumbnails;
  final bool keepTranscripts;
  final bool keepAnalysisVariant;
  final bool keepFullResolution;
  final bool enableEncryption;
  final int maxFileSizeMB;
  final int retentionDays;

  const StorageProfile({
    required this.policy,
    required this.displayName,
    required this.description,
    required this.keepThumbnails,
    required this.keepTranscripts,
    required this.keepAnalysisVariant,
    required this.keepFullResolution,
    required this.enableEncryption,
    required this.maxFileSizeMB,
    required this.retentionDays,
  });

  factory StorageProfile.fromJson(Map<String, dynamic> json) => _$StorageProfileFromJson(json);
  Map<String, dynamic> toJson() => _$StorageProfileToJson(this);

  static const StorageProfile minimal = StorageProfile(
    policy: StoragePolicy.minimal,
    displayName: 'Space-Saver',
    description: 'Keep only thumbnails and transcripts. References original files.',
    keepThumbnails: true,
    keepTranscripts: true,
    keepAnalysisVariant: false,
    keepFullResolution: false,
    enableEncryption: false,
    maxFileSizeMB: 10,
    retentionDays: 30,
  );

  static const StorageProfile balanced = StorageProfile(
    policy: StoragePolicy.balanced,
    displayName: 'Balanced',
    description: 'Keep analysis variants (1024px images, 360p videos, compressed audio) encrypted.',
    keepThumbnails: true,
    keepTranscripts: true,
    keepAnalysisVariant: true,
    keepFullResolution: false,
    enableEncryption: true,
    maxFileSizeMB: 25,
    retentionDays: 90,
  );

  static const StorageProfile hiFidelity = StorageProfile(
    policy: StoragePolicy.hiFidelity,
    displayName: 'Hi-Fidelity',
    description: 'Keep encrypted full-resolution local copies with auto-offload option.',
    keepThumbnails: true,
    keepTranscripts: true,
    keepAnalysisVariant: true,
    keepFullResolution: true,
    enableEncryption: true,
    maxFileSizeMB: 100,
    retentionDays: 180,
  );

  static List<StorageProfile> get allProfiles => [minimal, balanced, hiFidelity];

  static StorageProfile forPolicy(StoragePolicy policy) {
    switch (policy) {
      case StoragePolicy.minimal:
        return minimal;
      case StoragePolicy.balanced:
        return balanced;
      case StoragePolicy.hiFidelity:
        return hiFidelity;
    }
  }
}

@JsonSerializable()
class StorageSettings {
  final StoragePolicy globalDefault;
  final Map<AppMode, StoragePolicy> modeOverrides;
  final bool enableAutoOffload;
  final int autoOffloadDays;
  final bool enableRetentionPruner;

  const StorageSettings({
    required this.globalDefault,
    required this.modeOverrides,
    required this.enableAutoOffload,
    required this.autoOffloadDays,
    required this.enableRetentionPruner,
  });

  factory StorageSettings.fromJson(Map<String, dynamic> json) => _$StorageSettingsFromJson(json);
  Map<String, dynamic> toJson() => _$StorageSettingsToJson(this);

  static const StorageSettings defaultSettings = StorageSettings(
    globalDefault: StoragePolicy.minimal,
    modeOverrides: {
      AppMode.personal: StoragePolicy.minimal,
      AppMode.firstResponder: StoragePolicy.hiFidelity,
      AppMode.coach: StoragePolicy.hiFidelity,
    },
    enableAutoOffload: true,
    autoOffloadDays: 30,
    enableRetentionPruner: true,
  );

  StoragePolicy getPolicyForMode(AppMode mode) {
    return modeOverrides[mode] ?? globalDefault;
  }

  StorageProfile getProfileForMode(AppMode mode) {
    return StorageProfile.forPolicy(getPolicyForMode(mode));
  }

  StorageSettings copyWith({
    StoragePolicy? globalDefault,
    Map<AppMode, StoragePolicy>? modeOverrides,
    bool? enableAutoOffload,
    int? autoOffloadDays,
    bool? enableRetentionPruner,
  }) {
    return StorageSettings(
      globalDefault: globalDefault ?? this.globalDefault,
      modeOverrides: modeOverrides ?? Map.from(this.modeOverrides),
      enableAutoOffload: enableAutoOffload ?? this.enableAutoOffload,
      autoOffloadDays: autoOffloadDays ?? this.autoOffloadDays,
      enableRetentionPruner: enableRetentionPruner ?? this.enableRetentionPruner,
    );
  }
}

class StorageEstimate {
  final int totalFiles;
  final int totalSizeBytes;
  final int thumbnailSizeBytes;
  final int transcriptSizeBytes;
  final int analysisSizeBytes;
  final int fullResSizeBytes;

  const StorageEstimate({
    required this.totalFiles,
    required this.totalSizeBytes,
    required this.thumbnailSizeBytes,
    required this.transcriptSizeBytes,
    required this.analysisSizeBytes,
    required this.fullResSizeBytes,
  });

  double get totalSizeMB => totalSizeBytes / (1024 * 1024);
  double get thumbnailSizeMB => thumbnailSizeBytes / (1024 * 1024);
  double get transcriptSizeMB => transcriptSizeBytes / (1024 * 1024);
  double get analysisSizeMB => analysisSizeBytes / (1024 * 1024);
  double get fullResSizeMB => fullResSizeBytes / (1024 * 1024);

  @override
  String toString() {
    return 'StorageEstimate(files: $totalFiles, size: ${totalSizeMB.toStringAsFixed(1)}MB)';
  }
}