import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:math';
import 'package:intl/intl.dart';
import 'dart:developer' as developer;

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

// Hikaye bileşenleri modelleri
class StoryCharacter {
  final String name;
  final String description;
  final String personality;
  final String background;

  StoryCharacter({
    required this.name,
    required this.description,
    required this.personality,
    required this.background,
  });
}

class StorySetting {
  final String location;
  final String time;
  final String atmosphere;
  final String description;

  StorySetting({
    required this.location,
    required this.time,
    required this.atmosphere,
    required this.description,
  });
}

class StoryEvent {
  final String title;
  final String description;
  final String conflict;
  final String resolution;

  StoryEvent({
    required this.title,
    required this.description,
    required this.conflict,
    required this.resolution,
  });
}

class GeneratedStory {
  final String title;
  final String content;
  final StoryCharacter character;
  final StorySetting setting;
  final StoryEvent event;
  final DateTime createdAt;

  GeneratedStory({
    required this.title,
    required this.content,
    required this.character,
    required this.setting,
    required this.event,
    required this.createdAt,
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
      title: 'Anime Hikaye Oluşturucu',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const StoryCreatorPage(),
    );
  }
}

class StoryCreatorPage extends StatefulWidget {
  const StoryCreatorPage({super.key});

  @override
  State<StoryCreatorPage> createState() => _StoryCreatorPageState();
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

class _StoryCreatorPageState extends State<StoryCreatorPage> {
  final _storage = _MyHomeKeyStorage();

  // Hikaye bileşenleri
  StoryCharacter? _selectedCharacter;
  StorySetting? _selectedSetting;
  StoryEvent? _selectedEvent;
  
  // UI durumu
  bool _isGenerating = false;
  int _retryAttempt = 0;
  GeneratedStory? _generatedStory;
  final List<GeneratedStory> _savedStories = [];

  // Derleme zamanı ortam değişkenleri (opsiyonel):
  // flutter run --dart-define=GEMINI_API_KEY=... [--dart-define=GEMINI_KEY_URL=https://...]
  static const String _envApiKey = String.fromEnvironment('GEMINI_API_KEY');

  String? _apiKey; // Çalışma zamanında kullanılacak anahtar
  bool _keyLoaded = false;

  @override
  void initState() {
    super.initState();
    _initApiKey();
  }

  Future<void> _initApiKey() async {
    try {
      developer.log('API anahtarı yükleniyor...');
      
      // 1) Öncelik: Secure Storage
      String? key = await _storage.readKey();
      developer.log('Secure Storage\'dan anahtar: ${key != null ? "Mevcut (${key.length} karakter)" : "Bulunamadı"}');

      // 2) Yoksa: Derleme zamanı GEMINI_API_KEY
      if (key == null || key.isEmpty) {
        if (_envApiKey.isNotEmpty) {
          key = _envApiKey;
          await _storage.writeKey(key);
          developer.log('Derleme zamanı anahtarı kullanıldı: ${key.length} karakter');
        }
      }

      // 3) Hâlâ yoksa: Opsiyonel URL'den çek
      if (key == null || key.isEmpty) {
        final remoteKey = await _MyHomeRemoteConfig.fetchKeyFromUrl();
        if (remoteKey != null && remoteKey.isNotEmpty) {
          key = remoteKey;
          await _storage.writeKey(key);
          developer.log('Uzaktan anahtar alındı: ${key.length} karakter');
        }
      }

      setState(() {
        _apiKey = key;
        _keyLoaded = true;
      });
      
      developer.log('API anahtarı yükleme tamamlandı: ${key != null ? "Başarılı" : "Başarısız"}');
    } catch (e) {
      developer.log('API anahtarı yükleme hatası: $e');
      setState(() {
        _keyLoaded = true;
      });
      // Hata mesajını göster
      _showSnackBar('Anahtar yüklenirken hata: $e');
    }
  }

