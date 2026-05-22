import 'package:flutter/material.dart';
import 'dart:math';
import 'package:firebase_database/firebase_database.dart';
import 'package:mori_game/services/FirebaseService.dart';
import 'GameController.dart';

class EntrancePage extends StatefulWidget {
  const EntrancePage({super.key});

  @override
  State<EntrancePage> createState() => _EntrancePageState();
}

class _EntrancePageState extends State<EntrancePage> {
  final TextEditingController _controller = TextEditingController();
  final DatabaseReference _roomsRef = FirebaseDatabase.instance.ref('rooms');

  // ルーム作成（引数で公開・非公開を切り替え）
  void _createRoom({required bool isPrivate}) {
    String newRoomId = (Random().nextInt(9000) + 1000).toString();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GameController(roomId: newRoomId, isPrivate: isPrivate),
      ),
    );
  }

  void _joinRoom(String roomId) async {
    if (roomId.isEmpty) return;
    final db = FirebaseService(roomId);
    final snapshot = await db.getRoomSnapshot();
    
    if (snapshot.exists && snapshot.child('gameStarted').value == true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ゲーム進行中です')));
      return;
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => GameController(roomId: roomId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B5E20),
      appBar: AppBar(
        title: const Text('もり ロビー', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          const SizedBox(height: 10),
          // --- 作成ボタンエリア ---
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLargeBtn('公開で遊ぶ', Icons.public, Colors.orangeAccent, () => _createRoom(isPrivate: false)),
              const SizedBox(width: 15),
              _buildLargeBtn('友達と遊ぶ', Icons.lock, Colors.blueGrey, () => _createRoom(isPrivate: true)),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: Colors.white24),
          const Text('公開されている対戦', style: TextStyle(color: Colors.white70, fontSize: 16)),
          
          // --- ルーム一覧 (isPrivate == true を除外) ---
          Expanded(
            child: StreamBuilder(
              stream: _roomsRef.onValue,
              builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
                if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
                  return const Center(child: Text('部屋がありません', style: TextStyle(color: Colors.white38)));
                }

                Map rooms = snapshot.data!.snapshot.value as Map;
                List<MapEntry> activeRooms = rooms.entries.where((entry) {
                  final data = entry.value as Map;
                  // 1. 開始前 2. プレイヤーがいる 3. 非公開(isPrivate)ではない
                  return data['gameStarted'] == false && 
                         data['players'] != null && 
                         data['isPrivate'] != true; 
                }).toList();

                if (activeRooms.isEmpty) return const Center(child: Text('募集中はありません', style: TextStyle(color: Colors.white38)));

                return ListView.builder(
                  itemCount: activeRooms.length,
                  itemBuilder: (context, index) {
                    String rid = activeRooms[index].key.toString();
                    return Card(
                      color: Colors.white10,
                      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                      child: ListTile(
                        title: Text('ID: $rid', style: const TextStyle(color: Colors.white)),
                        trailing: const Icon(Icons.login, color: Colors.white),
                        onTap: () => _joinRoom(rid),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          
          // --- 直接入力 ---
          _buildBottomInput(),
        ],
      ),
    );
  }

  Widget _buildLargeBtn(String label, IconData icon, Color color, VoidCallback onTap) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
    );
  }

  Widget _buildBottomInput() {
    return Container(
      padding: const EdgeInsets.all(15),
      color: Colors.black38,
      child: Row(
        children: [
          Expanded(child: TextField(controller: _controller, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: 'ルームIDで検索', hintStyle: TextStyle(color: Colors.white38)))),
          ElevatedButton(onPressed: () => _joinRoom(_controller.text), child: const Text('ID入室')),
        ],
      ),
    );
  }
}