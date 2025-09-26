import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gemini_flutter_ai/di/locator.dart';
import 'package:gemini_flutter_ai/presentation/story_creator/story_view_model.dart';
import 'package:gemini_flutter_ai/presentation/story_reader/story_reader_page.dart';
import 'package:gemini_flutter_ai/data/models/story_models.dart';
import 'package:gemini_flutter_ai/data/repositories/api_key_repository.dart';
import 'package:gemini_flutter_ai/data/repositories/story_repository.dart';
import 'package:gemini_flutter_ai/core/error/failure.dart';

class StoryCreatorPage extends StatefulWidget {
  const StoryCreatorPage({super.key});

  @override
  State<StoryCreatorPage> createState() => _StoryCreatorPageState();
}

class _StoryCreatorPageState extends State<StoryCreatorPage> {
  late final StoryViewModel viewModel;

  @override
  void initState() {
    super.initState();
    viewModel = StoryViewModel(
      apiKeyRepo: getIt<ApiKeyRepository>(),
      storyRepo: getIt<StoryRepository>(),
    );
    viewModel.init();
  }

  @override
  void dispose() {
    viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: viewModel,
      child: const _StoryCreatorView(),
    );
  }
}

class _StoryCreatorView extends StatelessWidget {
  const _StoryCreatorView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Anime Hikaye Oluşturucu'),
        actions: const [_ApiKeyButton()],
      ),
      body: Consumer<StoryViewModel>(
        builder: (context, vm, _) {
          return Column(
            children: [
              if (!vm.keyLoaded) const LinearProgressIndicator(),
              if (vm.keyLoaded && (vm.apiKey == null || vm.apiKey!.isEmpty))
                const _ApiKeyWarning(),
              if (vm.error != null)
                _ErrorDisplay(error: vm.error!),
              Expanded(
                child: vm.generatedStory == null
                    ? const _StoryCreatorForm()
                    : _StoryDisplay(story: vm.generatedStory!),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ApiKeyButton extends StatelessWidget {
  const _ApiKeyButton();

  @override
  Widget build(BuildContext context) {
    return Consumer<StoryViewModel>(
      builder: (context, vm, _) {
        return IconButton(
          tooltip: 'API anahtarı yönet',
          icon: const Icon(Icons.vpn_key),
          onPressed: () => _showApiKeyDialog(context, vm),
        );
      },
    );
  }

  Future<void> _showApiKeyDialog(BuildContext context, StoryViewModel vm) async {
    final TextEditingController controller = TextEditingController(text: vm.apiKey ?? '');
    final String? result = await showDialog<String>(
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

    if (result == null) return;
    if (result == 'clear') {
      await vm.clearApiKey();
    } else if (result.isNotEmpty) {
      await vm.saveApiKey(result);
    }
  }
}

class _ApiKeyWarning extends StatelessWidget {
  const _ApiKeyWarning();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: Colors.orange),
          SizedBox(width: 8),
          Expanded(
            child: Text('API anahtarı ayarlı değil. Sağ üstten anahtar ekleyin.'),
          ),
        ],
      ),
    );
  }
}

class _ErrorDisplay extends StatelessWidget {
  final Failure error;
  const _ErrorDisplay({required this.error});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              error.message,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}

class _StoryCreatorForm extends StatelessWidget {
  const _StoryCreatorForm();

  @override
  Widget build(BuildContext context) {
    return Consumer<StoryViewModel>(
      builder: (context, vm, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Header(),
              const SizedBox(height: 32),
              _CharacterSelector(vm: vm),
              const SizedBox(height: 16),
              _SettingSelector(vm: vm),
              const SizedBox(height: 16),
              _EventSelector(vm: vm),
              const SizedBox(height: 24),
              _GenerateButton(vm: vm),
            ],
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Center(
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
    );
  }
}

class _CharacterSelector extends StatelessWidget {
  final StoryViewModel vm;
  const _CharacterSelector({required this.vm});

  @override
  Widget build(BuildContext context) {
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
            if (vm.selectedCharacter == null)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _CharacterOption(
                    name: 'Kaito',
                    description: 'Genç bir ninja',
                    personality: 'Cesur ve sadık',
                    background: 'Gizli ninja köyünden gelen yetenekli savaşçı',
                    onTap: () => vm.selectCharacter(StoryCharacter(
                      name: 'Kaito',
                      description: 'Genç bir ninja',
                      personality: 'Cesur ve sadık',
                      background: 'Gizli ninja köyünden gelen yetenekli savaşçı',
                    )),
                  ),
                  _CharacterOption(
                    name: 'Sakura',
                    description: 'Büyücü kız',
                    personality: 'Güçlü ve kararlı',
                    background: 'Büyülü güçleri olan genç büyücü',
                    onTap: () => vm.selectCharacter(StoryCharacter(
                      name: 'Sakura',
                      description: 'Büyücü kız',
                      personality: 'Güçlü ve kararlı',
                      background: 'Büyülü güçleri olan genç büyücü',
                    )),
                  ),
                  _CharacterOption(
                    name: 'Ren',
                    description: 'Mek pilotu',
                    personality: 'Analitik ve soğukkanlı',
                    background: 'Dev robotları kontrol eden pilot',
                    onTap: () => vm.selectCharacter(StoryCharacter(
                      name: 'Ren',
                      description: 'Mek pilotu',
                      personality: 'Analitik ve soğukkanlı',
                      background: 'Dev robotları kontrol eden pilot',
                    )),
                  ),
                  _CharacterOption(
                    name: 'Yuki',
                    description: 'Okul kızı',
                    personality: 'Tatlı ve meraklı',
                    background: 'Normal lise öğrencisi ama özel güçleri var',
                    onTap: () => vm.selectCharacter(StoryCharacter(
                      name: 'Yuki',
                      description: 'Okul kızı',
                      personality: 'Tatlı ve meraklı',
                      background: 'Normal lise öğrencisi ama özel güçleri var',
                    )),
                  ),
                  _CharacterOption(
                    name: 'Hiro',
                    description: 'Samuray',
                    personality: 'Onurlu ve güçlü',
                    background: 'Eski samuray ailesinden gelen savaşçı',
                    onTap: () => vm.selectCharacter(StoryCharacter(
                      name: 'Hiro',
                      description: 'Samuray',
                      personality: 'Onurlu ve güçlü',
                      background: 'Eski samuray ailesinden gelen savaşçı',
                    )),
                  ),
                  _CharacterOption(
                    name: 'Mira',
                    description: 'Kedi kız',
                    personality: 'Şirin ve çevik',
                    background: 'Kedi özellikleri olan nekomimi karakter',
                    onTap: () => vm.selectCharacter(StoryCharacter(
                      name: 'Mira',
                      description: 'Kedi kız',
                      personality: 'Şirin ve çevik',
                      background: 'Kedi özellikleri olan nekomimi karakter',
                    )),
                  ),
                ],
              )
            else
              _SelectedComponent(
                title: vm.selectedCharacter!.name,
                description: '${vm.selectedCharacter!.description}\n${vm.selectedCharacter!.personality}',
                onRemove: () => vm.resetSelections(),
              ),
          ],
        ),
      ),
    );
  }
}

