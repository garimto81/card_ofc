import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'ui/screens/home_screen.dart';

void main() {
  runApp(const ProviderScope(child: OFCApp()));
}

class OFCApp extends StatelessWidget {
  const OFCApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OFC Pineapple',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
