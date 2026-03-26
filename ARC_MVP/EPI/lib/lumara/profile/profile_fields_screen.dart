// lib/lumara/profile/profile_fields_screen.dart
// Phase 6: "Help LUMARA fill forms for you" — onboarding or standalone from Settings.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';
import 'package:my_app/features/agents/agents_persona_resolver.dart';
import 'package:my_app/shared/ui/onboarding/arc_onboarding_cubit.dart';
import 'user_profile_service.dart';

const String _keyProfileFieldsSkipped = 'profile_fields_skipped';

class ProfileFieldsScreen extends StatefulWidget {
  const ProfileFieldsScreen({
    super.key,
    this.standaloneMode = false,
    this.onSaveAndComplete,
    this.onSkip,
  });

  final bool standaloneMode;
  final VoidCallback? onSaveAndComplete;
  final VoidCallback? onSkip;

  @override
  State<ProfileFieldsScreen> createState() => _ProfileFieldsScreenState();
}

class _ProfileFieldsScreenState extends State<ProfileFieldsScreen> {
  final Map<String, TextEditingController> _controllers = {};
  bool _loading = true;
  bool _saving = false;
  bool _basicExpanded = true;
  bool _addressExpanded = false;
  bool _personalExpanded = false;
  bool _emergencyExpanded = false;
  /// Matches [AgentsPersonaResolver] roles: founder | student | coach | artist
  String? _agentsRole;

  static const List<({String key, String label})> _basic = [
    (key: 'full_name', label: 'Full name'),
    (key: 'preferred_name', label: 'Preferred name'),
    (key: 'email', label: 'Email'),
    (key: 'phone', label: 'Phone'),
  ];
  static const List<({String key, String label})> _address = [
    (key: 'address_street', label: 'Street'),
    (key: 'address_city', label: 'City'),
    (key: 'address_state', label: 'State'),
    (key: 'address_postcode', label: 'Postcode'),
    (key: 'address_country', label: 'Country'),
  ];
  static const List<({String key, String label})> _personal = [
    (key: 'date_of_birth', label: 'Date of birth (yyyy-MM-dd)'),
    (key: 'employer', label: 'Employer'),
    (key: 'job_title', label: 'Job title'),
  ];
  static const List<({String key, String label})> _emergency = [
    (key: 'emergency_contact_name', label: 'Emergency contact name'),
    (key: 'emergency_contact_phone', label: 'Emergency contact phone'),
    (key: 'health_insurance_number', label: 'Health insurance number'),
  ];

  @override
  void initState() {
    super.initState();
    for (final e in _basic) _controllers[e.key] = TextEditingController();
    for (final e in _address) _controllers[e.key] = TextEditingController();
    for (final e in _personal) _controllers[e.key] = TextEditingController();
    for (final e in _emergency) _controllers[e.key] = TextEditingController();
    _controllers[AgentsPersonaResolver.schoolOrProfessionFormKey] =
        TextEditingController();
    _load();
  }

  Future<void> _load() async {
    final profile = await UserProfileService.instance.getProfile();
    if (mounted) {
      for (final entry in _controllers.entries) {
        entry.value.text = profile[entry.key] ?? '';
      }
      var role = profile[AgentsPersonaResolver.agentsRoleFormKey]?.trim();
      if (role == null || role.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        role = prefs
            .getString(AgentsPersonaResolver.prefsChronicleProfessionKey)
            ?.trim();
      }
      _agentsRole =
          role != null && role.isNotEmpty ? role.toLowerCase() : null;
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) c.dispose();
    super.dispose();
  }

  Future<void> _saveAndAdvance() async {
    setState(() => _saving = true);
    final existing = await UserProfileService.instance.getProfile();
    final fields = Map<String, String>.from(existing);
    for (final entry in _controllers.entries) {
      fields[entry.key] = entry.value.text.trim();
    }
    final r = _agentsRole?.trim().toLowerCase();
    if (r != null && r.isNotEmpty) {
      fields[AgentsPersonaResolver.agentsRoleFormKey] = r;
    } else {
      fields.remove(AgentsPersonaResolver.agentsRoleFormKey);
    }
    await UserProfileService.instance.saveProfile(fields);
    await AgentsPersonaResolver.syncFormFieldsToHive(fields);
    if (!mounted) return;
    setState(() => _saving = false);
    if (widget.standaloneMode) {
      widget.onSaveAndComplete?.call();
    } else {
      context.read<ArcOnboardingCubit>().advanceAfterProfileFields();
    }
  }

