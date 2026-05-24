import 'package:flutter/material.dart';
import '../../logic/game_rules.dart';

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
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.black)),
        child: Column(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _buildSuitIcon(),
          Text(suit == Suit.joker ? 'J' : '$number', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black)),
        ]),
      ),
    );
  }

  Widget _buildSuitIcon() {
    String mark = {Suit.spade: '♠', Suit.heart: '♥', Suit.diamond: '♦', Suit.club: '♣', Suit.joker: '🤡'}[suit]!;
    Color color = (suit == Suit.heart || suit == Suit.diamond) ? Colors.red : Colors.black;
    return Text(mark, style: TextStyle(fontSize: 20, color: color));
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
    bool canMori = GameRules.canMori(fieldNumber: fieldNumber, hand: myHand, lastPlayerId: lastPlayerId, myId: myId, isInitialPhase: isInitialPhase);

    return Scaffold(
      backgroundColor: const Color(0xFF1B5E20),
      appBar: AppBar(title: Text('ルーム: $roomId'), backgroundColor: Colors.transparent),
      body: Column(
        children: [
          _buildOthers(),
          const Spacer(),
          _buildFieldArea(),
          const Spacer(),
          if (canMori) ElevatedButton(onPressed: onMori, child: const Text("もり！")),
          _buildHand(),
        ],
      ),
    );
  }

  Widget _buildOthers() {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: playerIds.where((id) => id != myId).map((id) => Column(children: [const Icon(Icons.person), Text('${handCounts[id] ?? 0}枚')])).toList());
  }

  Widget _buildFieldArea() {
    return Column(children: [
      if (isInitialPhase && isHost) ElevatedButton(onPressed: onFlip, child: const Text("開始")),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        GestureDetector(onTap: onDraw, child: Container(width: 60, height: 90, decoration: BoxDecoration(color: Colors.blueGrey, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.help_outline))),
        const SizedBox(width: 20),
        fieldNumber == -1 ? const SizedBox(width: 60, height: 90) : CardWidget(suit: fieldSuit, number: fieldNumber),
      ]),
    ]);
  }

  Widget _buildHand() {
    return SizedBox(height: 120, child: ListView(scrollDirection: Axis.horizontal, children: myHand.map((c) => Padding(padding: const EdgeInsets.all(4), child: CardWidget(suit: c.suit, number: c.number, onTap: () => onPlay(c)))).toList()));
  }
}