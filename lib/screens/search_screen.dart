import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../utils/highlight_text.dart';
import 'technologies_screen.dart';
import '../models/models.dart';
import 'technology_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final DatabaseService _dbService = DatabaseService();
  final TextEditingController _searchController = TextEditingController();
  
  List<SearchResult> _results = [];
  bool _isSearching = false;

  void _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _results = [];
        _isSearching = false;
      });
      return;
    }
    
    setState(() => _isSearching = true);
    final results = await _dbService.searchAll(query);
    setState(() {
      _results = results;
      _isSearching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _searchController,
          autofocus: true,
          textInputAction: TextInputAction.search,
          style: const TextStyle(fontSize: 18),
          decoration: const InputDecoration(
            hintText: 'Поиск по базе...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.grey),
          ),
          onChanged: _performSearch,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              _searchController.clear();
              _performSearch('');
            },
          ),
        ],
      ),
      body: _isSearching
          ? const Center(child: CircularProgressIndicator())
          : _results.isEmpty
              ? Center(
                  child: Text(
                    _searchController.text.isEmpty ? 'Начните вводить текст' : 'Ничего не найдено',
                    style: const TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: _results.length,
                  itemBuilder: (context, index) {
                    final res = _results[index];
                    IconData icon;
                    String subtitlePrefix;

                    if (res.type == 'vendor') {
                      icon = Icons.domain;
                      subtitlePrefix = 'Вендор';
                    } else if (res.type == 'tech_title') {
                      icon = Icons.settings_ethernet;
                      subtitlePrefix = 'Технология';
                    } else {
                      icon = Icons.description;
                      subtitlePrefix = 'Описание';
                    }

                    // Обрезаем текст описания, если он слишком длинный
                    String displayText = res.type == 'tech_desc'
                        ? HighlightedText.getSnippet(res.matchedText, _searchController.text)
                        : res.matchedText;

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: ListTile(
                        leading: Icon(icon, color: const Color(0xFF4A90E2)),
                        title: HighlightedText(
                          text: displayText,
                          searchQuery: _searchController.text,
                          baseStyle: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w500),
                        ),
                        // Явно указываем серый цвет для подзаголовка
                        subtitle: Text(
                          '$subtitlePrefix • ${res.vendorName}${res.technologyTitle != null ? ' • ${res.technologyTitle}' : ''}',
                          style: const TextStyle(color: Colors.grey),
                        ),
                        onTap: () {
                          if (res.type == 'vendor') {
                            // Переход к технологиям вендора
                            Navigator.push(context, MaterialPageRoute(
                              builder: (_) => TechnologiesScreen(
                                vendor: Vendor(id: res.vendorId, name: res.vendorName, createdAt: DateTime.now()),
                              ),
                            ));
                          } else {
                            // Переход к карточке технологии
                            Navigator.push(context, MaterialPageRoute(
                              builder: (_) => TechnologyDetailScreen(
                                technology: Technology(
                                  id: res.technologyId!,
                                  vendorId: res.vendorId,
                                  title: res.technologyTitle!,
                                  description: '', // Будет загружено из БД на экране деталий
                                  example: '',
                                  createdAt: DateTime.now(),
                                  updatedAt: DateTime.now(),
                                ),
                              ),
                            ));
                          }
                        },
                      ),
                    );
                  },
                ),
    );
  }
}