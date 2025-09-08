import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';
import 'incident_template_models.dart';
import 'incident_template_cubit.dart';
import 'incident_report_models.dart';

/// P29: AAR-SAGE Incident Template Flow Screen
/// Guided incident documentation following After Action Review principles
class IncidentTemplateFlowScreen extends StatefulWidget {
  final IncidentType? initialType;
  final String? incidentId;
  final VoidCallback? onCompleted;

  const IncidentTemplateFlowScreen({
    super.key,
    this.initialType,
    this.incidentId,
    this.onCompleted,
  });

  @override
  State<IncidentTemplateFlowScreen> createState() => _IncidentTemplateFlowScreenState();
}

class _IncidentTemplateFlowScreenState extends State<IncidentTemplateFlowScreen> {
  late PageController _pageController;
  int _currentStep = 0;

  final List<IncidentTemplateStep> _steps = [
    IncidentTemplateStep.incidentType,
    IncidentTemplateStep.aar,
    IncidentTemplateStep.sage,
    IncidentTemplateStep.tags,
    IncidentTemplateStep.review,
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    
    // Initialize with incident type if provided
    if (widget.initialType != null) {
      context.read<IncidentTemplateCubit>().setIncidentType(widget.initialType!);
    }
    if (widget.incidentId != null) {
      context.read<IncidentTemplateCubit>().setIncidentId(widget.incidentId!);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kcBackgroundColor,
      appBar: AppBar(
        backgroundColor: kcBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: kcPrimaryTextColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Incident Report',
          style: heading2Style(context).copyWith(color: kcPrimaryTextColor),
        ),
        actions: [
          if (_currentStep > 0)
            TextButton(
              onPressed: _previousStep,
              child: Text(
                'Back',
                style: bodyStyle(context).copyWith(color: kcAccentColor),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Progress indicator
          _buildProgressIndicator(),
          
          // Step content
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentStep = index;
                });
              },
              children: [
                _buildIncidentTypeStep(),
                _buildAARStep(),
                _buildSAGEStep(),
                _buildTagsStep(),
                _buildReviewStep(),
              ],
            ),
          ),
          
