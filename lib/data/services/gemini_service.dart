import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiService {
  final String modelName = 'gemini-1.5-flash';

  GeminiService();

  Future<GenerateContentResponse> generateContent({required String apiKey, required String prompt}) async {
    final List<String> candidates = <String>[
      modelName,
      'gemini-1.5-flash-8b',
      'gemini-1.5-pro',
    ];

    Exception? lastError;
    for (final String m in candidates) {
      try {
        print('Gemini API\'ye istek gönderiliyor...');
        print('Model: $m');
        print('Prompt uzunluğu: ${prompt.length} karakter');

        final GenerativeModel model = GenerativeModel(model: m, apiKey: apiKey);
        final List<Content> content = [Content.text(prompt)];
        final GenerateContentResponse response = await model.generateContent(content);
        print('API yanıtı alındı: ${response.text?.length ?? 0} karakter');
        return response;
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        final String err = e.toString().toLowerCase();
        final bool notFound = err.contains('was not found') || err.contains('not found for api version');
        final bool unsupported = err.contains('not supported for generatecontent');
        print('Model denemesi başarısız: $m -> $e');
        if (!(notFound || unsupported)) {
          // Model erişiminden bağımsız hata; tekrar denemenin faydası yok
          break;
        }
        // Aksi halde sıradaki adayı dene
      }
    }
    throw lastError ?? Exception('İçerik oluşturma başarısız.');
  }

  Future<String> generateText({required String apiKey, required String prompt}) async {
    final response = await generateContent(apiKey: apiKey, prompt: prompt);
    return response.text ?? '';
  }
}


