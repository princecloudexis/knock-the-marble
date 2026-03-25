import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';

class KnockTheMarbleApp extends ConsumerWidget {
  const KnockTheMarbleApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Knock the Marble',
      theme: AppTheme.darkTheme,
      home: const SplashScreen(),
    );
  }
}
