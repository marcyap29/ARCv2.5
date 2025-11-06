// lib/features/privacy/privacy_demo_screen.dart
// User Demonstration Interface - F5 Implementation
// REQ-5.1 through REQ-5.4

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_app/echo/privacy_core/pii_detection_service.dart';
import 'package:my_app/echo/privacy_core/pii_masking_service.dart';
import 'package:my_app/echo/privacy_core/models/pii_types.dart' hide MaskingOptions;

class PrivacyDemoScreen extends StatefulWidget {
  const PrivacyDemoScreen({super.key});

  @override
  State<PrivacyDemoScreen> createState() => _PrivacyDemoScreenState();
}

class _PrivacyDemoScreenState extends State<PrivacyDemoScreen> with TickerProviderStateMixin {
  final TextEditingController _inputController = TextEditingController();
  final PIIDetectionService _detectionService = PIIDetectionService();
  late final PIIMaskingService _maskingService;

  // Demo state
  PIIDetectionResult? _detectionResult;
  MaskingResult? _maskingResult;
  bool _isProcessing = false;
  SensitivityLevel _sensitivityLevel = SensitivityLevel.normal;
  MaskingOptions _maskingOptions = const MaskingOptions();

  // Animation controllers
  late AnimationController _highlightController;
  late AnimationController _statsController;

  // Sample texts for demonstration
  final List<String> _sampleTexts = [
    'Hi, I\'m John Smith. You can reach me at john.smith@company.com or call (555) 123-4567. I live at 123 Main Street, Apartment 5B.',
    'Sarah Johnson (sarah@email.com) mentioned she needs the financial report. Her SSN is 123-45-6789 for the background check.',
    'Conference call with Michael Davis at 2pm. His direct line is 555-987-6543. Send the agenda to michael.davis@corporation.org beforehand.',
    'Patient: Jennifer Wilson, DOB: 07/15/1985, Phone: (555) 246-8109, Address: 456 Oak Avenue, Credit Card: 4532 1234 5678 9012',
    'Meeting notes: Contact Jane Doe (jane.doe@startup.io) about the API integration. Server IP: 192.168.1.100, Database password: temp123!'
  ];

  @override
  void initState() {
    super.initState();
    _maskingService = PIIMaskingService(_detectionService);

    // Initialize animations
    _highlightController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _statsController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    // Set initial sample text
    _inputController.text = _sampleTexts.first;
    _processText();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _highlightController.dispose();
    _statsController.dispose();
    super.dispose();
  }

