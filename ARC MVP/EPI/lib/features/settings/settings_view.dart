import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../shared/app_colors.dart';
import '../../shared/text_style.dart';
import 'sync_settings_section.dart';
import 'music_control_section.dart';
import 'mcp_bundle_health_view.dart';
import 'privacy_settings_view.dart';
import 'memory_mode_settings_view.dart';
import 'memory_snapshot_management_view.dart';
import 'conflict_management_view.dart';
import 'lumara_settings_view.dart';
import '../../ui/screens/mcp_management_screen.dart';
import '../../arc/core/journal_repository.dart';
import '../../services/analytics_service.dart';
import '../../services/rivet_sweep_service.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  bool _isIndexing = false;
  
  Future<void> _handleIndexAndAnalyze() async {
    if (_isIndexing) return;
    
    setState(() {
      _isIndexing = true;
    });
    
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('Indexing and analyzing data...', style: heading3Style(context)),
            ],
          ),
        ),
      );
      
      // Import required services
      final analyticsService = AnalyticsService();
      final rivetSweepService = RivetSweepService(analyticsService);
      final journalRepo = JournalRepository();
      final journalEntries = journalRepo.getAllJournalEntriesSync();
      
      // Check if there are enough entries for analysis
      if (journalEntries.length < 5) {
        Navigator.of(context).pop(); // Close loading dialog
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Not enough entries for analysis (need at least 5, have ${journalEntries.length})'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      
      // Run RIVET Sweep
      final result = await rivetSweepService.analyzeEntries(journalEntries);
      final totalProposals = result.autoAssign.length + result.review.length + result.lowConfidence.length;
      
      Navigator.of(context).pop(); // Close loading dialog
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully indexed and analyzed data: $totalProposals phase proposals found'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to index and analyze data: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isIndexing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kcBackgroundColor,
      appBar: AppBar(
        backgroundColor: kcBackgroundColor,
        elevation: 0,
        title: Text(
          'Settings',
          style: heading1Style(context).copyWith(
            color: kcPrimaryTextColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: kcPrimaryTextColor),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Import & Export Section (Top Priority)
            _buildSection(
              context,
              title: 'Import & Export',
              children: [
                _buildSettingsTile(
                  context,
                  title: 'Import/Export Data',
                  subtitle: 'Export, import, and organize your journal data',
                  icon: Icons.dashboard,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => McpManagementScreen(
                          journalRepository: context.read<JournalRepository>(),
                        ),
                      ),
                    );
                  },
                ),
                _buildSettingsTile(
                  context,
                  title: 'Bundle Health Check',
                  subtitle: 'Validate and repair backup files',
                  icon: Icons.health_and_safety,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const McpBundleHealthView()),
                    );
                  },
                ),
                _buildSettingsTile(
                  context,
                  title: 'Index & Analyze Data',
                  subtitle: 'Process journal data for LUMARA reflections and phase analysis',
                  icon: Icons.refresh,
                  onTap: _handleIndexAndAnalyze,
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Privacy & Security Section
            _buildSection(
              context,
              title: 'Privacy & Security',
              children: [
                _buildSettingsTile(
                  context,
                  title: 'Privacy Protection',
                  subtitle: 'Configure PII detection and masking settings',
                  icon: Icons.security,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const PrivacySettingsView()),
                    );
                  },
                ),
                _buildSettingsTile(
                  context,
                  title: 'Memory Modes',
                  subtitle: 'Control how LUMARA uses your memories',
                  icon: Icons.memory,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const MemoryModeSettingsView()),
                    );
                  },
                ),
                _buildSettingsTile(
                  context,
                  title: 'Memory Snapshots',
                  subtitle: 'Backup and restore your memories',
                  icon: Icons.backup,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const MemorySnapshotManagementView()),
                    );
                  },
                ),
                _buildSettingsTile(
                  context,
                  title: 'Memory Conflicts',
                  subtitle: 'Resolve memory contradictions',
                  icon: Icons.psychology,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ConflictManagementView()),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Sync Settings Section
            const SyncSettingsSection(),

            const SizedBox(height: 32),

            // Music Control Section
            const MusicControlSection(),

            const SizedBox(height: 32),

            // LUMARA Settings Section
            _buildSection(
              context,
              title: 'LUMARA AI',
              children: [
                _buildSettingsTile(
                  context,
                  title: 'LUMARA Settings',
                  subtitle: 'Configure your AI reflection partner',
                  icon: Icons.auto_awesome,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const LumaraSettingsView()),
                    );
                  },
                ),
              ],
            ),
            
            const SizedBox(height: 32),
            
            // About Section
            _buildSection(
              context,
              title: 'About',
              children: [
                _buildSettingsTile(
                  context,
                  title: 'Version',
                  subtitle: '1.0.5',
                  icon: Icons.info,
                  onTap: null,
                ),
                _buildSettingsTile(
                  context,
                  title: 'Privacy Policy',
                  subtitle: 'Read our privacy policy',
                  icon: Icons.privacy_tip,
                  onTap: () {
                    // TODO: Implement privacy policy
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: heading2Style(context).copyWith(
            color: kcPrimaryTextColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildSettingsTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: kcAccentColor,
          size: 24,
        ),
        title: Text(
          title,
          style: heading3Style(context).copyWith(
            color: kcPrimaryTextColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: bodyStyle(context).copyWith(
            color: kcSecondaryTextColor,
          ),
        ),
        trailing: onTap != null
            ? const Icon(
                Icons.arrow_forward_ios,
                color: kcSecondaryTextColor,
                size: 16,
              )
            : null,
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
      ),
    );
  }
}