  @override
  void dispose() {
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
          rethrow;
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

  // Hikaye oluşturma fonksiyonu
  Future<void> _generateStory() async {
    if (_selectedCharacter == null || _selectedSetting == null || _selectedEvent == null) {
      _showSnackBar('Lütfen tüm hikaye bileşenlerini seçin!');
      return;
    }

    if ((_apiKey ?? '').isEmpty) {
      _showSnackBar('API anahtarı bulunamadı. Lütfen anahtar girin.');
      return;
    }

    setState(() {
      _isGenerating = true;
      _retryAttempt = 0;
    });

    try {
      developer.log('Hikaye oluşturma başlıyor...');
      developer.log('Seçili karakter: ${_selectedCharacter!.name}');
      developer.log('Seçili mekan: ${_selectedSetting!.location}');
      developer.log('Seçili olay: ${_selectedEvent!.title}');
      
      final storyContent = await _retryWithBackoff(() async {
        developer.log('Gemini API\'ye istek gönderiliyor...');
        final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: _apiKey!);
        
        final prompt = '''
Aşağıdaki bileşenleri kullanarak ANIME/MANGA tarzında, BÖLÜM BÖLÜM ve kitap gibi uzun bir hikaye yaz.

KARAKTER:
- İsim: ${_selectedCharacter!.name}
- Açıklama: ${_selectedCharacter!.description}
- Kişilik: ${_selectedCharacter!.personality}
- Geçmiş: ${_selectedCharacter!.background}

MEKAN VE ZAMAN:
- Konum: ${_selectedSetting!.location}
- Zaman: ${_selectedSetting!.time}
- Atmosfer: ${_selectedSetting!.atmosphere}
- Açıklama: ${_selectedSetting!.description}

OLAY:
- Başlık: ${_selectedEvent!.title}
- Açıklama: ${_selectedEvent!.description}
- Çatışma: ${_selectedEvent!.conflict}
- Çözüm: ${_selectedEvent!.resolution}

Format ve uzunluk kuralları (zorunlu):
- En az 10 bölüm, tercihen 12-15 bölüm yaz.
- Her bölüm 5-8 paragraf ve yaklaşık 600-1000 kelime olsun.
- Her bölüm başlığı şu biçimde olsun: "Bölüm N — Kısa Başlık" (N: 1,2,3...).
- Bölümler arası süreklilik ve karakter gelişimi korunsun.
- Bölüm sonları, final hariç, hafif bir cliffhanger ile bitsin.
- Son bölümde ana çatışma tatmin edici şekilde çözülsün ve kısa bir epilog ekle.
- Her bölümde detaylı diyaloglar, karakter monologları ve aksiyon sahneleri olsun.

Anlatım yönergeleri:
- Animeye özgü duygusal ve ifadeli diyaloglar kullan.
- Güç seviyeleri, büyüler veya ileri teknoloji gibi anime öğelerini dahil et (temaya uygun).
- Aksiyon sahnelerini dinamik, duygusal sahneleri içsel monologlarla betimle.
- Her bölümde karakter gelişimi ve hikaye ilerlemesi olsun.
- Yan karakterler ekleyerek hikayeyi zenginleştir.
- Detaylı çevre betimlemeleri ve atmosfer yarat.
- Karakterlerin duygusal yolculuklarını derinlemesine işle.
- Her bölümde yeni bir olay veya keşif ekle.
- Uzun diyaloglar ve karakter etkileşimleri kullan.

Sadece hikayeyi üret. Ek açıklama veya madde imleri ekleme. Markdown kullanma.
''';

        final content = [Content.text(prompt)];
        final response = await model.generateContent(content);
        developer.log('API yanıtı alındı: ${response.text?.length ?? 0} karakter');
        return response;
      });

      final story = GeneratedStory(
        title: '${_selectedCharacter!.name} - ${_selectedEvent!.title}',
        content: storyContent.text ?? 'Hikaye oluşturulamadı.',
        character: _selectedCharacter!,
        setting: _selectedSetting!,
        event: _selectedEvent!,
        createdAt: DateTime.now(),
      );

      developer.log('Hikaye başarıyla oluşturuldu: ${story.title}');
      developer.log('Hikaye içeriği: ${story.content.length} karakter');

      setState(() {
        _generatedStory = story;
      });
    } catch (e) {
      String errorMessage = 'Hata: $e';
      
      // Debug bilgisi için konsola yazdır
      developer.log('Hikaye oluşturma hatası: $e');
      developer.log('API Key durumu: ${_apiKey != null ? "Mevcut (${_apiKey!.length} karakter)" : "Bulunamadı"}');
      
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('503')) {
        errorMessage = 'Sunucu geçici olarak kullanılamıyor. Lütfen daha sonra tekrar deneyin.';
      } else if (errorString.contains('429')) {
        errorMessage = 'Çok fazla istek gönderildi. Lütfen biraz bekleyip tekrar deneyin.';
      } else if (errorString.contains('401') || errorString.contains('403')) {
        errorMessage = 'API anahtarı geçersiz. Lütfen anahtarınızı kontrol edin.';
      } else if (errorString.contains('network') || errorString.contains('connection')) {
        errorMessage = 'İnternet bağlantısı sorunu. Bağlantınızı kontrol edin.';
      } else if (errorString.contains('timeout')) {
        errorMessage = 'İstek zaman aşımına uğradı. Lütfen tekrar deneyin.';
      } else if (errorString.contains('quota') || errorString.contains('limit')) {
        errorMessage = 'API kotası aşıldı. Lütfen daha sonra tekrar deneyin.';
      }
      
      _showSnackBar(errorMessage);
    } finally {
      setState(() {
        _isGenerating = false;
      });
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // Hikaye bileşenleri seçim widget'ları
  Widget _buildCharacterSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Karakter Seç',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_selectedCharacter == null)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildCharacterOption('Kaito', 'Genç bir ninja', 'Cesur ve sadık', 'Gizli ninja köyünden gelen yetenekli savaşçı'),
                  _buildCharacterOption('Sakura', 'Büyücü kız', 'Güçlü ve kararlı', 'Büyülü güçleri olan genç büyücü'),
                  _buildCharacterOption('Ren', 'Mek pilotu', 'Analitik ve soğukkanlı', 'Dev robotları kontrol eden pilot'),
                  _buildCharacterOption('Yuki', 'Okul kızı', 'Tatlı ve meraklı', 'Normal lise öğrencisi ama özel güçleri var'),
                  _buildCharacterOption('Hiro', 'Samuray', 'Onurlu ve güçlü', 'Eski samuray ailesinden gelen savaşçı'),
                  _buildCharacterOption('Mira', 'Kedi kız', 'Şirin ve çevik', 'Kedi özellikleri olan nekomimi karakter'),
                ],
              )
            else
              _buildSelectedComponent(
                _selectedCharacter!.name,
                '${_selectedCharacter!.description}\n${_selectedCharacter!.personality}',
                () => setState(() => _selectedCharacter = null),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCharacterOption(String name, String description, String personality, String background) {
    return InkWell(
      onTap: () {
        setState(() {
          _selectedCharacter = StoryCharacter(
            name: name,
            description: description,
            personality: personality,
            background: background,
          );
        });
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Mekan ve Zaman Seç',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_selectedSetting == null)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildSettingOption('Tokyo, 2024', 'Modern şehir', 'Neon ışıkları ve teknoloji', 'Yüksek binalar arasında gizli dünyalar'),
                  _buildSettingOption('Akademi, Günümüz', 'Büyülü okul', 'Sihirli ve gizemli', 'Büyücülerin eğitim gördüğü prestijli akademi'),
                  _buildSettingOption('Ninja Köyü, Feodal', 'Gizli köy', 'Geleneksel ve tehlikeli', 'Dağların arasında gizli ninja yerleşimi'),
                  _buildSettingOption('Uzay İstasyonu, 2150', 'Gelecek', 'Teknolojik ve soğuk', 'Yıldızlar arasında dolaşan dev uzay gemisi'),
                  _buildSettingOption('Fantastik Orman, Efsanevi', 'Büyülü orman', 'Mistik ve büyülü', 'Periler ve ejderhaların yaşadığı orman'),
                  _buildSettingOption('Lise, Günümüz', 'Normal okul', 'Sıradan görünümlü', 'Gizli güçlerin saklandığı normal lise'),
                ],
              )
            else
              _buildSelectedComponent(
                '${_selectedSetting!.location} - ${_selectedSetting!.time}',
                '${_selectedSetting!.atmosphere}\n${_selectedSetting!.description}',
                () => setState(() => _selectedSetting = null),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingOption(String locationTime, String atmosphere, String description, String detail) {
    return InkWell(
      onTap: () {
        final parts = locationTime.split(', ');
        setState(() {
          _selectedSetting = StorySetting(
            location: parts[0],
            time: parts[1],
            atmosphere: atmosphere,
            description: '$description - $detail',
          );
        });
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              locationTime,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              atmosphere,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.event, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Olay Seç',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_selectedEvent == null)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildEventOption('Güç Keşfi', 'Gizli güçler ortaya çıkar', 'Bu güçler nereden geliyor?', 'Yeni yetenekler keşfedilir'),
                  _buildEventOption('Aşk Hikayesi', 'İlk aşk yaşanır', 'Aşk gerçek mi yoksa büyü mü?', 'Kalp kırıklığı veya mutlu son'),
                  _buildEventOption('Büyük Savaş', 'Epik bir savaş başlar', 'Kim kazanacak?', 'Kahramanlık ve fedakarlık'),
                  _buildEventOption('Zaman Yolculuğu', 'Geçmişe veya geleceğe gidilir', 'Zaman çizgisi değişebilir mi?', 'Kader değişir'),
                  _buildEventOption('Mek Savaşı', 'Dev robotlar savaşır', 'Hangi mek daha güçlü?', 'Pilotluk yetenekleri test edilir'),
                  _buildEventOption('Büyülü Macera', 'Büyülü dünyada keşif', 'Hangi büyüler keşfedilecek?', 'Büyücü olma yolculuğu'),
                ],
              )
            else
              _buildSelectedComponent(
                _selectedEvent!.title,
                '${_selectedEvent!.description}\nÇatışma: ${_selectedEvent!.conflict}',
                () => setState(() => _selectedEvent = null),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventOption(String title, String description, String conflict, String resolution) {
    return InkWell(
      onTap: () {
        setState(() {
          _selectedEvent = StoryEvent(
            title: title,
            description: description,
            conflict: conflict,
            resolution: resolution,
          );
        });
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedComponent(String title, String description, VoidCallback onRemove) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.primary),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: Icon(
              Icons.close,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
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
        title: const Text('Anime Hikaye Oluşturucu'),
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

          // Ana içerik
          Expanded(
            child: _generatedStory == null
                ? SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Başlık
                        Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.auto_stories,
                                size: 64,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Anime Hikaye Oluşturucu',
                                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Anime karakterleri, mekanları ve olayları seçerek uzun ve detaylı anime hikayeleri oluşturun!',
                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: Colors.grey.shade600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Hikaye bileşenleri
                        _buildCharacterSelector(),
                        const SizedBox(height: 16),
                        _buildSettingSelector(),
                        const SizedBox(height: 16),
                        _buildEventSelector(),
                        const SizedBox(height: 24),

                        // Hikaye oluştur butonu
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isGenerating || _selectedCharacter == null || _selectedSetting == null || _selectedEvent == null
                                ? null
                                : _generateStory,
                            icon: _isGenerating
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.auto_stories),
                            label: Text(_isGenerating ? 'Uzun Hikaye Oluşturuluyor...' : 'Uzun Hikaye Oluştur'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              textStyle: const TextStyle(fontSize: 18),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : _buildStoryDisplay(),
          ),
        ],
      ),
    );
  }

  Widget _buildStoryDisplay() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hikaye başlığı
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.auto_stories, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _generatedStory!.title,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => setState(() => _generatedStory = null),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    DateFormat('dd MMMM yyyy, HH:mm').format(_generatedStory!.createdAt),
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Hikaye içeriği
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hikaye',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SelectableText(
                    _generatedStory!.content,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Hikaye bileşenleri özeti
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hikaye Bileşenleri',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildStoryComponentSummary('Karakter', _generatedStory!.character.name, _generatedStory!.character.description),
                  const SizedBox(height: 8),
                  _buildStoryComponentSummary('Mekan', _generatedStory!.setting.location, _generatedStory!.setting.atmosphere),
                  const SizedBox(height: 8),
                  _buildStoryComponentSummary('Olay', _generatedStory!.event.title, _generatedStory!.event.description),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Aksiyon butonları
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => StoryReaderPage(story: _generatedStory!),
                      ),
                    );
                  },
                  icon: const Icon(Icons.menu_book),
                  label: const Text('Kitap Gibi Oku'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _savedStories.add(_generatedStory!);
                      _generatedStory = null;
                    });
                    _showSnackBar('Hikaye kaydedildi!');
                  },
                  icon: const Icon(Icons.save),
                  label: const Text('Kaydet'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _generatedStory = null;
                    });
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Yeni Hikaye'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStoryComponentSummary(String title, String name, String description) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            name,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            description,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}

