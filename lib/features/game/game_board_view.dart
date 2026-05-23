import 'package:flutter/material.dart';
import '../../logic/game_rules.dart'; // ここを確実にインポート

enum Suit { spade, heart, diamond, club, joker }

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
    // GameRulesが正しく参照できるはずです
    bool canMori = GameRules.canMori(
      fieldNumber: fieldNumber,
      hand: myHand,
      lastPlayerId: lastPlayerId,
      myId: myId,
      isInitialPhase: isInitialPhase,
    );

    return Scaffold(
      backgroundColor: const Color(0xFF1B5E20),
      appBar: AppBar(title: Text('ルーム: $roomId'), backgroundColor: Colors.transparent, elevation: 0),
      body: Column(
        children: [
          _buildOthersStatus(),
          const Spacer(),
          Column(
            children: [
              if (isInitialPhase && isHost) ElevatedButton(onPressed: onFlip, child: const Text("めくって開始")),
              const SizedBox(height: 20),
              fieldNumber == -1 ? const Icon(Icons.style, size: 80, color: Colors.white24) : CardWidget(suit: fieldSuit, number: fieldNumber),
            ],
          ),
          const Spacer(),
          if (canMori) ElevatedButton(onPressed: onMori, child: const Text("もり！")),
          SizedBox(
            height: 120,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: myHand.map((c) => Padding(padding: const EdgeInsets.all(4), child: CardWidget(suit: c.suit, number: c.number, onTap: () => onPlay(c)))).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOthersStatus() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: playerIds.where((id) => id != myId).map((id) => Padding(
        padding: const EdgeInsets.all(8),
        child: Column(children: [const Icon(Icons.person, color: Colors.white), Text('${handCounts[id] ?? 0}枚', style: const TextStyle(color: Colors.white))]),
      )).toList(),
    );
  }
}