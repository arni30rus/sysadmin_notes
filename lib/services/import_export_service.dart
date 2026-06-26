import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:archive/archive.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:file_selector/file_selector.dart';
import '../database/database_helper.dart';
import '../models/models.dart';
import 'package:uuid/uuid.dart';

class ImportExportService {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final DateFormat _dateFormatter = DateFormat('yyyy-MM-dd');

  // Универсальный метод сохранения файла через системный диалог
  Future<bool> _saveFile(String baseName, String extension, List<int> bytes) async {
    final String fileName = '${baseName}_${_dateFormatter.format(DateTime.now())}.$extension';
    final FileSaveLocation? saveLocation = await getSaveLocation(suggestedName: fileName);
    
    if (saveLocation != null) {
      final File file = File(saveLocation.path);
      await file.writeAsBytes(bytes);
      return true;
    }
    return false;
  }

  // Вспомогательный метод для красивого форматирования JSON
  String _encodeJson(Map<String, dynamic> data) {
    final JsonEncoder encoder = const JsonEncoder.withIndent('  ');
    return encoder.convert(data);
  }

  // --- ЭКСПОРТ ОДНОЙ ТЕХНОЛОГИИ ---
  Future<bool> exportTechnology(Technology tech, Vendor vendor) async {
    final db = await _dbHelper.database;
    final blocks = await db.query('blocks', where: 'technology_id = ?', whereArgs: [tech.id], orderBy: 'order_num ASC');

    final Map<String, dynamic> jsonData = {
      'type': 'technology',
      'export_date': DateTime.now().toIso8601String(),
      'data': {
        'vendor': vendor.toMap(),
        'technology': tech.toMap(),
        'blocks': blocks,
      }
    };

    final String jsonString = _encodeJson(jsonData);
    final String baseName = '${vendor.name}_${tech.title}';

    // Проверяем, есть ли картинки среди блоков
    bool hasImages = blocks.any((b) => b['type'] == 'image');

    if (!hasImages) {
      return _saveFile(baseName, 'json', utf8.encode(jsonString));
    } else {
      final Archive archive = Archive();
      archive.addFile(ArchiveFile('data.json', jsonString.length, utf8.encode(jsonString)));
      
      for (var blockMap in blocks) {
        if (blockMap['type'] == 'image') {
          final File imgFile = File(blockMap['content'] as String);
          if (await imgFile.exists()) {
            final bytes = await imgFile.readAsBytes();
            final fileName = p.basename(imgFile.path);
            archive.addFile(ArchiveFile('images/$fileName', bytes.length, bytes));
          }
        }
      }
      
      final zipBytes = ZipEncoder().encode(archive);
      if (zipBytes == null) return false;
      return _saveFile(baseName, 'zip', zipBytes);
    }
  }

  // --- ЭКСПОРТ ВЕНДОРА ---
  Future<bool> exportVendor(Vendor vendor) async {
    final db = await _dbHelper.database;
    final techs = await db.query('technologies', where: 'vendor_id = ?', whereArgs: [vendor.id]);
    
    List<Map<String, dynamic>> techData = [];
    bool hasImages = false;

    for (var techMap in techs) {
      final blocks = await db.query('blocks', where: 'technology_id = ?', whereArgs: [techMap['id']], orderBy: 'order_num ASC');
      if (blocks.any((b) => b['type'] == 'image')) hasImages = true;
      techData.add({
        'technology': techMap,
        'blocks': blocks,
      });
    }

    final Map<String, dynamic> jsonData = {
      'type': 'vendor',
      'export_date': DateTime.now().toIso8601String(),
      'data': {
        'vendor': vendor.toMap(),
        'technologies': techData,
      }
    };

    final String jsonString = _encodeJson(jsonData);
    final String baseName = 'Vendor_${vendor.name}';
    
    if (!hasImages) {
      return _saveFile(baseName, 'json', utf8.encode(jsonString));
    } else {
      final Archive archive = Archive();
      archive.addFile(ArchiveFile('data.json', jsonString.length, utf8.encode(jsonString)));
      
      for (var tech in techData) {
        for (var blockMap in tech['blocks'] as List) {
          if ((blockMap as Map)['type'] == 'image') {
            final File imgFile = File(blockMap['content'] as String);
            if (await imgFile.exists()) {
              final bytes = await imgFile.readAsBytes();
              final fileName = p.basename(imgFile.path);
              archive.addFile(ArchiveFile('images/$fileName', bytes.length, bytes));
            }
          }
        }
      }
      
      final zipBytes = ZipEncoder().encode(archive);
      if (zipBytes == null) return false;
      return _saveFile(baseName, 'zip', zipBytes);
    }
  }

