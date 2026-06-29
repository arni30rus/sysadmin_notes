import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class MarkdownHelpScreen extends StatelessWidget {
  const MarkdownHelpScreen({super.key});

  final String markdownData = """
# Краткая справка по Markdown

Вы можете использовать разметку Markdown прямо в текстовых блоках. При выходе из режима редактирования текст автоматически станет красивым.

### Основное форматирование
- **Жирный текст:** `**текст**` -> **текст**
- *Курсив:* `*текст*` или `_текст_` -> *текст*
- ~~Зачеркнутый:~~ `~~текст~~` -> ~~текст~~

### Заголовки
`# Заголовок 1`
`## Заголовок 2`
`### Заголовок 3`

### Списки
Маркированный список:
`- Пункт 1`
`- Пункт 2`

Нумерованный список:
`1. Пункт 1`
`2. Пункт 2`

### Цитаты и код
> Это блок цитаты. Начинается с символа `>`.

`Строка кода` выделяется обратными кавычками.

### Горизонтальная линия
`---`
""";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Справка по Markdown'),
      ),
      body: Markdown(
        data: markdownData,
        softLineBreak: true,
        padding: const EdgeInsets.all(16),
        styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
          codeblockDecoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}