import 'package:flutter/material.dart';
import 'home.dart'; // Import your Home widget

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Live Eye Stress Detection App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const Home(),
    );
  }
}
