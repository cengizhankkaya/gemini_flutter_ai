import 'package:flutter/foundation.dart';
import 'package:gemini_flutter_ai/core/error/failure.dart';
import 'package:gemini_flutter_ai/core/utils/retry_policy.dart';
import 'package:gemini_flutter_ai/data/models/story_models.dart';
import 'package:gemini_flutter_ai/data/repositories/api_key_repository.dart';
import 'package:gemini_flutter_ai/data/repositories/story_repository.dart';

class StoryViewModel extends ChangeNotifier {
  final ApiKeyRepository apiKeyRepo;
  final StoryRepository storyRepo;
  final RetryPolicy retryPolicy;

  StoryViewModel({
    required this.apiKeyRepo,
    required this.storyRepo,
    this.retryPolicy = const RetryPolicy(),
  });

  StoryCharacter? selectedCharacter;
  StorySetting? selectedSetting;
  StoryEvent? selectedEvent;

  bool isLoading = false;
  int retryAttempt = 0;
  GeneratedStory? generatedStory;
  Failure? error;
  String? _apiKey;
  bool keyLoaded = false;

  String? get apiKey => _apiKey;

  Future<void> init() async {
    try {
      _apiKey = await apiKeyRepo.loadApiKey();
    } finally {
      keyLoaded = true;
      notifyListeners();
    }
  }

  Future<void> saveApiKey(String key) async {
    await apiKeyRepo.saveApiKey(key);
    _apiKey = key;
    notifyListeners();
  }

  Future<void> clearApiKey() async {
    await apiKeyRepo.clearApiKey();
    _apiKey = null;
    notifyListeners();
  }

  void selectCharacter(StoryCharacter c) {
    selectedCharacter = c;
    notifyListeners();
  }

  void selectSetting(StorySetting s) {
    selectedSetting = s;
    notifyListeners();
  }

  void selectEvent(StoryEvent e) {
    selectedEvent = e;
    notifyListeners();
  }

  void resetSelections() {
    selectedCharacter = null;
    selectedSetting = null;
    selectedEvent = null;
    generatedStory = null;
    error = null;
    notifyListeners();
  }

  Future<void> generate() async {
    if (selectedCharacter == null || selectedSetting == null || selectedEvent == null) {
      error = const Failure(message: 'Lütfen tüm hikaye bileşenlerini seçin.');
      notifyListeners();
      return;
    }
    if ((_apiKey ?? '').isEmpty) {
      error = const Failure(message: 'API anahtarı bulunamadı.');
      notifyListeners();
      return;
    }

    isLoading = true;
    retryAttempt = 0;
    error = null;
    notifyListeners();

    print('Hikaye oluşturma başlıyor...');
    print('Seçili karakter: ${selectedCharacter!.name}');
    print('Seçili mekan: ${selectedSetting!.location}');
    print('Seçili olay: ${selectedEvent!.title}');
    print('API Key: ${_apiKey!.substring(0, 10)}...');

    try {
      final GeneratedStory story = await retryPolicy.executeWithBackoff<GeneratedStory>(
        () => storyRepo.generateLongStory(
          apiKey: _apiKey!,
          selections: StorySelections(
            character: selectedCharacter!,
            setting: selectedSetting!,
            event: selectedEvent!,
          ),
        ),
      );
      print('Hikaye başarıyla oluşturuldu: ${story.title}');
      print('Hikaye içeriği: ${story.content.length} karakter');
      generatedStory = story;
    } catch (e) {
      print('Hikaye oluşturma hatası: $e');
      final String err = e.toString().toLowerCase();
      FailureType type = FailureType.unknown;
      if (err.contains('503') || err.contains('unavailable')) type = FailureType.unavailable;
      else if (err.contains('429') || err.contains('rate limit')) type = FailureType.rateLimited;
      else if (err.contains('401') || err.contains('403')) type = FailureType.authentication;
      else if (err.contains('timeout')) type = FailureType.timeout;
      else if (err.contains('network') || err.contains('connection')) type = FailureType.network;
      error = Failure(message: 'Hata: $e', type: type);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}