  void _skip() async {
    if (widget.standaloneMode) {
      widget.onSkip?.call();
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyProfileFieldsSkipped, true);
    if (!mounted) return;
    context.read<ArcOnboardingCubit>().advanceAfterProfileFields();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: widget.standaloneMode
          ? AppBar(
              title: const Text('My Profile'),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              ),
            )
          : null,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!widget.standaloneMode)
                      _consentBanner(context),
                    if (!widget.standaloneMode) const SizedBox(height: 16),
                    Text(
                      'Help LUMARA fill forms for you',
                      style: heading1Style(context).copyWith(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Fill in what you\'re comfortable with — everything is optional',
                      style: bodyStyle(context).copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _schoolAndProfessionCard(context),
                    const SizedBox(height: 12),
                    _expansionSection(context, 'Basic', _basic, _basicExpanded, (v) => setState(() => _basicExpanded = v), false),
                    _expansionSection(context, 'Address', _address, _addressExpanded, (v) => setState(() => _addressExpanded = v), false),
                    _expansionSection(context, 'Personal', _personal, _personalExpanded, (v) => setState(() => _personalExpanded = v), false),
                    _expansionSection(context, 'Emergency & Health', _emergency, _emergencyExpanded, (v) => setState(() => _emergencyExpanded = v), true),
                    const SizedBox(height: 32),
                    if (_saving)
                      const Center(child: CircularProgressIndicator())
                    else ...[
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _saveAndAdvance,
                          style: FilledButton.styleFrom(
                            backgroundColor: kcPrimaryColor,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text(widget.standaloneMode ? 'Save changes' : 'Save & Continue'),
                        ),
                      ),
                      if (!widget.standaloneMode || widget.onSkip != null) ...[
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: _skip,
                          child: Text(
                            widget.standaloneMode ? 'Back' : 'Skip',
                            style: bodyStyle(context).copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  Widget _schoolAndProfessionCard(BuildContext context) {
    const roles = <(String, String)>[
      ('founder', 'Founder'),
      ('student', 'Student'),
      ('coach', 'Coach'),
      ('artist', 'Artist'),
    ];
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'School & profession',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Used to tailor LUMARA Agents (suggested goals and context). Optional.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 14),
            Text(
              'Which best describes you?',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: roles.map((role) {
                final id = role.$1;
                final label = role.$2;
                final selected = _agentsRole == id;
                return FilterChip(
                  label: Text(label),
                  selected: selected,
                  onSelected: (v) {
                    setState(() {
                      _agentsRole = v ? id : null;
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller:
                  _controllers[AgentsPersonaResolver.schoolOrProfessionFormKey],
              decoration: InputDecoration(
                labelText: 'School, company, or profession (optional)',
                helperText:
                    'e.g. university, employer, studio, or how you introduce yourself',
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _consentBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.3)),
      ),
      child: Text(
        'Your profile is stored only on this device. It is never shared with anyone and is only used when you ask LUMARA to pre-fill a form. You can edit or delete it anytime in Settings → Subscription and Account → My Profile.',
        style: bodyStyle(context).copyWith(
          fontSize: 13,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _expansionSection(
    BuildContext context,
    String title,
    List<({String key, String label})> fields,
    bool expanded,
    ValueChanged<bool> onExpandedChanged,
    bool isSensitiveSection,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          InkWell(
            onTap: () => onExpandedChanged(!expanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  if (isSensitiveSection)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        'Sensitive',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Theme.of(context).colorScheme.error,
                            ),
                      ),
                    ),
                  Icon(expanded ? Icons.expand_less : Icons.expand_more),
                ],
              ),
            ),
          ),
          if (isSensitiveSection)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'This information is sensitive. LUMARA will always ask for your permission before using it.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: fields
                    .map((e) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: TextField(
                            controller: _controllers[e.key],
                            decoration: InputDecoration(
                              labelText: e.label,
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }
}
