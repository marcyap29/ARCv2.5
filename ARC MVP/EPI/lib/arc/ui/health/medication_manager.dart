import 'package:flutter/material.dart';
import 'package:my_app/prism/models/health_summary.dart';
import 'package:my_app/prism/services/health_service.dart';
import 'dart:io';

class MedicationManager extends StatefulWidget {
  const MedicationManager({super.key});

  @override
  State<MedicationManager> createState() => _MedicationManagerState();
}

class _MedicationManagerState extends State<MedicationManager> {
  List<Medication> _medications = [];
  bool _loading = true;
  String? _error;
  final HealthService _healthService = HealthService();

  @override
  void initState() {
    super.initState();
    _loadMedications();
  }

  Future<void> _loadMedications() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    
    try {
      if (Platform.isIOS) {
        // Load medications from HealthKit
        final medications = await _healthService.fetchMedications();
        setState(() {
          _medications = medications;
          _loading = false;
        });
      } else {
        setState(() {
          _error = 'Medication tracking is only available on iOS';
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading medications: $e');
      setState(() {
        _error = 'Failed to load medications: ${e.toString()}';
        _loading = false;
      });
    }
  }

  Future<void> _refreshMedications() async {
    await _loadMedications();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Medications',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _refreshMedications,
                    tooltip: 'Refresh from HealthKit',
                  ),
                  if (Platform.isIOS)
                    TextButton.icon(
                      onPressed: () {
                        // Open Health app to manage medications
                        // Note: This requires URL scheme support
                      },
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: const Text('Manage in Health'),
                    ),
                ],
              ),
            ],
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              color: theme.colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.error_outline, color: theme.colorScheme.onErrorContainer),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onErrorContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Medications are synced from the Apple Health app. Add or manage medications there, then refresh.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (_medications.isEmpty && _error == null)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.medication_liquid,
                    size: 64,
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No medications found',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Medications are synced from the Apple Health app.\nAdd medications there, then refresh.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: _refreshMedications,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh from HealthKit'),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _medications.length,
              itemBuilder: (context, index) {
                final medication = _medications[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Icon(
                      Icons.medication_liquid,
                      color: medication.isActive
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    title: Text(
                      medication.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        decoration: medication.isActive
                            ? null
                            : TextDecoration.lineThrough,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (medication.dosage != null)
                          Text('Dosage: ${medication.dosage}'),
                        if (medication.frequency != null)
                          Text('Frequency: ${medication.frequency}'),
                        if (medication.startDate != null)
                          Text(
                            'Started: ${_formatDate(medication.startDate!)}',
                            style: theme.textTheme.bodySmall,
                          ),
                        if (!medication.isActive && medication.endDate != null)
                          Text(
                            'Ended: ${_formatDate(medication.endDate!)}',
                            style: theme.textTheme.bodySmall,
                          ),
                        if (medication.notes != null && medication.notes!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              medication.notes!,
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.info_outline),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Medications are managed in the Apple Health app'),
                            action: SnackBarAction(
                              label: 'Refresh',
                              onPressed: _refreshMedications,
                            ),
                          ),
                        );
                      },
                      tooltip: 'Managed in Health app',
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

