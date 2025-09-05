import 'package:flutter/material.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Settings',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: const Center(
        child: Text(
          'Settings Screen - Coming Soon',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}
