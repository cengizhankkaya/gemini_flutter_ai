# Anime Hikaye Oluşturucu

Google Gemini AI ile anime karakterleri, mekanları ve olayları seçerek uzun ve detaylı anime hikayeleri oluşturan çok platformlu Flutter uygulaması.

Bu uygulama, kullanıcıların anime tarzında hikayeler oluşturmasını sağlar. Karakter, mekan ve olay seçimleri yaparak Gemini AI'ın gücüyle kişiselleştirilmiş hikayeler üretir.

## Özellikler

### 🎭 Karakter Seçimi
- 6 farklı anime karakteri (Ninja, Büyücü, Mek Pilotu, Okul Kızı, Samuray, Kedi Kız)
- Her karakterin kendine özgü kişiliği ve geçmişi
- Detaylı karakter açıklamaları

### 🌍 Mekan ve Zaman Seçimi
- 6 farklı mekan ve zaman kombinasyonu
- Modern Tokyo'dan fantastik ormanlara kadar çeşitli ortamlar
- Her mekanın kendine özgü atmosferi ve detayları

### ⚔️ Olay Seçimi
- 6 farklı hikaye türü (Güç Keşfi, Aşk Hikayesi, Büyük Savaş, Zaman Yolculuğu, Mek Savaşı, Büyülü Macera)
- Her olayın kendine özgü çatışması ve çözümü
- Epik hikaye anlatımı

### 📖 Hikaye Okuma Deneyimi
- Kitap benzeri okuma arayüzü
- Bölüm bölüm hikaye okuma
- Yazı boyutu ayarlama
- Sayfa geçiş göstergesi

### 🔐 API Anahtarı Yönetimi
- 3 farklı yöntemle API anahtarı yönetimi:
  1) Uygulama içinden anahtar girip güvenli saklama (`flutter_secure_storage`)
  2) Derleme zamanında `--dart-define=GEMINI_API_KEY=...` ile verme
  3) Derleme zamanında anahtarı bir URL'den çekme: `--dart-define=GEMINI_KEY_URL=https://...`
- Anahtar durumu izleme ve hata yönetimi

## Gereksinimler

- Flutter (stable sürüm)
- Bir Google AI Studio (Gemini) API anahtarı

## Kurulum

```bash
flutter pub get
```

## Çalıştırma

Uygulamayı aşağıdaki yöntemlerden biriyle çalıştırın:

### Yöntem 1: Uygulama içinden API anahtarı girme (önerilir)

1. `flutter run`
2. Uygulama açıldıktan sonra sağ üstteki anahtar simgesine tıklayın.
3. Gemini API anahtarınızı girin ve kaydedin. Anahtar güvenli şekilde `flutter_secure_storage` ile saklanır.

### Yöntem 2: Derleme zamanında anahtar geçme

```bash
flutter run --dart-define=GEMINI_API_KEY=YOUR_API_KEY
```

### Yöntem 3: Anahtarı bir endpoint’ten alma

Anahtarı bir HTTPS endpoint’inden almak için:

```bash
flutter run --dart-define=GEMINI_KEY_URL=https://your-domain.com/secret/gemini-key
```

Uygulama bu URL’e GET isteği yapar ve dönen gövdeyi (response body) API anahtarı olarak kullanır. Bu yaklaşım, istemciye ham anahtar gömmemek için tercih edilebilir. URL’yi yetkilendirme ile korumanız tavsiye edilir.

Not: Aynı anda hem `GEMINI_API_KEY` hem `GEMINI_KEY_URL` verilirse öncelik mantığı `lib/main.dart` içindeki yükleme sırasına göre belirlenir.

## Teknik Detaylar

### Mimari
- **Clean Architecture** prensiplerine uygun katmanlı yapı
- **Dependency Injection** ile `get_it` kullanımı
- **Provider** ile state management
- **Repository Pattern** ile veri katmanı yönetimi

