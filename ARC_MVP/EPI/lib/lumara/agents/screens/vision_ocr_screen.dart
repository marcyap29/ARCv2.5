// lib/lumara/agents/screens/vision_ocr_screen.dart
//
// Image Analyzer: pick image (Gallery or camera), Simple (text) or Detailed (Q&A).
// Result and actions (Save to Outputs, Add to Research, Dismiss) shown inline below result.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:my_app/arc/chat/ui/research_screen.dart';
import 'package:my_app/arc/outputs/outputs_chronicle_service.dart';
import 'package:my_app/arc/outputs/outputs_models.dart';
import 'package:my_app/arc/outputs/outputs_repository.dart';
import 'package:my_app/arc/outputs/scan_action_sheet.dart';
import 'package:my_app/lumara/agents/forms/form_matcher.dart';
import 'package:my_app/lumara/agents/forms/form_review_screen.dart';
import 'package:my_app/lumara/agents/vision/parsed_document.dart';
import 'package:my_app/lumara/profile/user_profile_service.dart';
import 'package:my_app/services/swarmspace/prism_service.dart';
import 'package:my_app/shared/app_colors.dart';

/// Screen for Image Analyzer: Simple (extract text) or Detailed (answer your question).
class VisionOcrScreen extends StatefulWidget {
  const VisionOcrScreen({super.key});

  @override
  State<VisionOcrScreen> createState() => _VisionOcrScreenState();
}

class _VisionOcrScreenState extends State<VisionOcrScreen> {
  final ImagePicker _picker = ImagePicker();
  XFile? _image;
  /// true = Simple (OCR), false = Detailed (understand + prompt)
  bool _modeSimple = true;
  final TextEditingController _questionController = TextEditingController();
  String? _result;
  String? _error;
  bool _loading = false;
  ParsedDocument? _lastParsedDocument;

