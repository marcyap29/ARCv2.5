import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class A11yState {
  final bool largerText;     // ~1.2x on target screens
  final bool highContrast;   // swaps to high-contrast palette on target screens
  final bool reducedMotion;  // disables nonessential animations (e.g., Arcform reveal)
  
  const A11yState({
    this.largerText = false, 
    this.highContrast = false, 
    this.reducedMotion = false
  });

  A11yState copyWith({
    bool? largerText, 
    bool? highContrast, 
    bool? reducedMotion
  }) => A11yState(
    largerText: largerText ?? this.largerText,
    highContrast: highContrast ?? this.highContrast,
    reducedMotion: reducedMotion ?? this.reducedMotion,
  );
}

class A11yCubit extends Cubit<A11yState> {
  A11yCubit() : super(const A11yState());
  
  void setLargerText(bool v) => emit(state.copyWith(largerText: v));
  void setHighContrast(bool v) => emit(state.copyWith(highContrast: v));
  void setReducedMotion(bool v) => emit(state.copyWith(reducedMotion: v));
}

// Reusable wrappers for target screens only:
Widget withTextScale(BuildContext context, Widget child, {required bool enabled}) {
  final mq = MediaQuery.of(context);
  return MediaQuery(
    data: mq.copyWith(
      textScaler: enabled 
        ? TextScaler.linear((mq.textScaler.scale(1.0) * 1.2).clamp(1.0, 1.6))
        : mq.textScaler
    ),
    child: child,
  );
}

ThemeData highContrastTheme(ThemeData base) {
  // Only used locally in target screens; keep it minimal
  return base.copyWith(
    colorScheme: base.colorScheme.copyWith(
      primary: Colors.black,
      onPrimary: Colors.white,
      secondary: Colors.black,
      onSecondary: Colors.white,
      surface: Colors.white,
      onSurface: Colors.black,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(minimumSize: const Size(44, 44)),
    ),
  );
}

// 44x44 tappable area helper:
Widget tapTarget(Widget child) => ConstrainedBox(
  constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
  child: child,
);

// Semantics helper:
Widget semanticButton({
  required String label, 
  required Widget child, 
  bool isEnabled = true
}) {
  return Semantics(
    button: true,
    enabled: isEnabled,
    label: label,
    child: child,
  );
}