  // --- ЭКСПОРТ ВСЕЙ БАЗЫ ---
  Future<bool> exportFullBackup() async {
    final db = await _dbHelper.database;
    final vendors = await db.query('vendors');
    
    List<Map<String, dynamic>> allData = [];
    bool hasImages = false;
    
    for (var vendor in vendors) {
      final techs = await db.query('technologies', where: 'vendor_id = ?', whereArgs: [vendor['id']]);
      List<Map<String, dynamic>> techData = [];
      
      for (var techMap in techs) {
        final blocks = await db.query('blocks', where: 'technology_id = ?', whereArgs: [techMap['id']], orderBy: 'order_num ASC');
        if (blocks.any((b) => b['type'] == 'image')) hasImages = true;
        techData.add({
          'technology': techMap,
          'blocks': blocks,
        });
      }
      
      allData.add({
        'vendor': vendor,
        'technologies': techData,
      });
    }

    final Map<String, dynamic> jsonData = {
      'type': 'full_backup',
      'export_date': DateTime.now().toIso8601String(),
      'data': allData,
    };

    final String jsonString = _encodeJson(jsonData);

    // Полный бэкап всегда пакуем в ZIP для надежности, даже если нет картинок
    final Archive archive = Archive();
    archive.addFile(ArchiveFile('data.json', jsonString.length, utf8.encode(jsonString)));

    if (hasImages) {
      for (var vendor in allData) {
        for (var tech in vendor['technologies']) {
          for (var blockMap in tech['blocks'] as List) {
            if ((blockMap as Map)['type'] == 'image') {
              final File imgFile = File(blockMap['content'] as String);
              if (await imgFile.exists()) {
                final bytes = await imgFile.readAsBytes();
                final fileName = p.basename(imgFile.path);
                archive.addFile(ArchiveFile('images/$fileName', bytes.length, bytes));
              }
            }
          }
        }
      }
    }

    final zipBytes = ZipEncoder().encode(archive);
    if (zipBytes == null) return false;
    return _saveFile('Full_Backup', 'zip', zipBytes);
  }

