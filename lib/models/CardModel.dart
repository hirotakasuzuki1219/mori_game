import 'package:flutter/material.dart';

enum Suit { spade, heart, diamond, club, joker }

class CardModel extends StatelessWidget {
  final int number;
  final Suit suit;
  final VoidCallback? onTap;

  const CardModel({
    super.key,
    required this.number,
    required this.suit,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 60,
        height: 90,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.black, width: 1.5),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(2, 2))
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildSuitIcon(),
            Text(
              suit == Suit.joker ? 'J' : '$number',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// アイコンエラーを回避するため、特殊文字（テキスト）でマークを表現
  Widget _buildSuitIcon() {
    String mark;
    Color color;

    switch (suit) {
      case Suit.spade:
        mark = '♠';
        color = Colors.black;
        break;
      case Suit.heart:
        mark = '♥';
        color = Colors.red;
        break;
      case Suit.diamond:
        mark = '♦';
        color = Colors.red;
        break;
      case Suit.club:
        mark = '♣';
        color = Colors.black;
        break;
      case Suit.joker:
        return const Icon(Icons.face, color: Colors.purple, size: 26);
    }

    return Text(
      mark,
      style: TextStyle(
        fontSize: 24,
        color: color,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}