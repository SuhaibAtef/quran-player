import 'package:flutter/material.dart';
import 'package:tarteel_qul/fixtures.dart';
import 'package:tarteel_qul/tarteel_qul.dart';

/// A minimal demo of `tarteel_qul`.
///
/// It renders the engine's built-in [DemoMushafAssetSource] — an invented
/// three-page mini-layout drawn with a box-glyph stub font — so the package is
/// runnable without downloading any QUL resource. A real consumer supplies a
/// [MushafAssetSource] backed by genuine QUL layout, word, and font data.
void main() => runApp(const TarteelQulExampleApp());

class TarteelQulExampleApp extends StatelessWidget {
  const TarteelQulExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'tarteel_qul example',
      theme: ThemeData(useMaterial3: true),
      home: const _DemoScreen(),
    );
  }
}

class _DemoScreen extends StatefulWidget {
  const _DemoScreen();

  @override
  State<_DemoScreen> createState() => _DemoScreenState();
}

class _DemoScreenState extends State<_DemoScreen> {
  final MushafAssetSource _source = DemoMushafAssetSource();
  late final Future<MushafResult<MushafLayoutRepository>> _open =
      MushafLayoutRepository.open(_source);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('tarteel_qul — demo layout')),
      body: FutureBuilder<MushafResult<MushafLayoutRepository>>(
        future: _open,
        builder: (context, snapshot) {
          final result = snapshot.data;
          if (result == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return switch (result) {
            MushafErr(:final failure) => Center(
              child: Text('Failed to open the demo layout: $failure'),
            ),
            MushafOk(:final value) => _Reader(
              repository: value,
              source: _source,
            ),
          };
        },
      ),
    );
  }
}

class _Reader extends StatefulWidget {
  const _Reader({required this.repository, required this.source});

  final MushafLayoutRepository repository;
  final MushafAssetSource source;

  @override
  State<_Reader> createState() => _ReaderState();
}

class _ReaderState extends State<_Reader> {
  late final MushafController _controller = MushafController(
    pageCount: widget.repository.pageCount,
  );
  String _status = 'Tap a word to read its ayah event';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: MushafView(
            repository: widget.repository,
            assetSource: widget.source,
            controller: _controller,
            onAyahTap: (ayah) => setState(
              () => _status = 'Tapped ayah ${ayah.surah}:${ayah.ayah}',
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ElevatedButton(
                onPressed: _controller.previous,
                child: const Text('Previous'),
              ),
              Expanded(
                child: Text(
                  _status,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              ElevatedButton(
                onPressed: _controller.next,
                child: const Text('Next'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