  /// Process text through PII detection and masking (REQ-5.2)
  Future<void> _processText() async {
    if (_inputController.text.trim().isEmpty) {
      setState(() {
        _detectionResult = null;
        _maskingResult = null;
      });
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      // Step 1: Detect PII
      final stopwatch = Stopwatch()..start();
      final detectionResult = _detectionService.detectPII(_inputController.text);

      // Step 2: Mask detected PII
      final maskingResult = _maskingService.maskText(
        _inputController.text,
        options: _maskingOptions,
      );

      stopwatch.stop();

      setState(() {
        _detectionResult = detectionResult;
        _maskingResult = maskingResult;
        _isProcessing = false;
      });

      // Trigger animations
      _highlightController.forward();
      _statsController.forward();

    } catch (e) {
      setState(() {
        _isProcessing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error processing text: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PII Protection Demo'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderCard(),
            const SizedBox(height: 16),
            _buildInputSection(),
            const SizedBox(height: 16),
            _buildControlsSection(),
            const SizedBox(height: 16),
            _buildResultsSection(),
            const SizedBox(height: 16),
            _buildStatsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.security, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Privacy Protection Demonstration',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'This tool demonstrates real-time PII detection and masking. '
              'Enter text containing personal information to see how it\'s protected before external processing.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  /// Input section with text field and sample buttons (REQ-5.1)
  Widget _buildInputSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Input Text',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _inputController,
              decoration: const InputDecoration(
                hintText: 'Enter text containing personal information...',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
              onChanged: (_) => _processText(),
            ),
            const SizedBox(height: 12),
            Text(
              'Sample Texts:',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _sampleTexts.asMap().entries.map((entry) {
                final index = entry.key;
                return ActionChip(
                  label: Text('Sample ${index + 1}'),
                  onPressed: () {
                    _inputController.text = entry.value;
                    _processText();
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  /// Controls for sensitivity and masking options
  Widget _buildControlsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Detection & Masking Settings',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),

            // Sensitivity Level
            Text('Detection Sensitivity:', style: Theme.of(context).textTheme.labelMedium),
            SegmentedButton<SensitivityLevel>(
              segments: const [
                ButtonSegment(value: SensitivityLevel.relaxed, label: Text('Relaxed')),
                ButtonSegment(value: SensitivityLevel.normal, label: Text('Normal')),
                ButtonSegment(value: SensitivityLevel.strict, label: Text('Strict')),
              ],
              selected: {_sensitivityLevel},
              onSelectionChanged: (Set<SensitivityLevel> selection) {
                setState(() {
                  _sensitivityLevel = selection.first;
                  _detectionService.sensitivityLevel = _sensitivityLevel;
                });
                _processText();
              },
            ),

            const SizedBox(height: 16),

            // Masking Options
            Text('Masking Options:', style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 8),

            CheckboxListTile(
              title: const Text('Preserve Structure'),
              subtitle: const Text('Maintain text formatting and length'),
              value: _maskingOptions.preserveStructure,
              onChanged: (bool? value) {
                setState(() {
                  _maskingOptions = MaskingOptions(
                    preserveStructure: value ?? true,
                    consistentMapping: _maskingOptions.consistentMapping,
                    reversibleMasking: _maskingOptions.reversibleMasking,
                    hashEmails: _maskingOptions.hashEmails,
                  );
                });
                _processText();
              },
            ),

            CheckboxListTile(
              title: const Text('Hash Emails'),
              subtitle: const Text('Generate SHA256 hashes for email addresses'),
              value: _maskingOptions.hashEmails,
              onChanged: (bool? value) {
                setState(() {
                  _maskingOptions = MaskingOptions(
                    preserveStructure: _maskingOptions.preserveStructure,
                    consistentMapping: _maskingOptions.consistentMapping,
                    reversibleMasking: _maskingOptions.reversibleMasking,
                    hashEmails: value ?? true,
                  );
                });
                _processText();
              },
            ),

            CheckboxListTile(
              title: const Text('Reversible Masking'),
              subtitle: const Text('Allow local unmasking for debugging'),
              value: _maskingOptions.reversibleMasking,
              onChanged: (bool? value) {
                setState(() {
                  _maskingOptions = MaskingOptions(
                    preserveStructure: _maskingOptions.preserveStructure,
                    consistentMapping: _maskingOptions.consistentMapping,
                    reversibleMasking: value ?? false,
                    hashEmails: _maskingOptions.hashEmails,
                  );
                });
                _processText();
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Results section showing before/after and highlighting (REQ-5.2, REQ-5.3)
  Widget _buildResultsSection() {
    if (_detectionResult == null || _maskingResult == null) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Processing Results',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),

            // Before (with highlighting)
            _buildTextPreview(
              title: 'Before (Original Text)',
              text: _detectionResult!.originalText,
              matches: _detectionResult!.matches,
              isOriginal: true,
            ),

            const SizedBox(height: 16),

            // After (masked)
            _buildTextPreview(
              title: 'After (Protected Text)',
              text: _maskingResult!.maskedText,
              matches: [],
              isOriginal: false,
            ),

            // Reversible masking demo
            if (_maskingOptions.reversibleMasking) ...[
              const SizedBox(height: 16),
              _buildReversibleDemo(),
            ],
          ],
        ),
      ),
    );
  }

  /// Text preview with PII highlighting (REQ-5.3)
  Widget _buildTextPreview({
    required String title,
    required String text,
    required List<PIIMatch> matches,
    required bool isOriginal,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.copy),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: text));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied to clipboard')),
                );
              },
              tooltip: 'Copy to clipboard',
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isOriginal ? Colors.red.shade50 : Colors.green.shade50,
            border: Border.all(
              color: isOriginal ? Colors.red.shade200 : Colors.green.shade200,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: _buildHighlightedText(text, matches, isOriginal),
        ),
      ],
    );
  }

  /// Build text with PII highlighting (REQ-5.3)
  Widget _buildHighlightedText(String text, List<PIIMatch> matches, bool isOriginal) {
    if (matches.isEmpty || !isOriginal) {
      return Text(
        text,
        style: const TextStyle(fontFamily: 'monospace'),
      );
    }

    final spans = <TextSpan>[];
    int lastIndex = 0;

    // Sort matches by start index
    final sortedMatches = [...matches]..sort((a, b) => a.startIndex.compareTo(b.startIndex));

    for (final match in sortedMatches) {
      // Add text before this match
      if (match.startIndex > lastIndex) {
        spans.add(TextSpan(
          text: text.substring(lastIndex, match.startIndex),
        ));
      }

      // Add highlighted match
      final matchText = text.substring(match.startIndex, match.endIndex);
      spans.add(TextSpan(
        text: matchText,
        style: TextStyle(
          backgroundColor: _getHighlightColor(match.type),
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ));

      lastIndex = match.endIndex;
    }

    // Add remaining text
    if (lastIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastIndex),
      ));
    }

