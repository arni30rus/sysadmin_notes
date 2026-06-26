import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/database_service.dart';
import 'technology_detail_screen.dart';
import '../services/import_export_service.dart';


class TechnologiesScreen extends StatefulWidget {
  final Vendor vendor;
  const TechnologiesScreen({super.key, required this.vendor});

  @override
  State<TechnologiesScreen> createState() => _TechnologiesScreenState();
}

class _TechnologiesScreenState extends State<TechnologiesScreen> {
  final DatabaseService _dbService = DatabaseService();
  final ImportExportService _exportService = ImportExportService();
  late Future<List<Technology>> _techFuture;

  @override
  void initState() {
    super.initState();
    _refreshTech();
  }

  void _refreshTech() {
    setState(() {
      _techFuture = _dbService.getTechnologies(widget.vendor.id);
    });
  }

  Future<void> _addTechnologyDialog() async {
    final titleController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Новая технология (${widget.vendor.name})'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Название (IPSec, DHCP, BGP...)'),
              validator: (value) => value == null || value.isEmpty ? 'Введите название' : null,
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final tech = Technology.create(
                    vendorId: widget.vendor.id,
                    title: titleController.text.trim(),
                  );
                  await _dbService.insertTechnology(tech);
                  if (mounted) Navigator.pop(context);
                  _refreshTech();
                }
              },
              child: const Text('Добавить'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
  title: Text(widget.vendor.name),
  actions: [
    IconButton(
      icon: const Icon(Icons.archive_outlined),
      tooltip: 'Выгрузить вендора',
      onPressed: () async {
        final success = await _exportService.exportVendor(widget.vendor);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(success ? 'Вендор выгружен' : 'Отменено')),
          );
        }
      },
    ),
  ],
),
       floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Технология'),
        onPressed: _addTechnologyDialog,
      ),

      body: FutureBuilder<List<Technology>>(
        future: _techFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Нет технологий. Добавьте первую.'));
          }

          final techs = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: techs.length,
                        itemBuilder: (context, index) {
              final tech = techs[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 4),
                child: ListTile(
                  title: Text(tech.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                    trailing: PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Colors.grey),
                      onSelected: (value) async {
                        if (value == 'delete') {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Удаление'),
                              content: Text('Удалить технологию "${tech.title}"?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Нет')),
                                TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Да')),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await _dbService.deleteTechnology(tech.id);
                            _refreshTech();
                          }
                        } else if (value == 'rename') {
                          // ... код переименования (остается без изменений)
                          final titleController = TextEditingController(text: tech.title);
                          final formKey = GlobalKey<FormState>();
                          await showDialog<void>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Переименовать технологию'),
                              content: Form(
                                key: formKey,
                                child: TextFormField(
                                  controller: titleController,
                                  decoration: const InputDecoration(labelText: 'Новое название'),
                                  validator: (v) => v == null || v.isEmpty ? 'Введите название' : null,
                                ),
                              ),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
                                ElevatedButton(
                                  onPressed: () async {
                                    if (formKey.currentState!.validate()) {
                                      final updatedTech = Technology(
                                        id: tech.id,
                                        vendorId: tech.vendorId,
                                        title: titleController.text.trim(),
                                        description: '',
                                        example: '',
                                        createdAt: tech.createdAt,
                                        updatedAt: DateTime.now(),
                                      );
                                      await _dbService.updateTechnology(updatedTech);
                                      if (mounted) Navigator.pop(context);
                                      _refreshTech();
                                    }
                                  },
                                  child: const Text('Сохранить'),
                                ),
                              ],
                            ),
                          );
                        } else if (value == 'move') {
                          // ЛОГИКА ПЕРЕНОСА
                          final allVendors = await _dbService.getVendors();
                          // Убираем текущего вендора из списка
                          allVendors.removeWhere((v) => v.id == widget.vendor.id);
                          
                          if (allVendors.isEmpty) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Нет других вендоров для переноса.')),
                              );
                            }
                            return;
                          }

                          String? selectedVendorId = allVendors.first.id;

                          if (!mounted) return;
                          await showDialog<void>(
                            context: context,
                            builder: (context) => StatefulBuilder(
                              builder: (context, setState) => AlertDialog(
                                title: const Text('Перенести технологию'),
                                content: DropdownButton<String>(
                                  value: selectedVendorId,
                                  isExpanded: true,
                                  items: allVendors.map((v) => DropdownMenuItem(value: v.id, child: Text(v.name))).toList(),
                                  onChanged: (val) => setState(() => selectedVendorId = val),
                                ),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
                                  ElevatedButton(
                                    onPressed: () async {
                                      if (selectedVendorId != null) {
                                        await _dbService.moveTechnology(tech.id, selectedVendorId!);
                                        if (mounted) Navigator.pop(context);
                                        _refreshTech();
                                      }
                                    },
                                    child: const Text('Перенести'),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 'rename', child: Text('Переименовать')),
                        const PopupMenuItem(value: 'move', child: Text('Перенести к другому вендору')),
                        const PopupMenuItem(value: 'delete', child: Text('Удалить', style: TextStyle(color: Colors.red))),
                      ],
                    ),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => TechnologyDetailScreen(technology: tech))).then((_) => _refreshTech());
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}