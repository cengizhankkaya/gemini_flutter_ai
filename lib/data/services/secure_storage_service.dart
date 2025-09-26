import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static const String defaultKey = 'gemini_api_key';
  final FlutterSecureStorage storage;

  const SecureStorageService({this.storage = const FlutterSecureStorage()});

  Future<String?> readApiKey({String key = defaultKey}) => storage.read(key: key);
  Future<void> writeApiKey(String value, {String key = defaultKey}) => storage.write(key: key, value: value);
  Future<void> deleteApiKey({String key = defaultKey}) => storage.delete(key: key);
}