class _CharacterOption extends StatelessWidget {
  final String name;
  final String description;
  final String personality;
  final String background;
  final VoidCallback onTap;

  const _CharacterOption({
    required this.name,
    required this.description,
    required this.personality,
    required this.background,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
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
}

class _SettingSelector extends StatelessWidget {
  final StoryViewModel vm;
  const _SettingSelector({required this.vm});

  @override
  Widget build(BuildContext context) {
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
            if (vm.selectedSetting == null)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _SettingOption(
                    locationTime: 'Tokyo, 2024',
                    atmosphere: 'Modern şehir',
                    description: 'Neon ışıkları ve teknoloji',
                    detail: 'Yüksek binalar arasında gizli dünyalar',
                    onTap: () => vm.selectSetting(StorySetting(
                      location: 'Tokyo',
                      time: '2024',
                      atmosphere: 'Modern şehir',
                      description: 'Neon ışıkları ve teknoloji - Yüksek binalar arasında gizli dünyalar',
                    )),
                  ),
                  _SettingOption(
                    locationTime: 'Akademi, Günümüz',
                    atmosphere: 'Büyülü okul',
                    description: 'Sihirli ve gizemli',
                    detail: 'Büyücülerin eğitim gördüğü prestijli akademi',
                    onTap: () => vm.selectSetting(StorySetting(
                      location: 'Akademi',
                      time: 'Günümüz',
                      atmosphere: 'Büyülü okul',
                      description: 'Sihirli ve gizemli - Büyücülerin eğitim gördüğü prestijli akademi',
                    )),
                  ),
                  _SettingOption(
                    locationTime: 'Ninja Köyü, Feodal',
                    atmosphere: 'Gizli köy',
                    description: 'Geleneksel ve tehlikeli',
                    detail: 'Dağların arasında gizli ninja yerleşimi',
                    onTap: () => vm.selectSetting(StorySetting(
                      location: 'Ninja Köyü',
                      time: 'Feodal',
                      atmosphere: 'Gizli köy',
                      description: 'Geleneksel ve tehlikeli - Dağların arasında gizli ninja yerleşimi',
                    )),
                  ),
                  _SettingOption(
                    locationTime: 'Uzay İstasyonu, 2150',
                    atmosphere: 'Gelecek',
                    description: 'Teknolojik ve soğuk',
                    detail: 'Yıldızlar arasında dolaşan dev uzay gemisi',
                    onTap: () => vm.selectSetting(StorySetting(
                      location: 'Uzay İstasyonu',
                      time: '2150',
                      atmosphere: 'Gelecek',
                      description: 'Teknolojik ve soğuk - Yıldızlar arasında dolaşan dev uzay gemisi',
                    )),
                  ),
                  _SettingOption(
                    locationTime: 'Fantastik Orman, Efsanevi',
                    atmosphere: 'Büyülü orman',
                    description: 'Mistik ve büyülü',
                    detail: 'Periler ve ejderhaların yaşadığı orman',
                    onTap: () => vm.selectSetting(StorySetting(
                      location: 'Fantastik Orman',
                      time: 'Efsanevi',
                      atmosphere: 'Büyülü orman',
                      description: 'Mistik ve büyülü - Periler ve ejderhaların yaşadığı orman',
                    )),
                  ),
                  _SettingOption(
                    locationTime: 'Lise, Günümüz',
                    atmosphere: 'Normal okul',
                    description: 'Sıradan görünümlü',
                    detail: 'Gizli güçlerin saklandığı normal lise',
                    onTap: () => vm.selectSetting(StorySetting(
                      location: 'Lise',
                      time: 'Günümüz',
                      atmosphere: 'Normal okul',
                      description: 'Sıradan görünümlü - Gizli güçlerin saklandığı normal lise',
                    )),
                  ),
                ],
              )
            else
              _SelectedComponent(
                title: '${vm.selectedSetting!.location} - ${vm.selectedSetting!.time}',
                description: '${vm.selectedSetting!.atmosphere}\n${vm.selectedSetting!.description}',
                onRemove: () => vm.resetSelections(),
              ),
          ],
        ),
      ),
    );
  }
}

