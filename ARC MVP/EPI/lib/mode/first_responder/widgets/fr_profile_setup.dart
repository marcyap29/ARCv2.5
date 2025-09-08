import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';
import '../fr_settings.dart';
import '../fr_settings_cubit.dart';

class FRProfileSetup extends StatefulWidget {
  final VoidCallback? onCompleted;
  
  const FRProfileSetup({
    super.key,
    this.onCompleted,
  });

  @override
  State<FRProfileSetup> createState() => _FRProfileSetupState();
}

class _FRProfileSetupState extends State<FRProfileSetup> {
  final TextEditingController _departmentController = TextEditingController();
  final Set<String> _selectedSpecialties = <String>{};
  
  String? _selectedRole;
  String? _selectedShiftPattern;
  int? _yearsOfService;
  
  static const List<String> _roles = [
    'firefighter',
    'paramedic', 
    'police',
    'dispatcher',
    'other',
  ];
  
  static const List<String> _shiftPatterns = [
    '24/48',
    '12/12', 
    '8/40',
    'custom',
  ];
  
  static const List<String> _specialties = [
    'Trauma',
    'Hazmat',
    'Rescue',
    'Flight',
    'K9',
    'SWAT',
    'Arson Investigation',
    'Training',
    'Administration',
    'Community Outreach',
  ];

  @override
  void initState() {
    super.initState();
    final currentSettings = context.read<FRSettingsCubit>().state;
    _selectedRole = currentSettings.role;
    _selectedShiftPattern = currentSettings.shiftPattern;
    _yearsOfService = currentSettings.yearsOfService;
    _departmentController.text = currentSettings.department ?? '';
    _selectedSpecialties.addAll(currentSettings.specialties);
  }

