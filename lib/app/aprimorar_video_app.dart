import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import 'launch_page.dart';

class AprimorarVideoApp extends StatelessWidget {
  const AprimorarVideoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VanGogh',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      home: const LaunchPage(),
    );
  }
}