class _SettingOption extends StatelessWidget {
  final String locationTime;
  final String atmosphere;
  final String description;
  final String detail;
  final VoidCallback onTap;

  const _SettingOption({
    required this.locationTime,
    required this.atmosphere,
    required this.description,
    required this.detail,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
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
}

class _EventSelector extends StatelessWidget {
  final StoryViewModel vm;
  const _EventSelector({required this.vm});

  @override
  Widget build(BuildContext context) {
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
            if (vm.selectedEvent == null)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _EventOption(
                    title: 'Güç Keşfi',
                    description: 'Gizli güçler ortaya çıkar',
                    conflict: 'Bu güçler nereden geliyor?',
                    resolution: 'Yeni yetenekler keşfedilir',
                    onTap: () => vm.selectEvent(StoryEvent(
                      title: 'Güç Keşfi',
                      description: 'Gizli güçler ortaya çıkar',
                      conflict: 'Bu güçler nereden geliyor?',
                      resolution: 'Yeni yetenekler keşfedilir',
                    )),
                  ),
                  _EventOption(
                    title: 'Aşk Hikayesi',
                    description: 'İlk aşk yaşanır',
                    conflict: 'Aşk gerçek mi yoksa büyü mü?',
                    resolution: 'Kalp kırıklığı veya mutlu son',
                    onTap: () => vm.selectEvent(StoryEvent(
                      title: 'Aşk Hikayesi',
                      description: 'İlk aşk yaşanır',
                      conflict: 'Aşk gerçek mi yoksa büyü mü?',
                      resolution: 'Kalp kırıklığı veya mutlu son',
                    )),
                  ),
                  _EventOption(
                    title: 'Büyük Savaş',
                    description: 'Epik bir savaş başlar',
                    conflict: 'Kim kazanacak?',
                    resolution: 'Kahramanlık ve fedakarlık',
                    onTap: () => vm.selectEvent(StoryEvent(
                      title: 'Büyük Savaş',
                      description: 'Epik bir savaş başlar',
                      conflict: 'Kim kazanacak?',
                      resolution: 'Kahramanlık ve fedakarlık',
                    )),
                  ),
                  _EventOption(
                    title: 'Zaman Yolculuğu',
                    description: 'Geçmişe veya geleceğe gidilir',
                    conflict: 'Zaman çizgisi değişebilir mi?',
                    resolution: 'Kader değişir',
                    onTap: () => vm.selectEvent(StoryEvent(
                      title: 'Zaman Yolculuğu',
                      description: 'Geçmişe veya geleceğe gidilir',
                      conflict: 'Zaman çizgisi değişebilir mi?',
                      resolution: 'Kader değişir',
                    )),
                  ),
                  _EventOption(
                    title: 'Mek Savaşı',
                    description: 'Dev robotlar savaşır',
                    conflict: 'Hangi mek daha güçlü?',
                    resolution: 'Pilotluk yetenekleri test edilir',
                    onTap: () => vm.selectEvent(StoryEvent(
                      title: 'Mek Savaşı',
                      description: 'Dev robotlar savaşır',
                      conflict: 'Hangi mek daha güçlü?',
                      resolution: 'Pilotluk yetenekleri test edilir',
                    )),
                  ),
                  _EventOption(
                    title: 'Büyülü Macera',
                    description: 'Büyülü dünyada keşif',
                    conflict: 'Hangi büyüler keşfedilecek?',
                    resolution: 'Büyücü olma yolculuğu',
                    onTap: () => vm.selectEvent(StoryEvent(
                      title: 'Büyülü Macera',
                      description: 'Büyülü dünyada keşif',
                      conflict: 'Hangi büyüler keşfedilecek?',
                      resolution: 'Büyücü olma yolculuğu',
                    )),
                  ),
                ],
              )
            else
              _SelectedComponent(
                title: vm.selectedEvent!.title,
                description: '${vm.selectedEvent!.description}\nÇatışma: ${vm.selectedEvent!.conflict}',
                onRemove: () => vm.resetSelections(),
              ),
          ],
        ),
      ),
    );
  }
}

