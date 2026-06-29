import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../services/database_service.dart';
import '../services/import_export_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'markdown_help_screen.dart';


class TechnologyDetailScreen extends StatefulWidget {
  final Technology technology;
  const TechnologyDetailScreen({super.key, required this.technology});

  @override
  State<TechnologyDetailScreen> createState() => _TechnologyDetailScreenState();
}

class _TechnologyDetailScreenState extends State<TechnologyDetailScreen> {
  final DatabaseService _dbService = DatabaseService();
  final ImportExportService _exportService = ImportExportService();
  
  late Technology _currentTech;
  List<Block> _blocks = [];
  bool _isEditing = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _currentTech = widget.technology;
    _loadData();
  }

  Future<void> _loadData() async {
    final db = await _dbService.database;
    final techMaps = await db.query('technologies', where: 'id = ?', whereArgs: [_currentTech.id]);
    if (techMaps.isNotEmpty) {
      _currentTech = Technology.fromMap(techMaps.first);
    }
    
    final blocks = await _dbService.getBlocks(_currentTech.id);
    setState(() {
      _blocks = blocks;
      _isLoading = false;
    });
  }

  Future<void> _saveChanges() async {
    // Сохраняем все блоки
    for (var block in _blocks) {
      await _dbService.updateBlock(block);
    }
    
    final updatedTech = Technology(
      id: _currentTech.id,
      vendorId: _currentTech.vendorId,
      title: _currentTech.title,
      description: '', // Больше не используем, но оставляем пустым для совместимости
      example: '',
      createdAt: _currentTech.createdAt,
      updatedAt: DateTime.now(),
    );
    await _dbService.updateTechnology(updatedTech);
    
    setState(() => _isEditing = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Сохранено'), backgroundColor: Color(0xFFFFA726)),
    );
  }

  void _addBlock(String type) async {
    final newBlock = Block(
      id: const Uuid().v4(),
      technologyId: _currentTech.id,
      type: type,
      content: '',
      plainText: '',
      orderNum: _blocks.length,
    );
    await _dbService.insertBlock(newBlock);
    _blocks.add(newBlock);
    setState(() {});
  }

  void _pickImageBlock() async {
    try {
      const XTypeGroup typeGroup = XTypeGroup(label: 'images', extensions: ['jpg', 'png', 'jpeg', 'gif', 'webp', 'bmp']);
      final XFile? file = await openFile(acceptedTypeGroups: [typeGroup]);
      if (file == null) return;
      
      final String? sourcePath = file.path;
      if (sourcePath == null) return;

      final dir = await getApplicationSupportDirectory();
      final extension = p.extension(sourcePath);
      final String newFileName = '${const Uuid().v4()}$extension';
      final String destPath = p.join(dir.path, 'tech_images', newFileName);

      final newDir = Directory(p.dirname(destPath));
      if (!await newDir.exists()) {
        await newDir.create(recursive: true);
      }

      await File(sourcePath).copy(destPath);

      final newBlock = Block(
        id: const Uuid().v4(),
        technologyId: _currentTech.id,
        type: 'image',
        content: destPath,
        plainText: '',
        orderNum: _blocks.length,
      );
      await _dbService.insertBlock(newBlock);
      _blocks.add(newBlock);
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка загрузки: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _deleteBlock(int index) async {
    final block = _blocks[index];
    if (block.type == 'image') {
      final file = File(block.content);
      if (await file.exists()) await file.delete();
    }
    await _dbService.deleteBlock(block.id);
    _blocks.removeAt(index);
    setState(() {});
  }

  void _viewImage(String path) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.black, iconTheme: const IconThemeData(color: Colors.white)),
        body: Center(child: InteractiveViewer(child: Image.file(File(path)))),
      ),
    ));
  }

  void _moveBlock(int index, int direction) async {
    int newIndex = index + direction;
    if (newIndex < 0 || newIndex >= _blocks.length) return;

    // Меняем местами в списке
    final block1 = _blocks[index];
    final block2 = _blocks[newIndex];

    // Меняем orderNum
    int tempOrder = block1.orderNum;
    block1.orderNum = block2.orderNum;
    block2.orderNum = tempOrder;

    // Сохраняем в БД
    await _dbService.updateBlock(block1);
    await _dbService.updateBlock(block2);

    // Обновляем UI
    final tempBlock = _blocks.removeAt(index);
    _blocks.insert(newIndex, tempBlock);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentTech.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share),
            tooltip: 'Сохранить как файл',
            onPressed: () async {
              final db = await _dbService.database;
              final vMaps = await db.query('vendors', where: 'id = ?', whereArgs: [_currentTech.vendorId]);
              if (vMaps.isNotEmpty) {
                final vendor = Vendor.fromMap(vMaps.first);
                final success = await _exportService.exportTechnology(_currentTech, vendor);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(success ? 'Карточка выгружена' : 'Отменено')),
                );
              }
            },
          ),
          // НОВАЯ КНОПКА СПРАВКИ
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'Справка по Markdown',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MarkdownHelpScreen()),
              );
            },
          ),
          if (_isEditing)
            IconButton(icon: const Icon(Icons.save), onPressed: _saveChanges)
          else
            IconButton(icon: const Icon(Icons.edit), onPressed: () => setState(() => _isEditing = true)),
        ],
      ),
      body: Column(
        children: [
                    Expanded(
            child: _blocks.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(Icons.note_add_outlined, size: 70, color: const Color(0xFFFFA726).withOpacity(0.5)),
                          const SizedBox(height: 20),
                          const Text(
                            'Информация еще не добавлена.\nВойдите в режим редактирования, нажав на значок',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 16, color: Colors.grey, height: 1.5),
                          ),
                          const SizedBox(height: 8),
                          const Icon(Icons.edit, color: Color(0xFFFFA726), size: 30),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _blocks.length,
                    itemBuilder: (context, index) {
                      final block = _blocks[index];
                      return _buildBlockWidget(block, index);
                    },
                  ),
          ),
          // Панель добавления блоков (только в режиме редактирования)
          if (_isEditing)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, -2))],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildAddButton(Icons.text_fields, 'Текст', () => _addBlock('text')),
                  _buildAddButton(Icons.code, 'Код', () => _addBlock('code')),
                  _buildAddButton(Icons.image, 'Картинка', _pickImageBlock),
                ],
              ),
            )
        ],
      ),
    );
  }

  Widget _buildAddButton(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFFFFA726)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFFE65100))),
          ],
        ),
      ),
    );
  }

  Widget _buildBlockWidget(Block block, int index) {
    return Stack(
      children: [
        // Сам блок
          if (block.type == 'text')
          Padding(
            padding: EdgeInsets.only(right: _isEditing ? 90 : 0),
            child: _isEditing
                ? TextField(
                    controller: TextEditingController(text: block.content),
                    maxLines: null,
                    onChanged: (val) {
                      block.content = val;
                      block.plainText = val; // Для поиска сохраняем чистый текст
                    },
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Введите текст (поддерживается Markdown: **жирный**, _курсив_)',
                    ),
                  )
                : MarkdownBody(
                    data: block.content.isEmpty ? '*Пустой текстовый блок*' : block.content,
                    softLineBreak: true,
                    styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                      p: const TextStyle(fontSize: 16, height: 1.4),
                    ),
                  ),
          )
                  else if (block.type == 'code')
          // Добавляем Stack для возможности разместить кнопку поверх кода
          Stack(
            children: [
              Padding(
                padding: EdgeInsets.only(right: _isEditing ? 90 : 0),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 3),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF353535), // Темный фон
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TextField(
                    controller: TextEditingController(text: block.content),
                    readOnly: !_isEditing,
                    maxLines: null,
                    style: const TextStyle(color: Color(0xFF7CD17C), fontFamily: 'RobotoMono', fontSize: 14),
                    onChanged: (val) => block.content = val,
                    decoration: const InputDecoration(border: InputBorder.none, hintText: 'Код...', hintStyle: TextStyle(color: Colors.grey)),
                  ),
                ),
              ),
              // Кнопка копирования (показывается всегда)
              Positioned(
                top: 4,
                right: 4,
                child: IconButton(
                  icon: const Icon(Icons.copy, color: Colors.white54, size: 18),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: block.content));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Код скопирован в буфер обмена'), 
                        duration: Duration(seconds: 1),
                        backgroundColor: Color(0xFFFFA726),
                      ),
                    );
                  },
                ),
              ),
            ],
          )
        else if (block.type == 'image')
          GestureDetector(
            onTap: () => _viewImage(block.content),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(block.content),
                  errorBuilder: (c, e, s) => Container(height: 100, color: Colors.grey[300], child: const Icon(Icons.broken_image)),
                ),
              ),
            ),
          ),

        // Кнопка удаления блока (в режиме редактирования)
                // Кнопки управления блоком (в режиме редактирования)
        if (_isEditing)
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Стрелка ВВЕРХ
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                    icon: const Icon(Icons.arrow_upward, color: Colors.white, size: 16),
                    onPressed: index > 0 ? () => _moveBlock(index, -1) : null,
                  ),
                  // Стрелка ВНИЗ
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                    icon: const Icon(Icons.arrow_downward, color: Colors.white, size: 16),
                    onPressed: index < _blocks.length - 1 ? () => _moveBlock(index, 1) : null,
                  ),
                  // Кнопка УДАЛИТЬ
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                    icon: const Icon(Icons.close, color: Colors.red, size: 16),
                    onPressed: () => _deleteBlock(index),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}