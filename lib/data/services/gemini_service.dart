import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiService {
  final String modelName = 'gemini-1.5-flash';

  GeminiService();

  Future<GenerateContentResponse> generateContent({required String apiKey, required String prompt}) async {
    print('Gemini API\'ye istek gönderiliyor...');
    print('Model: $modelName');
    print('Prompt uzunluğu: ${prompt.length} karakter');
    
    final GenerativeModel model = GenerativeModel(model: modelName, apiKey: apiKey);
    final List<Content> content = [Content.text(prompt)];
    final GenerateContentResponse response = await model.generateContent(content);
    
    print('API yanıtı alındı: ${response.text?.length ?? 0} karakter');
    return response;
  }

  Future<String> generateText({required String apiKey, required String prompt}) async {
    final response = await generateContent(apiKey: apiKey, prompt: prompt);
    return response.text ?? '';
  }
}


