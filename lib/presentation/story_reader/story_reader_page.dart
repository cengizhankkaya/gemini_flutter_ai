import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gemini_flutter_ai/data/models/story_models.dart';
import 'package:gemini_flutter_ai/presentation/story_reader/reader_view_model.dart';

class StoryReaderPage extends StatefulWidget {
  final GeneratedStory story;

  const StoryReaderPage({super.key, required this.story});

  @override
  State<StoryReaderPage> createState() => _StoryReaderPageState();
}

class _StoryReaderPageState extends State<StoryReaderPage> {
  late final ReaderViewModel viewModel;
  late final PageController pageController;

  @override
  void initState() {
    super.initState();
    viewModel = ReaderViewModel(story: widget.story);
    pageController = PageController();
  }

  @override
  void dispose() {
    viewModel.dispose();
    pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: viewModel,
      child: const _StoryReaderView(),
    );
  }
}

class _StoryReaderView extends StatelessWidget {
  const _StoryReaderView();

  @override
  Widget build(BuildContext context) {
    return Consumer<ReaderViewModel>(
      builder: (context, vm, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text(vm.story.title),
            actions: const [_FontControls()],
          ),
          body: Container(
            color: const Color(0xFFF8F5E7),
            child: Stack(
              children: [
                PageView.builder(
                  onPageChanged: (index) => vm.setPage(index),
                  itemCount: vm.chapters.length,
                  itemBuilder: (context, index) {
                    final chapter = vm.chapters[index];
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
                                  color: Colors.black.withOpacity(0.06),
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
                                        color: const Color(0xFF2B2B2B),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Divider(color: Colors.grey.shade300, height: 24),
                                    const SizedBox(height: 4),
                                    Text(
                                      chapter.content,
                                      textAlign: TextAlign.justify,
                                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                        fontSize: vm.fontSize,
                                        height: 1.7,
                                        color: const Color(0xFF2B2B2B),
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
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Bölüm ${vm.currentPage + 1}/${vm.chapters.length}',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FontControls extends StatelessWidget {
  const _FontControls();

  @override
  Widget build(BuildContext context) {
    return Consumer<ReaderViewModel>(
      builder: (context, vm, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Yazı boyutu küçült',
              onPressed: vm.decreaseFont,
              icon: const Icon(Icons.text_decrease),
            ),
            IconButton(
              tooltip: 'Yazı boyutu büyüt',
              onPressed: vm.increaseFont,
              icon: const Icon(Icons.text_increase),
            ),
          ],
        );
      },
    );
  }
}
