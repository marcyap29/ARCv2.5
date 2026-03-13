// lib/lumara/agents/screens/vision_ocr_screen.dart
//
// Vision/OCR agent: pick an image, run OCR (text extraction) or Understand (Gemini).
// Calls SwarmSpace vision-ocr plugin via SwarmSpaceClient.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:image_picker/image_picker.dart';
import 'package:my_app/services/swarmspace/swarmspace_client.dart';
import 'package:my_app/shared/app_colors.dart';

/// Screen to run Vision (OCR or Understand) on a picked image.
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
    });
    try {
      final bytes = await _image!.readAsBytes();
      final base64 = base64Encode(bytes);
      final mode = _modeOcr ? 'ocr' : 'understand';
      final params = <String, dynamic>{
        'image_b64': base64,
        'mode': mode,
        '_prism_consent': true, // User consented via dialog or prior approval; PRISM intercept logs it.
      };
      if (!_modeOcr && _promptController.text.trim().isNotEmpty) {
        params['prompt'] = _promptController.text.trim();
      }
      final res = await SwarmSpaceClient.instance.invoke(
        'vision-ocr',
        params,
        onConsentRequired: (_) async {
          if (!mounted) return false;
          final ok = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Use Vision / OCR?'),
              content: const Text(
                'This plugin can extract text or describe images. Your image is sent to SwarmSpace (Vision API + Gemini). Allow once to use it.',
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Allow')),
              ],
            ),
          );
          return ok ?? false;
        },
      );
      if (!mounted) return;
      if (!res.success) {
        setState(() {
          _loading = false;
          _error = res.error ?? 'Request failed';
        });
        return;
      }
      final text = res.data?['text'] as String? ?? '';
      setState(() {
        _loading = false;
        _result = text.isEmpty ? '(No text returned)' : text;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kcBackgroundColor,
      appBar: AppBar(
        backgroundColor: kcBackgroundColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: kcPrimaryTextColor),
        title: Text(
          'Vision / OCR',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: kcPrimaryTextColor,
                fontWeight: FontWeight.bold,
              ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
                  child: OutlinedButton.icon(
                    onPressed: _loading ? null : () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_outlined, size: 20),
                    label: const Text('Camera'),
                    style: OutlinedButton.styleFrom(foregroundColor: kcPrimaryColor),
                  ),
                ),
              ],
            ),
            if (_image != null) ...[
              const Gap(16),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(_image!.path),
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ],
            const Gap(16),
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
            FilledButton.icon(
              onPressed: (_loading || _image == null) ? null : _run,
              icon: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.play_arrow),
              label: Text(_loading ? 'Running...' : 'Run'),
              style: FilledButton.styleFrom(backgroundColor: kcPrimaryColor),
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
            ],
          ],
        ),
      ),
    );
  }
}
