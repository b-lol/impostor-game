import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'menu_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _nameController = TextEditingController();
  final ApiService _apiService = ApiService();
  bool _isLoading = false;

  Future<void> _registerPlayer() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final playerId = await _apiService.registerPlayer(_nameController.text.trim());

    setState(() => _isLoading = false);

    if (playerId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MenuScreen(
            playerId: playerId,
            playerName: _nameController.text.trim(),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to register. Is the server running?')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Impostor Game'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Welcome!',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Enter your name to get started',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Your Name',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _registerPlayer,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Continue', style: TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}