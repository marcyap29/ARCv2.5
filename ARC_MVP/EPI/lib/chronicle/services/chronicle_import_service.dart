import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:archive/archive_io.dart';
import '../storage/aggregation_repository.dart';
import '../storage/changelog_repository.dart';
import '../models/chronicle_layer.dart';
import '../../crossroads/models/decision_capture.dart';
import '../../crossroads/storage/decision_capture_repository.dart';
import '../../models/phase_models.dart';
import '../../prism/atlas/rivet/rivet_models.dart';

/// Result of CHRONICLE import (aggregations, decisions, changelog).
class ChronicleImportResult {
  int monthlyCount = 0;
  int yearlyCount = 0;
  int multiyearCount = 0;
  int decisionsCount = 0;
  int changelogEntries = 0;
  bool success = false;
  String? error;

  int get totalCount => monthlyCount + yearlyCount + multiyearCount + decisionsCount + changelogEntries;

  @override
  String toString() {
    if (!success) return 'Import failed: $error';
    if (totalCount == 0) return 'No files were imported.';
    final parts = <String>[];
    if (monthlyCount + yearlyCount + multiyearCount > 0) {
      parts.add('$monthlyCount monthly, $yearlyCount yearly, $multiyearCount multi-year aggregations');
    }
    if (decisionsCount > 0) parts.add('$decisionsCount decisions');
    if (changelogEntries > 0) parts.add('$changelogEntries changelog entries');
    return 'Imported ${parts.join(', ')}';
  }
}

/// Service to import CHRONICLE data from a ZIP file (recommended) or a directory.
///
/// Supports:
/// - **ZIP file**: same layout as [ChronicleExportService.exportToZip] (monthly/, yearly/, multiyear/, decisions/, changelog.jsonl).
/// - **Directory**: for older exports or manual folders (same layout, or flat .md with frontmatter).
class ChronicleImportService {
  final AggregationRepository _aggregationRepo;
  final ChangelogRepository? _changelogRepo;

  ChronicleImportService({
    required AggregationRepository aggregationRepo,
    ChangelogRepository? changelogRepo,
  })  : _aggregationRepo = aggregationRepo,
        _changelogRepo = changelogRepo;

  /// Import from a ZIP file (e.g. created by Export). Extracts to a temp directory then imports.
  Future<ChronicleImportResult> importFromZip({
    required String userId,
    required File zipFile,
    void Function(int processed, int total)? onProgress,
  }) async {
    if (!zipFile.path.toLowerCase().endsWith('.zip')) {
      return ChronicleImportResult()
        ..success = false
        ..error = 'Please select a .zip file (from CHRONICLE Export).';
    }
    final tempDir = Directory(path.join(Directory.systemTemp.path, 'chronicle_import_${DateTime.now().millisecondsSinceEpoch}'));
    try {
      await tempDir.create(recursive: true);
      await extractFileToDisk(zipFile.path, tempDir.path);
      final result = await importFromDirectory(
        userId: userId,
        exportDir: tempDir,
        onProgress: onProgress,
      );
      return result;
    } catch (e) {
      print('❌ ChronicleImportService: ZIP import failed: $e');
      return ChronicleImportResult()
        ..success = false
        ..error = e.toString();
    } finally {
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
    }
  }

