import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../coach_mode_cubit.dart';
import '../models/coach_models.dart';

class DropletRunnerView extends StatefulWidget {
  final String templateId;

  const DropletRunnerView({
    super.key,
    required this.templateId,
  });

  @override
  State<DropletRunnerView> createState() => _DropletRunnerViewState();
}

class _DropletRunnerViewState extends State<DropletRunnerView> {
  CoachDropletTemplate? _template;
  final Map<String, dynamic> _values = {};
  final Map<String, TextEditingController> _controllers = {};
  bool _includeInShare = false;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTemplate();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadTemplate() async {
    try {
      // In a real implementation, you'd get this from the service
      // For now, we'll simulate loading
      await Future.delayed(const Duration(milliseconds: 500));
      
      // This would come from the service
      final templates = await _getAvailableTemplates();
      _template = templates.firstWhere(
        (t) => t.id == widget.templateId,
        orElse: () => throw Exception('Template not found'),
      );

      // Initialize controllers for text fields
      for (final field in _template!.fields) {
        if (field.type == DropletFieldType.text || 
            field.type == DropletFieldType.multi) {
          _controllers[field.id] = TextEditingController();
        }
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<List<CoachDropletTemplate>> _getAvailableTemplates() async {
    // This would come from the service in a real implementation
    return [];
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text('Error: $_error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _error = null;
                    _isLoading = true;
                  });
                  _loadTemplate();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_template == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Not Found')),
        body: const Center(child: Text('Template not found')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_template!.title),
        actions: [
          TextButton(
            onPressed: _canSave() ? _saveResponse : null,
            child: const Text('Save'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 24),
                  _buildFields(),
                  const SizedBox(height: 24),
                  _buildShareToggle(),
                ],
              ),
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.assignment,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
            size: 32,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _template!.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _template!.subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFields() {
    return Column(
      children: _template!.fields.map((field) => _buildField(field)).toList(),
    );
  }

  Widget _buildField(DropletField field) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                field.label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (field.required)
                const Text(
                  ' *',
                  style: TextStyle(color: Colors.red),
                ),
            ],
          ),
          if (field.help != null) ...[
            const SizedBox(height: 4),
            Text(
              field.help!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ],
          const SizedBox(height: 8),
          _buildFieldInput(field),
        ],
      ),
    );
  }

  Widget _buildFieldInput(DropletField field) {
    switch (field.type) {
      case DropletFieldType.text:
      case DropletFieldType.multi:
        return _buildTextInput(field);
      case DropletFieldType.scale:
        return _buildScaleInput(field);
      case DropletFieldType.bool:
        return _buildBoolInput(field);
      case DropletFieldType.chips:
        return _buildChipsInput(field);
      case DropletFieldType.date:
        return _buildDateInput(field);
      case DropletFieldType.time:
        return _buildTimeInput(field);
      case DropletFieldType.datetime:
        return _buildDateTimeInput(field);
      case DropletFieldType.number:
        return _buildNumberInput(field);
      case DropletFieldType.image:
        return _buildImageInput(field);
    }
  }

  Widget _buildTextInput(DropletField field) {
    final controller = _controllers[field.id] ?? TextEditingController();
    _controllers[field.id] = controller;

    return TextField(
      controller: controller,
      maxLines: field.type == DropletFieldType.multi ? 3 : 1,
      decoration: InputDecoration(
        hintText: 'Enter ${field.label.toLowerCase()}',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      onChanged: (value) {
        _values[field.id] = value;
      },
    );
  }

  Widget _buildScaleInput(DropletField field) {
    final min = field.min ?? 1;
    final max = field.max ?? 7;
    final currentValue = _values[field.id] as int? ?? min;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('$min'),
            Text(
              '$currentValue',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text('$max'),
          ],
        ),
        Slider(
          value: currentValue.toDouble(),
          min: min.toDouble(),
          max: max.toDouble(),
          divisions: max - min,
          onChanged: (value) {
            setState(() {
              _values[field.id] = value.round();
            });
          },
        ),
      ],
    );
  }

  Widget _buildBoolInput(DropletField field) {
    final currentValue = _values[field.id] as bool? ?? false;

    return SwitchListTile(
      value: currentValue,
      onChanged: (value) {
        setState(() {
          _values[field.id] = value;
        });
      },
      title: const Text('Yes'),
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildChipsInput(DropletField field) {
    final currentValues = (_values[field.id] as List<String>?) ?? [];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: (field.options ?? []).map((option) {
        final isSelected = currentValues.contains(option);
        return FilterChip(
          label: Text(option),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              if (selected) {
                _values[field.id] = [...currentValues, option];
              } else {
                _values[field.id] = currentValues.where((v) => v != option).toList();
              }
            });
          },
        );
      }).toList(),
    );
  }

  Widget _buildDateInput(DropletField field) {
    final currentValue = _values[field.id] as DateTime?;

    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: currentValue ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (date != null) {
          setState(() {
            _values[field.id] = date;
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outline),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, size: 20),
            const SizedBox(width: 8),
            Text(
              currentValue != null
                  ? '${currentValue.month}/${currentValue.day}/${currentValue.year}'
                  : 'Select date',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeInput(DropletField field) {
    final currentValue = _values[field.id] as TimeOfDay?;

    return InkWell(
      onTap: () async {
        final time = await showTimePicker(
          context: context,
          initialTime: currentValue ?? TimeOfDay.now(),
        );
        if (time != null) {
          setState(() {
            _values[field.id] = time;
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outline),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.access_time, size: 20),
            const SizedBox(width: 8),
            Text(
              currentValue != null
                  ? currentValue.format(context)
                  : 'Select time',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateTimeInput(DropletField field) {
    final currentValue = _values[field.id] as DateTime?;

    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: currentValue ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (date != null) {
          final time = await showTimePicker(
            context: context,
            initialTime: currentValue != null
                ? TimeOfDay.fromDateTime(currentValue)
                : TimeOfDay.now(),
          );
          if (time != null) {
            setState(() {
              _values[field.id] = DateTime(
                date.year,
                date.month,
                date.day,
                time.hour,
                time.minute,
              );
            });
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outline),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.schedule, size: 20),
            const SizedBox(width: 8),
            Text(
              currentValue != null
                  ? '${currentValue.month}/${currentValue.day}/${currentValue.year} ${currentValue.hour.toString().padLeft(2, '0')}:${currentValue.minute.toString().padLeft(2, '0')}'
                  : 'Select date and time',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberInput(DropletField field) {
    final controller = _controllers[field.id] ?? TextEditingController();
    _controllers[field.id] = controller;

    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        hintText: 'Enter ${field.label.toLowerCase()}',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      onChanged: (value) {
        _values[field.id] = double.tryParse(value);
      },
    );
  }

  Widget _buildImageInput(DropletField field) {
    final currentValue = _values[field.id] as String?;

    return InkWell(
      onTap: () {
        // TODO: Implement image picker
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image picker coming soon!')),
        );
      },
      child: Container(
        height: 100,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outline),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.add_a_photo, size: 32),
              const SizedBox(height: 4),
              Text(
                currentValue != null ? 'Image selected' : 'Tap to add image',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShareToggle() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.share,
            color: Theme.of(context).colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add to Coach Share Bundle?',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'This will include this response when you share with your coach.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _includeInShare,
            onChanged: (value) {
              setState(() {
                _includeInShare = value;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _canSave() ? _saveResponse : null,
              child: const Text('Save'),
            ),
          ),
        ],
      ),
    );
  }

  bool _canSave() {
    if (_template == null) return false;

    for (final field in _template!.fields) {
      if (field.required) {
        final value = _values[field.id];
        if (value == null || value.toString().isEmpty) {
          return false;
        }
      }
    }

    return true;
  }

  Future<void> _saveResponse() async {
    if (!_canSave()) return;

    try {
      final response = CoachDropletResponse(
        id: const Uuid().v4(),
        templateId: _template!.id,
        createdAt: DateTime.now(),
        values: Map.from(_values),
        includeInShare: _includeInShare,
      );

      // Save through the cubit
      context.read<CoachModeCubit>().completeDroplet(response);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Response saved successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    }
  }
}
