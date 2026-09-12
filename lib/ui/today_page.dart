import 'dart:io';

import 'package:flutter/material.dart';

import '../data/constants.dart';
import '../data/models.dart';
import '../data/outfit_builder.dart';
import '../data/wear_store.dart';
import '../data/weather_service.dart';
import 'add_flow.dart';
import 'mannequin_view.dart';
import 'theme/decor.dart';

/// Страница 1: образ дня, погода, кнопки.
class TodayPage extends StatefulWidget {
  const TodayPage({super.key});

  @override
  State<TodayPage> createState() => _TodayPageState();
}

/// Иконка для каждой погоды.
const Map<String, IconData> kWeatherIcons = {
  'Жара': Icons.wb_sunny,
  'Тепло': Icons.wb_cloudy,
  'Прохладно': Icons.air,
  'Холод': Icons.ac_unit,
  'Дождь': Icons.umbrella,
};

class _TodayPageState extends State<TodayPage> {
  String _weather = 'Тепло';
  Outfit? _outfit;
  bool _triedToBuild = false;

  /// Настоящая температура за окном (null — не узнали).
  double? _realTemp;

  /// Погоду выбрал сам — настоящую больше не подставляем.
  bool _manualWeather = false;

  @override
  void initState() {
    super.initState();
    _loadRealWeather();
    wearVersion.addListener(_refresh);
  }