class _Chapter {
  final String title;
  final String content;

  const _Chapter({required this.title, required this.content});
}

class StoryReaderPage extends StatefulWidget {
  final GeneratedStory story;

  const StoryReaderPage({super.key, required this.story});

  @override
  State<StoryReaderPage> createState() => _StoryReaderPageState();
}

class _StoryReaderPageState extends State<StoryReaderPage> {
  late final PageController _pageController;
  late final List<_Chapter> _chapters;
  int _currentPage = 0;
  double _fontSize = 18;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _chapters = _parseChapters(widget.story.content);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  List<_Chapter> _parseChapters(String content) {
    final lines = content.split('\n');
    final RegExp heading = RegExp(r'^Bölüm\s+\d+\s+—');

    final List<_Chapter> chapters = [];
    String? currentTitle;
    final StringBuffer buffer = StringBuffer();

    void pushChapter() {
      if (currentTitle != null) {
        chapters.add(_Chapter(title: currentTitle, content: buffer.toString().trim()));
      }
      buffer.clear();
    }

    for (final line in lines) {
      if (heading.hasMatch(line.trim())) {
        pushChapter();
        currentTitle = line.trim();
      } else {
        buffer.writeln(line);
      }
    }
    // push last
    if (currentTitle == null) {
      // Başlık bulunamadıysa tek bölüm olarak ele al
      return [
        _Chapter(title: widget.story.title, content: content.trim()),
      ];
    }
    pushChapter();
    return chapters;
  }

