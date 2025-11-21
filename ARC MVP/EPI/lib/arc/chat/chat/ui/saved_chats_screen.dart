import 'package:flutter/material.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';
import '../chat_models.dart';
import '../enhanced_chat_repo.dart';
import '../chat_repo_impl.dart';
import 'session_view.dart';
import '../../services/favorites_service.dart';
import '../../data/models/lumara_favorite.dart';

class SavedChatsScreen extends StatefulWidget {
  final EnhancedChatRepo chatRepo;

  const SavedChatsScreen({
    super.key,
    required this.chatRepo,
  });

  @override
  State<SavedChatsScreen> createState() => _SavedChatsScreenState();
}

class _SavedChatsScreenState extends State<SavedChatsScreen> {
  List<LumaraFavorite> _savedChats = [];
  List<ChatSession> _sessions = [];
  bool _isLoading = true;
  final FavoritesService _favoritesService = FavoritesService.instance;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      await _favoritesService.initialize();
      final savedChats = await _favoritesService.getSavedChats();
      final sessions = await widget.chatRepo.listActive();

      if (mounted) {
        setState(() {
          _savedChats = savedChats;
          _sessions = sessions;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kcBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kcPrimaryColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Saved Chats',
          style: heading1Style(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _savedChats.isEmpty
              ? Center(
                  child: Text(
                    'No saved chats yet',
                    style: bodyStyle(context).copyWith(color: kcTextSecondaryColor),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _savedChats.length,
                  itemBuilder: (context, index) {
                    final favorite = _savedChats[index];
                    final session = _sessions.firstWhere(
                      (s) => s.id == favorite.sessionId,
                      orElse: () => ChatSession(
                        id: favorite.sessionId ?? '',
                        subject: 'Saved Chat',
                        createdAt: favorite.timestamp,
                        updatedAt: favorite.timestamp,
                        tags: [],
                        metadata: {},
                      ),
                    );

                    return SavedChatCard(
                      favorite: favorite,
                      session: session,
                      onTap: () {
                        if (session.id.isNotEmpty && _sessions.any((s) => s.id == session.id)) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SessionView(
                                sessionId: session.id,
                                chatRepo: ChatRepoImpl.instance,
                              ),
                            ),
                          );
                        } else {
                           ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Original chat session not found')),
                          );
                        }
                      },
                      onUnsave: () async {
                        await _favoritesService.removeFavorite(favorite.id);
                        _loadData();
                      },
                    );
                  },
                ),
    );
  }
}

class SavedChatCard extends StatelessWidget {
  final LumaraFavorite favorite;
  final ChatSession session;
  final VoidCallback onTap;
  final VoidCallback onUnsave;

  const SavedChatCard({
    super.key,
    required this.favorite,
    required this.session,
    required this.onTap,
    required this.onUnsave,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: const Color(0xFF2196F3).withOpacity(0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF2196F3), width: 1),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: const Icon(Icons.bookmark, color: Color(0xFF2196F3), size: 24),
        title: Row(
          children: [
            Expanded(
              child: Text(
                session.subject,
                style: heading2Style(context).copyWith(
                  fontSize: 16,
                  color: const Color(0xFF2196F3),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              'Saved ${_formatDate(favorite.timestamp)}',
              style: captionStyle(context),
            ),
            const SizedBox(height: 8),
            Text(
              favorite.content.length > 100
                  ? '${favorite.content.substring(0, 100)}...'
                  : favorite.content,
              style: bodyStyle(context).copyWith(
                fontSize: 12,
                color: kcTextSecondaryColor,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.bookmark, color: Color(0xFF2196F3)),
          onPressed: onUnsave,
          tooltip: 'Unsave chat',
        ),
        onTap: onTap,
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
