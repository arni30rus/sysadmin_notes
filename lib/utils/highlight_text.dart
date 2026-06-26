import 'package:flutter/material.dart';

class HighlightedText extends StatelessWidget {
  final String text;
  final String searchQuery;
  final TextStyle? baseStyle;
  final TextStyle? highlightStyle;

  const HighlightedText({
    super.key,
    required this.text,
    required this.searchQuery,
    this.baseStyle,
    this.highlightStyle,
  });

  @override
  Widget build(BuildContext context) {
    if (searchQuery.isEmpty) {
      return Text(text, style: baseStyle);
    }

    final List<TextSpan> spans = [];
    final String lowerText = text.toLowerCase();
    final String lowerQuery = searchQuery.toLowerCase();

    int start = 0;
    int indexOfMatch;

    while ((indexOfMatch = lowerText.indexOf(lowerQuery, start)) != -1) {
      if (indexOfMatch > start) {
        spans.add(TextSpan(text: text.substring(start, indexOfMatch), style: baseStyle));
      }
        spans.add(TextSpan(
        text: text.substring(indexOfMatch, indexOfMatch + lowerQuery.length),
        // Ярко-желтый фон, черный жирный шрифт
        style: highlightStyle ?? const TextStyle(backgroundColor: Color(0xFFFFEB3B), color: Colors.black, fontWeight: FontWeight.bold),
      ));
      start = indexOfMatch + lowerQuery.length;
    }

    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start), style: baseStyle));
    }

    return RichText(
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(children: spans, style: baseStyle),
    );
  }

  // Вспомогательный метод для обрезки текста вокруг совпадения (сниппет)
  static String getSnippet(String text, String query, {int padding = 60}) {
    if (query.isEmpty) return text;
    final lowerText = text.toLowerCase();
    final index = lowerText.indexOf(query.toLowerCase());
    
    if (index == -1) return text.length > 100 ? '${text.substring(0, 100)}...' : text;
    
    int start = (index - padding).clamp(0, text.length);
    int end = (index + query.length + padding).clamp(0, text.length);
    
    String snippet = text.substring(start, end);
    if (start > 0) snippet = '...$snippet';
    if (end < text.length) snippet = '$snippet...';
    
    return snippet;
  }
}