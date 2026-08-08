import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/reader_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.immersiveSticky,
  );

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor:
          Colors.transparent,
    ),
  );

  runApp(
    const MyApp(),
  );
}

class MyApp
    extends StatelessWidget {
  const MyApp({
    super.key,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return const MaterialApp(
      debugShowCheckedModeBanner:
          false,
      home: ReaderScreen(),
    );
  }
}