import 'dart:io';

import 'package:flutter/material.dart';

import '../data/constants.dart';
import '../data/models.dart';
import '../data/options_store.dart';
import '../data/wardrobe_store.dart';
import 'add_flow.dart';
import 'filter_chips.dart';
import 'item_edit_sheet.dart';
import 'theme/decor.dart';

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

  bool get _hasActiveFilters =>
      _filterType != null || _filterColor != null || _filterWeather != null;

  List<ClothingItem> get _filteredItems {
    return WardrobeStore.items.where((item) {
      if (_filterType != null && item.type != _filterType) return false;
      if (_filterColor != null && item.color != _filterColor) return false;
      if (_filterWeather != null && item.weather != _filterWeather) return false;
      return true;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    wardrobeVersion.addListener(_refresh);
  }

  @override
  void dispose() {
    wardrobeVersion.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
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
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Поиск вещей...',
                      isDense: true,
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
            ),
          ),
          const SizedBox(height: 8),
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
            child: _openFilter == null
                ? const SizedBox(height: 0, width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: _chipsFor(_openFilter!),
                  ),
          ),
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
                        hint: 'Попробуй изменить фильтры',
                        hintColor: muted,
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
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
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () => _editItem(item),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Image.file(
                File(item.imagePath),
                width: double.infinity,
                fit: BoxFit.cover,
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