/// Одна вещь в гардеробе.
class ClothingItem {
  ClothingItem({
    required this.id,
    required this.imagePath,
    this.originalPath,
    this.type,
    this.color,
    this.weather,
  });

  final String id;
  String imagePath;

  /// Путь к исходному (неочищенному) фото — для повторной очистки фона.
  /// null у старых вещей, добавленных до «умной камеры».
  String? originalPath;
  String? type;
  String? color;
  String? weather;

  bool get isComplete => type != null && color != null && weather != null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'imagePath': imagePath,
        if (originalPath != null) 'originalPath': originalPath,
        'type': type,
        'color': color,
        'weather': weather,
      };

  factory ClothingItem.fromJson(Map<String, dynamic> json) => ClothingItem(
        id: json['id'] as String,
        imagePath: json['imagePath'] as String,
        originalPath: json['originalPath'] as String?,
        type: json['type'] as String?,
        color: json['color'] as String?,
        weather: json['weather'] as String?,
      );
}