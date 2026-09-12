/// Одна вещь в гардеробе.
class ClothingItem {
  ClothingItem({
    required this.id,
    required this.imagePath,
    this.originalPath,
    this.type,
    this.color,
    this.weather,
    this.note,
    this.laundryUntil,
    this.appVersion,
    this.filterVersion,
    List<String>? anglePaths,
  }) : anglePaths = anglePaths ?? [];

  final String id;
  String imagePath;

  /// Путь к исходному (неочищенному) фото — для повторной очистки фона.
  /// null у старых вещей, добавленных до «умной камеры».
  String? originalPath;
  String? type;
  String? color;
  String? weather;

  /// Заметка пользователя: бренд, «колется», «тёплая» и т.п.
  String? note;

  /// До какой даты вещь «в стирке» (ISO «2026-09-13»). В стирке вещь
  /// не попадает в образы. null — вещь доступна.
  String? laundryUntil;

  /// Вещь сейчас в стирке? Дата хранения включительна.
  bool get inLaundry {
    final until = laundryUntil;
    if (until == null) return false;
    final d = DateTime.tryParse(until);
    if (d == null) return false;
    final now = DateTime.now();
    final endOfDay = DateTime(d.year, d.month, d.day, 23, 59, 59);
    return now.isBefore(endOfDay);
  }

  /// Помечает вещь «в стирке» до завтрашнего дня.
  void sendToLaundry() {
    final t = DateTime.now().add(const Duration(days: 1));
    laundryUntil =
        '${t.year}-${t.month.toString().padLeft(2, '0')}-'
        '${t.day.toString().padLeft(2, '0')}';
  }

  /// Версия приложения, в которой вещь была добавлена (например
  /// «1.0.3+4»). null у старых вещей.
  String? appVersion;

  /// Версия фильтра (алгоритма вырезания фона), которой обработано
  /// текущее фото. Если не совпадает с kFilterVersion — вещь можно
  /// перекроить из оригинала кнопкой «Обновить фильтр».
  String? filterVersion;

  /// Дополнительные ракурсы (очищенные PNG): слева, сзади, справа.
  /// Первый ракурс «спереди» — это imagePath. Используются для
  /// вращения вещи в карточке.
  final List<String> anglePaths;

  /// Все ракурсы по порядку: спереди, потом остальные.
  List<String> get allAngles => [imagePath, ...anglePaths];

  bool get isComplete => type != null && color != null && weather != null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'imagePath': imagePath,
        if (originalPath != null) 'originalPath': originalPath,
        'type': type,
        'color': color,
        'weather': weather,
        if (note != null) 'note': note,
        if (laundryUntil != null) 'laundryUntil': laundryUntil,
        if (appVersion != null) 'appVersion': appVersion,
        if (filterVersion != null) 'filterVersion': filterVersion,
        if (anglePaths.isNotEmpty) 'anglePaths': anglePaths,
      };

  factory ClothingItem.fromJson(Map<String, dynamic> json) => ClothingItem(
        id: json['id'] as String,
        imagePath: json['imagePath'] as String,
        originalPath: json['originalPath'] as String?,
        type: json['type'] as String?,
        color: json['color'] as String?,
        weather: json['weather'] as String?,
        note: json['note'] as String?,
        laundryUntil: json['laundryUntil'] as String?,
        appVersion: json['appVersion'] as String?,
        filterVersion: json['filterVersion'] as String?,
        anglePaths:
            (json['anglePaths'] as List<dynamic>?)?.cast<String>() ?? [],
      );
}