          // Navigation buttons
          _buildNavigationButtons(),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: _steps.asMap().entries.map((entry) {
          final index = entry.key;
          final isActive = index == _currentStep;
          final isCompleted = index < _currentStep;
          
          return Expanded(
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isCompleted 
                        ? kcAccentColor 
                        : isActive 
                            ? kcAccentColor.withValues(alpha: 0.3)
                            : Colors.grey.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(Icons.check, color: Colors.white, size: 16)
                        : Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: isActive ? kcAccentColor : Colors.grey,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                if (index < _steps.length - 1)
                  Expanded(
                    child: Container(
                      height: 2,
                      color: isCompleted 
                          ? kcAccentColor 
                          : Colors.grey.withValues(alpha: 0.3),
                    ),
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildIncidentTypeStep() {
    return BlocBuilder<IncidentTemplateCubit, IncidentTemplateState>(
      builder: (context, state) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Incident Type',
                style: heading2Style(context).copyWith(color: kcPrimaryTextColor),
              ),
              const SizedBox(height: 8),
              Text(
                'Select the type of incident you\'re documenting',
                style: bodyStyle(context).copyWith(color: kcSecondaryTextColor),
              ),
              const SizedBox(height: 32),
              
              // Incident type options
              ...IncidentType.values.map((type) => _buildIncidentTypeOption(type, state.incidentType)),
              
              const SizedBox(height: 32),
              
              // Incident ID input
              Text(
                'Incident ID (Optional)',
                style: heading3Style(context).copyWith(color: kcPrimaryTextColor),
              ),
              const SizedBox(height: 12),
              TextField(
                decoration: InputDecoration(
                  hintText: 'Enter incident ID or case number',
                  hintStyle: bodyStyle(context).copyWith(color: kcSecondaryTextColor),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: kcAccentColor),
                  ),
                ),
                onChanged: (value) {
                  context.read<IncidentTemplateCubit>().setIncidentId(value);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildIncidentTypeOption(IncidentType type, IncidentType? selectedType) {
    final isSelected = selectedType == type;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          context.read<IncidentTemplateCubit>().setIncidentType(type);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected 
                ? kcAccentColor.withValues(alpha: 0.1)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected 
                  ? kcAccentColor 
                  : Colors.grey.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                _getIncidentTypeIcon(type),
                color: isSelected ? kcAccentColor : kcSecondaryTextColor,
                size: 24,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getIncidentTypeTitle(type),
                      style: heading3Style(context).copyWith(
                        color: isSelected ? kcAccentColor : kcPrimaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getIncidentTypeDescription(type),
                      style: bodyStyle(context).copyWith(
                        color: kcSecondaryTextColor,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                const Icon(
                  Icons.check_circle,
                  color: kcAccentColor,
                  size: 24,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAARStep() {
    return BlocBuilder<IncidentTemplateCubit, IncidentTemplateState>(
      builder: (context, state) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'After Action Review',
                style: heading2Style(context).copyWith(color: kcPrimaryTextColor),
              ),
              const SizedBox(height: 8),
              Text(
                'Document what happened vs. what was expected',
                style: bodyStyle(context).copyWith(color: kcSecondaryTextColor),
              ),
              const SizedBox(height: 32),
              
              // Expected vs Actual
              _buildAARField(
                'Situation',
                'Describe what happened in neutral, factual terms',
                state.aarData.situation,
                (value) => context.read<IncidentTemplateCubit>().updateAARData(
                  state.aarData.copyWith(situation: value),
                ),
              ),
              
              const SizedBox(height: 24),
              
              _buildAARField(
                'Awareness',
                'What did you observe and assess on arrival',
                state.aarData.awareness,
                (value) => context.read<IncidentTemplateCubit>().updateAARData(
                  state.aarData.copyWith(awareness: value),
                ),
              ),
              
              const SizedBox(height: 24),
              
              _buildAARField(
                'Environment',
                'Describe conditions, hazards, and constraints',
                state.aarData.environment,
                (value) => context.read<IncidentTemplateCubit>().updateAARData(
                  state.aarData.copyWith(environment: value),
                ),
              ),
              
              const SizedBox(height: 24),
              
              _buildAARField(
                'Outcome',
                'What was the final outcome of the incident',
                state.aarData.outcome,
                (value) => context.read<IncidentTemplateCubit>().updateAARData(
                  state.aarData.copyWith(outcome: value),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAARField(String title, String hint, String value, Function(String) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: heading3Style(context).copyWith(color: kcPrimaryTextColor),
        ),
        const SizedBox(height: 8),
        TextField(
          maxLines: 4,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: bodyStyle(context).copyWith(color: kcSecondaryTextColor),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: kcAccentColor),
            ),
          ),
          onChanged: onChanged,
          controller: TextEditingController(text: value),
        ),
      ],
    );
  }

  Widget _buildSAGEStep() {
    return BlocBuilder<IncidentTemplateCubit, IncidentTemplateState>(
      builder: (context, state) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SAGE Analysis',
                style: heading2Style(context).copyWith(color: kcPrimaryTextColor),
              ),
              const SizedBox(height: 8),
              Text(
                'Structured analysis of the incident',
                style: bodyStyle(context).copyWith(color: kcSecondaryTextColor),
              ),
              const SizedBox(height: 32),
              
              _buildSAGEField(
                'Situation',
                'Describe the situation in neutral, factual terms',
                state.sageData.situation,
                (value) => context.read<IncidentTemplateCubit>().updateSAGEData(
                  state.sageData.copyWith(situation: value),
                ),
              ),
              
              const SizedBox(height: 24),
              
              _buildSAGEField(
                'Awareness',
                'What did you observe and assess',
                state.sageData.awareness,
                (value) => context.read<IncidentTemplateCubit>().updateSAGEData(
                  state.sageData.copyWith(awareness: value),
                ),
              ),
              
              const SizedBox(height: 24),
              
              _buildSAGEField(
                'Environment',
                'Describe conditions, hazards, and constraints',
                state.sageData.environment,
                (value) => context.read<IncidentTemplateCubit>().updateSAGEData(
                  state.sageData.copyWith(environment: value),
                ),
              ),
              
              const SizedBox(height: 24),
              
              _buildSAGEField(
                'Key Learning',
                'Key takeaway or learning from this incident',
                state.sageData.keyLearning,
                (value) => context.read<IncidentTemplateCubit>().updateSAGEData(
                  state.sageData.copyWith(keyLearning: value),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSAGEField(String title, String hint, String value, Function(String) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: heading3Style(context).copyWith(color: kcPrimaryTextColor),
        ),
        const SizedBox(height: 8),
        TextField(
          maxLines: 3,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: bodyStyle(context).copyWith(color: kcSecondaryTextColor),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: kcAccentColor),
            ),
          ),
          onChanged: onChanged,
          controller: TextEditingController(text: value),
        ),
      ],
    );
  }

  Widget _buildTagsStep() {
    return BlocBuilder<IncidentTemplateCubit, IncidentTemplateState>(
      builder: (context, state) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Incident Tags',
                style: heading2Style(context).copyWith(color: kcPrimaryTextColor),
              ),
              const SizedBox(height: 8),
              Text(
                'Tag this incident for better organization and analysis',
                style: bodyStyle(context).copyWith(color: kcSecondaryTextColor),
              ),
              const SizedBox(height: 32),
              
              // Predefined tags
              Text(
                'Common Tags',
                style: heading3Style(context).copyWith(color: kcPrimaryTextColor),
              ),
              const SizedBox(height: 16),
              
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: IncidentTag.values.map((tag) {
                  final isSelected = state.selectedTags.contains(tag);
                  return FilterChip(
                    label: Text(_getTagLabel(tag)),
                    selected: isSelected,
                    onSelected: (selected) {
                      context.read<IncidentTemplateCubit>().toggleTag(tag);
                    },
                    selectedColor: kcAccentColor.withValues(alpha: 0.2),
                    checkmarkColor: kcAccentColor,
                  );
                }).toList(),
              ),
              
              const SizedBox(height: 32),
              
              // Custom tags
              Text(
                'Custom Tags',
                style: heading3Style(context).copyWith(color: kcPrimaryTextColor),
              ),
              const SizedBox(height: 16),
              
              TextField(
                decoration: InputDecoration(
                  hintText: 'Add custom tags (comma separated)',
                  hintStyle: bodyStyle(context).copyWith(color: kcSecondaryTextColor),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: kcAccentColor),
                  ),
                ),
                onChanged: (value) {
                  final customTags = value.split(',').map((tag) => tag.trim()).where((tag) => tag.isNotEmpty).toList();
                  context.read<IncidentTemplateCubit>().setCustomTags(customTags);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReviewStep() {
    return BlocBuilder<IncidentTemplateCubit, IncidentTemplateState>(
      builder: (context, state) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Review & Save',
                style: heading2Style(context).copyWith(color: kcPrimaryTextColor),
              ),
              const SizedBox(height: 8),
              Text(
                'Review your incident report before saving',
                style: bodyStyle(context).copyWith(color: kcSecondaryTextColor),
              ),
              const SizedBox(height: 32),
              
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildReviewSection('Incident Type', _getIncidentTypeTitle(state.incidentType ?? IncidentType.medical)),
                      _buildReviewSection('Incident ID', state.incidentId ?? 'Not specified'),
                      _buildReviewSection('Situation', state.aarData.situation),
                      _buildReviewSection('Awareness', state.aarData.awareness),
                      _buildReviewSection('Environment', state.aarData.environment),
                      _buildReviewSection('Outcome', state.aarData.outcome),
                      _buildReviewSection('SAGE Situation', state.sageData.situation),
                      _buildReviewSection('SAGE Awareness', state.sageData.awareness),
                      _buildReviewSection('SAGE Environment', state.sageData.environment),
                      _buildReviewSection('Key Learning', state.sageData.keyLearning),
                      _buildReviewSection('Tags', [
                        ...state.selectedTags.map((tag) => _getTagLabel(tag)),
                        ...state.customTags,
                      ].join(', ')),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReviewSection(String title, String content) {
    if (content.isEmpty) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: heading3Style(context).copyWith(color: kcAccentColor),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: bodyStyle(context).copyWith(color: kcPrimaryTextColor),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _previousStep,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: kcAccentColor),
                ),
                child: Text(
                  'Previous',
                  style: bodyStyle(context).copyWith(color: kcAccentColor),
                ),
              ),
            ),
          
          if (_currentStep > 0) const SizedBox(width: 16),
          
          Expanded(
            child: ElevatedButton(
              onPressed: _canProceed() ? _nextStep : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: kcAccentColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                disabledBackgroundColor: Colors.grey.withValues(alpha: 0.3),
              ),
              child: Text(
                _currentStep == _steps.length - 1 ? 'Save Report' : 'Next',
                style: bodyStyle(context).copyWith(
                  color: _canProceed() ? Colors.white : Colors.grey,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _canProceed() {
    final state = context.read<IncidentTemplateCubit>().state;
    
    switch (_currentStep) {
      case 0: // Incident Type
        return state.incidentType != null;
      case 1: // AAR
        return state.aarData.situation.isNotEmpty && state.aarData.awareness.isNotEmpty;
      case 2: // SAGE
        return state.sageData.situation.isNotEmpty && state.sageData.keyLearning.isNotEmpty;
      case 3: // Tags
        return true; // Tags are optional
      case 4: // Review
        return true; // Review step
      default:
        return false;
    }
  }

  void _nextStep() {
    if (_currentStep < _steps.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _saveIncident();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _saveIncident() async {
    try {
      await context.read<IncidentTemplateCubit>().saveIncident();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Incident report saved successfully'),
            backgroundColor: kcAccentColor,
          ),
        );
        
        widget.onCompleted?.call();
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving incident: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Helper methods
  IconData _getIncidentTypeIcon(IncidentType type) {
    switch (type) {
      case IncidentType.fire:
        return Icons.local_fire_department;
      case IncidentType.medical:
        return Icons.medical_services;
      case IncidentType.rescue:
        return Icons.search;
      case IncidentType.hazmat:
        return Icons.warning;
      case IncidentType.mva:
        return Icons.car_crash;
      case IncidentType.law:
        return Icons.local_police;
      case IncidentType.other:
        return Icons.help_outline;
    }
  }

  String _getIncidentTypeTitle(IncidentType type) {
    switch (type) {
      case IncidentType.fire:
        return 'Fire Response';
      case IncidentType.medical:
        return 'Medical Emergency';
      case IncidentType.rescue:
        return 'Rescue Operation';
      case IncidentType.hazmat:
        return 'Hazmat Incident';
      case IncidentType.mva:
        return 'Motor Vehicle Accident';
      case IncidentType.law:
        return 'Law Enforcement';
      case IncidentType.other:
        return 'Other';
    }
  }

  String _getIncidentTypeDescription(IncidentType type) {
    switch (type) {
      case IncidentType.fire:
        return 'Structure fires, wildland fires, vehicle fires';
      case IncidentType.medical:
        return 'Medical emergencies, trauma, cardiac events';
      case IncidentType.rescue:
        return 'Technical rescue, water rescue, confined space';
      case IncidentType.hazmat:
        return 'Chemical spills, gas leaks, contamination';
      case IncidentType.mva:
        return 'Motor vehicle accidents, traffic incidents';
      case IncidentType.law:
        return 'Law enforcement activities, arrests';
      case IncidentType.other:
        return 'Other types of incidents';
    }
  }

  String _getTagLabel(IncidentTag tag) {
    return tag.displayName;
  }
}

enum IncidentTemplateStep {
  incidentType,
  aar,
  sage,
  tags,
  review,
}
