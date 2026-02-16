import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:my_app/arc/chat/config/api_config.dart';
import 'package:my_app/arc/chat/services/groq_service.dart';
import 'package:my_app/lumara/agents/writing/writing_agent.dart';
import 'package:my_app/lumara/agents/writing/writing_models.dart';
import 'package:my_app/services/firebase_auth_service.dart';

/// Dedicated screen for the LUMARA Writing Agent.
/// User enters a prompt and content type, then sees the generated draft and optional scores.
class WritingScreen extends StatefulWidget {
  const WritingScreen({super.key});

  @override
  State<WritingScreen> createState() => _WritingScreenState();
}

class _WritingScreenState extends State<WritingScreen> {
  final TextEditingController _promptController = TextEditingController();
  ContentType _contentType = ContentType.linkedIn;
  String? _draft;
  double? _voiceScore;
  double? _themeAlignment;
  List<String> _suggestedEdits = [];
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) {
      setState(() {
        _error = 'Enter a prompt (e.g. what to write about).';
      });
      return;
    }
    final userId = FirebaseAuthService.instance.currentUser?.uid ?? 'default_user';
    setState(() {
      _loading = true;
      _error = null;
      _draft = null;
      _voiceScore = null;
      _themeAlignment = null;
      _suggestedEdits = [];
    });
    try {
      await LumaraAPIConfig.instance.initialize();
      final config = LumaraAPIConfig.instance.getConfig(LLMProvider.groq);
      final apiKey = config?.apiKey;
      if (apiKey == null || apiKey.isEmpty) {
        setState(() {
          _loading = false;
          _error = 'Groq API key not set. Add it in LUMARA settings.';
        });
        return;
      }
      final groq = GroqService(apiKey: apiKey);
      final agent = WritingAgent(
        generateContent: ({required systemPrompt, required userPrompt, maxTokens}) async {
          return groq.generateContent(
            prompt: userPrompt,
            systemPrompt: systemPrompt,
            maxTokens: maxTokens ?? 800,
          );
        },
      );
      final composed = await agent.composeContent(
        userId: userId,
        prompt: prompt,
        type: _contentType,
        maxCritiqueIterations: 2,
      );
      if (mounted) {
        setState(() {
          _loading = false;
          _draft = composed.draft.content;
          _voiceScore = composed.voiceScore;
          _themeAlignment = composed.themeAlignment;
          _suggestedEdits = composed.suggestedEdits;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  void _copyDraft() {
    if (_draft != null) {
      Clipboard.setData(ClipboardData(text: _draft!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Draft copied to clipboard')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LUMARA Writing'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _promptController,
              decoration: const InputDecoration(
                labelText: 'What should we write about?',
                hintText: 'e.g. Why CHRONICLE hierarchical aggregation matters for AI memory',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 3,
            ),
            const Gap(16),
            DropdownButtonFormField<ContentType>(
              // ignore: deprecated_member_use
              value: _contentType,
              decoration: const InputDecoration(
                labelText: 'Content type',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: ContentType.linkedIn, child: Text('LinkedIn post')),
                DropdownMenuItem(value: ContentType.substack, child: Text('Substack article')),
                DropdownMenuItem(value: ContentType.technical, child: Text('Technical doc')),
              ],
              onChanged: (v) => setState(() => _contentType = v ?? ContentType.linkedIn),
            ),
            const Gap(24),
            FilledButton(
              onPressed: _loading ? null : _generate,
              child: _loading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Generate draft'),
            ),
            if (_error != null) ...[
              const Gap(16),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            if (_draft != null) ...[
              const Gap(24),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Draft', style: Theme.of(context).textTheme.titleMedium),
                  TextButton.icon(
                    onPressed: _copyDraft,
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Copy'),
                  ),
                ],
              ),
              if (_voiceScore != null || _themeAlignment != null) ...[
                const Gap(8),
                Text(
                  'Voice: ${(_voiceScore! * 100).toStringAsFixed(0)}%  •  Theme: ${(_themeAlignment! * 100).toStringAsFixed(0)}%',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const Gap(8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(_draft!),
              ),
              if (_suggestedEdits.isNotEmpty) ...[
                const Gap(16),
                Text('Suggestions', style: Theme.of(context).textTheme.titleSmall),
                const Gap(4),
                ..._suggestedEdits.map((s) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.lightbulb_outline, size: 16),
                          const SizedBox(width: 8),
                          Expanded(child: Text(s, style: Theme.of(context).textTheme.bodySmall)),
                        ],
                      ),
                    )),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