### Kullanılan Paketler
- `google_generative_ai` (^0.4.7): Gemini API istemcisi
- `flutter_secure_storage` (^9.2.2): API anahtarını güvenli saklama
- `get_it` (^7.7.0): Dependency injection
- `provider` (^6.1.2): State management
- `http` (^1.2.2): HTTP istekleri
- `intl` (^0.19.0): Tarih/saat formatlaması

### Proje Yapısı
```
lib/
├── app.dart                    # Ana uygulama widget'ı
├── main.dart                   # Uygulama giriş noktası
├── core/                       # Temel sınıflar
│   ├── error/                  # Hata yönetimi
│   └── utils/                  # Yardımcı fonksiyonlar
├── data/                       # Veri katmanı
│   ├── models/                 # Veri modelleri
│   ├── repositories/           # Repository sınıfları
│   └── services/               # Servis sınıfları
├── di/                         # Dependency injection
├── presentation/               # UI katmanı
│   ├── story_creator/          # Hikaye oluşturma sayfası
│   └── story_reader/           # Hikaye okuma sayfası
```

### API Anahtarı Yönetimi
- Model oluşturma: `GenerativeModel(model: 'gemini-1.5-flash', apiKey: ...)`
- Anahtar yükleme sırası:
  1. Uygulama içindeki güvenli depodan oku
  2. Derleme zamanı `GEMINI_API_KEY` değişkeni
  3. Derleme zamanı `GEMINI_KEY_URL` üzerinden uzaktan getir

## Kullanım

### Hikaye Oluşturma
1. Uygulamayı başlatın
2. API anahtarınızı ayarlayın (sağ üstteki anahtar simgesi)
3. Bir karakter seçin (Ninja, Büyücü, Mek Pilotu, vb.)
4. Bir mekan ve zaman seçin (Tokyo 2024, Akademi, vb.)
5. Bir olay türü seçin (Güç Keşfi, Aşk Hikayesi, vb.)
6. "Uzun Hikaye Oluştur" butonuna tıklayın
7. AI'ın hikayeyi oluşturmasını bekleyin

### Hikaye Okuma
1. Oluşturulan hikayeyi "Kitap Gibi Oku" butonu ile açın
2. Sayfa geçişleri için kaydırma yapın
3. Yazı boyutunu ayarlayın (sağ üstteki butonlar)
4. Bölüm göstergesini takip edin

## Sorun Giderme

### API Anahtarı Sorunları
- "API anahtarı bulunamadı" uyarısı: Sağ üstten anahtar girin ya da `--dart-define` kullanın
- "Geçersiz anahtar" hatası: Anahtarınızı Google AI Studio'dan yeniden kopyalayın
- "Kota aşıldı" hatası: Bir süre bekleyip tekrar deneyin

### Derleme Sorunları
- iOS'ta ilk derlemede daha uzun sürebilir (Pods)
- Gerekirse: `cd ios && pod repo update && pod install`
- Flutter sürümünüzün güncel olduğundan emin olun

### Hikaye Oluşturma Sorunları
- Tüm seçimlerin (karakter, mekan, olay) yapıldığından emin olun
- İnternet bağlantınızın aktif olduğunu kontrol edin
- API anahtarınızın geçerli olduğunu doğrulayın

## Güvenlik Tavsiyeleri

- Üretimde API anahtarını istemciye gömmeyin
- `GEMINI_KEY_URL` ile korumalı endpoint kullanın
- Anahtarı uygulama içinden giriyorsanız, cihaz paylaşımını göz önünde bulundurun
- API anahtarınızı düzenli olarak yenileyin

## Katkıda Bulunma

Bu proje eğitim amaçlıdır. Katkıda bulunmak için:
1. Fork yapın
2. Feature branch oluşturun
3. Değişikliklerinizi commit edin
4. Pull request gönderin

## Lisans

Bu proje eğitim/örnek amaçlıdır. Kendi projenize entegre ederken lisans ve kullanım koşullarını kontrol ediniz.
