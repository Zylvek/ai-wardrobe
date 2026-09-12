import 'dart:io';

import 'package:flutter/material.dart';

import '../data/constants.dart';
import '../data/models.dart';
import '../data/options_store.dart';
import '../data/wardrobe_store.dart';
import '../data/wear_store.dart';
import 'add_flow.dart';
import 'filter_chips.dart';
import 'item_edit_sheet.dart';
import 'theme/decor.dart';

/// Режим сортировки карточек в гардеробе.
enum SortMode {
  newest('Сначала новые'),
  oldest('Сначала старые'),
  byType('По типу'),
  byColor('По цвету'),
  byWear('По частоте носки');

  const SortMode(this.label);
  final String label;
}

/// Страница 2: поиск, фильтры, карточки вещей.
class WardrobePage extends StatefulWidget {
  const WardrobePage({super.key});

  @override
  State<WardrobePage> createState() => _WardrobePageState();
}

class _WardrobePageState extends State<WardrobePage> {
  String? _openFilter;    // какая группа фильтров раскрыта
  String? _filterType;    // выбранный тип (null = «Всё»)
  String? _filterColor;   // выбранный цвет (null = «Любой»)
  String? _filterWeather; // выбранная погода (null = «Любая»)

  final _searchController = TextEditingController();
  String _query = '';
  SortMode _sort = SortMode.newest;

  // Мультивыбор: id выбранных вещей.
  final Set<String> _selected = {};
  bool get _selecting => _selected.isNotEmpty;

  @override
  void initState() {
    super.initState();
    wardrobeVersion.addListener(_refresh);
    wearVersion.addListener(_refresh);
  }

