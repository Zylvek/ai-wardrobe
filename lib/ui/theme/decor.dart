import 'package:flutter/material.dart';

// ───────── Красивые переиспользуемые элементы оформления ─────────

/// Фирменный градиент: индиго → фиолетовый. Один на всё приложение.
List<Color> heroGradient(Brightness brightness) => brightness == Brightness.dark
    ? const [Color(0xFF6D63F0), Color(0xFF9A6BF5)]
    : const [Color(0xFF5B5FE9), Color(0xFF9A6BF5)];

/// Мягкая «дорогая» тень для карточек.
List<BoxShadow> softShadow(ColorScheme scheme) => [
      BoxShadow(
        color: scheme.shadow.withValues(alpha: 0.10),
        blurRadius: 24,
        offset: const Offset(0, 8),
      ),
    ];

/// Цветное «свечение» под градиентными элементами.
List<BoxShadow> glowShadow(List<Color> gradient) => [
      BoxShadow(
        color: gradient.first.withValues(alpha: 0.35),
        blurRadius: 16,
        offset: const Offset(0, 6),
      ),
    ];

/// Плавный градиент-фон страницы: сверху светлее, снизу глубже.
class AppGradientBackground extends StatelessWidget {
  const AppGradientBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            scheme.surfaceContainerLowest,
            scheme.surface,
            scheme.surfaceContainerLow,
          ],
          stops: const [0, 0.55, 1],
        ),
      ),
      child: child,
    );
  }
}

/// Яркая градиентная «плитка» (шапка, погода). Текст и иконки внутри — белые.
class GradientTile extends StatelessWidget {
  const GradientTile({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 22,
    this.decorations = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  /// Рисовать декоративные полупрозрачные круги на фоне.
  final bool decorations;

  @override
  Widget build(BuildContext context) {
    final gradient = heroGradient(Theme.of(context).brightness);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        boxShadow: glowShadow(gradient),
      ),
      child: IconTheme(
        data: const IconThemeData(color: Colors.white),
        child: DefaultTextStyle.merge(
          style: const TextStyle(color: Colors.white),
          child: child,
        ),
      ),
    );
  }
}

/// Главная кнопка с фирменным градиентом и свечением.
class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final gradient = heroGradient(Theme.of(context).brightness);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        boxShadow: glowShadow(gradient),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                ],
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Появление элемента: подъём снизу + проявление (для сетки/списков).
class AppearOnBuild extends StatelessWidget {
  const AppearOnBuild({
    super.key,
    required this.child,
    this.index = 0,
    this.maxStagger = 8,
  });

  final Widget child;

  /// Позиция элемента — чем больше, тем позже появляется (ступенчатая анимация).
  final int index;
  final int maxStagger;

  @override
  Widget build(BuildContext context) {
    final delay = (index < maxStagger ? index : maxStagger) * 40;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 320 + delay),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 24 * (1 - t)),
          child: Transform.scale(scale: 0.94 + 0.06 * t, child: child),
        ),
      ),
      child: child,
    );
  }
}