import 'package:flutter/material.dart';
import 'timeline_view.dart';
import '../../voice_notes/screens/voice_notes_view.dart';
import '../../voice_notes/repositories/voice_note_repository.dart';
import 'package:hive/hive.dart';
import '../../voice_notes/models/voice_note.dart';

/// Timeline view with Voice Notes tab
/// 
/// This wraps the existing TimelineView and adds a swipeable tab
/// for the Voice Notes section.
/// 
/// Tab structure:
/// - Timeline: Existing journal entries and LUMARA conversations
/// - Voice Notes: Quick voice captures
class TimelineWithIdeasView extends StatefulWidget {
  const TimelineWithIdeasView({super.key});

  @override
  State<TimelineWithIdeasView> createState() => _TimelineWithIdeasViewState();
}

class _TimelineWithIdeasViewState extends State<TimelineWithIdeasView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  VoiceNoteRepository? _voiceNoteRepository;
  int _voiceNoteCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeRepository();
  }

  Future<void> _initializeRepository() async {
    try {
      // Check if box is already open
      if (Hive.isBoxOpen(VoiceNoteRepository.boxName)) {
        final box = Hive.box<VoiceNote>(VoiceNoteRepository.boxName);
        _voiceNoteRepository = VoiceNoteRepository(box);
      } else {
        // Open the box
        final box = await Hive.openBox<VoiceNote>(VoiceNoteRepository.boxName);
        _voiceNoteRepository = VoiceNoteRepository(box);
      }
      
      // Update count
      if (mounted) {
        setState(() {
          _voiceNoteCount = _voiceNoteRepository?.activeCount ?? 0;
        });
      }
      
      // Listen for changes
      _voiceNoteRepository?.watch().listen((_) {
        if (mounted) {
          setState(() {
            _voiceNoteCount = _voiceNoteRepository?.activeCount ?? 0;
          });
        }
      });
    } catch (e) {
      debugPrint('TimelineWithIdeasView: Error initializing repository: $e');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _voiceNoteRepository?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      children: [
        // Tab bar
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            border: Border(
              bottom: BorderSide(
                color: Colors.grey.withOpacity(0.2),
              ),
            ),
          ),
          child: TabBar(
            controller: _tabController,
            indicatorColor: theme.primaryColor,
            // Selected tab (user is on): lighter/brighter text so it stands out
            labelColor: isDark ? Colors.white : Colors.black87,
            // Unselected tab: darker/muted gray
            unselectedLabelColor: isDark ? Colors.grey[600] : Colors.grey[500],
            indicatorWeight: 3,
            // Selected tab: normal weight
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
            // Unselected tab: same weight but color does the work
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
            tabs: [
              const Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.timeline, size: 20),
                    SizedBox(width: 8),
                    Text('Timeline'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.mic, size: 20),
                    const SizedBox(width: 8),
                    const Text('Voice Notes'),
                    if (_voiceNoteCount > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: theme.primaryColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _voiceNoteCount.toString(),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),

        // Tab content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // Timeline tab - existing view
              const TimelineView(),

              // Voice Notes tab
              _voiceNoteRepository != null
                  ? VoiceNotesView(repository: _voiceNoteRepository!)
                  : const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Loading Voice Notes...'),
                        ],
                      ),
                    ),
            ],
          ),
        ),
      ],
    );
  }
}
