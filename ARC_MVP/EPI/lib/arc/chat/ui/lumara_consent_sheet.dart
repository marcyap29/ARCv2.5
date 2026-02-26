import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import '../data/context_scope.dart';

/// Consent sheet for LUMARA privacy settings
class LumaraConsentSheet extends StatefulWidget {
  const LumaraConsentSheet({super.key});

  @override
  State<LumaraConsentSheet> createState() => _LumaraConsentSheetState();
}

class _LumaraConsentSheetState extends State<LumaraConsentSheet> {
  late LumaraScope _scope;

  @override
  void initState() {
    super.initState();
    // Initialize with default scope
    _scope = const LumaraScope();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Gap(24),
          
          // Title
          Text(
            'LUMARA Access',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const Gap(8),
          
          Text(
            'Choose what data LUMARA can access to provide insights',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const Gap(24),
          
          // Scope toggles
          _buildScopeToggle(
            'Conversations',
            'Access your conversations for pattern analysis',
            _scope.journal,
            (value) => setState(() {
              _scope = _scope.copyWith(journal: value);
            }),
            Icons.book,
          ),
          
          _buildScopeToggle(
            'Arcform Responses',
            'Access your Arcform responses for insights',
            _scope.arcforms,
            (value) => setState(() {
              _scope = _scope.copyWith(arcforms: value);
            }),
            Icons.quiz,
          ),
          
          _buildScopeToggle(
            'Voice Transcripts',
            'Access voice recordings and transcripts',
            _scope.voice,
            (value) => setState(() {
              _scope = _scope.copyWith(voice: value);
            }),
            Icons.mic,
          ),
          
          _buildScopeToggle(
            'Media Captions',
            'Access photos and their captions',
            _scope.media,
            (value) => setState(() {
              _scope = _scope.copyWith(media: value);
            }),
            Icons.photo,
          ),
          
          const Gap(24),
          
          // Privacy notice
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.security, color: Colors.blue[700], size: 20),
                const Gap(12),
                Expanded(
                  child: Text(
                    'All data stays on your device. LUMARA never sends your personal information to external servers.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.blue[700],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const Gap(24),
          
          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const Gap(16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _saveSettings,
                  child: const Text('Save Settings'),
                ),
              ),
            ],
          ),
          
          const Gap(16),
        ],
      ),
    );
  }

  Widget _buildScopeToggle(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const Gap(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.blue,
          ),
        ],
      ),
    );
  }

  void _saveSettings() {
    // TODO: Save scope settings to preferences
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('LUMARA settings saved'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}
