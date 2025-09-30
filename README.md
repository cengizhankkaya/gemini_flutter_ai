# 🤖 AI-Powered Anime Story Generator

Bu proje, **Google Gemini AI**'yi kullanarak anime/manga tarzında uzun ve detaylı hikayeler oluşturan bir Flutter uygulamasıdır. AI'nin yaratıcı yazım gücünü kullanarak kullanıcıların seçtiği karakter, mekan ve olay kombinasyonlarından profesyonel kalitede hikayeler üretir.

## 🧠 AI Kullanımı ve Yaklaşımım

### 🎯 AI Prompt Engineering
Bu projede AI'yi etkili kullanmak için **gelişmiş prompt engineering** teknikleri uyguladım:

#### 1. **Structured Prompt Design**
```dart
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
''';
```

#### 2. **Format ve Uzunluk Kontrolü**
AI'ye net talimatlar verdim:
- **Bölüm sayısı**: En az 10, tercihen 12-15 bölüm
- **Kelime sayısı**: Her bölüm 600-1000 kelime
- **Bölüm formatı**: "Bölüm N — Kısa Başlık" formatı
- **Süreklilik**: Bölümler arası karakter gelişimi

#### 3. **Anime-Specific Instructions**
```dart
// Animeye özgü talimatlar
'- Animeye özgü duygusal ve ifadeli diyaloglar kullan.
- Güç seviyeleri, büyüler veya ileri teknoloji gibi anime öğelerini dahil et.
- Aksiyon sahnelerini dinamik, duygusal sahneleri içsel monologlarla betimle.
- Her bölümde karakter gelişimi ve hikaye ilerlemesi olsun.';
```

### 🔄 AI Error Handling ve Retry Logic
AI API'lerinin kararsız doğasını ele almak için **akıllı hata yönetimi** sistemi geliştirdim:

#### Exponential Backoff Algorithm
```dart
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
      
      // AI API hatalarını tespit et
      final errorString = e.toString().toLowerCase();
      final isTransient = errorString.contains('503') ||
          errorString.contains('unavailable') ||
          errorString.contains('overloaded') ||
          errorString.contains('rate limit') ||
          errorString.contains('timeout');

      if (!isTransient || attempt >= maxAttempts) {
        rethrow;
      }

      // Exponential backoff + jitter
      final jitterMs = rand.nextInt(250);
      final delay = baseDelay * pow(2, attempt) + Duration(milliseconds: jitterMs);
      
      await Future.delayed(delay);
    }
  }
}
```

#### AI-Specific Error Messages
```dart
// AI API'ye özgü hata mesajları
if (errorString.contains('503')) {
  errorMessage = 'Sunucu geçici olarak kullanılamıyor. Lütfen daha sonra tekrar deneyin.';
} else if (errorString.contains('429')) {
  errorMessage = 'Çok fazla istek gönderildi. Lütfen biraz bekleyip tekrar deneyin.';
} else if (errorString.contains('quota') || errorString.contains('limit')) {
  errorMessage = 'API kotası aşıldı. Lütfen daha sonra tekrar deneyin.';
}
```

### 🔐 AI API Key Management
AI servislerinin güvenli kullanımı için **3 katmanlı anahtar yönetimi** sistemi:

#### 1. Secure Storage (Öncelik)
```dart
class _MyHomeKeyStorage {
  static const String storageKey = 'gemini_api_key';
  final FlutterSecureStorage storage = const FlutterSecureStorage();

  Future<String?> readKey() => storage.read(key: storageKey);
  Future<void> writeKey(String value) => storage.write(key: storageKey, value: value);
}
```

#### 2. Build-time Environment Variables
```dart
// Derleme zamanı ortam değişkenleri
static const String _envApiKey = String.fromEnvironment('GEMINI_API_KEY');
```

#### 3. Remote Configuration
```dart
// Uzaktan anahtar yükleme
static Future<String?> fetchKeyFromUrl() async {
  if (envKeyUrl.isEmpty) return null;
  final uri = Uri.parse(envKeyUrl);
  final resp = await http.get(uri);
  if (resp.statusCode == 200) {
    return resp.body.trim();
  }
  return null;
}
```

