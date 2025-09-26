import 'package:http/http.dart' as http;

class RemoteConfigService {
  static const String envKeyUrl = String.fromEnvironment('GEMINI_KEY_URL');

  const RemoteConfigService();

  Future<String?> fetchApiKeyFromUrl() async {
    if (envKeyUrl.isEmpty) return null;
    final Uri uri = Uri.parse(envKeyUrl);
    final http.Response resp = await http.get(uri);
    if (resp.statusCode == 200) {
      final String body = resp.body.trim();
      if (body.isNotEmpty) return body;
    }
    return null;
  }
}


