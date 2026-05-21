import 'package:flutter/material.dart';
import 'package:mori_game/models/CardModel.dart';
import 'package:mori_game/widgets/CardWidget.dart';
import 'package:mori_game/logic/MoriLogic.dart';

class GameView extends StatelessWidget {
  final int fieldNumber;
  final Suit fieldSuit;
  final List<CardModel> myHand;
  final String myId;
  final String? lastPlayerId;
  final bool isInitialPhase;
  final bool isMyTurn;
  final bool isHost;
  final bool iAmDrawer;
  
  // アクション用コールバック
  final Function(CardModel) onPlay;
  final VoidCallback onDraw;
  final VoidCallback onFlip;
  final VoidCallback onMori;

  const GameView({
    super.key,
    required this.fieldNumber,
    required this.fieldSuit,
    required this.myHand,
    required this.myId,
    required this.lastPlayerId,
    required this.isInitialPhase,
    required this.isMyTurn,
    required this.isHost,
    required this.iAmDrawer,
    required this.onPlay,
    required this.onDraw,
    required this.onFlip,
    required this.onMori,
  });

  @override
  Widget build(BuildContext context) {
    // ロジック層に判定を依頼
    bool canMoriNow = MoriLogic.canMori(
      fieldNumber: fieldNumber,
      hand: myHand,
      lastPlayerId: lastPlayerId,
      myId: myId,
      isInitialPhase: isInitialPhase,
    );

    String turnStatusText = isInitialPhase 
        ? "【初期】数字を合わせて開始！" 
        : (isMyTurn || iAmDrawer ? "あなたの番 / 競争中" : "相手の番です");

    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // 状態テキスト
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(turnStatusText, 
            style: TextStyle(color: (isMyTurn || iAmDrawer) ? Colors.orange : Colors.white70, fontWeight: FontWeight.bold)),
        ),

        // 盤面中央（ドロー・めくる・場札）
        Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _actionBtn("ドロー", isMyTurn && !isInitialPhase ? onDraw : null),
                if (isInitialPhase && isHost) ...[
                  const SizedBox(width: 20),
                  _actionBtn("めくる", onFlip, color: Colors.orange[800], icon: Icons.refresh),
                ],
              ],
            ),
            const SizedBox(height: 20),
            Text('場: ${fieldSuit.name} $fieldNumber', 
              style: const TextStyle(color: Colors.yellow, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            CardWidget(card: CardModel(suit: fieldSuit, number: fieldNumber), onTap: () {}),
          ],
        ),

        // 下部（もりボタン・手札）
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            children: [
              ElevatedButton(
                onPressed: canMoriNow ? onMori : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orangeAccent,
                  disabledBackgroundColor: Colors.grey.withAlpha(50),
                  padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                ),
                child: const Text('もり！', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 20),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: myHand.map((c) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: CardWidget(card: c, onTap: () => onPlay(c)),
                  )).toList(),
                ),
              ),
              const SizedBox(height: 5),
              Text('手札: ${myHand.length}/7', style: const TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _actionBtn(String label, VoidCallback? onTap, {Color? color, IconData? icon}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 70, height: 100,
        decoration: BoxDecoration(
          color: onTap != null ? (color ?? Colors.blueGrey[900]) : Colors.grey,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) Icon(icon, color: Colors.white, size: 20),
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}