  @override
  void dispose() {
    wardrobeVersion.removeListener(_refresh);
    wearVersion.removeListener(_refresh);
    _searchController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  /// Добавляет/убирает вещь из выбранных.
  void _toggleSelect(String id) {
    setState(() {
      if (!_selected.remove(id)) _selected.add(id);
    });
  }

  bool get _hasActiveFilters =>
      _filterType != null || _filterColor != null || _filterWeather != null;

  List<ClothingItem> get _filteredItems {
    final q = _query.trim().toLowerCase();
    final items = WardrobeStore.items.where((item) {
      if (_filterType != null && item.type != _filterType) return false;
      if (_filterColor != null && item.color != _filterColor) return false;
      if (_filterWeather != null && item.weather != _filterWeather) {
        return false;
      }
      // Поиск по названию, цвету, погоде и заметке.
      if (q.isNotEmpty) {
        final haystack = [
          item.type ?? '',
          item.color ?? '',
          item.weather ?? '',
          item.note ?? '',
        ].join(' ').toLowerCase();
        if (!haystack.contains(q)) return false;
      }
      return true;
    }).toList();

    switch (_sort) {
      case SortMode.newest:
        // Список хранится «старые первыми» — новые в конце.
        return items.reversed.toList();
      case SortMode.oldest:
        return items;
      case SortMode.byType:
        items.sort((a, b) =>
            (a.type ?? 'Я').compareTo(b.type ?? 'Я'));
        return items;
      case SortMode.byColor:
        items.sort((a, b) =>
            (a.color ?? 'Я').compareTo(b.color ?? 'Я'));
        return items;
      case SortMode.byWear:
        items.sort((a, b) =>
            WearStore.wearCount(b.id).compareTo(WearStore.wearCount(a.id)));
        return items;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurfaceVariant;
    return SafeArea(
      bottom: false,
      child: AppGradientBackground(
        child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _selecting ? _selectionBar() : _searchBar(),
          ),
          const SizedBox(height: 8),
          if (!_selecting)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _filterToggle('Погода', Icons.wb_cloudy),
                  const SizedBox(width: 8),
                  _filterToggle('Цвет', Icons.palette),
                  const SizedBox(width: 8),
                  _filterToggle('Тип', Icons.checkroom),
                  if (_hasActiveFilters)
                    TextButton.icon(
                      onPressed: () => setState(() {
                        _filterType = null;
                        _filterColor = null;
                        _filterWeather = null;
                      }),
                      icon: const Icon(Icons.clear_all, size: 16),
                      label: const Text('Сбросить'),
                    ),
                ],
              ),
            ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            child: !_selecting && _openFilter != null
                ? Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: _chipsFor(_openFilter!),
                  )
                : const SizedBox(height: 0, width: double.infinity),
          ),
          if (_selecting) _selectionActions(),
          Expanded(
            child: WardrobeStore.items.isEmpty
                ? _emptyState(
                    icon: Icons.checkroom,
                    iconColors: [scheme.primaryContainer, scheme.secondaryContainer],
                    iconColor: scheme.onPrimaryContainer,
                    title: 'Вещей пока нет',
                    hint: 'Нажми «Добавить», чтобы сфотографировать первую вещь',
                    hintColor: muted,
                  )
                : _filteredItems.isEmpty
                    ? _emptyState(
                        icon: Icons.search_off,
                        iconColors: [scheme.surfaceContainerHigh, scheme.surfaceContainerHighest],
                        iconColor: muted,
                        title: 'Ничего не найдено',
                        hint: 'Попробуй изменить фильтры или поиск',
                        hintColor: muted,
                      )
                    : GridView.builder(
                        padding: EdgeInsets.fromLTRB(
                            16, 16, 16, _selecting ? 160 : 100),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 180,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.9,
                        ),
                        itemCount: _filteredItems.length,
                        itemBuilder: (context, index) => AppearOnBuild(
                          index: index,
                          child: _itemCard(_filteredItems[index]),
                        ),
                      ),
          ),
        ],
      ),
      ),
    );
  }

  /// Обычная строка: поиск + сортировка + «Добавить».
  Widget _searchBar() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Поиск вещей...',
              isDense: true,
              suffixIcon: PopupMenuButton<SortMode>(
                icon: Icon(
                  Icons.sort,
                  color: _sort == SortMode.newest
                      ? Theme.of(context).colorScheme.onSurfaceVariant
                      : Theme.of(context).colorScheme.primary,
                ),
                tooltip: 'Сортировка',
                onSelected: (m) => setState(() => _sort = m),
                itemBuilder: (_) => [
                  for (final m in SortMode.values)
                    PopupMenuItem(
                      value: m,
                      child: Row(
                        children: [
                          if (m == _sort)
                            const Icon(Icons.check, size: 18)
                          else
                            const SizedBox(width: 18),
                          const SizedBox(width: 8),
                          Text(m.label),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton.tonalIcon(
          onPressed: () => runAddFlow(context),
          icon: const Icon(Icons.add_a_photo),
          label: const Text('Добавить'),
        ),
      ],
    );
  }

  /// Строка режима выбора: счётчик + «Выбрать всё» + «Отмена».
  Widget _selectionBar() {
    return Row(
      children: [
        Icon(Icons.check_circle,
            color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          'Выбрано: ${_selected.length}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const Spacer(),
        TextButton(
          onPressed: () => setState(() {
            for (final item in WardrobeStore.items) {
              _selected.add(item.id);
            }
          }),
          child: const Text('Выбрать всё'),
        ),
        TextButton(
          onPressed: () => setState(() => _selected.clear()),
          child: const Text('Отмена'),
        ),
      ],
    );
  }

  /// Нижняя панель действий над выбранными вещами.
  Widget _selectionActions() {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: FilledButton.tonalIcon(
              onPressed: _deleteSelected,
              style: FilledButton.styleFrom(
                foregroundColor: scheme.error,
              ),
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('Удалить'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton.tonalIcon(
              onPressed: _laundrySelected,
              icon: const Icon(Icons.local_laundry_service, size: 18),
              label: const Text('В стирку'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: PopupMenuButton<String>(
              onSelected: (w) => _weatherSelected(w),
              itemBuilder: (_) => [
                for (final w in kWeathers)
                  PopupMenuItem(value: w, child: Text(w)),
              ],
              child: FilledButton.tonalIcon(
                onPressed: null,
                icon: const Icon(Icons.wb_cloudy, size: 18),
                label: const Text('Погода'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSelected() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Удалить выбранные вещи?'),
        content: Text(
          'Будут удалены ${_selected.length} '
          '${_pluralThing(_selected.length)} вместе с фото.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    for (final item in WardrobeStore.items
        .where((i) => _selected.contains(i.id))
        .toList()) {
      WardrobeStore.items.remove(item);
      try {
        await File(item.imagePath).delete();
      } catch (_) {}
    }
    _selected.clear();
    await WardrobeStore.save();
    wardrobeVersion.value++;
  }

  static String _pluralThing(int n) {
    if (n % 10 == 1 && n % 100 != 11) return 'вещь';
    if ({2, 3, 4}.contains(n % 10) &&
        !{12, 13, 14}.contains(n % 100)) {
      return 'вещи';
    }
    return 'вещей';
  }

  Future<void> _laundrySelected() async {
    for (final item in WardrobeStore.items) {
      if (_selected.contains(item.id)) item.sendToLaundry();
    }
    _selected.clear();
    await WardrobeStore.save();
    wardrobeVersion.value++;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Вещи отправлены в стирку — до завтра 🧺'),
        ),
      );
    }
  }

  Future<void> _weatherSelected(String weather) async {
    for (final item in WardrobeStore.items) {
      if (_selected.contains(item.id)) item.weather = weather;
    }
    _selected.clear();
    await WardrobeStore.save();
    wardrobeVersion.value++;
  }

  /// Большое пустое состояние с иконкой в градиентном круге.
  Widget _emptyState({
    required IconData icon,
    required List<Color> iconColors,
    required Color iconColor,
    required Color hintColor,
    required String title,
    required String hint,
  }) {
    return Center(
      child: AppearOnBuild(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: heroGradient(Theme.of(context).brightness),
                ),
                shape: BoxShape.circle,
                boxShadow:
                    glowShadow(heroGradient(Theme.of(context).brightness)),
              ),
              child: Icon(icon, size: 56, color: Colors.white),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              hint,
              textAlign: TextAlign.center,
              style: TextStyle(color: hintColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _itemCard(ClothingItem item) {
    final scheme = Theme.of(context).colorScheme;
    final dot = _colorDotFor(item.color, scheme);
    final isSelected = _selected.contains(item.id);
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () =>
            _selecting ? _toggleSelect(item.id) : _editItem(item),
        onLongPress: () => _toggleSelect(item.id),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Image.file(
                    File(item.imagePath),
                    width: double.infinity,
                    // contain: вещь видна целиком, а не «только середина».
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => Center(
                      child: Icon(Icons.broken_image, size: 40, color: scheme.onSurfaceVariant),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  child: Row(
                    children: [
                      ?dot,
                      Expanded(
                        child: Text(
                          item.type ?? 'Укажи параметры',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: item.isComplete
                                ? scheme.onSurfaceVariant
                                : scheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Вещь в стирке — приглушаем и показываем бейдж.
            if (item.inLaundry) ...[
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    color: scheme.surface.withValues(alpha: 0.55),
                  ),
                ),
              ),
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.local_laundry_service,
                    size: 16,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
            // Выбранная вещь — подсветка и галочка.
            if (isSelected) ...[
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    color: scheme.primary.withValues(alpha: 0.25),
                  ),
                ),
              ),
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.check,
                      size: 16, color: scheme.onPrimary),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget? _colorDotFor(String? colorName, ColorScheme scheme) {
    final c = kNamedColors[colorName];
    if (c == null) return null;
    return Container(
      width: 10,
      height: 10,
      margin: const EdgeInsets.only(right: 4),
      decoration: BoxDecoration(
        color: c,
        shape: BoxShape.circle,
        border: Border.all(color: scheme.outlineVariant),
      ),
    );
  }

  Future<void> _editItem(ClothingItem item) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxHeight: 640),
      builder: (_) => ItemEditSheet(item: item),
    );
    if (result == 'save') {
      await WardrobeStore.save();
      wardrobeVersion.value++;
    } else if (result == 'delete') {
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Удалить вещь?'),
          content: const Text('Фото и её характеристики будут удалены.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Удалить'),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        WardrobeStore.items.remove(item);
        try {
          await File(item.imagePath).delete();
        } catch (_) {}
        await WardrobeStore.save();
        wardrobeVersion.value++;
      }
    }
  }

  Widget _filterToggle(String name, IconData icon) {
    final isOpen = _openFilter == name;
    return FilterChip(
      label: Text(
        name,
        style: TextStyle(
          color: isOpen
              ? Theme.of(context).colorScheme.onPrimary
              : Theme.of(context).colorScheme.onSurface,
          fontWeight: isOpen ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      avatar: Icon(
        icon,
        size: 18,
        color: isOpen
            ? Theme.of(context).colorScheme.onPrimary
            : Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      selected: isOpen,
      showCheckmark: false,
      onSelected: (_) {
        setState(() {
          _openFilter = isOpen ? null : name;
        });
      },
    );
  }

  Widget _chipsFor(String filter) {
    switch (filter) {
      case 'Погода':
        final idx = kWeathers.indexOf(_filterWeather ?? '');
        return FilterChips(
          labels: ['Любая', ...kWeathers],
          selectedIndex: (_filterWeather == null || idx == -1) ? 0 : idx + 1,
          onSelected: (i) => setState(
            () => _filterWeather = i == 0 ? null : kWeathers[i - 1],
          ),
          onAdd: () => _addCustomOption('Погода'),
        );
      case 'Цвет':
        final names = kNamedColors.keys.toList();
        final idx = names.indexOf(_filterColor ?? '');
        return FilterChips(
          labels: ['Любой', ...names],
          colors: [null, ...kNamedColors.values],
          selectedIndex: (_filterColor == null || idx == -1) ? 0 : idx + 1,
          onSelected: (i) => setState(
            () => _filterColor = i == 0 ? null : names[i - 1],
          ),
          onAdd: () => _addCustomOption('Цвет'),
        );
      default:
        final idx = kTypes.indexOf(_filterType ?? '');
        return FilterChips(
          labels: ['Всё', ...kTypes],
          selectedIndex: (_filterType == null || idx == -1) ? 0 : idx + 1,
          onSelected: (i) => setState(
            () => _filterType = i == 0 ? null : kTypes[i - 1],
          ),
          onAdd: () => _addCustomOption('Тип'),
        );
    }
  }

  /// Диалог создания своего фильтра + сохранение.
  Future<void> _addCustomOption(String group) async {
    final result = await showDialog<(String, Color)>(
      context: context,
      builder: (_) => _AddOptionDialog(group: group),
    );
    if (result == null) return;
    final name = result.$1;

    if (group == 'Тип' && !kTypes.contains(name)) {
      kTypes.add(name);
    } else if (group == 'Погода' && !kWeathers.contains(name)) {
      kWeathers.add(name);
    } else if (group == 'Цвет' && !kNamedColors.containsKey(name)) {
      kNamedColors[name] = result.$2;
    }
    await OptionsStore.save();
    if (mounted) setState(() {});
  }
}

/// Диалог: название (+ палитра, если группа «Цвет»).
class _AddOptionDialog extends StatefulWidget {
  const _AddOptionDialog({required this.group});

  final String group;

  @override
  State<_AddOptionDialog> createState() => _AddOptionDialogState();
}

class _AddOptionDialogState extends State<_AddOptionDialog> {
  final _controller = TextEditingController();
  Color _pickedColor = _paletteColors.first;

  static const List<Color> _paletteColors = [
    Colors.white, Colors.black, Colors.grey, Colors.brown,
    Colors.red, Colors.pink, Colors.orange, Colors.yellow,
    Colors.green, Colors.teal, Colors.blue, Colors.indigo,
    Colors.purple, Color(0xFFE8D5B5),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isColorGroup = widget.group == 'Цвет';
    return AlertDialog(
      title: Text('Свой фильтр: ${widget.group}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Название'),
            onSubmitted: (_) => _submit(),
          ),
          if (isColorGroup) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in _paletteColors)
                  GestureDetector(
                    onTap: () => setState(() => _pickedColor = c),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _pickedColor == c
                              ? scheme.primary
                              : scheme.outlineVariant,
                          width: _pickedColor == c ? 3 : 1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Добавить'),
        ),
      ],
    );
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(context, (name, _pickedColor));
  }
}