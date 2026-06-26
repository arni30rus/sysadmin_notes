import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path_provider/path_provider.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    // Инициализируем FFI для всех платформ (Windows, Android, iOS)
    // позволит использовать современный SQLite с поддержкой FTS5
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    // Получаем путь к директории приложения
    final Directory appDir = await getApplicationSupportDirectory();
    final String dbPath = join(appDir.path, 'sysadmin_notes.db');

    return await openDatabase(
      dbPath,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE vendors (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE technologies (
        id TEXT PRIMARY KEY,
        vendor_id TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        example TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (vendor_id) REFERENCES vendors (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE blocks (
        id TEXT PRIMARY KEY,
        technology_id TEXT NOT NULL,
        type TEXT NOT NULL, -- 'text', 'code', 'image'
        content TEXT NOT NULL, -- Текст, код или путь к файлу
        plain_text TEXT NOT NULL DEFAULT '',
        order_num INTEGER NOT NULL,
        FOREIGN KEY (technology_id) REFERENCES technologies (id) ON DELETE CASCADE
      )
    ''');


    await db.execute('PRAGMA foreign_keys = ON;');

    // Виртуальная таблица для поиска (настроим на Этапе 3)
    await db.execute('''
      CREATE VIRTUAL TABLE search_fts USING fts5(
        content, 
        vendor_id UNINDEXED, 
        technology_id UNINDEXED, 
        type
      )
    ''');
  }
}