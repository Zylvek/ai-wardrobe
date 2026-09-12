import 'package:flutter/material.dart';

/// Ряд фильтров-чипов. Одиночный выбор: индекс 0 = «Любой/Всё».
class FilterChips extends StatelessWidget {
  const FilterChips({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
    this.colors,
    this.onAdd,
  });

  final List<String> labels;
  final List<Color?>? colors;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final colors = this.colors;
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          for (int i = 0; i < labels.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(
                  labels[i],
                  style: TextStyle(
                    color: selectedIndex == i
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(context).colorScheme.onSurface,
                    fontWeight: selectedIndex == i
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
                selected: selectedIndex == i,
                onSelected: (_) => onSelected(i),
                avatar: (colors != null && colors[i] != null)
                    ? Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: colors[i],
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                      )
                    : null,
              ),
            ),
          if (onAdd != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ActionChip(
                avatar: const Icon(Icons.add, size: 18),
                label: const Text('Свой'),
                onPressed: onAdd,
              ),
            ),
        ],
      ),
    );
  }
}
