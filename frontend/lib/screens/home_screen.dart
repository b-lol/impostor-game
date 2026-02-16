import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
      //Save player credentials locally
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('player_id', playerId);
      await prefs.setString('player_name', _nameController.text.trim());
      
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const SizedBox.shrink(),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Spacer(flex: 1),

            // Title from Figma
            const Text(
              "What's your name?",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: Color(0xFF08C8E9),
              ),
            ),
            const SizedBox(height: 24),

            // Outlined text field from original
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Your Name',
                labelStyle: const TextStyle(color: Color(0xFFB0B0B0)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF08C8E9)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFB0B0B0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF08C8E9), width: 2),
                ),
                filled: false,
              ),
              textCapitalization: TextCapitalization.words,
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 24),

            // Continue button
            ElevatedButton(
              onPressed: _isLoading ? null : _registerPlayer,
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Continue'),
            ),

            const Spacer(flex: 3),
          ],
        ),
      ),
    );
  }
}