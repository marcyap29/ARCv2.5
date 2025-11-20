// lib/shared/ui/insights/unified_insights_view.dart
// Unified Insights View - Combines Phase, Health, and Analytics into a single section

import 'package:flutter/material.dart';
import 'package:my_app/ui/phase/phase_analysis_view.dart';
import 'package:my_app/arc/ui/health/health_view.dart';
import 'package:my_app/insights/analytics_page.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/ui/settings/settings_view.dart';
import 'package:my_app/shared/ui/settings/advanced_analytics_preference_service.dart';

class UnifiedInsightsView extends StatefulWidget {
  const UnifiedInsightsView({super.key});

  @override
  State<UnifiedInsightsView> createState() => _UnifiedInsightsViewState();
}

class _UnifiedInsightsViewState extends State<UnifiedInsightsView>
    with TickerProviderStateMixin {
  TabController? _tabController;
  int _previousIndex = 0;
  bool _isNavigatingToSettings = false;
  bool _advancedAnalyticsEnabled = false;
  bool _isLoadingPreference = true;
  bool _isInitialLoad = true;

  @override
  void initState() {
    super.initState();
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    final enabled = await AdvancedAnalyticsPreferenceService.instance.isAdvancedAnalyticsEnabled();
    if (mounted) {
      final wasEnabled = _advancedAnalyticsEnabled;
      final wasInitialLoad = _isInitialLoad;
      
      // Always create controller on initial load, or if preference changed
      final needsControllerUpdate = wasInitialLoad || (wasEnabled != enabled);
      
      if (needsControllerUpdate) {
        // Dispose old controller first (if it exists) - do this BEFORE setState
        if (_tabController != null) {
          _tabController!.removeListener(_handleTabChange);
          _tabController!.dispose();
          _tabController = null;
        }
        
        // Update state first
        setState(() {
          _advancedAnalyticsEnabled = enabled;
          _isLoadingPreference = false;
          _isInitialLoad = false;
        });
        
        // Then create new controller AFTER setState so the widget tree is ready
        // Use a post-frame callback to ensure the widget has rebuilt
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _updateTabController();
            });
          }
        });
      } else {
        // No controller update needed, just update the state
        setState(() {
          _advancedAnalyticsEnabled = enabled;
          _isLoadingPreference = false;
          _isInitialLoad = false;
        });
      }
      
      // Show notification when tabs appear (only if they weren't enabled before and not initial load)
      if (enabled && !wasEnabled && !wasInitialLoad) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green.shade300, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '✨ Health and Analytics tabs are now visible!',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
                backgroundColor: Colors.green.shade800,
                duration: const Duration(seconds: 4),
                behavior: SnackBarBehavior.floating,
                margin: const EdgeInsets.all(16),
              ),
            );
          }
        });
      }
    }
  }

  void _updateTabController() {
    // Dispose old controller if it exists
    if (_tabController != null) {
      _tabController!.removeListener(_handleTabChange);
      _tabController!.dispose();
      _tabController = null; // Clear reference
    }
    
    // Calculate number of tabs: Phase (always) + Health (conditional) + Analytics (conditional) + Settings (always)
    final tabCount = 2 + (_advancedAnalyticsEnabled ? 2 : 0); // Phase + Settings + (Health + Analytics if enabled)
    
    // Create new controller with appropriate length
    _tabController = TabController(length: tabCount, vsync: this, initialIndex: 0); // Always start at index 0
    _tabController!.addListener(_handleTabChange);
    
    // If we were on Health or Analytics and they're now hidden, switch to Phase
    if (!_advancedAnalyticsEnabled && _previousIndex > 0 && _previousIndex < 3) {
      _previousIndex = 0;
    }
  }


  void _handleTabChange() {
    if (!mounted || _tabController == null) return;
    
    // Calculate Settings tab index based on whether advanced analytics is enabled
    final settingsTabIndex = _advancedAnalyticsEnabled ? 3 : 1; // Phase + Health + Analytics + Settings OR Phase + Settings
    
    // Navigate to Settings when Settings tab is selected
    if (_tabController!.index == settingsTabIndex && !_isNavigatingToSettings) {
      _isNavigatingToSettings = true;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const SettingsView(),
        ),
      ).then((result) {
        // Return to previous tab after Settings is closed
        if (mounted) {
          _isNavigatingToSettings = false;
          // Reload preference in case it was changed in Settings
          // result == true indicates preference was changed
          if (result == true) {
            // Preference changed - reload and rebuild
            _loadPreference();
          } else {
            // No change - just return to previous tab
            if (_tabController != null) {
              _tabController!.removeListener(_handleTabChange);
              _tabController!.animateTo(_previousIndex);
              Future.delayed(const Duration(milliseconds: 300), () {
                if (mounted && _tabController != null) {
                  _tabController!.addListener(_handleTabChange);
                }
              });
            }
          }
        }
      });
    } else {
      final settingsTabIndex = _advancedAnalyticsEnabled ? 3 : 1;
      if (_tabController != null && _tabController!.index != settingsTabIndex) {
        // Track previous index (excluding Settings tab)
        _previousIndex = _tabController!.index;
      }
    }
  }

  @override
  void dispose() {
    if (_tabController != null) {
      _tabController!.removeListener(_handleTabChange);
      _tabController!.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // No longer need tab controller or preference loading
    // Just show PhaseAnalysisView directly
    return Scaffold(
      body: SafeArea(
        child: const PhaseAnalysisView(),
      ),
    );
  }
}

