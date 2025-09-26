import 'package:gemini_flutter_ai/data/services/secure_storage_service.dart';
import 'package:gemini_flutter_ai/data/services/remote_config_service.dart';

class ApiKeyRepository {
  static const String _envApiKey = String.fromEnvironment('GEMINI_API_KEY');

  final SecureStorageService storageService;
  final RemoteConfigService remoteConfigService;

  const ApiKeyRepository({
    required this.storageService,
    required this.remoteConfigService,
  });

  String _sanitize(String? raw) {
    if (raw == null) return '';
    // Trim kenarlar, satır sonlarını ve kontrol karakterlerini temizle
    String k = raw.trim();
    // Çift/tek tırnak ve backtick karakterlerini at
    k = k.replaceAll('"', '').replaceAll('\'', '').replaceAll('`', '');
    // Tüm whitespace (\s) karakterlerini kaldır (boşluk, \n, \r, \t)
    k = k.replaceAll(RegExp(r"\s+"), '');
    return k;
  }

  Future<String?> loadApiKey() async {
    // 1) Secure storage
    String key = _sanitize(await storageService.readApiKey());

    // 2) Derleme zamanı
    if (key.isEmpty) {
      if (_envApiKey.isNotEmpty) {
        key = _sanitize(_envApiKey);
        await storageService.writeApiKey(key);
      }
    }

    // 3) Remote URL
    if (key.isEmpty) {
      final String remote = _sanitize(await remoteConfigService.fetchApiKeyFromUrl());
      if (remote.isNotEmpty) {
        key = remote;
        await storageService.writeApiKey(key);
      }
    }

    return key.isEmpty ? null : key;
  }

  Future<void> saveApiKey(String key) => storageService.writeApiKey(_sanitize(key));
  Future<void> clearApiKey() => storageService.deleteApiKey();
}


