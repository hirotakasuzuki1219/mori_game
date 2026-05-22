import 'package:flutter/material.dart';
import 'package:mori_game/models/CardModel.dart';
import 'package:mori_game/logic/MoriLogic.dart';

class GameView extends StatelessWidget {
  final int fieldNumber;
  final Suit fieldSuit;
  final List<CardModel> myHand;
  final List<String> playerIds;
  final String myId;
  final Map<String, int> handCounts;
  final int currentTurnIndex;
  final String? lastPlayerId;
  final bool isInitialPhase;
  final bool isMyTurn;
  final bool isHost;
  final bool iAmDrawer;
  
  final Function(CardModel) onPlay;
  final VoidCallback onDraw;
  final VoidCallback onFlip;
  final VoidCallback onMori;

  const GameView({
    super.key,
    required this.fieldNumber,
    required this.fieldSuit,
    required this.myHand,
    required this.playerIds,
    required this.myId,
    required this.handCounts,
    required this.currentTurnIndex,
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
    bool canMoriNow = MoriLogic.canMori(
      fieldNumber: fieldNumber,
      hand: myHand,
      lastPlayerId: lastPlayerId,
      myId: myId,
      isInitialPhase: isInitialPhase,
    );

    return Column(
      children: [
        _buildOthersStatus(),
        const Spacer(),
        Text(
          fieldNumber == -1 
            ? (isHost ? "山札をめくって開始してください" : "ホストの開始を待っています...")
            : (isInitialPhase ? "【初期フェーズ】数字を合わせろ" : (isMyTurn || iAmDrawer ? "あなたの番" : "相手の番です")),
          style: TextStyle(
            color: (isMyTurn || iAmDrawer || fieldNumber == -1) ? Colors.orange : Colors.white70,
            fontWeight: FontWeight.bold,
            fontSize: 16
          ),
        ),
        const SizedBox(height: 15),
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
            // 修正箇所：fieldNumberが-1のときはカードの枠だけ表示
            fieldNumber == -1 
              ? Container(
                  width: 60, height: 90,
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white24, width: 2),
                  ),
                  child: const Center(child: Icon(Icons.style, color: Colors.white10, size: 40)),
                )
              : CardModel(suit: fieldSuit, number: fieldNumber),
          ],
        ),
        const Spacer(),
        ElevatedButton(
          onPressed: canMoriNow ? onMori : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orangeAccent,
            disabledBackgroundColor: Colors.grey.withAlpha(50),
            padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 18),
          ),
          child: const Text('もり！', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 30),
        Container(
          padding: const EdgeInsets.only(bottom: 30),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: myHand.map((c) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: CardModel(
                  suit: c.suit,
                  number: c.number,
                  onTap: () => onPlay(c),
                ),
              )).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOthersStatus() {
    final others = playerIds.where((id) => id != myId).toList();
    final activePlayerId = playerIds.isNotEmpty ? playerIds[currentTurnIndex % playerIds.length] : "";

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: others.map((id) {
          bool isHisTurn = (id == activePlayerId);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              children: [
                CircleAvatar(
                  backgroundColor: isHisTurn ? Colors.orange : Colors.grey[800],
                  radius: 20,
                  child: Icon(Icons.person, color: isHisTurn ? Colors.white : Colors.white54),
                ),
                const SizedBox(height: 4),
                Text('${handCounts[id] ?? 0} 枚', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _actionBtn(String label, VoidCallback? onTap, {Color? color, IconData? icon}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 75, height: 105,
        decoration: BoxDecoration(
          color: onTap != null ? (color ?? Colors.blueGrey[900]) : Colors.grey,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) Icon(icon, color: Colors.white, size: 22),
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}