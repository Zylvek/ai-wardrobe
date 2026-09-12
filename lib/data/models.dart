/// Одна вещь в гардеробе.
class ClothingItem {
  ClothingItem({
    required this.id,
    required this.imagePath,
    this.originalPath,
    this.type,
    this.color,
    this.weather,
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
        if (anglePaths.isNotEmpty) 'anglePaths': anglePaths,
      };

  factory ClothingItem.fromJson(Map<String, dynamic> json) => ClothingItem(
        id: json['id'] as String,
        imagePath: json['imagePath'] as String,
        originalPath: json['originalPath'] as String?,
        type: json['type'] as String?,
        color: json['color'] as String?,
        weather: json['weather'] as String?,
        anglePaths:
            (json['anglePaths'] as List<dynamic>?)?.cast<String>() ?? [],
      );
}