### 📊 AI Response Processing
AI'den gelen yanıtları işlemek için **akıllı parsing** algoritması:

#### Chapter Detection Algorithm
```dart
List<_Chapter> _parseChapters(String content) {
  final lines = content.split('\n');
  final RegExp heading = RegExp(r'^Bölüm\s+\d+\s+—');
  
  final List<_Chapter> chapters = [];
  String? currentTitle;
  final StringBuffer buffer = StringBuffer();

  for (final line in lines) {
    if (heading.hasMatch(line.trim())) {
      // Yeni bölüm başlığı bulundu
      if (currentTitle != null) {
        chapters.add(_Chapter(title: currentTitle, content: buffer.toString().trim()));
      }
      currentTitle = line.trim();
      buffer.clear();
    } else {
      buffer.writeln(line);
    }
  }
  
  return chapters;
}
```

### 🎨 AI-Generated Content Display
AI'den gelen içeriği kullanıcı dostu şekilde sunmak için **özel UI bileşenleri**:

#### Book-like Reading Experience
```dart
// Kitap benzeri okuma deneyimi
Container(
  color: const Color(0xFFF8F5E7), // Kağıt rengi
  child: PageView.builder(
    itemBuilder: (context, index) {
      return DecoratedBox(
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
        child: Text(
          chapter.content,
          textAlign: TextAlign.justify,
          style: TextStyle(
            fontSize: _fontSize, // Ayarlanabilir font boyutu
            height: 1.7, // Okunabilirlik için satır yüksekliği
            color: const Color(0xFF2B2B2B), // Mürekkep rengi
          ),
        ),
      );
    },
  ),
);
```

## 🚀 AI Entegrasyonu ve Performans

### Model Selection
- **Gemini 1.5 Flash**: Hızlı ve verimli model seçimi
- **Streaming Support**: Gelecekte streaming desteği için hazırlık
- **Token Management**: Verimli token kullanımı

### Performance Optimization
- **Async Processing**: UI'yi bloke etmeden AI işlemleri
- **Loading States**: Kullanıcı deneyimi için yükleme göstergeleri
- **Memory Management**: Büyük AI yanıtları için bellek yönetimi

## 📱 Özellikler

### 🎯 AI-Powered Features
- **Anime Karakterleri**: 6 farklı anime karakteri seçeneği
- **Mekan ve Zaman**: 6 farklı ortam ve zaman dilimi
- **Olay Türleri**: 6 farklı hikaye türü ve çatışma
- **Uzun Hikayeler**: 10-15 bölüm, her bölüm 600-1000 kelime
- **Kitap Okuma Deneyimi**: Bölüm bölüm okuma arayüzü
- **Güvenli API Anahtarı**: Flutter Secure Storage ile güvenli saklama

### 🎨 Kullanıcı Arayüzü
- **Material Design 3**: Modern ve kullanıcı dostu arayüz
- **Responsive Tasarım**: Tüm ekran boyutlarına uyumlu
- **Dark/Light Theme**: Sistem temasına uyum
- **Animasyonlar**: Akıcı geçişler ve yükleme animasyonları

### 🔧 Teknik Özellikler
- **Hata Yönetimi**: Otomatik yeniden deneme (exponential backoff)
- **API Anahtarı Yönetimi**: 3 farklı yöntemle anahtar yükleme
- **Bölüm Ayrıştırma**: Otomatik bölüm tespiti ve ayrıştırma
- **Yazı Boyutu Ayarı**: Okuma deneyimi için ayarlanabilir font boyutu

## ⚠️ Önemli Not: Paket Durumu

**`google_generative_ai: ^0.4.7` paketi artık deprecated (kullanımdan kaldırılmış) durumda.**

Google, Gemini 2.0 ile birlikte yeni bir **Firebase SDK** oluşturmuş ve bu eski paketi kullanımdan kaldırmıştır. Bu proje şu anda eski paketi kullanmaktadır ve gelecekte Firebase SDK'ya geçiş yapılması gerekecektir.

