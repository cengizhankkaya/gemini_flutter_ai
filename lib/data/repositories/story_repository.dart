import 'package:gemini_flutter_ai/data/models/story_models.dart';
import 'package:gemini_flutter_ai/data/services/gemini_service.dart';

class StoryRepository {
  final GeminiService gemini;

  const StoryRepository({required this.gemini});

  Future<GeneratedStory> generateLongStory({
    required String apiKey,
    required StorySelections selections,
  }) async {
    final String prompt = _buildPrompt(selections);
    final String content = await gemini.generateText(apiKey: apiKey, prompt: prompt);
    return GeneratedStory(
      title: '${selections.character.name} - ${selections.event.title}',
      content: content.isEmpty ? 'Hikaye oluşturulamadı.' : content,
      character: selections.character,
      setting: selections.setting,
      event: selections.event,
      createdAt: DateTime.now(),
    );
  }

  String _buildPrompt(StorySelections s) {
    return '''
Aşağıdaki bileşenleri kullanarak ANIME/MANGA tarzında, BÖLÜM BÖLÜM ve kitap gibi uzun bir hikaye yaz.

KARAKTER:
- İsim: ${s.character.name}
- Açıklama: ${s.character.description}
- Kişilik: ${s.character.personality}
- Geçmiş: ${s.character.background}

MEKAN VE ZAMAN:
- Konum: ${s.setting.location}
- Zaman: ${s.setting.time}
- Atmosfer: ${s.setting.atmosphere}
- Açıklama: ${s.setting.description}

OLAY:
- Başlık: ${s.event.title}
- Açıklama: ${s.event.description}
- Çatışma: ${s.event.conflict}
- Çözüm: ${s.event.resolution}

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
  }
}


