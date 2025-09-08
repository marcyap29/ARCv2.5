import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../redaction/redaction_service.dart';
import '../debrief/debrief_models.dart';
import '../incident_template/incident_template_models.dart';
import '../fr_settings.dart';

/// P30: Clean Share Export Service
/// Handles de-identification and export of first responder data
class CleanShareService {
  static final CleanShareService _instance = CleanShareService._internal();
  factory CleanShareService() => _instance;
  CleanShareService._internal();

  final RedactionService _redactionService = RedactionService();

  /// Get default FR settings for redaction
  FRSettings get _frSettings => FRSettings.defaults();

  /// Export debrief record as clean PDF
  Future<File> exportDebriefAsPDF(DebriefRecord debrief, {
    String? customTitle,
    bool includeVoiceTranscriptions = true,
    bool includeMetadata = false,
  }) async {
    final pdf = pw.Document();
    
    // Apply redaction to all text content
    final redactedSnapshot = await _redactionService.redact(
      entryId: debrief.id,
      originalText: debrief.snapshot,
      createdAt: debrief.createdAt,
      settings: _frSettings,
    );
    final redactedWentWell = await Future.wait(debrief.wentWell.map((item) => _redactionService.redact(
      entryId: debrief.id,
      originalText: item,
      createdAt: debrief.createdAt,
      settings: _frSettings,
    )));
    final redactedWasHard = await Future.wait(debrief.wasHard.map((item) => _redactionService.redact(
      entryId: debrief.id,
      originalText: item,
      createdAt: debrief.createdAt,
      settings: _frSettings,
    )));
    final redactedEssence = await _redactionService.redact(
      entryId: debrief.id,
      originalText: debrief.essence,
      createdAt: debrief.createdAt,
      settings: _frSettings,
    );
    final redactedNextStep = await _redactionService.redact(
      entryId: debrief.id,
      originalText: debrief.nextStep,
      createdAt: debrief.createdAt,
      settings: _frSettings,
    );

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey300,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      customTitle ?? 'Debrief Summary',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'Generated: ${_formatDate(DateTime.now())}',
                      style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
                    ),
                  ],
                ),
              ),
              
              pw.SizedBox(height: 20),
              
              // Snapshot section
              _buildSection(
                'Incident Snapshot',
                redactedSnapshot,
              ),
              
              pw.SizedBox(height: 16),
              
              // Reflection section
              _buildReflectionSection(redactedWentWell, redactedWasHard),
              
              pw.SizedBox(height: 16),
              
              // Body check section
              _buildBodyCheckSection(debrief.bodyScore),
              
              pw.SizedBox(height: 16),
              
              // Essence section
              _buildSection(
                'Key Takeaway',
                redactedEssence,
              ),
              
              pw.SizedBox(height: 16),
              
              // Next step section
              _buildSection(
                'Next Step',
                redactedNextStep,
              ),
              
              // Voice transcriptions
              if (includeVoiceTranscriptions && debrief.voiceRecordings.isNotEmpty) ...[
                pw.SizedBox(height: 20),
                _buildVoiceTranscriptionsSection(debrief.voiceRecordings),
              ],
              
              // Metadata
              if (includeMetadata) ...[
                pw.SizedBox(height: 20),
                _buildMetadataSection(debrief),
              ],
            ],
          );
        },
      ),
    );

    // Save PDF
    final directory = await getApplicationDocumentsDirectory();
    final fileName = 'debrief_clean_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File(path.join(directory.path, 'exports', fileName));
    
    // Create exports directory if it doesn't exist
    await file.parent.create(recursive: true);
    
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  /// Export incident report as clean PDF
  Future<File> exportIncidentAsPDF(IncidentTemplate incident, {
    String? customTitle,
    bool includeMetadata = false,
  }) async {
    final pdf = pw.Document();
    
    // Apply redaction to all text content
    final redactedLocation = await _redactionService.redact(
      entryId: incident.id,
      originalText: incident.location,
      createdAt: incident.createdAt,
      settings: _frSettings,
    );
    final redactedSituation = await _redactionService.redact(
      entryId: incident.id,
      originalText: incident.situation,
      createdAt: incident.createdAt,
      settings: _frSettings,
    );
    final redactedAwareness = await _redactionService.redact(
      entryId: incident.id,
      originalText: incident.awareness,
      createdAt: incident.createdAt,
      settings: _frSettings,
    );
    final redactedEnvironment = await _redactionService.redact(
      entryId: incident.id,
      originalText: incident.environment,
      createdAt: incident.createdAt,
      settings: _frSettings,
    );
    final redactedOutcome = await _redactionService.redact(
      entryId: incident.id,
      originalText: incident.outcome,
      createdAt: incident.createdAt,
      settings: _frSettings,
    );
    final redactedKeyLearning = await _redactionService.redact(
      entryId: incident.id,
      originalText: incident.keyLearning,
      createdAt: incident.createdAt,
      settings: _frSettings,
    );
    final redactedFutureConsiderations = await _redactionService.redact(
      entryId: incident.id,
      originalText: incident.futureConsiderations,
      createdAt: incident.createdAt,
      settings: _frSettings,
    );

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey300,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      customTitle ?? 'Incident Report',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'Incident ID: ${incident.id}',
                      style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
                    ),
                    pw.Text(
                      'Generated: ${_formatDate(DateTime.now())}',
                      style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
                    ),
                  ],
                ),
              ),
              
              pw.SizedBox(height: 20),
              
              // Incident type
              _buildSection(
                'Incident Type',
                _getIncidentTypeDisplay(incident.type),
              ),
              
              pw.SizedBox(height: 16),
              
              // SAGE Framework section
              _buildSAGESection(redactedSituation, redactedAwareness, redactedEnvironment),
              
              pw.SizedBox(height: 16),
              
              // Actions & Outcomes section
              _buildActionsSection(incident.actionsCompleted, incident.challengesFaced, redactedOutcome),
              
              pw.SizedBox(height: 16),
              
              // Location
              if (redactedLocation.isNotEmpty)
                _buildSection('Location', redactedLocation),
              
              pw.SizedBox(height: 16),
              
              // Learning & Improvement
              if (redactedKeyLearning.isNotEmpty)
                _buildSection('Key Learning', redactedKeyLearning),
              
              pw.SizedBox(height: 16),
              
              // Future Considerations
              if (redactedFutureConsiderations.isNotEmpty)
                _buildSection('Future Considerations', redactedFutureConsiderations),
              
              // Metadata
              if (includeMetadata) ...[
                pw.SizedBox(height: 20),
                _buildIncidentMetadataSection(incident),
              ],
            ],
          );
        },
      ),
    );

    // Save PDF
    final directory = await getApplicationDocumentsDirectory();
    final fileName = 'incident_clean_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File(path.join(directory.path, 'exports', fileName));
    
    // Create exports directory if it doesn't exist
    await file.parent.create(recursive: true);
    
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  /// Export data as clean JSON
  Future<File> exportAsJSON(Map<String, dynamic> data, {
    String? fileName,
  }) async {
    // Apply redaction to all string values recursively
    final redactedData = await _redactMapRecursively(data);
    
    final jsonString = const JsonEncoder.withIndent('  ').convert(redactedData);
    
    final directory = await getApplicationDocumentsDirectory();
    final finalFileName = fileName ?? 'export_clean_${DateTime.now().millisecondsSinceEpoch}.json';
    final file = File(path.join(directory.path, 'exports', finalFileName));
    
    // Create exports directory if it doesn't exist
    await file.parent.create(recursive: true);
    
    await file.writeAsString(jsonString);
    return file;
  }

  /// Get export statistics
  Future<Map<String, dynamic>> getExportStatistics() async {
    final directory = await getApplicationDocumentsDirectory();
    final exportsDir = Directory(path.join(directory.path, 'exports'));
    
    if (!await exportsDir.exists()) {
      return {
        'totalFiles': 0,
        'totalSize': 0,
        'fileTypes': {},
        'lastExport': null,
      };
    }

    final files = await exportsDir.list().toList();
    int totalSize = 0;
    final fileTypes = <String, int>{};
    DateTime? lastExport;

    for (final file in files) {
      if (file is File) {
        final stat = await file.stat();
        totalSize += stat.size;
        
        final extension = path.extension(file.path).toLowerCase();
        fileTypes[extension] = (fileTypes[extension] ?? 0) + 1;
        
        if (lastExport == null || stat.modified.isAfter(lastExport)) {
          lastExport = stat.modified;
        }
      }
    }

    return {
      'totalFiles': files.length,
      'totalSize': totalSize,
      'fileTypes': fileTypes,
      'lastExport': lastExport?.toIso8601String(),
    };
  }

  /// Delete all exports
  Future<bool> deleteAllExports() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final exportsDir = Directory(path.join(directory.path, 'exports'));
      
      if (await exportsDir.exists()) {
        await exportsDir.delete(recursive: true);
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  // Private helper methods

  pw.Widget _buildSection(String title, String content) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          content.isEmpty ? 'No content provided' : content,
          style: pw.TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  pw.Widget _buildReflectionSection(List<String> wentWell, List<String> wasHard) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Reflection',
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 8),
        
        if (wentWell.isNotEmpty) ...[
          pw.Text(
            'What went well:',
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          ...wentWell.map((item) => pw.Padding(
            padding: const pw.EdgeInsets.only(left: 16, bottom: 2),
            child: pw.Text('• $item', style: pw.TextStyle(fontSize: 12)),
          )),
          pw.SizedBox(height: 8),
        ],
        
        if (wasHard.isNotEmpty) ...[
          pw.Text(
            'What was hard:',
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          ...wasHard.map((item) => pw.Padding(
            padding: const pw.EdgeInsets.only(left: 16, bottom: 2),
            child: pw.Text('• $item', style: pw.TextStyle(fontSize: 12)),
          )),
        ],
      ],
    );
  }

  pw.Widget _buildBodyCheckSection(int bodyScore) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Body Check',
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          'Stress Level: $bodyScore/5',
          style: pw.TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  pw.Widget _buildVoiceTranscriptionsSection(List<dynamic> recordings) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Voice Recordings',
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 8),
        ...recordings.map((recording) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 8),
          child: pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Recording (${recording.duration?.toString() ?? 'Unknown'})',
                  style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                ),
                if (recording.transcription != null) ...[
                  pw.SizedBox(height: 4),
                  pw.Text(
                    recording.transcription.toString(),
                    style: pw.TextStyle(fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
        )),
      ],
    );
  }

  pw.Widget _buildMetadataSection(DebriefRecord debrief) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Metadata',
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          'Created: ${_formatDate(debrief.createdAt)}',
          style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
        ),
        pw.Text(
          'ID: ${debrief.id}',
          style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
        ),
      ],
    );
  }


  pw.Widget _buildActionsSection(List<String> actions, List<String> challenges, String outcome) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Actions & Outcomes',
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 8),
        
        if (actions.isNotEmpty) ...[
          pw.Text('Actions Completed:', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          ...actions.map((action) => pw.Padding(
            padding: const pw.EdgeInsets.only(left: 16, bottom: 2),
            child: pw.Text('• $action', style: pw.TextStyle(fontSize: 11)),
          )),
          pw.SizedBox(height: 8),
        ],
        
        if (challenges.isNotEmpty) ...[
          pw.Text('Challenges Faced:', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          ...challenges.map((challenge) => pw.Padding(
            padding: const pw.EdgeInsets.only(left: 16, bottom: 2),
            child: pw.Text('• $challenge', style: pw.TextStyle(fontSize: 11)),
          )),
          pw.SizedBox(height: 8),
        ],
        
        if (outcome.isNotEmpty) ...[
          pw.Text('Outcome:', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.Text(outcome, style: pw.TextStyle(fontSize: 11)),
        ],
      ],
    );
  }

  pw.Widget _buildSAGESection(String situation, String awareness, String environment) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'SAGE Analysis',
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 8),
        
        if (situation.isNotEmpty) ...[
          pw.Text('Situation:', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.Text(situation, style: pw.TextStyle(fontSize: 11)),
          pw.SizedBox(height: 8),
        ],
        
        if (awareness.isNotEmpty) ...[
          pw.Text('Awareness:', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.Text(awareness, style: pw.TextStyle(fontSize: 11)),
          pw.SizedBox(height: 8),
        ],
        
        if (environment.isNotEmpty) ...[
          pw.Text('Environment:', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.Text(environment, style: pw.TextStyle(fontSize: 11)),
        ],
      ],
    );
  }


  pw.Widget _buildIncidentMetadataSection(IncidentTemplate incident) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Metadata',
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          'Created: ${_formatDate(incident.createdAt)}',
          style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
        ),
        if (incident.updatedAt != null)
          pw.Text(
            'Updated: ${_formatDate(incident.updatedAt!)}',
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
          ),
        pw.Text(
          'ID: ${incident.id}',
          style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _getIncidentTypeDisplay(IncidentType type) {
    switch (type) {
      case IncidentType.fire:
        return 'Fire Response';
      case IncidentType.medical:
        return 'Medical Emergency';
      case IncidentType.rescue:
        return 'Rescue Operation';
      case IncidentType.hazmat:
        return 'Hazmat Incident';
      case IncidentType.mva:
        return 'Motor Vehicle Accident';
      case IncidentType.law:
        return 'Law Enforcement';
      case IncidentType.other:
        return 'Other';
    }
  }



  Future<Map<String, dynamic>> _redactMapRecursively(Map<String, dynamic> data) async {
    final redacted = <String, dynamic>{};
    final entryId = 'export_${DateTime.now().millisecondsSinceEpoch}';
    final now = DateTime.now();
    
    for (final entry in data.entries) {
      if (entry.value is String) {
        redacted[entry.key] = await _redactionService.redact(
          entryId: entryId,
          originalText: entry.value,
          createdAt: now,
          settings: _frSettings,
        );
      } else if (entry.value is Map<String, dynamic>) {
        redacted[entry.key] = await _redactMapRecursively(entry.value);
      } else if (entry.value is List) {
        redacted[entry.key] = await Future.wait(entry.value.map((item) async {
          if (item is String) {
            return await _redactionService.redact(
              entryId: entryId,
              originalText: item,
              createdAt: now,
              settings: _frSettings,
            );
          } else if (item is Map<String, dynamic>) {
            return await _redactMapRecursively(item);
          }
          return item;
        }));
      } else {
        redacted[entry.key] = entry.value;
      }
    }
    
    return redacted;
  }
}
