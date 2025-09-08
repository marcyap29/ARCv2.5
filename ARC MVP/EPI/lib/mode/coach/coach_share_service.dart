import 'dart:convert';
import 'dart:io';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';
import 'models/coach_models.dart';
import 'coach_droplet_service.dart';

class CoachShareService {
  final CoachDropletService _dropletService;
  final Box _shareBundlesBox;
  final Uuid _uuid;

  CoachShareService({
    required CoachDropletService dropletService,
    required Box shareBundlesBox,
    Uuid? uuid,
  })  : _dropletService = dropletService,
        _shareBundlesBox = shareBundlesBox,
        _uuid = uuid ?? const Uuid();

  Future<int> getPendingShareCount() async {
    try {
      final responses = await _dropletService.getResponsesForShare();
      return responses.length;
    } catch (e) {
      return 0;
    }
  }

  Future<CoachShareBundle> createShareBundle({
    List<String>? responseIds,
    SharePolicy policy = SharePolicy.redactableByUser,
    List<String> redactedFieldPaths = const [],
    String? coachId,
  }) async {
    try {
      final responses = responseIds != null
          ? (await Future.wait(responseIds.map((id) => _dropletService.getResponse(id))))
              .where((response) => response != null)
              .cast<CoachDropletResponse>()
              .toList()
          : await _dropletService.getResponsesForShare();

      final bundle = CoachShareBundle(
        id: 'csb_${_uuid.v4().substring(0, 8)}',
        createdAt: DateTime.now(),
        dropletResponseIds: responses.map((r) => r.id).toList(),
        policy: policy,
        redactedFieldPaths: redactedFieldPaths,
        version: 'csb-0',
        coachId: coachId,
      );

      await _shareBundlesBox.put(bundle.id, bundle);
      return bundle;
    } catch (e) {
      throw Exception('Failed to create share bundle: $e');
    }
  }

  Future<void> exportShareBundle() async {
    try {
      final bundle = await createShareBundle();
      await _exportBundleAsJson(bundle);
      await _exportBundleAsPdf(bundle);
    } catch (e) {
      throw Exception('Failed to export share bundle: $e');
    }
  }

  Future<void> _exportBundleAsJson(CoachShareBundle bundle) async {
    try {
      final responses = await _dropletService.getRecentResponses(limit: 100);
      final responsesMap = {for (var r in responses) r.id: r};
      
      final bundleData = {
        'version': bundle.version,
        'id': bundle.id,
        'createdAt': bundle.createdAt.toIso8601String(),
        'policy': bundle.policy.name,
        'redactedFieldPaths': bundle.redactedFieldPaths,
        'coachId': bundle.coachId,
        'droplets': bundle.dropletResponseIds
            .map((id) => responsesMap[id])
            .where((response) => response != null)
            .map((response) => {
                  'templateId': response!.templateId,
                  'createdAt': response.createdAt.toIso8601String(),
                  'values': response.values,
                })
            .toList(),
      };

      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/csb_${_formatDate(bundle.createdAt)}.json');
      await file.writeAsString(jsonEncode(bundleData));

      await Share.shareXFiles([XFile(file.path)], text: 'Coach Share Bundle');
    } catch (e) {
      throw Exception('Failed to export JSON: $e');
    }
  }

  Future<void> _exportBundleAsPdf(CoachShareBundle bundle) async {
    try {
      // For now, create a simple text summary
      // In a full implementation, you'd use a PDF library like pdf package
      final responses = await _dropletService.getRecentResponses(limit: 100);
      final responsesMap = {for (var r in responses) r.id: r};
      
      final selectedResponses = bundle.dropletResponseIds
          .map((id) => responsesMap[id])
          .where((response) => response != null)
          .cast<CoachDropletResponse>()
          .toList();

      final summary = StringBuffer();
      summary.writeln('Coach Share Bundle Summary');
      summary.writeln('Generated: ${_formatDate(bundle.createdAt)}');
      summary.writeln('Policy: ${bundle.policy.name}');
      summary.writeln('');

      for (final response in selectedResponses) {
        final template = await _dropletService.getTemplate(response.templateId);
        if (template != null) {
          summary.writeln('${template.title}');
          summary.writeln('Date: ${_formatDate(response.createdAt)}');
          summary.writeln('');
          
          for (final field in template.fields) {
            final value = response.values[field.id];
            if (value != null && !bundle.redactedFieldPaths.contains('${response.templateId}.${field.id}')) {
              summary.writeln('${field.label}: $value');
            }
          }
          summary.writeln('');
        }
      }

      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/csb_${_formatDate(bundle.createdAt)}.txt');
      await file.writeAsString(summary.toString());

      await Share.shareXFiles([XFile(file.path)], text: 'Coach Share Bundle Summary');
    } catch (e) {
      throw Exception('Failed to export PDF: $e');
    }
  }

  Future<void> importCoachReply(String filePath) async {
    try {
      final file = File(filePath);
      final content = await file.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;

      final crb = CoachReplyBundle(
        id: data['id'] as String,
        version: data['version'] as String,
        createdAt: DateTime.parse(data['createdAt'] as String),
        coach: CoachRef(
          displayName: data['coach']['displayName'] as String,
          coachId: data['coach']['coachId'] as String?,
        ),
        references: ReplyRefs(
          csbId: data['references']['csbId'] as String?,
          clientAlias: data['references']['clientAlias'] as String?,
        ),
        recommendations: (data['recommendations'] as List)
            .map((rec) => CoachRecommendation(
                  id: rec['id'] as String,
                  title: rec['title'] as String,
                  why: rec['why'] as String,
                  steps: List<String>.from(rec['steps'] as List),
                  priority: rec['priority'] as String,
                  durationMin: rec['durationMin'] as int?,
                  tags: rec['tags'] != null ? List<String>.from(rec['tags'] as List) : null,
                ))
            .toList(),
        cadence: data['cadence'] != null
            ? Cadence(
                checkIn: data['cadence']['checkIn'] as String,
                nextSessionPrompt: data['cadence']['nextSessionPrompt'] as String?,
              )
            : null,
        notes: data['notes'] as String?,
        attachments: data['attachments'] != null ? List<String>.from(data['attachments'] as List) : null,
        hash: data['hash'] as String?,
      );

      await _shareBundlesBox.put('crb_${crb.id}', crb);
      
      // TODO: Process recommendations into insights
      // This would integrate with your existing insights system
    } catch (e) {
      throw Exception('Failed to import coach reply: $e');
    }
  }

  Future<List<CoachShareBundle>> getShareBundles() async {
    try {
      final bundles = _shareBundlesBox.values
          .cast<CoachShareBundle>()
          .toList();
      
      bundles.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return bundles;
    } catch (e) {
      return [];
    }
  }

  Future<List<CoachReplyBundle>> getCoachReplies() async {
    try {
      final replies = _shareBundlesBox.values
          .where((value) => value is CoachReplyBundle)
          .cast<CoachReplyBundle>()
          .toList();
      
      replies.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return replies;
    } catch (e) {
      return [];
    }
  }

  Future<void> deleteShareBundle(String bundleId) async {
    try {
      await _shareBundlesBox.delete(bundleId);
    } catch (e) {
      throw Exception('Failed to delete share bundle: $e');
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