class _EventOption extends StatelessWidget {
  final String title;
  final String description;
  final String conflict;
  final String resolution;
  final VoidCallback onTap;

  const _EventOption({
    required this.title,
    required this.description,
    required this.conflict,
    required this.resolution,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
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
}

class _SelectedComponent extends StatelessWidget {
  final String title;
  final String description;
  final VoidCallback onRemove;

  const _SelectedComponent({
    required this.title,
    required this.description,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
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
                    color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.7),
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
}

class _GenerateButton extends StatelessWidget {
  final StoryViewModel vm;
  const _GenerateButton({required this.vm});

  @override
  Widget build(BuildContext context) {
    return Consumer<StoryViewModel>(
      builder: (context, vm, _) {
        final bool canGenerate = !vm.isLoading &&
            vm.selectedCharacter != null &&
            vm.selectedSetting != null &&
            vm.selectedEvent != null;

        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: canGenerate ? () => vm.generate() : null,
            icon: vm.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_stories),
            label: Text(vm.isLoading ? 'Uzun Hikaye Oluşturuluyor...' : 'Uzun Hikaye Oluştur'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle: const TextStyle(fontSize: 18),
            ),
          ),
        );
      },
    );
  }
}

class _StoryDisplay extends StatelessWidget {
  final GeneratedStory story;
  const _StoryDisplay({required this.story});

