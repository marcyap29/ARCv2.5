import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'models/coach_models.dart';
import 'templates/default_droplets.dart';

class CoachDropletService {
  final Box _dropletTemplatesBox;
  final Box _dropletResponsesBox;
  final Uuid _uuid;

  CoachDropletService({
    required Box dropletTemplatesBox,
    required Box dropletResponsesBox,
    Uuid? uuid,
  })  : _dropletTemplatesBox = dropletTemplatesBox,
        _dropletResponsesBox = dropletResponsesBox,
        _uuid = uuid ?? const Uuid();

  Future<void> initialize() async {
    // Initialize default templates if not already present
    final existingTemplates = _dropletTemplatesBox.values.toList();
    if (existingTemplates.isEmpty) {
      for (final template in defaultDroplets) {
        await _dropletTemplatesBox.put(template.id, template);
      }
    }
  }

  Future<List<CoachDropletTemplate>> getAvailableTemplates() async {
    try {
      final templates = _dropletTemplatesBox.values
          .cast<CoachDropletTemplate>()
          .where((template) => template.isDefault)
          .toList();
      
      // Sort by title for consistent ordering
      templates.sort((a, b) => a.title.compareTo(b.title));
      return templates;
    } catch (e) {
      return [];
    }
  }

  Future<List<CoachDropletTemplate>> getAllTemplates() async {
    try {
      final templates = _dropletTemplatesBox.values
          .cast<CoachDropletTemplate>()
          .toList();
      
      templates.sort((a, b) => a.title.compareTo(b.title));
      return templates;
    } catch (e) {
      return [];
    }
  }

  Future<CoachDropletTemplate?> getTemplate(String templateId) async {
    try {
      return _dropletTemplatesBox.get(templateId) as CoachDropletTemplate?;
    } catch (e) {
      return null;
    }
  }

  Future<List<CoachDropletResponse>> getRecentResponses({int limit = 10}) async {
    try {
      final responses = _dropletResponsesBox.values
          .cast<CoachDropletResponse>()
          .toList();
      
      // Sort by creation date (newest first)
      responses.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      return responses.take(limit).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<CoachDropletResponse>> getResponsesForShare() async {
    try {
      final responses = _dropletResponsesBox.values
          .cast<CoachDropletResponse>()
          .where((response) => response.includeInShare)
          .toList();
      
      // Sort by creation date (newest first)
      responses.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      return responses;
    } catch (e) {
      return [];
    }
  }

  Future<CoachDropletResponse?> getResponse(String responseId) async {
    try {
      return _dropletResponsesBox.get(responseId) as CoachDropletResponse?;
    } catch (e) {
      return null;
    }
  }

  Future<String> saveResponse(CoachDropletResponse response) async {
    try {
      await _dropletResponsesBox.put(response.id, response);
      return response.id;
    } catch (e) {
      throw Exception('Failed to save droplet response: $e');
    }
  }

  Future<CoachDropletResponse> createResponse({
    required String templateId,
    required Map<String, dynamic> values,
    bool includeInShare = false,
    String? coachId,
  }) async {
    final response = CoachDropletResponse(
      id: _uuid.v4(),
      templateId: templateId,
      createdAt: DateTime.now(),
      values: values,
      includeInShare: includeInShare,
      coachId: coachId,
    );

    await saveResponse(response);
    return response;
  }

  Future<void> updateResponse(CoachDropletResponse response) async {
    try {
      await _dropletResponsesBox.put(response.id, response);
    } catch (e) {
      throw Exception('Failed to update droplet response: $e');
    }
  }

  Future<void> deleteResponse(String responseId) async {
    try {
      await _dropletResponsesBox.delete(responseId);
    } catch (e) {
      throw Exception('Failed to delete droplet response: $e');
    }
  }

  Future<void> setIncludeInShare(String responseId, bool includeInShare) async {
    try {
      final response = await getResponse(responseId);
      if (response != null) {
        final updatedResponse = response.copyWith(includeInShare: includeInShare);
        await updateResponse(updatedResponse);
      }
    } catch (e) {
      throw Exception('Failed to update share setting: $e');
    }
  }

  Future<List<CoachDropletResponse>> getResponsesByTemplate(String templateId) async {
    try {
      final responses = _dropletResponsesBox.values
          .cast<CoachDropletResponse>()
          .where((response) => response.templateId == templateId)
          .toList();
      
      // Sort by creation date (newest first)
      responses.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      return responses;
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, int>> getResponseCountsByTemplate() async {
    try {
      final responses = _dropletResponsesBox.values
          .cast<CoachDropletResponse>()
          .toList();
      
      final counts = <String, int>{};
      for (final response in responses) {
        counts[response.templateId] = (counts[response.templateId] ?? 0) + 1;
      }
      
      return counts;
    } catch (e) {
      return {};
    }
  }

  Future<void> clearAllResponses() async {
    try {
      await _dropletResponsesBox.clear();
    } catch (e) {
      throw Exception('Failed to clear all responses: $e');
    }
  }

  Future<void> clearOldResponses({int daysOld = 90}) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: daysOld));
      final responses = _dropletResponsesBox.values
          .cast<CoachDropletResponse>()
          .where((response) => response.createdAt.isBefore(cutoffDate))
          .toList();
      
      for (final response in responses) {
        await _dropletResponsesBox.delete(response.id);
      }
    } catch (e) {
      throw Exception('Failed to clear old responses: $e');
    }
  }
}
