import '../database/database_helper.dart';
import '../models/models.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class SearchResult {
  final String vendorId;
  final String vendorName;
  final String? technologyId;
  final String? technologyTitle;
  final String matchedText;
  final String type;

  SearchResult({
    required this.vendorId,
    required this.vendorName,
    this.technologyId,
    this.technologyTitle,
    required this.matchedText,
    required this.type,
  });
}

class DatabaseService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

Future<Database> get database => _dbHelper.database; 

  // --- Vendors ---
  Future<List<Vendor>> getVendors() async {
    final db = await _dbHelper.database;
    final maps = await db.query('vendors', orderBy: 'name ASC');
    return maps.map((e) => Vendor.fromMap(e)).toList();
  }

  Future<void> insertVendor(Vendor vendor) async {
    final db = await _dbHelper.database;
    await db.insert('vendors', vendor.toMap());
  }

  Future<void> deleteVendor(String id) async {
    final db = await _dbHelper.database;
    await db.delete('vendors', where: 'id = ?', whereArgs: [id]);
  }

  // --- Technologies ---
  Future<List<Technology>> getTechnologies(String vendorId) async {
    final db = await _dbHelper.database;
    final maps = await db.query('technologies', where: 'vendor_id = ?', whereArgs: [vendorId], orderBy: 'title ASC');
    return maps.map((e) => Technology.fromMap(e)).toList();
  }

  Future<void> insertTechnology(Technology technology) async {
    final db = await _dbHelper.database;
    await db.insert('technologies', technology.toMap());
  }

  Future<void> updateTechnology(Technology technology) async {
    final db = await _dbHelper.database;
    await db.update('technologies', technology.toMap(), where: 'id = ?', whereArgs: [technology.id]);
  }

  Future<void> deleteTechnology(String id) async {
    final db = await _dbHelper.database;
    await db.delete('technologies', where: 'id = ?', whereArgs: [id]);
  }

  // НОВЫЙ ПОИСКОВЫЙ ЗАПРОС (ищет в названиях технологий и внутри блоков)
  Future<List<SearchResult>> searchAll(String query) async {
    if (query.trim().isEmpty) return [];
    final db = await _dbHelper.database;
    final String q = '%${query.toLowerCase()}%';
    List<SearchResult> results = [];

    // 1. Поиск по Вендорам
    final vendorMaps = await db.query('vendors', where: 'LOWER(name) LIKE ?', whereArgs: [q]);
    for (var map in vendorMaps) {
      results.add(SearchResult(
        vendorId: map['id'] as String,
        vendorName: map['name'] as String,
        matchedText: map['name'] as String,
        type: 'vendor',
      ));
    }

    // 2. Поиск по Названиям Технологий
    final techMaps = await db.query('technologies', where: 'LOWER(title) LIKE ?', whereArgs: [q]);
    final vendors = await db.query('vendors');
    final vendorMap = {for (var v in vendors) v['id'] as String: v['name'] as String};

    for (var map in techMaps) {
      final vId = map['vendor_id'] as String;
      final vName = vendorMap[vId] ?? 'Неизвестно';
      results.add(SearchResult(
        vendorId: vId,
        vendorName: vName,
        technologyId: map['id'] as String,
        technologyTitle: map['title'] as String,
        matchedText: map['title'] as String,
        type: 'tech_title',
      ));
    }

    // 3. Поиск внутри Блоков (по полю plain_text)
    final blockMaps = await db.rawQuery('''
      SELECT b.plain_text as matched_text, t.id as tech_id, t.title as tech_title, v.id as vendor_id, v.name as vendor_name
      FROM blocks b
      JOIN technologies t ON b.technology_id = t.id
      JOIN vendors v ON t.vendor_id = v.id
      WHERE LOWER(b.plain_text) LIKE ?
    ''', [q]);

    for (var map in blockMaps) {
      results.add(SearchResult(
        vendorId: map['vendor_id'] as String,
        vendorName: map['vendor_name'] as String,
        technologyId: map['tech_id'] as String,
        technologyTitle: map['tech_title'] as String,
        matchedText: map['matched_text'] as String,
        type: 'tech_desc',
      ));
    }

    return results;
  }

  // --- Images ---
  Future<List<AppImage>> getImages(String technologyId) async {
    final db = await _dbHelper.database;
    final maps = await db.query('images', where: 'technology_id = ?', whereArgs: [technologyId]);
    return maps.map((e) => AppImage.fromMap(e)).toList();
  }

  Future<void> insertImage(AppImage image) async {
    final db = await _dbHelper.database;
    await db.insert('images', image.toMap());
  }

  Future<void> deleteImage(String id) async {
    final db = await _dbHelper.database;
    await db.delete('images', where: 'id = ?', whereArgs: [id]);
  }

  // --- Очистка базы данных ---
  Future<void> clearDatabase() async {
    final db = await _dbHelper.database;
    await db.delete('blocks');
    await db.delete('technologies');
    await db.delete('vendors');

    // Удаляем папку с картинками
    final dir = await getApplicationDocumentsDirectory();
    final imgDir = Directory(p.join(dir.path, 'tech_images'));
    if (await imgDir.exists()) {
      await imgDir.delete(recursive: true);
    }
  }

    // --- Blocks ---
  Future<List<Block>> getBlocks(String technologyId) async {
    final db = await _dbHelper.database;
    final maps = await db.query('blocks', where: 'technology_id = ?', whereArgs: [technologyId], orderBy: 'order_num ASC');
    return maps.map((e) => Block.fromMap(e)).toList();
  }

  Future<void> insertBlock(Block block) async {
    final db = await _dbHelper.database;
    await db.insert('blocks', block.toMap());
  }

  Future<void> updateBlock(Block block) async {
    final db = await _dbHelper.database;
    await db.update('blocks', block.toMap(), where: 'id = ?', whereArgs: [block.id]);
  }

  Future<void> deleteBlock(String id) async {
    final db = await _dbHelper.database;
    await db.delete('blocks', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateVendor(Vendor vendor) async {
    final db = await _dbHelper.database;
    await db.update('vendors', vendor.toMap(), where: 'id = ?', whereArgs: [vendor.id]);
  }

  Future<void> moveTechnology(String techId, String newVendorId) async {
    final db = await _dbHelper.database;
    await db.update('technologies', {'vendor_id': newVendorId}, where: 'id = ?', whereArgs: [techId]);
  }

}