  /// Import from a directory (export layout or older folder export). Use for backwards compatibility.
  /// [onProgress] is called with (processedCount, totalCount).
  Future<ChronicleImportResult> importFromDirectory({
    required String userId,
    required Directory exportDir,
    void Function(int processed, int total)? onProgress,
  }) async {
    final result = ChronicleImportResult();
    try {
      // 1) Aggregations: standard structure or flat
      final monthlyDir = Directory(path.join(exportDir.path, 'monthly'));
      final yearlyDir = Directory(path.join(exportDir.path, 'yearly'));
      final multiyearDir = Directory(path.join(exportDir.path, 'multiyear'));

      final monthlyFiles = await _listMdFiles(monthlyDir);
      final yearlyFiles = await _listMdFiles(yearlyDir);
      final multiyearFiles = await _listMdFiles(multiyearDir);

      List<({File file, ChronicleLayer layer, String period})> items = [];

      if (monthlyFiles.isNotEmpty || yearlyFiles.isNotEmpty || multiyearFiles.isNotEmpty) {
        for (final file in monthlyFiles) {
          items.add((file: file, layer: ChronicleLayer.monthly, period: path.basenameWithoutExtension(file.path)));
        }
        for (final file in yearlyFiles) {
          items.add((file: file, layer: ChronicleLayer.yearly, period: path.basenameWithoutExtension(file.path)));
        }
        for (final file in multiyearFiles) {
          items.add((file: file, layer: ChronicleLayer.multiyear, period: path.basenameWithoutExtension(file.path)));
        }
      } else {
        final flatFiles = await _listMdFiles(exportDir);
        for (final file in flatFiles) {
          final typePeriod = _parseTypeAndPeriodFromFile(file);
          if (typePeriod != null) {
            items.add((file: file, layer: typePeriod.layer, period: typePeriod.period));
          }
        }
      }

      int processed = 0;
      final totalAggs = items.length;
      onProgress?.call(0, totalAggs);

      for (final item in items) {
        try {
          final content = await item.file.readAsString();
          final agg = _aggregationRepo.parseFromMarkdownContent(
            content,
            item.layer,
            item.period,
            userId,
          );
          switch (item.layer) {
            case ChronicleLayer.monthly:
              await _aggregationRepo.saveMonthly(userId, agg);
              result.monthlyCount++;
              break;
            case ChronicleLayer.yearly:
              await _aggregationRepo.saveYearly(userId, agg);
              result.yearlyCount++;
              break;
            case ChronicleLayer.multiyear:
              await _aggregationRepo.saveMultiYear(userId, agg);
              result.multiyearCount++;
              break;
            default:
              break;
          }
        } catch (e) {
          print('⚠️ ChronicleImportService: Failed to import ${item.file.path}: $e');
        }
        processed++;
        onProgress?.call(processed, totalAggs);
      }

      // 2) Decisions (decisions/ folder — same format as export)
      final decisionsDir = Directory(path.join(exportDir.path, 'decisions'));
      final decisionFiles = await _listMdFiles(decisionsDir);
      if (decisionFiles.isNotEmpty) {
        final decisionRepo = DecisionCaptureRepository();
        await decisionRepo.initialize();
        for (final file in decisionFiles) {
          try {
            final capture = _parseDecisionMarkdown(file);
            if (capture != null) {
              await decisionRepo.save(capture);
              result.decisionsCount++;
            }
          } catch (e) {
            print('⚠️ ChronicleImportService: Failed to import decision ${file.path}: $e');
          }
        }
      }

      // 3) Changelog (changelog.jsonl or changelog.json)
      if (_changelogRepo != null) {
        final jsonlFile = File(path.join(exportDir.path, 'changelog.jsonl'));
        final jsonFile = File(path.join(exportDir.path, 'changelog.json'));
        List<ChangelogEntry> changelogEntries = [];
        if (await jsonlFile.exists()) {
          final lines = await jsonlFile.readAsString();
          for (final line in lines.split('\n').where((l) => l.trim().isNotEmpty)) {
            try {
              final map = jsonDecode(line) as Map<String, dynamic>;
              changelogEntries.add(ChangelogEntry.fromJson(map));
            } catch (_) {}
          }
        } else if (await jsonFile.exists()) {
          final content = await jsonFile.readAsString();
          try {
            final list = jsonDecode(content) as List<dynamic>;
            for (final e in list) {
              changelogEntries.add(ChangelogEntry.fromJson(Map<String, dynamic>.from(e as Map)));
            }
          } catch (_) {}
        }
        if (changelogEntries.isNotEmpty) {
          await _changelogRepo!.appendEntries(changelogEntries);
          result.changelogEntries = changelogEntries.length;
        }
      }

      result.success = true;
      if (result.totalCount == 0) {
        result.error = 'No importable files found. Select the folder you exported to (with monthly/, yearly/, multiyear/, decisions/, changelog.jsonl).';
      } else {
        print('✅ ChronicleImportService: Imported ${result.monthlyCount} monthly, ${result.yearlyCount} yearly, ${result.multiyearCount} multi-year, ${result.decisionsCount} decisions, ${result.changelogEntries} changelog entries');
      }
      return result;
    } catch (e) {
      print('❌ ChronicleImportService: Import failed: $e');
      result.success = false;
      result.error = e.toString();
      return result;
    }
  }

  /// Import a single .md file (e.g. user picked a file). Layer and period from frontmatter.
  Future<ChronicleImportResult> importFromFile({
    required String userId,
    required File file,
    void Function(int processed, int total)? onProgress,
  }) async {
    final result = ChronicleImportResult();
    if (!file.path.endsWith('.md')) {
      result.success = false;
      result.error = 'Please select an .md aggregation file (from CHRONICLE Export).';
      return result;
    }
    try {
      onProgress?.call(0, 1);
      final typePeriod = _parseTypeAndPeriodFromFile(file);
      if (typePeriod == null) {
        result.success = false;
        result.error = 'File is not a valid aggregation (missing type/period in frontmatter).';
        return result;
      }
      final content = await file.readAsString();
      final agg = _aggregationRepo.parseFromMarkdownContent(
        content,
        typePeriod.layer,
        typePeriod.period,
        userId,
      );
      switch (typePeriod.layer) {
        case ChronicleLayer.monthly:
          await _aggregationRepo.saveMonthly(userId, agg);
          result.monthlyCount = 1;
          break;
        case ChronicleLayer.yearly:
          await _aggregationRepo.saveYearly(userId, agg);
          result.yearlyCount = 1;
          break;
        case ChronicleLayer.multiyear:
          await _aggregationRepo.saveMultiYear(userId, agg);
          result.multiyearCount = 1;
          break;
        default:
          result.success = false;
          result.error = 'Unsupported aggregation type: ${typePeriod.layer.name}';
          return result;
      }
      onProgress?.call(1, 1);
      result.success = true;
      return result;
    } catch (e) {
      print('❌ ChronicleImportService: Import from file failed: $e');
      result.success = false;
      result.error = e.toString();
      return result;
    }
  }

