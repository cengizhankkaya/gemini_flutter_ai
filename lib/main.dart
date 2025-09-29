import 'package:flutter/material.dart';
import 'package:gemini_flutter_ai/app.dart';
import 'package:gemini_flutter_ai/di/locator.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  setupLocator();
  runApp(const MyApp());
}

