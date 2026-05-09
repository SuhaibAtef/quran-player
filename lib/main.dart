import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

void main() {
  runApp(const QuranPlayerApp());
}

class QuranPlayerApp extends StatelessWidget {
  const QuranPlayerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quran Player',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: FLocalizations.localizationsDelegates,
      supportedLocales: FLocalizations.supportedLocales,
      theme: FThemes.zinc.light.toApproximateMaterialTheme(),
      builder: (context, child) =>
          FTheme(data: FThemes.zinc.light, child: child!),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return FScaffold(
      header: const FHeader(title: Text('Quran Player')),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Welcome to Quran Player'),
            const SizedBox(height: 16),
            FButton(onPress: () {}, child: const Text('Get started')),
          ],
        ),
      ),
    );
  }
}
