import 'package:flutter/material.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';
import '../chat_category_models.dart';
import '../enhanced_chat_repo.dart';

/// Screen for managing chat categories
class CategoryManagementScreen extends StatefulWidget {
  final EnhancedChatRepo chatRepo;

  const CategoryManagementScreen({
    super.key,
    required this.chatRepo,
  });

  @override
  State<CategoryManagementScreen> createState() => _CategoryManagementScreenState();
}

class _CategoryManagementScreenState extends State<CategoryManagementScreen> {
  List<ChatCategory> _categories = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await widget.chatRepo.getCategories();
      setState(() {
        _categories = categories;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _createCategory() async {
    final result = await showDialog<ChatCategory>(
      context: context,
      builder: (context) => _CategoryEditDialog(),
    );

    if (result != null) {
      try {
        await widget.chatRepo.createCategory(
          name: result.name,
          description: result.description,
          color: result.color,
          icon: result.icon,
          sortOrder: _categories.length,
        );
        await _loadCategories();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Category "${result.name}" created')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to create category: $e')),
          );
        }
      }
    }
  }

  Future<void> _editCategory(ChatCategory category) async {
    final result = await showDialog<ChatCategory>(
      context: context,
      builder: (context) => _CategoryEditDialog(category: category),
    );

    if (result != null) {
      try {
        await widget.chatRepo.updateCategory(
          category.id,
          name: result.name,
          description: result.description,
          color: result.color,
          icon: result.icon,
        );
        await _loadCategories();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Category "${result.name}" updated')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update category: $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteCategory(ChatCategory category) async {
    if (category.isDefault) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot delete default categories')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text(
          'Are you sure you want to delete "${category.name}"? '
          'All sessions in this category will be moved to General.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: kcDangerColor),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await widget.chatRepo.deleteCategory(category.id);
        await _loadCategories();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Category "${category.name}" deleted')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete category: $e')),
          );
        }
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
        title: Text(
          'Chat Categories',
          style: heading1Style(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: kcPrimaryColor),
            onPressed: _createCategory,
            tooltip: 'Create Category',
          ),
        ],
      ),
      body: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, color: kcDangerColor, size: 48),
            const SizedBox(height: 16),
            Text('Error: $_error', style: bodyStyle(context)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadCategories,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_categories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.category_outlined, color: kcTextSecondaryColor, size: 48),
            const SizedBox(height: 16),
            Text(
              'No categories yet',
              style: heading2Style(context),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first category to organize your chats',
              style: bodyStyle(context).copyWith(color: kcTextSecondaryColor),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadCategories,
      child: ReorderableListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _categories.length,
        onReorder: (oldIndex, newIndex) async {
          if (oldIndex < newIndex) {
            newIndex -= 1;
          }
          final item = _categories.removeAt(oldIndex);
          _categories.insert(newIndex, item);
          
          // Update sort orders
          final categoryIds = _categories.map((c) => c.id).toList();
          await widget.chatRepo.reorderCategories(categoryIds);
        },
        itemBuilder: (context, index) {
          final category = _categories[index];
          return _CategoryCard(
            key: ValueKey(category.id),
            category: category,
            onEdit: () => _editCategory(category),
            onDelete: () => _deleteCategory(category),
          );
        },
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final ChatCategory category;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CategoryCard({
    super.key,
    required this.category,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: kcSurfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Color(int.parse(category.color.replaceFirst('#', '0xFF'))),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            _getIconData(category.icon),
            color: Colors.white,
            size: 24,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                category.name,
                style: heading2Style(context).copyWith(fontSize: 16),
              ),
            ),
            if (category.isDefault)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: kcPrimaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Default',
                  style: captionStyle(context).copyWith(
                    color: kcPrimaryColor,
                    fontSize: 10,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (category.description != null) ...[
              const SizedBox(height: 4),
              Text(
                category.description!,
                style: bodyStyle(context).copyWith(
                  color: kcTextSecondaryColor,
                  fontSize: 12,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 8),
            Text(
              '${category.sessionCount} sessions',
              style: captionStyle(context),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'edit':
                onEdit();
                break;
              case 'delete':
                onDelete();
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit, size: 16),
                  SizedBox(width: 8),
                  Text('Edit'),
                ],
              ),
            ),
            if (!category.isDefault)
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, size: 16, color: kcDangerColor),
                    SizedBox(width: 8),
                    Text('Delete', style: TextStyle(color: kcDangerColor)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'chat':
        return Icons.chat;
      case 'psychology':
        return Icons.psychology;
      case 'event_note':
        return Icons.event_note;
      case 'school':
        return Icons.school;
      case 'palette':
        return Icons.palette;
      case 'work':
        return Icons.work;
      case 'favorite':
        return Icons.favorite;
      case 'star':
        return Icons.star;
      case 'lightbulb':
        return Icons.lightbulb;
      case 'home':
        return Icons.home;
      default:
        return Icons.category;
    }
  }
}

