import 'package:flutter/material.dart';
import 'dart:math';
import 'package:firebase_database/firebase_database.dart';
import '../../services/firebase_db.dart';
import '../game/game_room_page.dart';

class EntrancePage extends StatefulWidget {
  const EntrancePage({super.key});

  @override
  State<EntrancePage> createState() => _EntrancePageState();
}

class _EntrancePageState extends State<EntrancePage> {
  final TextEditingController _controller = TextEditingController();
  final DatabaseReference _roomsRef = FirebaseDatabase.instance.ref('rooms');

  // ルーム作成処理
  void _createRoom({required bool isPrivate}) {
    // 4桁のランダムなIDを生成
    String newRoomId = (Random().nextInt(9000) + 1000).toString();
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GameRoomPage(
          roomId: newRoomId,
          isPrivate: isPrivate,
        ),
      ),
    );
  }

  // ルーム入室処理
  void _joinRoom(String roomId) async {
    if (roomId.isEmpty) return;

    final db = FirebaseDB(roomId);
    final snapshot = await db.getSnapshot();
    
    // 入室前のバリデーション（存在チェックや開始済みチェック）
    if (snapshot.exists && snapshot.child('gameStarted').value == true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('その部屋は既にゲームが開始されています')),
      );
      return;
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GameRoomPage(roomId: roomId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B5E20),
      appBar: AppBar(
        title: const Text('もり - オンラインロビー', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          // --- 新規作成ボタン ---
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildActionBtn('公開で作成', Icons.public, Colors.orangeAccent, () => _createRoom(isPrivate: false)),
              const SizedBox(width: 15),
              _buildActionBtn('非公開で作成', Icons.lock, Colors.blueGrey, () => _createRoom(isPrivate: true)),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: Colors.white24, indent: 40, endIndent: 40),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text('募集中（公開ルーム）', style: TextStyle(color: Colors.white70, fontSize: 16)),
          ),
          
          // --- 公開ルーム一覧 (リアルタイム更新) ---
          Expanded(
            child: StreamBuilder(
              stream: _roomsRef.onValue,
              builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
                if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
                  return const Center(child: Text('募集中の部屋はありません', style: TextStyle(color: Colors.white38)));
                }

                Map rooms = snapshot.data!.snapshot.value as Map;
                // 公開ルームかつ開始前のみフィルタリング
                List<MapEntry> activeRooms = rooms.entries.where((e) {
                  final data = e.value as Map;
                  return data['isPrivate'] != true && data['gameStarted'] != true && data['players'] != null;
                }).toList();

                if (activeRooms.isEmpty) {
                  return const Center(child: Text('募集中の部屋はありません', style: TextStyle(color: Colors.white38)));
                }

                return ListView.builder(
                  itemCount: activeRooms.length,
                  itemBuilder: (context, index) {
                    String rid = activeRooms[index].key.toString();
                    int count = (activeRooms[index].value['players'] as List).length;

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                      color: Colors.white.withOpacity(0.1),
                      child: ListTile(
                        leading: const Icon(Icons.meeting_room, color: Colors.orangeAccent),
                        title: Text('ルームID: $rid', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: Text('待機中: $count 人', style: const TextStyle(color: Colors.white70)),
                        trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
                        onTap: () => _joinRoom(rid),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          
          // --- ID直接入力エリア ---
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildActionBtn(String label, IconData icon, Color color, VoidCallback onTap) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: const BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'ルームIDを入力して合流',
                hintStyle: TextStyle(color: Colors.white38),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: () => _joinRoom(_controller.text),
            child: const Text('合流'),
          ),
        ],
      ),
    );
  }
}