import 'package:flutter/material.dart';

import 'database_factory_init_stub.dart'
    if (dart.library.io) 'database_factory_init_io.dart' as db_factory;
import 'screens/main_shell_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  db_factory.configureDatabaseFactoryForPlatform();
  runApp(const EduBooksApp());
}

class EduBooksApp extends StatelessWidget {
  const EduBooksApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'توزيع الكتب',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      builder: (context, child) {
        final content = child ?? const SizedBox.shrink();
        return Directionality(
          textDirection: TextDirection.rtl,
          child: content,
        );
      },
      home: const MainShellScreen(),
    );
  }
}
