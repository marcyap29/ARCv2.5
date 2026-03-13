// lib/lumara/agents/screens/vision_ocr_screen.dart
//
// Vision/Scanning: pick image (Gallery or Scan/camera), run OCR or Understand.
// Result and actions (Save to Outputs, Add to Research, Dismiss) shown inline below result.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:image_picker/image_picker.dart';
import 'package:my_app/arc/chat/ui/research_screen.dart';
import 'package:my_app/arc/outputs/outputs_chronicle_service.dart';
import 'package:my_app/arc/outputs/outputs_models.dart';
import 'package:my_app/arc/outputs/outputs_repository.dart';
import 'package:my_app/arc/outputs/scan_action_sheet.dart';
import 'package:my_app/lumara/agents/vision/parsed_document.dart';
import 'package:my_app/services/swarmspace/prism_service.dart';
import 'package:my_app/shared/app_colors.dart';

/// Screen for Vision/Scanning: OCR or Understand on a picked or camera-captured image.
class VisionOcrScreen extends StatefulWidget {
  const VisionOcrScreen({super.key});

  @override
  State<VisionOcrScreen> createState() => _VisionOcrScreenState();
}

class _VisionOcrScreenState extends State<VisionOcrScreen> {
  final ImagePicker _picker = ImagePicker();
  XFile? _image;
  bool _modeOcr = true; // true = OCR, false = Understand
  final TextEditingController _promptController = TextEditingController(
    text: 'Describe this image and any text in it. Be concise.',
  );
  String? _result;
  String? _error;
  bool _loading = false;
  /// Last scan result as ParsedDocument for Save/Add to Research (inline actions).
  ParsedDocument? _lastParsedDocument;

  @override
  void dispose() {
    _promptController.dispose();
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

  /// Run vision-ocr plugin (OCR or Understand) on current image.
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
      final base64 = base64Encode(bytes);
      final mode = _modeOcr ? 'ocr' : 'understand';
      final params = <String, dynamic>{
        'image_b64': base64,
        'mode': mode,
      };
      if (!_modeOcr && _promptController.text.trim().isNotEmpty) {
        params['prompt'] = _promptController.text.trim();
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
          _error = 'Vision/Scanning was cancelled.';
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

  /// Single "Scan" action: if no image, open camera then run; otherwise run on current image.
  Future<void> _onScan() async {
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
      final item = OutputItem(
        id: '',
        agentKey: req.agentKey,
        folderKey: req.folderKey,
        title: req.title,
        createdAt: DateTime.now(),
        contentJson: req.contentJson,
        autoTags: req.autoTags,
        userTags: const [],
        thumbnailUrl: req.thumbnailUrl,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kcBackgroundColor,
      appBar: AppBar(
        backgroundColor: kcBackgroundColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: kcPrimaryTextColor),
        title: Text(
          'Vision/Scanning',
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
                // Image box at top, below title
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
                // Mode: OCR | Understand
                Text(
                  'Mode',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(color: kcSecondaryColor),
                ),
                const Gap(6),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('OCR (extract text)'), icon: Icon(Icons.text_fields)),
                    ButtonSegment(value: false, label: Text('Understand'), icon: Icon(Icons.auto_awesome)),
                  ],
                  selected: {_modeOcr},
                  onSelectionChanged: (s) => setState(() => _modeOcr = s.first),
                ),
                if (!_modeOcr) ...[
                  const Gap(12),
                  TextField(
                    controller: _promptController,
                    decoration: const InputDecoration(
                      labelText: 'Prompt (optional)',
                      hintText: 'Describe this image...',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                ],
                const Gap(20),
                // Two buttons: Gallery | Scan
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
                        onPressed: _loading ? null : _onScan,
                        icon: const Icon(Icons.document_scanner_outlined, size: 20),
                        label: const Text('Scan'),
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
                  // Inline actions below result (no modal)
                  if (_lastParsedDocument != null)
                    ScanResultActionsInline(
                      document: _lastParsedDocument!,
                      onSaveToOutputs: _onSaveScanToOutputs,
                      onAddToResearch: _onAddScanToResearch,
                      onDismiss: _onDismissResult,
                    ),
                ],
              ],
            ),
          ),
          // Running overlay
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
