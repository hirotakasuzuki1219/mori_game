import 'package:flutter/material.dart';
import '../../logic/game_rules.dart';

enum Suit { spade, heart, diamond, club, joker }

// --- CardWidget は以前の通り ---
class CardWidget extends StatelessWidget {
  final int number;
  final Suit suit;
  final VoidCallback? onTap;
  const CardWidget({super.key, required this.number, required this.suit, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 60, height: 90,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.black, width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildSuitIcon(),
            Text(suit == Suit.joker ? 'J' : '$number',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black)),
          ],
        ),
      ),
    );
  }

  Widget _buildSuitIcon() {
    if (suit == Suit.joker) return const Icon(Icons.face, color: Colors.purple, size: 26);
    String mark = {Suit.spade: '♠', Suit.heart: '♥', Suit.diamond: '♦', Suit.club: '♣'}[suit]!;
    Color color = (suit == Suit.heart || suit == Suit.diamond) ? Colors.red : Colors.black;
    return Text(mark, style: TextStyle(fontSize: 24, color: color));
  }
}

// --- GameBoardView 本体 ---
class GameBoardView extends StatelessWidget {
  final String roomId;
  final int fieldNumber;
  final Suit fieldSuit;
  final List<CardWidget> myHand;
  final List<String> playerIds;
  final String myId;
  final Map<String, int> handCounts;
  final bool isMyTurn;
  final bool isHost;
  final String? lastPlayerId;
  final bool isInitialPhase;

  final Function(CardWidget) onPlay;
  final VoidCallback onDraw;
  final VoidCallback onFlip;
  final VoidCallback onMori;

  const GameBoardView({
    super.key, required this.roomId, required this.fieldNumber, required this.fieldSuit,
    required this.myHand, required this.playerIds, required this.myId,
    required this.handCounts, required this.isMyTurn, required this.isHost,
    this.lastPlayerId, required this.isInitialPhase,
    required this.onPlay, required this.onDraw, required this.onFlip, required this.onMori,
  });

  @override
  Widget build(BuildContext context) {
    bool canMori = GameRules.canMori(
      fieldNumber: fieldNumber, hand: myHand,
      lastPlayerId: lastPlayerId, myId: myId, isInitialPhase: isInitialPhase,
    );

    return Scaffold(
      backgroundColor: const Color(0xFF1B5E20),
      appBar: AppBar(title: Text('ルーム: $roomId'), backgroundColor: Colors.transparent, elevation: 0),
      body: Column(
        children: [
          _buildOthersStatus(),
          const Spacer(),
          _buildFieldArea(), // ← ここで呼び出し
          const Spacer(),
          if (canMori) 
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: ElevatedButton(
                onPressed: onMori,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15)),
                child: const Text("もり！", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              ),
            ),
          _buildMyHandArea(),
        ],
      ),
    );
  }

  // --- パーツごとに切り出したメソッド ---

  /// 1. 他のプレイヤーの状態表示
  Widget _buildOthersStatus() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: playerIds.where((id) => id != myId).map((id) => Padding(
        padding: const EdgeInsets.all(8),
        child: Column(children: [const Icon(Icons.person, color: Colors.white), Text('${handCounts[id] ?? 0}枚', style: const TextStyle(color: Colors.white))]),
      )).toList(),
    );
  }

  /// 2. 場のカードエリア（今回の修正のメイン）
  Widget _buildFieldArea() {
    return Column(
      children: [
        if (isInitialPhase && isHost)
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: ElevatedButton(
              onPressed: onFlip,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.yellow[800]),
              child: const Text("山札をめくって開始", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        // カード本体
        fieldNumber == -1 
            ? const Icon(Icons.style, size: 80, color: Colors.white24) 
            : CardWidget(suit: fieldSuit, number: fieldNumber),
        const SizedBox(height: 8),
        const Text("場のカード", style: TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  /// 3. 自分の手札エリア
  Widget _buildMyHandArea() {
    return Container(
      height: 120,
      padding: const EdgeInsets.only(bottom: 20),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: myHand.map((c) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: CardWidget(suit: c.suit, number: c.number, onTap: () => onPlay(c)),
        )).toList(),
      ),
    );
  }
}