  @override
  Widget build(BuildContext context) {
    final Color paper = const Color(0xFFF8F5E7);
    final Color ink = const Color(0xFF2B2B2B);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.story.title),
        actions: [
          IconButton(
            tooltip: 'Yazı boyutu küçült',
            onPressed: () {
              setState(() {
                _fontSize = (_fontSize - 2).clamp(14, 28);
              });
            },
            icon: const Icon(Icons.text_decrease),
          ),
          IconButton(
            tooltip: 'Yazı boyutu büyüt',
            onPressed: () {
              setState(() {
                _fontSize = (_fontSize + 2).clamp(14, 28);
              });
            },
            icon: const Icon(Icons.text_increase),
          ),
        ],
      ),
      body: Container(
        color: paper,
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              onPageChanged: (i) => setState(() => _currentPage = i),
              itemCount: _chapters.length,
              itemBuilder: (context, index) {
                final chapter = _chapters[index];
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  chapter.title,
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: ink,
                                      ),
                                ),
                                const SizedBox(height: 12),
                                Divider(color: Colors.grey.shade300, height: 24),
                                const SizedBox(height: 4),
                                Text(
                                  chapter.content,
                                  textAlign: TextAlign.justify,
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                        fontSize: _fontSize,
                                        height: 1.7,
                                        color: ink,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 12,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Bölüm ${_currentPage + 1}/${_chapters.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
