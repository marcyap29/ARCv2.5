// lib/features/insights/cards/memory_dashboard_card.dart
// Memory dashboard card for MIRA insights screen

import 'package:flutter/material.dart';
import 'package:my_app/mira/memory/enhanced_mira_memory_service.dart';
import 'package:my_app/mira/mira_service.dart';
// Memory snapshot management accessible through settings

class MemoryDashboardCard extends StatefulWidget {
  const MemoryDashboardCard({super.key});

  @override
  State<MemoryDashboardCard> createState() => _MemoryDashboardCardState();
}

class _MemoryDashboardCardState extends State<MemoryDashboardCard> {
  late EnhancedMiraMemoryService _memoryService;
  bool _isLoading = true;
  Map<String, dynamic>? _dashboardData;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeService();
  }

  Future<void> _initializeService() async {
    try {
      _memoryService = EnhancedMiraMemoryService(
        miraService: MiraService.instance,
      );
      
      await _memoryService.initialize(
        userId: 'current_user', // This should use actual user ID
        sessionId: null,
        currentPhase: 'Discovery', // This should use actual current phase
      );
      
      await _loadDashboardData();
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to initialize memory service: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadDashboardData() async {
    try {
      final dashboard = await _memoryService.getMemoryDashboard();
      setState(() {
        _dashboardData = {
          'totalMemories': dashboard.totalMemories,
          'domainDistribution': dashboard.domainDistribution,
          'privacyDistribution': dashboard.privacyDistribution,
          'lifecycleStats': dashboard.lifecycleStats,
          'conflictSummary': dashboard.conflictSummary,
          'attributionStats': dashboard.attributionStats,
          'memoryHealth': dashboard.memoryHealth,
          'sovereigntyScore': dashboard.sovereigntyScore,
        };
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load memory data: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const Icon(Icons.error, color: Colors.red, size: 48),
              const SizedBox(height: 8),
              Text(
                'Memory Dashboard Error',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                _errorMessage!,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final data = _dashboardData!;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Memory Dashboard',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                IconButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/settings');
                  },
                  icon: const Icon(Icons.backup),
                  tooltip: 'Manage Snapshots',
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Memory Health Score
            _buildStatRow(
              'Memory Health',
              '${(data['memoryHealth'] as double? ?? 0.0).toStringAsFixed(1)}%',
              Icons.health_and_safety,
              _getHealthColor(data['memoryHealth'] as double? ?? 0.0),
            ),
            
            const SizedBox(height: 12),
            
            // Total Memories
            _buildStatRow(
              'Total Memories',
              '${data['totalMemories'] ?? 0}',
              Icons.memory,
              Colors.blue,
            ),
            
            const SizedBox(height: 12),
            
            // Sovereignty Score
            _buildStatRow(
              'Sovereignty Score',
              '${(data['sovereigntyScore'] as double? ?? 0.0).toStringAsFixed(1)}%',
              Icons.security,
              Colors.green,
            ),
            
            const SizedBox(height: 16),
            
            // Quick Actions
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(context, '/settings');
                    },
                    icon: const Icon(Icons.backup, size: 16),
                    label: const Text('Snapshots'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _loadDashboardData,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Refresh'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Color _getHealthColor(double health) {
    if (health >= 80) return Colors.green;
    if (health >= 60) return Colors.orange;
    return Colors.red;
  }
}
