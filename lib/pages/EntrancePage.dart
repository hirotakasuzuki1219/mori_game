import 'package:flutter/material.dart';
import 'dart:math';
import 'GameController.dart';

class EntrancePage extends StatefulWidget {
  const EntrancePage({super.key});

  @override
  State<EntrancePage> createState() => _EntrancePageState();
}

class _EntrancePageState extends State<EntrancePage> {
  final TextEditingController _controller = TextEditingController();

  void _createRoom() {
    String newRoomId = (Random().nextInt(9000) + 1000).toString();
    _joinRoom(newRoomId);
  }

  void _joinRoom(String roomId) {
    if (roomId.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => GameController(roomId: roomId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B5E20),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.style, color: Colors.white, size: 80),
              const SizedBox(height: 16),
              const Text('もり - Mori Game', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
              const SizedBox(height: 60),
              ElevatedButton(
                onPressed: _createRoom,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(200, 50),
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.green[900],
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                child: const Text('新しく部屋を作る'),
              ),
              const SizedBox(height: 40),
              const Text('または', style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 40),
              SizedBox(
                width: 200,
                child: TextField(
                  controller: _controller,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 20),
                  decoration: InputDecoration(
                    fillColor: Colors.white, filled: true,
                    hintText: 'ルームID (4桁)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _joinRoom(_controller.text),
                style: ElevatedButton.styleFrom(minimumSize: const Size(200, 50)),
                child: const Text('部屋に入る'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}