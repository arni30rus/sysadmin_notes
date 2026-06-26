import 'package:uuid/uuid.dart';

const uuid = Uuid();

class Vendor {
  final String id;
  final String name;
  final DateTime createdAt;

  Vendor({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  factory Vendor.create({required String name}) {
    return Vendor(
      id: uuid.v4(),
      name: name,
      createdAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'created_at': createdAt.toIso8601String(),
      };

    factory Vendor.fromMap(Map<String, dynamic> map) => Vendor(
        id: map['id'] as String,
        name: map['name'] as String,
        // Если даты нет, ставим текущую
        createdAt: map['created_at'] != null ? DateTime.parse(map['created_at'] as String) : DateTime.now(),
      );
}

class Technology {
  final String id;
  final String vendorId;
  final String title;
  final String description;
  final String example;
  final DateTime createdAt;
  final DateTime updatedAt;

  Technology({
    required this.id,
    required this.vendorId,
    required this.title,
    required this.description,
    required this.example,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Technology.create({
    required String vendorId,
    required String title,
    String description = '',
    String example = '',
  }) {
    final now = DateTime.now();
    return Technology(
      id: uuid.v4(),
      vendorId: vendorId,
      title: title,
      description: description,
      example: example,
      createdAt: now,
      updatedAt: now,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'vendor_id': vendorId,
        'title': title,
        'description': description,
        'example': example,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

    factory Technology.fromMap(Map<String, dynamic> map) => Technology(
        id: map['id'] as String,
        vendorId: map['vendor_id'] as String,
        title: map['title'] as String,
        // Если текста нет, пустая строка
        description: map['description'] as String? ?? '',
        example: map['example'] as String? ?? '',
        createdAt: map['created_at'] != null ? DateTime.parse(map['created_at'] as String) : DateTime.now(),
        updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at'] as String) : DateTime.now(),
      );
}

class AppImage {
  final String id;
  final String technologyId; // Было commandId
  final String filePath;

  AppImage({
    required this.id,
    required this.technologyId,
    required this.filePath,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'technology_id': technologyId,
        'file_path': filePath,
      };

  factory AppImage.fromMap(Map<String, dynamic> map) => AppImage(
        id: map['id'] as String,
        technologyId: map['technology_id'] as String,
        filePath: map['file_path'] as String,
      );

}

 class Block {
  final String id;
  final String technologyId;
  final String type;
  String content;
  String plainText; // НОВОЕ ПОЛЕ
  int orderNum;

  Block({
    required this.id,
    required this.technologyId,
    required this.type,
    required this.content,
    required this.plainText,
    required this.orderNum,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'technology_id': technologyId,
        'type': type,
        'content': content,
        'plain_text': plainText, // НОВОЕ ПОЛЕ
        'order_num': orderNum,
      };

  factory Block.fromMap(Map<String, dynamic> map) => Block(
        id: map['id'] as String,
        technologyId: map['technology_id'] as String,
        type: map['type'] as String,
        content: map['content'] as String? ?? '',
        plainText: map['plain_text'] as String? ?? '',
        orderNum: map['order_num'] as int? ?? 0,
      );
}