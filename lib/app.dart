import 'package:flutter/material.dart';
import 'package:gemini_flutter_ai/presentation/story_creator/story_creator_page.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Anime Hikaye Oluşturucu',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const StoryCreatorPage(),
    );
  }
}
