# gemini_flutter_ai

Google Gemini (Generative AI) API ile etkileşime geçen, çok platformlu (iOS/Android/Web/Windows/macOS/Linux) bir Flutter örnek uygulaması.

Uygulama, API anahtarını güvenle yönetmek için birden fazla yöntem sunar ve `google_generative_ai` paketi ile metin üretimi yapar.

## Özellikler

- Google Gemini modeli ile metin üretimi (varsayılan: `gemini-1.5-flash`)
- API anahtarı yönetimi için 3 yöntem:
  1) Uygulama içinden anahtar girip kalıcı olarak saklama (`flutter_secure_storage`)
  2) Derleme zamanında `--dart-define=GEMINI_API_KEY=...` ile verme
  3) Derleme zamanında anahtarı bir URL'den çekme: `--dart-define=GEMINI_KEY_URL=https://...`
- Anahtarın varlığını/uzunluğunu izleme, hata/kota yönetimi için temel uyarılar

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

## Paketler

- `google_generative_ai` (^0.4.6): Gemini API istemcisi
- `flutter_secure_storage` (^9.2.2): API anahtarını güvenli saklama
- `path_provider`: Platforma özel güvenli depolama/klasör erişimi için yardımcı paketler

Sürümler için `pubspec.yaml` ve `pubspec.lock` dosyalarına bakabilirsiniz.

## Mimari Notları

- Model oluşturma: `GenerativeModel(model: 'gemini-1.5-flash', apiKey: ...)`
- Anahtar yükleme sırası özetle:
  - (Varsa) Uygulama içindeki güvenli depodan oku
  - (Yoksa) Derleme zamanı `GEMINI_API_KEY`
  - (Yoksa) Derleme zamanı `GEMINI_KEY_URL` üzerinden uzaktan getir

Bu akış ve detaylar `lib/main.dart` içinde uygulanmıştır.

## Sorun Giderme

- "API anahtarı bulunamadı" uyarısı: Sağ üstten anahtar girin ya da `--dart-define` kullanın.
- "Geçersiz anahtar" hatası: Anahtarınızı Google AI Studio’dan yeniden kopyalayın ve boşluk/kaçak karakter olmadığından emin olun.
- "Kota aşıldı" hatası: Bir süre bekleyip tekrar deneyin; model/istek sıklığını gözden geçirin.
- iOS’ta ilk derlemede daha uzun sürebilir (Pods). Gerekirse: `cd ios && pod repo update && pod install`.

## Güvenlik Tavsiyeleri

- Üretimde API anahtarını istemciye gömmeyin. `GEMINI_KEY_URL` ile korumalı bir endpoint üzerinden anahtar döndürmeyi veya yetkisiz kullanımı engelleyen bir backend proxy yaklaşımını tercih edin.
- Anahtarı uygulama içinden giriyorsanız, cihaz paylaşımını ve yedeklemeyi göz önünde bulundurun.

## Lisans

Bu proje eğitim/örnek amaçlıdır. Kendi projenize entegre ederken lisans ve kullanım koşullarını kontrol ediniz.