  @override
  void dispose() {
    _departmentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kcBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: kcSecondaryColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'First Responder Profile',
          style: heading2Style(context).copyWith(
            color: Colors.white,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Help us customize your experience',
                      style: bodyStyle(context).copyWith(
                        color: kcSecondaryColor,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Role selection
                    _buildRoleSelection(),
                    const SizedBox(height: 24),
                    
                    // Department
                    _buildDepartmentField(),
                    const SizedBox(height: 24),
                    
                    // Shift pattern
                    _buildShiftPatternSelection(),
                    const SizedBox(height: 24),
                    
                    // Years of service
                    _buildYearsOfServiceSlider(),
                    const SizedBox(height: 24),
                    
                    // Specialties
                    _buildSpecialtiesSelection(),
                    const SizedBox(height: 32),
                    
                    // Privacy settings
                    _buildPrivacySettings(),
                  ],
                ),
              ),
            ),
            
            // Save button
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Role',
          style: heading3Style(context).copyWith(
            color: Colors.white,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _roles.map((role) {
            final isSelected = _selectedRole == role;
            return ChoiceChip(
              label: Text(_getRoleDisplayName(role)),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedRole = selected ? role : null;
                });
              },
              selectedColor: kcPrimaryColor.withOpacity(0.3),
              backgroundColor: kcSurfaceAltColor,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : kcSecondaryColor,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDepartmentField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Department (Optional)',
          style: heading3Style(context).copyWith(
            color: Colors.white,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _departmentController,
          style: bodyStyle(context).copyWith(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Metro Fire Dept, City Police, etc.',
            hintStyle: bodyStyle(context).copyWith(
              color: kcSecondaryColor.withOpacity(0.5),
            ),
            filled: true,
            fillColor: kcSurfaceColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildShiftPatternSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Shift Pattern',
          style: heading3Style(context).copyWith(
            color: Colors.white,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _shiftPatterns.map((pattern) {
            final isSelected = _selectedShiftPattern == pattern;
            return ChoiceChip(
              label: Text(_getShiftPatternDisplay(pattern)),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedShiftPattern = selected ? pattern : null;
                });
              },
              selectedColor: kcPrimaryColor.withOpacity(0.3),
              backgroundColor: kcSurfaceAltColor,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : kcSecondaryColor,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildYearsOfServiceSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Years of Service: ${_yearsOfService?.toString() ?? 'Not specified'}',
          style: heading3Style(context).copyWith(
            color: Colors.white,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 12),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: kcPrimaryColor,
            inactiveTrackColor: kcSurfaceAltColor,
            thumbColor: kcPrimaryColor,
            overlayColor: kcPrimaryColor.withOpacity(0.2),
          ),
          child: Slider(
            value: (_yearsOfService ?? 0).toDouble(),
            min: 0,
            max: 40,
            divisions: 40,
            label: _yearsOfService?.toString(),
            onChanged: (value) {
              setState(() {
                _yearsOfService = value.round();
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSpecialtiesSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Specialties (Optional)',
          style: heading3Style(context).copyWith(
            color: Colors.white,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Select areas you work in',
          style: captionStyle(context).copyWith(
            color: kcSecondaryColor.withOpacity(0.7),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _specialties.map((specialty) {
            final isSelected = _selectedSpecialties.contains(specialty);
            return FilterChip(
              label: Text(specialty),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedSpecialties.add(specialty);
                  } else {
                    _selectedSpecialties.remove(specialty);
                  }
                });
              },
              selectedColor: kcPrimaryColor.withOpacity(0.3),
              backgroundColor: kcSurfaceAltColor,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : kcSecondaryColor,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPrivacySettings() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kcSurfaceColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Privacy & Sharing Defaults',
            style: heading3Style(context).copyWith(
              color: Colors.white,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Default settings for when you share entries',
            style: captionStyle(context).copyWith(
              color: kcSecondaryColor.withOpacity(0.7),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          
          BlocBuilder<FRSettingsCubit, FRSettings>(
            builder: (context, settings) {
              return Column(
                children: [
                  SwitchListTile(
                    title: Text(
                      'Auto-redact names',
                      style: bodyStyle(context).copyWith(color: Colors.white),
                    ),
                    subtitle: Text(
                      'Automatically hide names when sharing',
                      style: captionStyle(context).copyWith(color: kcSecondaryColor),
                    ),
                    value: settings.autoRedactNames,
                    onChanged: (value) {
                      context.read<FRSettingsCubit>().updatePrivacySettings(
                        autoRedactNames: value,
                      );
                    },
                    activeColor: kcPrimaryColor,
                  ),
                  SwitchListTile(
                    title: Text(
                      'Auto-redact locations',
                      style: bodyStyle(context).copyWith(color: Colors.white),
                    ),
                    subtitle: Text(
                      'Automatically hide addresses and locations',
                      style: captionStyle(context).copyWith(color: kcSecondaryColor),
                    ),
                    value: settings.autoRedactLocations,
                    onChanged: (value) {
                      context.read<FRSettingsCubit>().updatePrivacySettings(
                        autoRedactLocations: value,
                      );
                    },
                    activeColor: kcPrimaryColor,
                  ),
                  SwitchListTile(
                    title: Text(
                      'Share redacted by default',
                      style: bodyStyle(context).copyWith(color: Colors.white),
                    ),
                    subtitle: Text(
                      'Default to sharing redacted versions',
                      style: captionStyle(context).copyWith(color: kcSecondaryColor),
                    ),
                    value: settings.shareByDefaultRedacted,
                    onChanged: (value) {
                      context.read<FRSettingsCubit>().updatePrivacySettings(
                        shareByDefaultRedacted: value,
                      );
                    },
                    activeColor: kcPrimaryColor,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: _saveProfile,
          style: FilledButton.styleFrom(
            backgroundColor: kcPrimaryColor,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: Text(
            'Save Profile',
            style: buttonStyle(context).copyWith(
              color: Colors.white,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }

  void _saveProfile() {
    context.read<FRSettingsCubit>().updateProfile(
      role: _selectedRole,
      department: _departmentController.text.trim().isEmpty 
          ? null 
          : _departmentController.text.trim(),
      shiftPattern: _selectedShiftPattern,
      yearsOfService: _yearsOfService,
      specialties: _selectedSpecialties.toList(),
    );
    
    widget.onCompleted?.call();
    Navigator.of(context).pop();
  }

  String _getRoleDisplayName(String role) {
    switch (role) {
      case 'firefighter': return 'Firefighter';
      case 'paramedic': return 'Paramedic';
      case 'police': return 'Police Officer';
      case 'dispatcher': return 'Dispatcher';
      case 'other': return 'Other';
      default: return role;
    }
  }

  String _getShiftPatternDisplay(String pattern) {
    switch (pattern) {
      case '24/48': return '24 on / 48 off';
      case '12/12': return '12 on / 12 off';
      case '8/40': return '8 hour / 40 week';
      case 'custom': return 'Custom';
      default: return pattern;
    }
  }
}