### Gelecek Güncellemeler
- [ ] **Firebase SDK Migration**: Yeni Firebase SDK'ya geçiş
- [ ] **Gemini 2.0 Support**: Yeni model desteği
- [ ] **Unified SDK**: Google'ın birleşik SDK'sı

### Mevcut Durum
Bu proje şu anda **`google_generative_ai: ^0.4.7`** paketini kullanmaktadır ve çalışmaya devam etmektedir. Ancak Google bu pakete yeni özellikler eklemeyeceğini ve güncellemeler yapmayacağını belirtmiştir.

## 🚀 Kurulum

### Gereksinimler
- Flutter SDK 3.9.2 veya üzeri
- Dart SDK 3.9.2 veya üzeri
- Google Gemini API anahtarı

### Adımlar

1. **Projeyi klonlayın**
```bash
git clone https://github.com/yourusername/gemini_flutter_ai.git
cd gemini_flutter_ai
```

2. **Bağımlılıkları yükleyin**
```bash
flutter pub get
```

3. **API anahtarını ayarlayın**

   **Yöntem 1: Derleme zamanı (Önerilen)**
   ```bash
   flutter run --dart-define=GEMINI_API_KEY=your_api_key_here
   ```

   **Yöntem 2: Uygulama içi**
   - Uygulamayı çalıştırın
   - Sağ üstteki anahtar simgesine tıklayın
   - API anahtarınızı girin

   **Yöntem 3: Uzaktan URL (Gelişmiş)**
   ```bash
   flutter run --dart-define=GEMINI_KEY_URL=https://your-server.com/api-key
   ```

4. **Uygulamayı çalıştırın**
```bash
flutter run
```

## 🎮 AI Kullanımı ve Kullanıcı Deneyimi

### 1. Hikaye Bileşenlerini Seçin

**Karakter Seçimi:**
- Kaito: Genç ninja savaşçı
- Sakura: Büyücü kız
- Ren: Mek pilotu
- Yuki: Okul kızı (özel güçleri var)
- Hiro: Samuray
- Mira: Kedi kız (nekomimi)

**Mekan ve Zaman:**
- Tokyo, 2024: Modern şehir
- Akademi, Günümüz: Büyülü okul
- Ninja Köyü, Feodal: Gizli köy
- Uzay İstasyonu, 2150: Gelecek
- Fantastik Orman, Efsanevi: Büyülü orman
- Lise, Günümüz: Normal okul

**Olay Türleri:**
- Güç Keşfi: Gizli güçler ortaya çıkar
- Aşk Hikayesi: İlk aşk yaşanır
- Büyük Savaş: Epik savaş
- Zaman Yolculuğu: Geçmiş/gelecek
- Mek Savaşı: Dev robot savaşları
- Büyülü Macera: Büyülü dünyada keşif

### 2. AI Hikaye Oluşturma Süreci
- Tüm bileşenleri seçtikten sonra "Uzun Hikaye Oluştur" butonuna tıklayın
- AI, seçtiğiniz bileşenleri analiz eder ve yaratıcı bir hikaye oluşturur
- Hikaye 10-15 bölüm olarak oluşturulacak
- Her bölüm 600-1000 kelime arasında olacak
- AI, anime/manga tarzında diyaloglar ve aksiyon sahneleri ekler

### 3. AI-Generated Content'i Okuyun
- **Kitap Gibi Oku**: Bölüm bölüm okuma deneyimi
- **Yazı Boyutu**: Ayarlanabilir font boyutu
- **Bölüm Geçişi**: Kaydırarak bölümler arası geçiş
- **AI Parsing**: Otomatik bölüm tespiti ve ayrıştırma

## 🏗️ Proje Yapısı ve AI Entegrasyonu

### Ana Sınıflar ve AI Kullanımı

