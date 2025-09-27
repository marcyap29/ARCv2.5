import 'package:flutter/material.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';
import 'package:my_app/core/i18n/copy.dart';

class EmotionPicker extends StatefulWidget {
  final Function(String) onEmotionSelected;
  final VoidCallback? onBackPressed;
  final String? selectedEmotion;

  const EmotionPicker({
    super.key,
    required this.onEmotionSelected,
    this.onBackPressed,
    this.selectedEmotion,
  });

  @override
  State<EmotionPicker> createState() => _EmotionPickerState();
}

class _EmotionPickerState extends State<EmotionPicker> 
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  String? _selectedEmotion;

  @override
  void initState() {
    super.initState();
    _selectedEmotion = widget.selectedEmotion;
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
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
          onPressed: () {
            // For now, just pop - the tab navigation will handle the rest
            Navigator.popUntil(context, (route) => route.isFirst);
          },
          icon: const Icon(
            Icons.close,
            color: Colors.white,
            size: 28,
          ),
          tooltip: 'Close',
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: kcPrimaryGradient,
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  
                  // Title
                  Text(
                    Copy.emotionTitle,
                    style: heading1Style(context).copyWith(
                      color: Colors.white,
                      fontSize: 32,
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Subtitle
                  Text(
                    "Choose what feels truest in this moment",
                    style: bodyStyle(context).copyWith(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 18,
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Emotion chips
                  Expanded(
                    child: SingleChildScrollView(
                      child: Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: Copy.emotions.map((emotion) {
                          final isSelected = _selectedEmotion == emotion;
                          
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedEmotion = emotion;
                                });
                                
                                // Animate selection and call callback
                                Future.delayed(const Duration(milliseconds: 150), () {
                                  widget.onEmotionSelected(emotion);
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected 
                                      ? Colors.white 
                                      : Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(28),
                                  border: Border.all(
                                    color: isSelected 
                                        ? Colors.transparent 
                                        : Colors.white.withOpacity(0.3),
                                    width: 1.5,
                                  ),
                                  boxShadow: isSelected ? [
                                    BoxShadow(
                                      color: kcPrimaryColor.withOpacity(0.4),
                                      blurRadius: 20,
                                      spreadRadius: 2,
                                    ),
                                  ] : null,
                                ),
                                child: Text(
                                  emotion,
                                  style: heading3Style(context).copyWith(
                                    color: isSelected
                                        ? kcPrimaryGradient.colors.first
                                        : Colors.white,
                                    fontWeight: isSelected 
                                        ? FontWeight.w600 
                                        : FontWeight.w400,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}