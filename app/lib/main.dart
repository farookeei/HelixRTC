import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'presentation/screens/video_call_screen.dart';

void main() {
  runApp(
    // ProviderScope is mandatory for Riverpod to store all states
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HelixRTC',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark, // Sleek dark mode fit for video apps
        primaryColor: Colors.blueAccent,
        useMaterial3: true,
      ),
      home: const VideoCallScreen(), // Load our WebRTC call screen!
    );
  }
}
