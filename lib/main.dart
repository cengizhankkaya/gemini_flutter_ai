import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:math';
import 'package:intl/intl.dart';

// Chat mesaj modeli
class ChatMessage {
  final String content;
  final bool isUser;
  final DateTime timestamp;
  final bool isLoading;

  ChatMessage({
    required this.content,
    required this.isUser,
    required this.timestamp,
    this.isLoading = false,
  });
}

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

  List<ChatMessage> _messages = [];
  bool _isLoading = false;
  int _retryAttempt = 0;

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
        _keyLoaded = true;
      });
      // Hata mesajını chat'e ekle
      final errorMessage = ChatMessage(
        content: 'Anahtar yüklenirken hata: $e',
        isUser: false,
        timestamp: DateTime.now(),
      );
      setState(() {
        _messages.add(errorMessage);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // 503 ve benzeri geçici hatalar için yeniden deneme fonksiyonu
  Future<T> _retryWithBackoff<T>(
    Future<T> Function() action, {
    int maxAttempts = 5,
    Duration baseDelay = const Duration(milliseconds: 400),
  }) async {
    final rand = Random.secure();
    int attempt = 0;

    while (true) {
      try {
        return await action();
      } catch (e) {
        attempt++;

        // 503, UNAVAILABLE ve benzeri geçici hataları kontrol et
        final errorString = e.toString().toLowerCase();
        final isTransient = errorString.contains('503') ||
            errorString.contains('unavailable') ||
            errorString.contains('overloaded') ||
            errorString.contains('rate limit') ||
            errorString.contains('timeout') ||
            errorString.contains('service temporarily unavailable');

        if (!isTransient || attempt >= maxAttempts) {
          throw e;
        }

        // Exponential backoff + jitter
        final jitterMs = rand.nextInt(250);
        final delay = baseDelay * pow(2, attempt) + Duration(milliseconds: jitterMs);
        
        // UI'da yeniden deneme bilgisini göster
        if (mounted) {
          setState(() {
            _retryAttempt = attempt;
          });
        }

        await Future.delayed(delay);
      }
    }
  }

  Future<void> _sendPrompt() async {
    final prompt = _controller.text.trim();
    if (prompt.isEmpty) return;

    if ((_apiKey ?? '').isEmpty) {
      // API anahtarı hatası için hata mesajı ekle
      final errorMessage = ChatMessage(
        content: 'API anahtarı bulunamadı. Lütfen anahtar girin.',
        isUser: false,
        timestamp: DateTime.now(),
      );
      setState(() {
        _messages.add(errorMessage);
      });
      return;
    }

    // Kullanıcı mesajını ekle
    final userMessage = ChatMessage(
      content: prompt,
      isUser: true,
      timestamp: DateTime.now(),
    );

    // Loading mesajını ekle
    final loadingMessage = ChatMessage(
      content: '',
      isUser: false,
      timestamp: DateTime.now(),
      isLoading: true,
    );

    setState(() {
      _messages.add(userMessage);
      _messages.add(loadingMessage);
      _isLoading = true;
      _retryAttempt = 0;
    });

    _controller.clear();
    _scrollToBottom();

    try {
      final response = await _retryWithBackoff(() async {
        final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: _apiKey!);
        final content = [
          Content.text(prompt),
        ];
        return await model.generateContent(content);
      });

      final text = response.text;
      
      setState(() {
        // Loading mesajını kaldır ve gerçek yanıtı ekle
        _messages.removeLast(); // Loading mesajını kaldır
        final aiMessage = ChatMessage(
          content: text?.trim().isEmpty == true ? '(Boş yanıt)' : text!,
          isUser: false,
          timestamp: DateTime.now(),
        );
        _messages.add(aiMessage);
      });
    } catch (e) {
      String errorMessage = 'Hata: $e';
      
      // Hata tipine göre daha açıklayıcı mesajlar
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('503')) {
        errorMessage = 'Sunucu geçici olarak kullanılamıyor. Lütfen daha sonra tekrar deneyin.';
      } else if (errorString.contains('429')) {
        errorMessage = 'Çok fazla istek gönderildi. Lütfen biraz bekleyip tekrar deneyin.';
      } else if (errorString.contains('401') || errorString.contains('403')) {
        errorMessage = 'API anahtarı geçersiz. Lütfen anahtarınızı kontrol edin.';
      } else if (errorString.contains('network') || errorString.contains('connection')) {
        errorMessage = 'İnternet bağlantısı sorunu. Bağlantınızı kontrol edin.';
      }
      
      setState(() {
        // Loading mesajını kaldır ve hata mesajını ekle
        _messages.removeLast(); // Loading mesajını kaldır
        final errorChatMessage = ChatMessage(
          content: errorMessage,
          isUser: false,
          timestamp: DateTime.now(),
        );
        _messages.add(errorChatMessage);
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      child: Row(
        mainAxisAlignment: message.isUser 
            ? MainAxisAlignment.end 
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.blue.shade100,
              child: Icon(
                Icons.smart_toy,
                size: 18,
                color: Colors.blue.shade700,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: message.isUser 
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(message.isUser ? 18 : 4),
                  bottomRight: Radius.circular(message.isUser ? 4 : 18),
                ),
                border: message.isUser 
                    ? null 
                    : Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.isLoading)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.grey.shade600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Yanıt yazılıyor...',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    )
                  else
                    SelectableText(
                      message.content,
                      style: TextStyle(
                        color: message.isUser 
                            ? Colors.white 
                            : Colors.black87,
                        fontSize: 16,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('HH:mm').format(message.timestamp),
                    style: TextStyle(
                      color: message.isUser 
                          ? Colors.white70 
                          : Colors.grey.shade600,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (message.isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: Theme.of(context).colorScheme.secondary,
              child: Icon(
                Icons.person,
                size: 18,
                color: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
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
      body: Column(
        children: [
          // API anahtarı uyarısı
          if (!_keyLoaded) const LinearProgressIndicator(),
          if (_keyLoaded && (_apiKey == null || _apiKey!.isEmpty))
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
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
          
          // Yeniden deneme bilgisi
          if (_retryAttempt > 0)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.refresh, size: 16, color: Colors.blue),
                  const SizedBox(width: 8),
                  Text(
                    'Yeniden deneme: $_retryAttempt',
                    style: const TextStyle(color: Colors.blue, fontSize: 12),
                  ),
                ],
              ),
            ),

          // Chat mesajları
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Gemini ile sohbet etmeye başlayın!',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Aşağıdan bir mesaj yazın ve gönder butonuna basın.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(top: 8, bottom: 8),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      return _buildMessageBubble(_messages[index]);
                    },
                  ),
          ),

          // Input alanı
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                top: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.send,
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Mesajınızı yazın...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                      ),
                      onSubmitted: (_) => _isLoading ? null : _sendPrompt(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: _isLoading 
                        ? Colors.grey.shade300 
                        : Theme.of(context).colorScheme.primary,
                    child: IconButton(
                      icon: _isLoading
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.grey.shade600,
                                ),
                              ),
                            )
                          : const Icon(Icons.send, color: Colors.white),
                      onPressed: _isLoading ? null : _sendPrompt,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
