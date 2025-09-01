import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/features/onboarding/onboarding_cubit.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';

class CentralWordInput extends StatefulWidget {
  const CentralWordInput({super.key});

  @override
  State<CentralWordInput> createState() => _CentralWordInputState();
}

class _CentralWordInputState extends State<CentralWordInput> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: TextField(
            controller: _controller,
            style: heading2Style(context).copyWith(
              color: Colors.white,
              fontSize: 24,
            ),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: 'Your word...',
              hintStyle: heading2Style(context).copyWith(
                color: Colors.white.withOpacity(0.5),
                fontSize: 24,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            textCapitalization: TextCapitalization.words,
            maxLength: 20,
            buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
            onChanged: (value) {
              setState(() {});
            },
          ),
        ),
        const SizedBox(height: 32),
        AnimatedOpacity(
          opacity: _controller.text.trim().isNotEmpty ? 1.0 : 0.5,
          duration: const Duration(milliseconds: 200),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(
              minWidth: 240,
              maxWidth: 320,
              minHeight: 56,
            ),
            decoration: BoxDecoration(
              gradient: _controller.text.trim().isNotEmpty ? kcPrimaryGradient : null,
              color: _controller.text.trim().isEmpty ? Colors.white.withOpacity(0.1) : null,
              borderRadius: BorderRadius.circular(28),
              boxShadow: _controller.text.trim().isNotEmpty ? [
                BoxShadow(
                  color: kcPrimaryColor.withOpacity(0.4),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ] : null,
            ),
            child: ElevatedButton(
              onPressed: _controller.text.trim().isNotEmpty ? () {
                context.read<OnboardingCubit>().setCentralWord(_controller.text.trim());
              } : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
              child: Text(
                'Create My First Arcform',
                style: buttonStyle(context).copyWith(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}