class _CategoryEditDialog extends StatefulWidget {
  final ChatCategory? category;

  const _CategoryEditDialog({this.category});

  @override
  State<_CategoryEditDialog> createState() => _CategoryEditDialogState();
}

class _CategoryEditDialogState extends State<_CategoryEditDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  String _selectedColor = '#2196F3';
  String _selectedIcon = 'category';

  final List<String> _colors = [
    '#2196F3', '#9C27B0', '#FF9800', '#4CAF50', '#E91E63',
    '#00BCD4', '#8BC34A', '#FF5722', '#795548', '#607D8B',
  ];

  final List<String> _icons = [
    'category', 'chat', 'psychology', 'event_note', 'school',
    'palette', 'work', 'favorite', 'star', 'lightbulb', 'home',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.category != null) {
      _nameController.text = widget.category!.name;
      _descriptionController.text = widget.category!.description ?? '';
      _selectedColor = widget.category!.color;
      _selectedIcon = widget.category!.icon;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.category == null ? 'Create Category' : 'Edit Category'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            Text(
              'Color',
              style: bodyStyle(context).copyWith(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _colors.map((color) => GestureDetector(
                onTap: () => setState(() => _selectedColor = color),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Color(int.parse(color.replaceFirst('#', '0xFF'))),
                    shape: BoxShape.circle,
                    border: _selectedColor == color
                        ? Border.all(color: Colors.white, width: 3)
                        : null,
                  ),
                  child: _selectedColor == color
                      ? const Icon(Icons.check, color: Colors.white, size: 16)
                      : null,
                ),
              )).toList(),
            ),
            const SizedBox(height: 16),
            Text(
              'Icon',
              style: bodyStyle(context).copyWith(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _icons.map((icon) => GestureDetector(
                onTap: () => setState(() => _selectedIcon = icon),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _selectedIcon == icon
                        ? kcPrimaryColor
                        : kcSurfaceColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _selectedIcon == icon
                          ? kcPrimaryColor
                          : kcTextSecondaryColor.withOpacity(0.3),
                    ),
                  ),
                  child: Icon(
                    _getIconData(icon),
                    color: _selectedIcon == icon
                        ? Colors.white
                        : kcTextSecondaryColor,
                    size: 20,
                  ),
                ),
              )).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            final name = _nameController.text.trim();
            if (name.isNotEmpty) {
              final category = ChatCategory.create(
                name: name,
                description: _descriptionController.text.trim().isEmpty
                    ? null
                    : _descriptionController.text.trim(),
                color: _selectedColor,
                icon: _selectedIcon,
              );
              Navigator.pop(context, category);
            }
          },
          child: Text(widget.category == null ? 'Create' : 'Update'),
        ),
      ],
    );
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'category':
        return Icons.category;
      case 'chat':
        return Icons.chat;
      case 'psychology':
        return Icons.psychology;
      case 'event_note':
        return Icons.event_note;
      case 'school':
        return Icons.school;
      case 'palette':
        return Icons.palette;
      case 'work':
        return Icons.work;
      case 'favorite':
        return Icons.favorite;
      case 'star':
        return Icons.star;
      case 'lightbulb':
        return Icons.lightbulb;
      case 'home':
        return Icons.home;
      default:
        return Icons.category;
    }
  }
}
