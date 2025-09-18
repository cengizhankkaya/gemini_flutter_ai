import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gemini Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const GeminiPage(title: 'Gemini Demo'),
    );
  }
}

class GeminiPage extends StatefulWidget {
  const GeminiPage({super.key, required this.title});

  final String title;

  @override
  State<GeminiPage> createState() => _GeminiPageState();
}

class _MyHomeKeyStorage {
  static const String storageKey = 'gemini_api_key';
  final FlutterSecureStorage storage = const FlutterSecureStorage();

  Future<String?> readKey() => storage.read(key: storageKey);
  Future<void> writeKey(String value) => storage.write(key: storageKey, value: value);
  Future<void> deleteKey() => storage.delete(key: storageKey);
}

class _MyHomeRemoteConfig {
  static const String envKeyUrl = String.fromEnvironment('GEMINI_KEY_URL');

  static Future<String?> fetchKeyFromUrl() async {
    if (envKeyUrl.isEmpty) return null;
    final uri = Uri.parse(envKeyUrl);
    final resp = await http.get(uri);
    if (resp.statusCode == 200) {
      final body = resp.body.trim();
      if (body.isNotEmpty) return body;
    }
    return null;
  }
}

class _GeminiPageState extends State<GeminiPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final _storage = _MyHomeKeyStorage();

  String? _responseText;
  bool _isLoading = false;
  String? _error;

  // Derleme zamanı ortam değişkenleri (opsiyonel):
  // flutter run --dart-define=GEMINI_API_KEY=... [--dart-define=GEMINI_KEY_URL=https://...]
  static const String _envApiKey = String.fromEnvironment('AIzaSyANxj_oAuwxz9I2pEuFRVPTmypJhSnUYk8');

  String? _apiKey; // Çalışma zamanında kullanılacak anahtar
  bool _keyLoaded = false;

  @override
  void initState() {
    super.initState();
    _initApiKey();
  }

  Future<void> _initApiKey() async {
    try {
      // 1) Öncelik: Secure Storage
      String? key = await _storage.readKey();

      // 2) Yoksa: Derleme zamanı GEMINI_API_KEY
      if (key == null || key.isEmpty) {
        if (_envApiKey.isNotEmpty) {
          key = _envApiKey;
          await _storage.writeKey(key);
        }
      }

      // 3) Hâlâ yoksa: Opsiyonel URL'den çek
      if (key == null || key.isEmpty) {
        final remoteKey = await _MyHomeRemoteConfig.fetchKeyFromUrl();
        if (remoteKey != null && remoteKey.isNotEmpty) {
          key = remoteKey;
          await _storage.writeKey(key);
        }
      }

      setState(() {
        _apiKey = key;
        _keyLoaded = true;
      });
    } catch (e) {
      setState(() {
        _error = 'Anahtar yüklenirken hata: $e';
        _keyLoaded = true;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendPrompt() async {
    final prompt = _controller.text.trim();
    if (prompt.isEmpty) return;

    if ((_apiKey ?? '').isEmpty) {
      setState(() {
        _error = 'API anahtarı bulunamadı. Lütfen anahtar girin.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _responseText = null;
    });

    try {
      final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: _apiKey!);
      final content = [
        Content.text(prompt),
      ];
      final response = await model.generateContent(content);
      final text = response.text;
      setState(() {
        _responseText = text?.trim().isEmpty == true ? '(Boş yanıt)' : text;
      });
    } catch (e) {
      setState(() {
        _error = 'Hata: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
      await Future.delayed(const Duration(milliseconds: 50));
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    }
  }

  Future<void> _promptForApiKey() async {
    final controller = TextEditingController(text: _apiKey ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('API anahtarı'),
          content: TextField(
            controller: controller,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Gemini API Key',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('İptal'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop('clear'),
              child: const Text('Sıfırla'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Kaydet'),
            ),
          ],
        );
      },
    );

    if (result == null) return; // İptal

    if (result == 'clear') {
      await _storage.deleteKey();
      setState(() {
        _apiKey = null;
      });
      return;
    }

    if (result.isNotEmpty) {
      await _storage.writeKey(result);
      setState(() {
        _apiKey = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: 'API anahtarı yönet',
            icon: const Icon(Icons.vpn_key),
            onPressed: _promptForApiKey,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (!_keyLoaded) const LinearProgressIndicator(),
            if (_keyLoaded && (_apiKey == null || _apiKey!.isEmpty))
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'API anahtarı ayarlı değil. Sağ üstten anahtar ekleyin.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            TextField(
              controller: _controller,
              textInputAction: TextInputAction.send,
              minLines: 1,
              maxLines: 6,
              decoration: InputDecoration(
                labelText: 'İstem (prompt)',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _isLoading ? null : _sendPrompt,
                ),
              ),
              onSubmitted: (_) => _isLoading ? null : _sendPrompt(),
            ),
            const SizedBox(height: 16),
            if (_isLoading) const LinearProgressIndicator(),
            if (_error != null) ...[
              Text(
                _error!,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 8),
            ],
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                child: SelectableText(
                  _responseText ?? 'Yanıt burada görünecek.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isLoading ? null : _sendPrompt,
        tooltip: 'Gönder',
        child: const Icon(Icons.send),
      ),
    );
  }
}