  /// Parse type and period from export-format frontmatter (type: monthly_aggregation, period: 2025-01).
  ({ChronicleLayer layer, String period})? _parseTypeAndPeriodFromFile(File file) {
    try {
      final content = file.readAsStringSync();
      if (!content.startsWith('---')) return null;
      final parts = content.split('---');
      if (parts.length < 2) return null;
      final frontmatter = parts[1].trim();
      String? typeStr;
      String? periodStr;
      for (final line in frontmatter.split('\n')) {
        if (line.contains(':')) {
          final idx = line.indexOf(':');
          final key = line.substring(0, idx).trim();
          final value = line.substring(idx + 1).trim();
          if (key == 'type') typeStr = value;
          if (key == 'period') periodStr = value;
        }
      }
      if (typeStr == null || periodStr == null) return null;
      ChronicleLayer layer;
      if (typeStr == 'monthly_aggregation') {
        layer = ChronicleLayer.monthly;
      } else if (typeStr == 'yearly_aggregation') {
        layer = ChronicleLayer.yearly;
      } else if (typeStr == 'multiyear_aggregation') {
        layer = ChronicleLayer.multiyear;
      } else {
        return null;
      }
      return (layer: layer, period: periodStr);
    } catch (_) {
      return null;
    }
  }

  Future<List<File>> _listMdFiles(Directory dir) async {
    if (!await dir.exists()) return [];
    try {
      return dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.md'))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Parse decision capture from export-format markdown (frontmatter + ## sections).
  DecisionCapture? _parseDecisionMarkdown(File file) {
    try {
      final content = file.readAsStringSync();
      if (!content.startsWith('---')) return null;
      final parts = content.split('---');
      if (parts.length < 2) return null;
      final frontmatter = parts[1].trim();
      String? id;
      DateTime? capturedAt;
      String? phaseAtCaptureStr;
      bool userInitiated = false;
      for (final line in frontmatter.split('\n')) {
        if (line.contains(':')) {
          final idx = line.indexOf(':');
          final key = line.substring(0, idx).trim();
          final value = line.substring(idx + 1).trim();
          if (key == 'id') id = value;
          if (key == 'captured_at') capturedAt = DateTime.tryParse(value);
          if (key == 'phase_at_capture') phaseAtCaptureStr = value;
          if (key == 'user_initiated') userInitiated = value.toLowerCase() == 'true';
        }
      }
      if (id == null || capturedAt == null || phaseAtCaptureStr == null) return null;
      final phaseAtCapture = PhaseLabel.values.firstWhere(
            (p) => p.name == phaseAtCaptureStr,
            orElse: () => PhaseLabel.discovery,
          );
      final body = parts.length > 2 ? parts.sublist(2).join('---').trim() : '';
      final decisionStatement = _sectionContent(body, 'What I Was Deciding');
      final lifeContext = _sectionContent(body, 'What Was Going On');
      final optionsConsidered = _sectionContent(body, 'What I Was Weighing');
      final successMarker = _sectionContent(body, 'What Success Looks Like');
      String? outcomeLog = _sectionContent(body, 'What Actually Happened');
      if (outcomeLog != null && (outcomeLog.isEmpty || outcomeLog == 'Not yet logged')) {
        outcomeLog = null;
      }
      return DecisionCapture(
        id: id,
        capturedAt: capturedAt,
        phaseAtCapture: phaseAtCapture,
        sentinelScoreAtCapture: 0.0,
        decisionStatement: decisionStatement ?? '',
        lifeContext: lifeContext ?? '',
        optionsConsidered: optionsConsidered ?? '',
        successMarker: successMarker ?? '',
        outcomeLog: outcomeLog,
        outcomeLoggedAt: null,
        phaseAtOutcome: null,
        linkedJournalEntryId: null,
        includedInAggregation: false,
        triggerConfidence: 0.0,
        triggerPhrase: DecisionPhraseCategory.consideration,
        userInitiated: userInitiated,
      );
    } catch (_) {
      return null;
    }
  }

  String? _sectionContent(String body, String sectionTitle) {
    final marker = '## $sectionTitle';
    final idx = body.indexOf(marker);
    if (idx < 0) return null;
    final start = idx + marker.length;
    final rest = body.substring(start).trim();
    final nextHash = rest.indexOf('\n## ');
    final content = nextHash < 0 ? rest : rest.substring(0, nextHash).trim();
    return content.isEmpty ? null : content;
  }
}
