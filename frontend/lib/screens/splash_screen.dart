import 'package:flutter/material.dart';
import 'home_screen.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Spacer(flex: 2),

            // Logo
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 200, maxHeight: 200),
              child: Image.asset(
                'assets/AppIconTransparent',
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 16),

            // Title
            const Text(
              'Impostor',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF08C8E9),
              ),
            ),
            const SizedBox(height: 8),

            // Tagline
            const Text(
              'Can you blend in?',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFFB0B0B0),
              ),
            ),

            const Spacer(flex: 3),

            // Start Button
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const HomeScreen(),
                  ),
                );
              },
              child: const Text('Start'),
            ),

            const Spacer(flex: 1),
          ],
        ),
      ),
    );
  }
}