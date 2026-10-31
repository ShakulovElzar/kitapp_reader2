import 'package:flutter/material.dart';

import 'screens/app_shell.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';

class KitappApp extends StatelessWidget {
  const KitappApp({super.key, required this.state});

  final AppStateController state;

  @override
  Widget build(BuildContext context) {
    return AppStateScope(
      state: state,
      child: AnimatedBuilder(
        animation: state,
        builder: (context, _) => MaterialApp(
          title: 'Kitapp',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          // Guests browse the catalog; signing in is asked for on buy or read.
          home: const AppShell(),
        ),
      ),
    );
  }
}
