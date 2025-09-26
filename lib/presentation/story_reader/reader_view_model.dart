import 'package:flutter/foundation.dart';
import 'package:gemini_flutter_ai/data/models/story_models.dart';

class ReaderViewModel extends ChangeNotifier {
  final GeneratedStory story;
  late final List<Chapter> chapters;
  int currentPage = 0;
  double fontSize = 18;

  ReaderViewModel({required this.story}) {
    chapters = _parseChapters(story.content);
  }

  void setPage(int index) {
    currentPage = index;
    notifyListeners();
  }

  void increaseFont() {
    fontSize = (fontSize + 2).clamp(14, 28);
    notifyListeners();
  }

  void decreaseFont() {
    fontSize = (fontSize - 2).clamp(14, 28);
    notifyListeners();
  }

  List<Chapter> _parseChapters(String content) {
    final List<String> lines = content.split('\n');
    final RegExp heading = RegExp(r'^Bölüm\s+\d+\s+—');

    final List<Chapter> list = <Chapter>[];
    String? currentTitle;
    final StringBuffer buffer = StringBuffer();

    void push() {
      final String? title = currentTitle;
      if (title != null) {
        list.add(Chapter(title: title, content: buffer.toString().trim()));
      }
      buffer.clear();
    }

    for (final String line in lines) {
      if (heading.hasMatch(line.trim())) {
        push();
        currentTitle = line.trim();
      } else {
        buffer.writeln(line);
      }
    }

    if (currentTitle == null) {
      return <Chapter>[Chapter(title: story.title, content: content.trim())];
    }
    push();
    return list;
  }
}

class Chapter {
  final String title;
  final String content;

  const Chapter({required this.title, required this.content});
}


