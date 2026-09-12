import 'package:flutter/material.dart';

/// Единая дизайн-система приложения.
/// Единственное место, где задаются цвета и стили компонентов.
/// В коде экранов цвет берётся ТОЛЬКО из Theme.of(context).colorScheme
/// и из helpers файла decor.dart (градиенты).

/// Яркий индиго-акцент — основа фирменного стиля.
const kSeed = Color(0xFF5B5FE9);

ThemeData buildAppTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: kSeed,
    brightness: brightness,
  ).copyWith(
    primary: kSeed,
    onPrimary: Colors.white,
    primaryContainer:
        isDark ? const Color(0xFF41478F) : const Color(0xFFE2E3FF),
    onPrimaryContainer: isDark ? Colors.white : const Color(0xFF23259A),
    // Поверхности вручную: тёплый «айвори» в светлой теме,
    // глубокий сине-чёрный в тёмной — чтобы ничего не было «грязно-серым».
    surface: isDark ? const Color(0xFF0E1018) : const Color(0xFFF7F5F2),
    surfaceContainerLowest:
        isDark ? const Color(0xFF090B12) : Colors.white,
    surfaceContainerLow:
        isDark ? const Color(0xFF161927) : const Color(0xFFF1EEE9),
    surfaceContainer:
        isDark ? const Color(0xFF1B1F30) : const Color(0xFFEBE8E3),
    surfaceContainerHigh:
        isDark ? const Color(0xFF222639) : const Color(0xFFE5E2DC),
    surfaceContainerHighest:
        isDark ? const Color(0xFF2A2F46) : const Color(0xFFDFDCD5),
  );

  final base = ThemeData(brightness: brightness);
  final text = base.textTheme.copyWith(
    titleLarge: base.textTheme.titleLarge
        ?.copyWith(fontWeight: FontWeight.w800, fontSize: 26),
    titleMedium:
        base.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
  );

  final inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide.none,
  );
  final focusedBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: scheme.primary, width: 2),
  );

  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    textTheme: text,
    // Красивые переходы между экранами (появление «вперёд» с затуханием).
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
      },
    ),
    // Карточки: белые (светлая) / глубокие (тёмная), мягкая тень.
    cardTheme: CardThemeData(
      color: isDark ? const Color(0xFF161927) : Colors.white,
      elevation: isDark ? 0 : 2,
      shadowColor: scheme.shadow.withValues(alpha: 0.08),
      surfaceTintColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    // Чипы: выбранный — залит акцентом, с белым текстом.
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: scheme.surfaceContainerHigh,
      selectedColor: scheme.primary,
      side: BorderSide.none,
      showCheckmark: false,
      elevation: 0,
      pressElevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 4,
        shadowColor: scheme.primary.withValues(alpha: 0.35),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHigh,
      border: inputBorder,
      enabledBorder: inputBorder,
      focusedBorder: focusedBorder,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: TextStyle(color: scheme.onInverseSurface),
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: scheme.surfaceContainerHigh,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 64,
      elevation: 0,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      indicatorColor: scheme.primary,
      shadowColor: Colors.transparent,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? scheme.onPrimary
              : scheme.onSurfaceVariant,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12,
          color: states.contains(WidgetState.selected)
              ? scheme.onPrimary
              : scheme.onSurfaceVariant,
          fontWeight:
              states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    ),
  );
}