  static const String _defaultDetailedPrompt =
      'Describe this image and any text in it. Be concise.';

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? picked = await _picker.pickImage(
      source: source,
      maxWidth: 1920,
      imageQuality: 85,
    );
    if (picked != null && mounted) {
      setState(() {
        _image = picked;
        _error = null;
        _result = null;
        _lastParsedDocument = null;
      });
    }
  }

  Future<void> _run() async {
    if (_image == null) {
      setState(() => _error = 'Pick an image first.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
      _lastParsedDocument = null;
    });
    try {
      final bytes = await _image!.readAsBytes();
      if (!mounted) return;
      final base64 = base64Encode(bytes);
      final mode = _modeSimple ? 'ocr' : 'understand';
      final params = <String, dynamic>{
        'image_b64': base64,
        'mode': mode,
      };
      if (!_modeSimple) {
        final q = _questionController.text.trim();
        params['prompt'] = q.isNotEmpty ? q : _defaultDetailedPrompt;
      }
      final prismResult = await PrismService.instance.authoriseAndCall(
        pluginId: 'vision-ocr',
        params: params,
        context: context,
      );
      if (!mounted) return;
      if (prismResult.isDenied) {
        setState(() {
          _loading = false;
          _error = 'Image Analyzer was cancelled.';
        });
        return;
      }
      final res = prismResult.result!;
      if (!res.success) {
        setState(() {
          _loading = false;
          _error = res.error ?? 'Request failed';
        });
        return;
      }
      final text = res.data?['text'] as String? ?? '';
      final resultText = text.isEmpty ? '(No text returned)' : text;
      setState(() {
        _loading = false;
        _result = resultText;
        _lastParsedDocument = ParsedDocument(
          rawText: resultText,
          keyFields: const [],
          createdAt: DateTime.now(),
        );
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  /// Open camera (or run if image already selected).
  Future<void> _onTakePicture() async {
    if (_image == null) {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        imageQuality: 85,
      );
      if (picked == null || !mounted) return;
      setState(() {
        _image = picked;
        _error = null;
        _result = null;
        _lastParsedDocument = null;
      });
      await _run();
      return;
    }
    await _run();
  }

  Future<void> _onSaveScanToOutputs(OutputSaveRequest req) async {
    try {
      String contentJson = req.contentJson;
      String? thumbnailUrl = req.thumbnailUrl;

      if (_image != null) {
        try {
          final appDir = await getApplicationDocumentsDirectory();
          final scansDir = Directory('${appDir.path}/scans');
          if (!await scansDir.exists()) await scansDir.create(recursive: true);
          final name = 'scan_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final path = '${scansDir.path}/$name';
          await File(_image!.path).copy(path);
          thumbnailUrl = path;
          final contentMap = jsonDecode(contentJson) as Map<String, dynamic>;
          contentMap['image_path'] = path;
          contentJson = jsonEncode(contentMap);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Image save failed: $e'), backgroundColor: Colors.orange),
            );
          }
        }
      }

      final item = OutputItem(
        id: '',
        agentKey: req.agentKey,
        folderKey: req.folderKey,
        title: req.title,
        createdAt: DateTime.now(),
        contentJson: contentJson,
        autoTags: req.autoTags,
        userTags: const [],
        thumbnailUrl: thumbnailUrl,
      );
      final saved = await OutputsRepository.instance.save(item);
      OutputsChronicleService.instance.onOutputSaved(type: 'output_created', item: saved);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved to Outputs')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _onAddScanToResearch(String rawText) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => ResearchScreen(initialDocumentContext: rawText),
      ),
    );
  }

  void _onDismissResult() {
    setState(() {
      _result = null;
      _lastParsedDocument = null;
    });
  }

  Future<void> _onFillForm(ParsedDocument document) async {
    ParsedDocument doc = document;
    if (doc.keyFields.isEmpty && doc.rawText.trim().isNotEmpty) {
      final keyFields = ParsedDocument.parseKeyFieldsFromRawText(doc.rawText);
      doc = ParsedDocument(
        title: doc.title,
        date: doc.date,
        keyFields: keyFields,
        rawText: doc.rawText,
        createdAt: doc.createdAt,
      );
    }
    if (doc.keyFields.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No form fields detected. Try scanning a form with lines like "Name: ___" or "Email: ___".'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    final profile = await UserProfileService.instance.getProfile();
    if (!mounted) return;
    final matches = FormMatcher.match(doc, profile);
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => FormReviewScreen(document: doc, matches: matches),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kcBackgroundColor,
      appBar: AppBar(
        backgroundColor: kcBackgroundColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: kcPrimaryTextColor),
        title: Text(
          'Image Analyzer',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: kcPrimaryTextColor,
                fontWeight: FontWeight.bold,
              ),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_image != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(_image!.path),
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const Gap(16),
                ],
                Text(
                  'Mode',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(color: kcSecondaryColor),
                ),
                const Gap(6),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: true,
                      label: Text('Simple'),
                      icon: Icon(Icons.text_fields, size: 18),
                    ),
                    ButtonSegment(
                      value: false,
                      label: Text('Detailed'),
                      icon: Icon(Icons.auto_awesome, size: 18),
                    ),
                  ],
                  selected: {_modeSimple},
                  onSelectionChanged: (s) {
                    if (s.isEmpty) return;
                    setState(() {
                      _modeSimple = s.first;
                      _error = null;
                      _result = null;
                      _lastParsedDocument = null;
                    });
                  },
                ),
                const Gap(16),
                Text(
                  'Add your question in the box below, then choose a photo. '
                  'Detailed mode answers using vision; Simple mode extracts visible text.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: kcSecondaryColor,
                        height: 1.35,
                      ),
                ),
                const Gap(8),
                Text(
                  'Examples:\n'
                  '• What kind of animal is this?\n'
                  '• What kind of bug is this?\n'
                  '• What kind of tree is this?\n'
                  '• What is the name of this building?',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: kcPrimaryTextColor.withOpacity(0.85),
                        height: 1.4,
                      ),
                ),
                const Gap(12),
                TextField(
                  controller: _questionController,
                  decoration: const InputDecoration(
                    labelText: 'Your question',
                    hintText: 'What would you like to know about the image?',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 3,
                  style: const TextStyle(color: kcPrimaryTextColor),
                ),
                const Gap(20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _loading ? null : () => _pickImage(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_outlined, size: 20),
                        label: const Text('Gallery'),
                        style: OutlinedButton.styleFrom(foregroundColor: kcPrimaryColor),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _loading ? null : _onTakePicture,
                        icon: const Icon(Icons.photo_camera_outlined, size: 20),
                        label: const Text('Take a picture'),
                        style: FilledButton.styleFrom(backgroundColor: kcPrimaryColor),
                      ),
                    ),
                  ],
                ),
                if (_error != null) ...[
                  const Gap(12),
                  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
                if (_result != null) ...[
                  const Gap(16),
                  Text(
                    'Result',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: kcPrimaryTextColor,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const Gap(6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: kcSurfaceAltColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SelectableText(
                      _result!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: kcPrimaryTextColor),
                    ),
                  ),
                  if (_lastParsedDocument != null)
                    ScanResultActionsInline(
                      document: _lastParsedDocument!,
                      onSaveToOutputs: _onSaveScanToOutputs,
                      onAddToResearch: _onAddScanToResearch,
                      onFillForm: _onFillForm,
                      onDismiss: _onDismissResult,
                    ),
                ],
              ],
            ),
          ),
          if (_loading)
            Container(
              color: Colors.black38,
              child: Center(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 40,
                          height: 40,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const Gap(12),
                        Text(
                          'Running…',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(color: kcPrimaryTextColor),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