- **`StoryCreatorPage`**: Ana hikaye oluşturma sayfası - AI prompt engineering
- **`StoryReaderPage`**: Hikaye okuma sayfası - AI content parsing
- **`GeneratedStory`**: Hikaye veri modeli - AI response structure
- **`StoryCharacter`**: Karakter modeli - AI input parameters
- **`StorySetting`**: Mekan modeli - AI context building
- **`StoryEvent`**: Olay modeli - AI story framework

### AI Prompt Engineering Detayları

#### Prompt Structure
```dart
// AI'ye gönderilen prompt yapısı
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
```

#### AI Model Configuration
```dart
// Gemini AI model konfigürasyonu
final model = GenerativeModel(
  model: 'gemini-1.5-flash',  // Hızlı ve verimli model
  apiKey: _apiKey!
);

final content = [Content.text(prompt)];
final response = await model.generateContent(content);
```

## 🔧 AI API Key Management

AI servislerinin güvenli kullanımı için **3 katmanlı anahtar yönetimi** sistemi:

### 1. Secure Storage (Öncelik)
```dart
class _MyHomeKeyStorage {
  static const String storageKey = 'gemini_api_key';
  final FlutterSecureStorage storage = const FlutterSecureStorage();

  Future<String?> readKey() => storage.read(key: storageKey);
  Future<void> writeKey(String value) => storage.write(key: storageKey, value: value);
  Future<void> deleteKey() => storage.delete(key: storageKey);
}
```

### 2. Build-time Environment Variables
```dart
// Derleme zamanı ortam değişkenleri
static const String _envApiKey = String.fromEnvironment('GEMINI_API_KEY');
```

### 3. Remote Configuration
```dart
// Uzaktan anahtar yükleme
static Future<String?> fetchKeyFromUrl() async {
  if (envKeyUrl.isEmpty) return null;
  final uri = Uri.parse(envKeyUrl);
  final resp = await http.get(uri);
  if (resp.statusCode == 200) {
    return resp.body.trim();
  }
  return null;
}
```

### API Key Loading Priority
```dart
Future<void> _initApiKey() async {
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
}
```

## 🎨 AI-Generated Content Display

AI'den gelen içeriği kullanıcı dostu şekilde sunmak için **özel UI bileşenleri**:

### Book-like Reading Experience
```dart
// Kitap benzeri okuma deneyimi
Container(
  color: const Color(0xFFF8F5E7), // Kağıt rengi
  child: PageView.builder(
    itemBuilder: (context, index) {
      return DecoratedBox(
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
        child: Text(
          chapter.content,
          textAlign: TextAlign.justify,
          style: TextStyle(
            fontSize: _fontSize, // Ayarlanabilir font boyutu
            height: 1.7, // Okunabilirlik için satır yüksekliği
            color: const Color(0xFF2B2B2B), // Mürekkep rengi
          ),
        ),
      );
    },
  ),
);
```

### AI Content Parsing
```dart
// AI'den gelen hikayeyi bölümlere ayırma
List<_Chapter> _parseChapters(String content) {
  final lines = content.split('\n');
  final RegExp heading = RegExp(r'^Bölüm\s+\d+\s+—');
  
  final List<_Chapter> chapters = [];
  String? currentTitle;
  final StringBuffer buffer = StringBuffer();

  for (final line in lines) {
    if (heading.hasMatch(line.trim())) {
      // Yeni bölüm başlığı bulundu
      if (currentTitle != null) {
        chapters.add(_Chapter(title: currentTitle, content: buffer.toString().trim()));
      }
      currentTitle = line.trim();
      buffer.clear();
    } else {
      buffer.writeln(line);
    }
  }
  
  return chapters;
}
```

## 🚀 AI Entegrasyonu ve Performans

### Model Selection
- **Gemini 1.5 Flash**: Hızlı ve verimli model seçimi
- **Streaming Support**: Gelecekte streaming desteği için hazırlık
- **Token Management**: Verimli token kullanımı

### Performance Optimization
- **Async Processing**: UI'yi bloke etmeden AI işlemleri
- **Loading States**: Kullanıcı deneyimi için yükleme göstergeleri
- **Memory Management**: Büyük AI yanıtları için bellek yönetimi