  // --- ИМПОРТ ДАННЫХ ---
  Future<String> importData(BuildContext context) async {
    try {
      const XTypeGroup typeGroup = XTypeGroup(
        label: 'data',
        extensions: ['json', 'zip'],
      );
      final XFile? file = await openFile(acceptedTypeGroups: [typeGroup]);
      if (file == null) return 'Импорт отменен';

      final String filePath = file.path;
      Map<String, dynamic> jsonData;
      Map<String, String> importedImages = {}; 

      final db = await _dbHelper.database;
      const uuid = Uuid();

      if (filePath.toLowerCase().endsWith('.zip')) {
        final bytes = await File(filePath).readAsBytes();
        final archive = ZipDecoder().decodeBytes(bytes);
        final jsonFile = archive.findFile('data.json');
        if (jsonFile == null) return 'Ошибка: В архиве нет data.json';
        
        jsonData = jsonDecode(utf8.decode(jsonFile.content as List<int>));

        final dir = await getApplicationDocumentsDirectory();
        final imgDir = Directory(p.join(dir.path, 'tech_images'));
        if (!await imgDir.exists()) {
          await imgDir.create(recursive: true);
        }

        for (var archFile in archive) {
          if (archFile.name.startsWith('images/')) {
            final fileName = p.basename(archFile.name);
            final destPath = p.join(imgDir.path, fileName);
            final extractedFile = File(destPath);
            await extractedFile.writeAsBytes(archFile.content as List<int>);
            importedImages[fileName] = destPath;
          }
        }
      } else {
        final jsonString = await File(filePath).readAsString();
        jsonData = jsonDecode(jsonString);
      }

      final String type = jsonData['type'] as String;
      final List<dynamic> dataItems = type == 'full_backup' ? jsonData['data'] as List : [jsonData['data']];
      
      int addedCount = 0;

      // Предзагрузка существующих вендоров для сверки по имени
      final existingVendors = await db.query('vendors');
      Map<String, String> vendorNameToId = {
        for (var v in existingVendors) (v['name'] as String).toLowerCase(): v['id'] as String
      };

      for (var item in dataItems) {
        final vendorMap = item['vendor'] as Map<String, dynamic>;
        final importedVendorName = vendorMap['name'] as String? ?? 'Без имени';
        
        String localVendorId;

        // Проверяем, есть ли вендор с таким же именем
        if (vendorNameToId.containsKey(importedVendorName.toLowerCase())) {
          localVendorId = vendorNameToId[importedVendorName.toLowerCase()]!;
        } else {
          // Создаем нового вендора
          localVendorId = uuid.v4();
          await db.insert('vendors', {
            'id': localVendorId,
            'name': importedVendorName,
            'created_at': DateTime.now().toIso8601String(),
          });
          vendorNameToId[importedVendorName.toLowerCase()] = localVendorId;
        }

        // Обработка технологий
        List<dynamic> technologies = [];
        if (item.containsKey('technologies')) {
          technologies = item['technologies'] as List;
        } else if (item.containsKey('technology')) {
          technologies = [item];
        }

        for (var techItem in technologies) {
          final techMap = techItem['technology'] as Map<String, dynamic>;
          final importedTechTitle = techMap['title'] as String? ?? 'Без названия';
          
          // Проверяем, есть ли технология с таким же именем у этого вендора
          final existingTechs = await db.query('technologies', 
            where: 'vendor_id = ? AND LOWER(title) = ?', 
            whereArgs: [localVendorId, importedTechTitle.toLowerCase()]);
            
          String finalTechTitle = importedTechTitle;
          if (existingTechs.isNotEmpty) {
            // Добавляем (Копия)
            int copyNum = 1;
            while (true) {
              String tempTitle = '$importedTechTitle (Копия $copyNum)';
              final checkCopy = await db.query('technologies', 
                where: 'vendor_id = ? AND LOWER(title) = ?', 
                whereArgs: [localVendorId, tempTitle.toLowerCase()]);
              if (checkCopy.isEmpty) {
                finalTechTitle = tempTitle;
                break;
              }
              copyNum++;
            }
          }

          String localTechId = uuid.v4();
          await db.insert('technologies', {
            'id': localTechId,
            'vendor_id': localVendorId,
            'title': finalTechTitle,
            'description': '',
            'example': '',
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });
          addedCount++;

          // Импорт блоков
          if (techItem.containsKey('blocks')) {
            for (var blockMap in techItem['blocks'] as List) {
              final bMap = blockMap as Map<String, dynamic>;
              String localBlockId = uuid.v4();
              String content = bMap['content'] as String? ?? '';
              String blockType = bMap['type'] as String? ?? 'text';

              if (blockType == 'image') {
                final fileName = p.basename(content);
                final String? newPath = importedImages[fileName];
                if (newPath != null) {
                  content = newPath;
                } else {
                  continue; 
                }
              }

              await db.insert('blocks', {
                'id': localBlockId,
                'technology_id': localTechId,
                'type': blockType,
                'content': content,
                'order_num': bMap['order_num'] ?? 0,
              });
            }
          }
        }
      }
      return 'Импорт успешно завершен! Добавлено новых записей: $addedCount';
    } catch (e) {
      return 'Ошибка: Файл поврежден или имеет неверный формат.';
    }
  }
}