  @override
  Widget build(BuildContext context) {
    return Consumer<StoryViewModel>(
      builder: (context, vm, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StoryHeader(story: story, onClose: () => vm.resetSelections()),
              const SizedBox(height: 16),
              _StoryContent(story: story),
              const SizedBox(height: 16),
              _StoryComponents(story: story),
              const SizedBox(height: 16),
              _ActionButtons(story: story, onNewStory: () => vm.resetSelections()),
            ],
          ),
        );
      },
    );
  }
}

class _StoryHeader extends StatelessWidget {
  final GeneratedStory story;
  final VoidCallback onClose;
  const _StoryHeader({required this.story, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Card(
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
                    story.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${story.createdAt.day} ${_getMonthName(story.createdAt.month)} ${story.createdAt.year}, ${story.createdAt.hour.toString().padLeft(2, '0')}:${story.createdAt.minute.toString().padLeft(2, '0')}',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getMonthName(int month) {
    const List<String> months = [
      'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
      'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
    ];
    return months[month - 1];
  }
}

class _StoryContent extends StatelessWidget {
  final GeneratedStory story;
  const _StoryContent({required this.story});

  @override
  Widget build(BuildContext context) {
    return Card(
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
              story.content,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoryComponents extends StatelessWidget {
  final GeneratedStory story;
  const _StoryComponents({required this.story});

  @override
  Widget build(BuildContext context) {
    return Card(
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
            _ComponentSummary(
              title: 'Karakter',
              name: story.character.name,
              description: story.character.description,
            ),
            const SizedBox(height: 8),
            _ComponentSummary(
              title: 'Mekan',
              name: story.setting.location,
              description: story.setting.atmosphere,
            ),
            const SizedBox(height: 8),
            _ComponentSummary(
              title: 'Olay',
              name: story.event.title,
              description: story.event.description,
            ),
          ],
        ),
      ),
    );
  }
}

class _ComponentSummary extends StatelessWidget {
  final String title;
  final String name;
  final String description;
  const _ComponentSummary({
    required this.title,
    required this.name,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
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

class _ActionButtons extends StatelessWidget {
  final GeneratedStory story;
  final VoidCallback onNewStory;
  const _ActionButtons({required this.story, required this.onNewStory});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => StoryReaderPage(story: story),
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
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Hikaye kaydedildi!')),
              );
            },
            icon: const Icon(Icons.save),
            label: const Text('Kaydet'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: onNewStory,
            icon: const Icon(Icons.refresh),
            label: const Text('Yeni Hikaye'),
          ),
        ),
      ],
    );
  }
}
