import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/database_service.dart';
import 'technologies_screen.dart';
import 'search_screen.dart';
import '../services/import_export_service.dart';
import 'about_screen.dart';
import '../widgets/confirm_delete_dialog.dart';

class VendorsScreen extends StatefulWidget {
  const VendorsScreen({super.key});

  @override
  State<VendorsScreen> createState() => _VendorsScreenState();

}

class _VendorsScreenState extends State<VendorsScreen> {
  final DatabaseService _dbService = DatabaseService();
  final ImportExportService _exportService = ImportExportService();
  late Future<List<Vendor>> _vendorsFuture;

  @override
  void initState() {
    super.initState();
    _refreshVendors();
  }

  void _refreshVendors() {
    setState(() {
      _vendorsFuture = _dbService.getVendors();
    });
  }

  Future<void> _addVendorDialog() async {
    final nameController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Новый вендор'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Название (Cisco, Huawei...)'),
              validator: (value) => value == null || value.isEmpty ? 'Введите название' : null,
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final vendor = Vendor.create(name: nameController.text.trim());
                  await _dbService.insertVendor(vendor);
                  if (mounted) Navigator.pop(context);
                  _refreshVendors();
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
        title: const Text('SysAdmin Notes', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SearchScreen()),
              );
            },
          ),
                    PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) async {
              if (value == 'backup') {
                final success = await _exportService.exportFullBackup();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(success ? 'Резервная копия сохранена' : 'Отменено')),
                );
              } else if (value == 'import') {
                final result = await _exportService.importData(context);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(result)),
                );
                _refreshVendors();
              } else if (value == 'clear') {
                // Используем наш новый виджет
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => const ConfirmDeleteDialog(
                    itemName: 'все данные',
                  ),
                );
                if (confirm == true) {
                  await _dbService.clearDatabase();
                  _refreshVendors();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('База данных очищена')),
                  );
                }
              } else if (value == 'about') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AboutScreen()),
                );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'backup', child: Text('Резервная копия / Выгрузить всё')),
              const PopupMenuItem(value: 'import', child: Text('Загрузить данные (Импорт)')),
              const PopupMenuItem(
                value: 'clear',
                child: Text('Очистить базу данных', style: TextStyle(color: Colors.red)),
              ),
              const PopupMenuItem(value: 'about', child: Text('О приложении')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Вендор'),
        onPressed: _addVendorDialog,
      ),
      body: FutureBuilder<List<Vendor>>(
        future: _vendorsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('База пуста. Добавьте первый вендор.'));
          }

          final vendors = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: vendors.length,
            itemBuilder: (context, index) {
              final vendor = vendors[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 4),
                child: ListTile(
                  title: Text(vendor.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  trailing: PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Colors.grey),
                    onSelected: (value) async {
                      if (value == 'delete') {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Удаление'),
                            content: Text('Удалить вендора "${vendor.name}" и все его команды?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Нет')),
                              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Да')),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await _dbService.deleteVendor(vendor.id);
                          _refreshVendors();
                        }
                      } else if (value == 'rename') {
                        final nameController = TextEditingController(text: vendor.name);
                        final formKey = GlobalKey<FormState>();
                        
                        await showDialog<void>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Переименовать вендора'),
                            content: Form(
                              key: formKey,
                              child: TextFormField(
                                controller: nameController,
                                decoration: const InputDecoration(labelText: 'Новое название'),
                                validator: (v) => v == null || v.isEmpty ? 'Введите название' : null,
                              ),
                            ),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
                              ElevatedButton(
                                onPressed: () async {
                                  if (formKey.currentState!.validate()) {
                                    final updatedVendor = Vendor(
                                      id: vendor.id,
                                      name: nameController.text.trim(),
                                      createdAt: vendor.createdAt,
                                    );
                                    await _dbService.updateVendor(updatedVendor);
                                    if (mounted) Navigator.pop(context);
                                    _refreshVendors();
                                  }
                                },
                                child: const Text('Сохранить'),
                              ),
                            ],
                          ),
                        );
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'rename', child: Text('Переименовать')),
                      const PopupMenuItem(value: 'delete', child: Text('Удалить', style: TextStyle(color: Colors.red))),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TechnologiesScreen(vendor: vendor),
                      ),
                    ).then((_) => _refreshVendors());
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