  @override
  void dispose() {
    wearVersion.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  /// Узнаёт настоящую погоду и подставляет её, если пользователь
  /// ещё не выбрал свою.
  Future<void> _loadRealWeather() async {
    final info = await fetchRealWeather();
    if (info == null || !mounted || _manualWeather) return;
    setState(() {
      _weather = info.category;
      _realTemp = info.temp;
    });
  }

  void _generate() {
    setState(() {
      _outfit = buildOutfit(weather: _weather, avoid: _outfit);
      _triedToBuild = true;
    });
  }

  Future<void> _rate(int rating) async {
    final outfit = _outfit;
    if (outfit == null) return;
    await rateOutfit(outfit, rating, _weather);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(rating == 1
            ? 'Запомнил — тебе понравилось 👍'
            : 'Запомнил — не понравилось 👎'),
      ),
    );
    _generate();
  }

  /// Записывает «надел сегодня» за текущий образ.
  Future<void> _wearToday() async {
    final outfit = _outfit;
    if (outfit == null) return;
    await WearStore.addWear(outfit, _weather);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Записал — надел сегодня ✅')),
    );
  }

  /// Добавляет/убирает образ в избранное.
  Future<void> _toggleFavorite() async {
    final outfit = _outfit;
    if (outfit == null) return;
    final added = await WearStore.toggleFavorite(outfit);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            added ? 'Образ в избранном ⭐' : 'Убрал из избранного'),
      ),
    );
  }

  /// Показывает, что было надето в выбранный день.
  Future<void> _showDay(DateTime day) async {
    final t = DateTime.now();
    final date =
        '${t.year}-${t.month.toString().padLeft(2, '0')}-'
        '${day.day.toString().padLeft(2, '0')}';
    final event = WearStore.eventFor(date);
    final outfit = event == null ? null : outfitFromIds(event.itemIds);
    const dayNames = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    const monthNames = [
      'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
      'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря',
    ];
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${dayNames[day.weekday - 1]}, '
                '${day.day} ${monthNames[day.month - 1]}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              if (outfit == null)
                const Text('В этот день ничего не надевал')
              else
                SizedBox(
                  height: 120,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (final item in outfit.items)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                              child: Image.file(
                                File(item.imagePath),
                                width: 100,
                                height: 120,
                                fit: BoxFit.contain,
                                errorBuilder: (_, _, _) =>
                                    const SizedBox(width: 100, height: 120),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurfaceVariant;
    final hour = DateTime.now().hour;
    final isDay = hour >= 7 && hour < 20;

    return SafeArea(
      bottom: false,
      child: AppGradientBackground(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isDay ? 'Добрый день! 👋' : 'Добрый вечер! 👋',
                          style: TextStyle(
                            fontSize: 13,
                            color: muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Образ дня',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                  ),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.elasticOut,
                    builder: (context, t, child) =>
                        Transform.scale(scale: t, child: child),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isDay ? Icons.wb_sunny : Icons.dark_mode,
                        color: scheme.onPrimaryContainer,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _weekStrip(scheme),
              const SizedBox(height: 16),
              _weatherHeroCard(scheme),
              const SizedBox(height: 14),
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final w in kWeathers)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(
                            w,
                            style: TextStyle(
                              color: _weather == w
                                  ? scheme.onPrimary
                                  : scheme.onSurface,
                              fontWeight: _weather == w
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                          selected: _weather == w,
                          onSelected: (_) => setState(() {
                            _weather = w;
                            _manualWeather = true;
                          }),
                        ),
                      ),
                  ],
                ),
              ),
              _favoritesStrip(scheme),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 380),
                  switchInCurve: Curves.easeOutBack,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: ScaleTransition(
                      scale: Tween(begin: 0.92, end: 1.0).animate(anim),
                      child: child,
                    ),
                  ),
                  child: _outfit == null
                      ? SizedBox.expand(
                          key: const ValueKey('placeholder'),
                          child: _buildPlaceholder(scheme),
                        )
                      : SizedBox.expand(
                          key: ValueKey(_outfit),
                          child: _buildOutfitView(_outfit!),
                        ),
                ),
              ),
              const SizedBox(height: 8),
              Center(child: _buildColorRow(scheme)),
              const SizedBox(height: 12),
              if (_outfit != null) ...[
                Center(
                  child: Text('Как тебе образ?', style: TextStyle(color: muted)),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton.filledTonal(
                      onPressed: () => _rate(1),
                      icon: Icon(Icons.thumb_up_outlined,
                          color: scheme.onPrimaryContainer),
                      style: IconButton.styleFrom(
                        backgroundColor: scheme.primaryContainer,
                        minimumSize: const Size(58, 48),
                      ),
                    ),
                    const SizedBox(width: 20),
                    IconButton.filledTonal(
                      onPressed: () => _rate(-1),
                      icon: Icon(Icons.thumb_down_outlined,
                          color: scheme.onErrorContainer),
                      style: IconButton.styleFrom(
                        backgroundColor: scheme.errorContainer,
                        minimumSize: const Size(58, 48),
                      ),
                    ),
                    const SizedBox(width: 20),
                    // В избранное / уже в избранном.
                    IconButton.filledTonal(
                      onPressed: _toggleFavorite,
                      icon: Icon(
                        _outfit != null &&
                                WearStore.hasFavorite(_outfit!.items
                                    .map((e) => e.id)
                                    .toList())
                            ? Icons.star
                            : Icons.star_border,
                        color: Colors.amber.shade700,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: scheme.primaryContainer,
                        minimumSize: const Size(48, 48),
                      ),
                    ),
                    const SizedBox(width: 20),
                    // «Надел сегодня» — запись в историю носки.
                    IconButton.filledTonal(
                      onPressed: _wearToday,
                      icon: Icon(Icons.check_rounded,
                          color: scheme.onPrimaryContainer),
                      tooltip: 'Надел сегодня',
                      style: IconButton.styleFrom(
                        backgroundColor: scheme.primaryContainer,
                        minimumSize: const Size(48, 48),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              Row(
                children: [
                  Expanded(
                    child: GradientButton(
                      label: _outfit == null ? 'Создать наряд' : 'Ещё вариант',
                      icon: _outfit == null ? Icons.auto_awesome : Icons.refresh,
                      onPressed: _generate,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: () => runAddFlow(context),
                      style: FilledButton.styleFrom(
                        backgroundColor: scheme.surfaceContainerHigh,
                        foregroundColor: scheme.onSurface,
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.add_a_photo, size: 20),
                      label: const Text('Добавить вещь'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 88),
            ],
          ),
        ),
      ),
    );
  }

  /// Градиентная карточка погоды: показывает выбранную погоду.
  Widget _weatherHeroCard(ColorScheme scheme) {
    return GradientTile(
      child: Row(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, anim) => ScaleTransition(
              scale: Tween(begin: 0.5, end: 1.0).animate(anim),
              child: FadeTransition(opacity: anim, child: child),
            ),
            child: Container(
              key: ValueKey(_weather),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                kWeatherIcons[_weather] ?? Icons.thermostat,
                size: 28,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Погода за окном',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                ),
                Text(
                  _weather,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Text(
            _realTemp == null ? '—°C' : '${_realTemp!.round()}°C',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder(ColorScheme scheme) {
    final muted = scheme.onSurfaceVariant;
    if (_triedToBuild) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: scheme.errorContainer.withValues(alpha: 0.7),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.warning_amber_rounded,
                  size: 44, color: scheme.onErrorContainer),
            ),
            const SizedBox(height: 16),
            Text(
              'Не из чего собрать образ\nдля этой погоды',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'У вещей должны быть заполнены «Тип» и «Погода»\nили выбери другую погоду',
              textAlign: TextAlign.center,
              style: TextStyle(color: muted),
            ),
          ],
        ),
      );
    }
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // «Вешалка» в градиентном круге с декоративными кольцами.
          SizedBox(
            width: 150,
            height: 150,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scheme.primaryContainer.withValues(alpha: 0.35),
                  ),
                ),
                Container(
                  width: 112,
                  height: 112,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: heroGradient(Theme.of(context).brightness),
                    ),
                    boxShadow: glowShadow(
                        heroGradient(Theme.of(context).brightness)),
                  ),
                  child: const Icon(Icons.checkroom, size: 52, color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Нажми «Создать наряд» —\nи я соберу образ из твоих вещей',
            textAlign: TextAlign.center,
            style: TextStyle(color: muted, fontSize: 15, height: 1.4),
          ),
        ],
      ),
    );
  }

  // ───────── История носки: последние 7 дней ─────────

  Widget _weekStrip(ColorScheme scheme) {
    final now = DateTime.now();
    final days = List.generate(
        7, (i) => DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: 6 - i)));
    // Буквы дней недели: Пн Вт Ср Чт Пт Сб Вс.
    const letters = ['П', 'В', 'С', 'Ч', 'П', 'С', 'В'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final d in days)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: () => _showDay(d),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: WearStore.eventFor(
                              '${d.year}-${d.month.toString().padLeft(2, '0')}-'
                              '${d.day.toString().padLeft(2, '0')}') !=
                          null
                      ? scheme.primary
                      : scheme.surfaceContainerHigh,
                  border: (d.year == now.year &&
                          d.month == now.month &&
                          d.day == now.day)
                      ? Border.all(color: scheme.primary, width: 2)
                      : null,
                ),
                child: Center(
                  child: Text(
                    letters[d.weekday - 1],
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: WearStore.eventFor(
                                  '${d.year}-${d.month.toString().padLeft(2, '0')}-'
                                  '${d.day.toString().padLeft(2, '0')}') !=
                              null
                          ? scheme.onPrimary
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ───────── Избранные образы ─────────

  Widget _favoritesStrip(ColorScheme scheme) {
    if (WearStore.favorites.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: SizedBox(
        height: 74,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (final f in WearStore.favorites)
              _favoriteCard(f, scheme),
          ],
        ),
      ),
    );
  }

  Widget _favoriteCard(FavoriteOutfit f, ColorScheme scheme) {
    final outfit = outfitFromIds(f.itemIds);
    final items = outfit?.items ?? const <ClothingItem>[];
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () {
          if (outfit != null) setState(() => _outfit = outfit);
        },
        onLongPress: () => WearStore.removeFavorite(f),
        child: Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                for (final item in items.take(3))
                  SizedBox(
                    width: 56,
                    height: 64,
                    child: Image.file(
                      File(item.imagePath),
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const SizedBox.expand(),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOutfitView(Outfit outfit) {
    // Манекен: вещи надеваются на фигуру. Пилюли-подписи не нужны —
    // и так видно, где что надето.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SizedBox(
        height: 430,
        child: MannequinOutfit(outfit: outfit),
      ),
    );
  }

  Widget _buildColorRow(ColorScheme scheme) {
    final colors = <Color>[];
    for (final item in _outfit?.items ?? const <ClothingItem>[]) {
      final c = kNamedColors[item.color];
      if (c != null && !colors.contains(c)) colors.add(c);
    }
    if (colors.isEmpty) {
      return Text(
        'цвета образа появятся здесь',
        style: TextStyle(
          color: scheme.onSurfaceVariant,
          fontSize: 13,
        ),
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final c in colors)
          Container(
            width: 18,
            height: 18,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: c,
              shape: BoxShape.circle,
              border: Border.all(
                  color: scheme.outlineVariant, width: 2),
            ),
          ),
      ],
    );
  }
}