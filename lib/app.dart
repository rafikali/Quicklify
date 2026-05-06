import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'features/shell/app_shell.dart';

class QuicklifyApp extends StatelessWidget {
  final String? sharedUrl;

  const QuicklifyApp({super.key, this.sharedUrl});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quicklify',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: AppShell(sharedUrl: sharedUrl),
    );
  }
}
