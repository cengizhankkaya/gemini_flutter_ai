import 'package:get_it/get_it.dart';
import 'package:gemini_flutter_ai/data/services/gemini_service.dart';
import 'package:gemini_flutter_ai/data/services/remote_config_service.dart';
import 'package:gemini_flutter_ai/data/services/secure_storage_service.dart';
import 'package:gemini_flutter_ai/data/repositories/api_key_repository.dart';
import 'package:gemini_flutter_ai/data/repositories/story_repository.dart';

final GetIt getIt = GetIt.instance;

void setupLocator() {
  // Services
  getIt.registerLazySingleton<GeminiService>(() =>  GeminiService());
  getIt.registerLazySingleton<SecureStorageService>(() => const SecureStorageService());
  getIt.registerLazySingleton<RemoteConfigService>(() => const RemoteConfigService());

  // Repositories
  getIt.registerLazySingleton<ApiKeyRepository>(() => ApiKeyRepository(
        storageService: getIt<SecureStorageService>(),
        remoteConfigService: getIt<RemoteConfigService>(),
      ));
  getIt.registerLazySingleton<StoryRepository>(() => StoryRepository(
        gemini: getIt<GeminiService>(),
      ));
}