    return RichText(
      text: TextSpan(
        children: spans,
        style: const TextStyle(
          fontFamily: 'monospace',
          color: Colors.black,
        ),
      ),
    );
  }

  /// Get color for PII type highlighting (REQ-5.3)
  Color _getHighlightColor(PIIType type) {
    switch (type) {
      case PIIType.name:
        return Colors.blue;
      case PIIType.email:
        return Colors.purple;
      case PIIType.phone:
        return Colors.orange;
      case PIIType.address:
        return Colors.green;
      case PIIType.ssn:
        return Colors.red;
      case PIIType.creditCard:
        return Colors.deepOrange;
      case PIIType.ipAddress:
        return Colors.teal;
      case PIIType.url:
        return Colors.indigo;
      case PIIType.dateOfBirth:
        return Colors.brown;
      case PIIType.macAddress:
      case PIIType.licensePlate:
      case PIIType.passport:
      case PIIType.driverLicense:
      case PIIType.bankAccount:
      case PIIType.routingNumber:
      case PIIType.medicalRecord:
      case PIIType.healthInsurance:
      case PIIType.biometric:
      case PIIType.other:
        return Colors.grey;
    }
  }

  /// Reversible masking demonstration
  Widget _buildReversibleDemo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Reversible Masking Demo (Local Only)',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            border: Border.all(color: Colors.blue.shade200),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Unmasked (for local debugging):',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _maskingService.unmaskText(_maskingResult!.maskedText),
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Statistics section showing performance and detection details (REQ-5.4)
  Widget _buildStatsSection() {
    if (_detectionResult == null || _maskingResult == null) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: _statsController,
      builder: (context, child) {
        return Transform.scale(
          scale: 0.8 + (_statsController.value * 0.2),
          child: Opacity(
            opacity: _statsController.value,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Detection & Performance Statistics',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),

                    // Detection stats
                    _buildStatRow('PII Items Detected', '${_detectionResult!.matches.length}'),
                    _buildStatRow('Processing Time', '${_detectionResult!.processingTime.inMilliseconds}ms'),
                    _buildStatRow('Text Length', '${_detectionResult!.originalText.length} characters'),
                    _buildStatRow('Masking Mappings', '${_maskingResult!.maskingMap.length}'),

                    const SizedBox(height: 12),

                    // PII type breakdown
                    Text(
                      'PII Types Detected:',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const SizedBox(height: 8),

                    ..._buildPIITypeBreakdown(),

                    const SizedBox(height: 12),

                    // Confidence scores
                    Text(
                      'Detection Confidence:',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const SizedBox(height: 8),

                    _buildConfidenceIndicator(),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPIITypeBreakdown() {
    final typeCount = <PIIType, int>{};
    for (final match in _detectionResult!.matches) {
      typeCount[match.type] = (typeCount[match.type] ?? 0) + 1;
    }

    return typeCount.entries.map((entry) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: _getHighlightColor(entry.key),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(entry.key.toString().split('.').last),
            const Spacer(),
            Text('${entry.value}'),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildConfidenceIndicator() {
    if (_detectionResult!.matches.isEmpty) {
      return const Text('No PII detected');
    }

    final avgConfidence = _detectionResult!.matches
        .map((m) => m.confidence)
        .reduce((a, b) => a + b) / _detectionResult!.matches.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Average: ${(avgConfidence * 100).toStringAsFixed(1)}%'),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: avgConfidence,
          backgroundColor: Colors.grey.shade300,
          valueColor: AlwaysStoppedAnimation<Color>(
            avgConfidence > 0.8 ? Colors.green :
            avgConfidence > 0.6 ? Colors.orange : Colors.red,
          ),
        ),
      ],
    );
  }
}