### AI Error Handling
```dart
// AI API'ye özgü hata mesajları
if (errorString.contains('503')) {
  errorMessage = 'Sunucu geçici olarak kullanılamıyor. Lütfen daha sonra tekrar deneyin.';
} else if (errorString.contains('429')) {
  errorMessage = 'Çok fazla istek gönderildi. Lütfen biraz bekleyip tekrar deneyin.';
} else if (errorString.contains('quota') || errorString.contains('limit')) {
  errorMessage = 'API kotası aşıldı. Lütfen daha sonra tekrar deneyin.';
}
```

## 🎨 Tasarım Sistemi

### Renkler
- **Primary**: Deep Purple
- **Background**: Material Design 3 renkleri
- **Paper**: #F8F5E7 (okuma deneyimi)
- **Ink**: #2B2B2B (metin rengi)

### Tipografi
- **Başlık**: Material Design 3 başlık stilleri
- **Gövde**: 18px varsayılan, 14-28px arası ayarlanabilir
- **Satır Yüksekliği**: 1.6-1.7

### Bileşenler
- **Card**: Material Design 3 kart bileşenleri
- **Button**: Elevated, Outlined, Filled butonlar
- **Icon**: Material Icons
- **Progress**: Linear ve Circular progress göstergeleri

## 📱 Platform Desteği

- ✅ **Android**: API 21+ (Android 5.0+)
- ✅ **iOS**: iOS 11.0+
- ✅ **Web**: Modern tarayıcılar
- ✅ **Windows**: Windows 10+
- ✅ **macOS**: macOS 10.14+
- ✅ **Linux**: Ubuntu 18.04+

## 🔮 Gelecek AI Özellikleri

### Planlanan AI Geliştirmeleri
- [ ] **Streaming AI Responses**: Gerçek zamanlı hikaye oluşturma
- [ ] **AI Character Development**: Dinamik karakter gelişimi
- [ ] **AI Plot Twists**: Beklenmedik hikaye dönüşleri
- [ ] **AI Dialogue Generation**: Daha doğal diyaloglar
- [ ] **AI Image Generation**: Hikaye karakterleri için görsel oluşturma
- [ ] **AI Voice Synthesis**: Hikayeleri sesli okuma

### AI Model İyileştirmeleri
- [ ] **Firebase SDK Migration**: Google'ın yeni Firebase SDK'sına geçiş
- [ ] **Gemini 2.0 Support**: Yeni Gemini 2.0 model desteği
- [ ] **Fine-tuned Models**: Anime özelinde eğitilmiş modeller
- [ ] **Multi-modal AI**: Metin + görsel + ses entegrasyonu
- [ ] **Context Memory**: Uzun hikayeler için bağlam hafızası
- [ ] **Style Transfer**: Farklı anime stillerinde hikaye yazma
- [ ] **Collaborative AI**: Birden fazla AI modelinin birlikte çalışması

### Teknik AI İyileştirmeleri
- [ ] **AI Caching**: Daha hızlı yanıtlar için önbellekleme
- [ ] **AI Load Balancing**: Birden fazla AI sağlayıcısı desteği
- [ ] **AI Analytics**: AI kullanım istatistikleri ve optimizasyon
- [ ] **AI A/B Testing**: Farklı prompt stratejilerini test etme
- [ ] **AI Quality Metrics**: Hikaye kalitesi ölçümü


### AI Kullanım Metrikleri
- **Prompt Engineering**: Gelişmiş yapılandırılmış prompt
- **Error Recovery**: Exponential backoff algoritması
- **Content Processing**: Regex tabanlı bölüm tespiti
- **User Experience**: Kitap benzeri okuma deneyimi
- **Security**: 3 katmanlı API anahtarı yönetimi
- **Package Status**: Deprecated `google_generative_ai: ^0.4.7` (Firebase SDK'ya geçiş gerekli)

---

⭐ **Bu AI projesini beğendiyseniz yıldız vermeyi unutmayın!**

🤖 **AI ile anime hikayelerinizi oluşturmaya başlayın!**