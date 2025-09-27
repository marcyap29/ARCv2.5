import 'package:flutter/material.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';
import 'package:my_app/core/i18n/copy.dart';

class ReasonPicker extends StatefulWidget {
  final Function(String) onReasonSelected;
  final VoidCallback? onBackPressed;
  final String? selectedReason;
  final String selectedEmotion;

  const ReasonPicker({
    super.key,
    required this.onReasonSelected,
    this.onBackPressed,
    required this.selectedEmotion,
    this.selectedReason,
  });

  @override
  State<ReasonPicker> createState() => _ReasonPickerState();
}

class _ReasonPickerState extends State<ReasonPicker> 
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  String? _selectedReason;

  @override
  void initState() {
    super.initState();
    _selectedReason = widget.selectedReason;
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.3, 0.0), 
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController, 
      curve: Curves.easeOutCubic,
    ));
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
          onPressed: widget.onBackPressed ?? () => Navigator.of(context).pop(),
          icon: const Icon(
            Icons.arrow_back_ios,
            color: Colors.white,
            size: 24,
          ),
        ),
        actions: [
          IconButton(
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
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: kcPrimaryGradient,
        ),
        child: SafeArea(
          child: SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    
                    // Context hint
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        "Feeling: ${widget.selectedEmotion}",
                        style: captionStyle(context).copyWith(
                          color: Colors.white.withOpacity(0.9),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Title
                    Text(
                      Copy.reasonTitle,
                      style: heading1Style(context).copyWith(
                        color: Colors.white,
                        fontSize: 28,
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Subtitle
                    Text(
                      "What's behind this feeling?",
                      style: bodyStyle(context).copyWith(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 16,
                      ),
                    ),
                    
                    const SizedBox(height: 30),
                    
                    // Reason chips
                    Expanded(
                      child: SingleChildScrollView(
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: Copy.emotionReasons.map((reason) {
                            final isSelected = _selectedReason == reason;
                            
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedReason = reason;
                                  });
                                  
                                  // Animate selection and call callback
                                  Future.delayed(const Duration(milliseconds: 150), () {
                                    widget.onReasonSelected(reason);
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected 
                                        ? Colors.white 
                                        : Colors.white.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: isSelected 
                                          ? Colors.transparent 
                                          : Colors.white.withOpacity(0.2),
                                      width: 1,
                                    ),
                                    boxShadow: isSelected ? [
                                      BoxShadow(
                                        color: kcPrimaryColor.withOpacity(0.3),
                                        blurRadius: 16,
                                        spreadRadius: 1,
                                      ),
                                    ] : null,
                                  ),
                                  child: Text(
                                    reason,
                                    style: bodyStyle(context).copyWith(
                                      color: isSelected
                                          ? kcPrimaryGradient.colors.first
                                          : Colors.white,
                                      fontWeight: isSelected 
                                          ? FontWeight.w600 
                                          : FontWeight.w400,
                                      fontSize: 16,
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
      ),
    );
  }
}