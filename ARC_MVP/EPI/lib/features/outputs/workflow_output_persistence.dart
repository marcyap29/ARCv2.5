import 'dart:convert';
import 'dart:io';

import 'package:my_app/arc/outputs/outputs_chronicle_service.dart';
import 'package:my_app/arc/outputs/outputs_models.dart';
import 'package:my_app/arc/outputs/outputs_repository.dart';
import 'package:my_app/features/outputs/output_model.dart';
import 'package:my_app/services/firebase_auth_service.dart';
import 'package:path_provider/path_provider.dart';

/// Writes the workflow JSON under app Documents `LumaraOutputs/` and mirrors to Firestore
/// output folders (Writing / Research taxonomy) when the user is signed in.
Future<void> persistWorkflowOutputEverywhere(WorkflowOutput output) async {
  await _exportToDocumentsFolder(output);
  await _syncToFirestoreOutputs(output);
}

Future<void> _exportToDocumentsFolder(WorkflowOutput output) async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    final root = Directory('${dir.path}/LumaraOutputs');
    await root.create(recursive: true);
    var rawStem =
        '${output.title}_${output.id}'.replaceAll(RegExp(r'[^\w\-.]+'), '_');
    if (rawStem.isEmpty) rawStem = output.id;
    final stem =
        rawStem.length > 80 ? '${rawStem.substring(0, 80)}_${output.id.substring(0, 8)}' : rawStem;
    final file = File('${root.path}/$stem.json');
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(_jsonEncodable(output.toJson())));
  } catch (_) {
    /* non-fatal */
  }
}

dynamic _jsonEncodable(dynamic v) {
  if (v == null || v is num || v is String || v is bool) return v;
  if (v is Map) {
    return v.map((k, e) => MapEntry(k.toString(), _jsonEncodable(e)));
  }
  if (v is List) {
    return v.map(_jsonEncodable).toList();
  }
  return v.toString();
}

String _folderKeyForPlatformId(String id) {
  switch (id) {
    case 'linkedin':
      return 'linkedin';
    case 'orbital_ai':
    case 'mechanical_musings':
      return 'substack';
    case 'twitter':
      return 'threads';
    case 'bluesky':
      return 'bluesky';
    default:
      return 'articles';
  }
}

({String agentKey, String folderKey, List<String> autoTags}) _taxonomy(WorkflowOutput o) {
  final tags = <String>{
    'workflow',
    o.type,
    for (final s in o.steps) s.toLowerCase().replaceAll(' ', '_'),
  }.toList();
  switch (o.type) {
    case 'writing':
      final platforms = o.data['platforms'];
      var fk = 'articles';
      if (platforms is Map && platforms.isNotEmpty) {
        fk = _folderKeyForPlatformId(platforms.keys.first.toString());
      }
      return (agentKey: 'writing', folderKey: fk, autoTags: tags);
    case 'competitor':
    case 'plugins':
      return (agentKey: 'research', folderKey: 'research', autoTags: tags);
    default:
      return (agentKey: 'research', folderKey: 'research', autoTags: tags);
  }
}

Future<void> _syncToFirestoreOutputs(WorkflowOutput o) async {
  try {
    final uid = FirebaseAuthService.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;
    final t = _taxonomy(o);
    final item = OutputItem(
      id: o.id,
      agentKey: t.agentKey,
      folderKey: t.folderKey,
      title: o.title,
      createdAt: o.createdAt,
      contentJson: jsonEncode(_jsonEncodable(o.toJson())),
      autoTags: t.autoTags,
      userTags: const [],
    );
    final saved = await OutputsRepository.instance.save(item);
    OutputsChronicleService.instance.onOutputSaved(type: 'output_created', item: saved);
  } catch (_) {
    /* non-fatal: offline / rules */
  }
}
