import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

class BootstrappingScreenKeys {
  const BootstrappingScreenKeys._();

  static const root = Key('bootstrapping.root');
  static const indicator = Key('bootstrapping.indicator');
}

class BootstrappingScreen extends StatelessWidget {
  const BootstrappingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Use the indeterminate linear bar inside a centered, narrow column so
    // the loading state stays calm instead of a full-bleed bar.
    return FScaffold(
      key: BootstrappingScreenKeys.root,
      child: Center(
        child: SizedBox(
          width: 240,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              FProgress(key: BootstrappingScreenKeys.indicator),
              SizedBox(height: 16),
              Text('Verifying Quran data…'),
            ],
          ),
        ),
      ),
    );
  }
}
