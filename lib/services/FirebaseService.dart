import 'package:firebase_database/firebase_database.dart';
import 'package:mori_game/models/CardModel.dart';

class FirebaseService {
  final DatabaseReference _roomRef = FirebaseDatabase.instance.ref('rooms/test_room');

  // データのリアルタイム購読用ストリーム
  Stream<DatabaseEvent> get roomStream => _roomRef.onValue;

  // 初期化：ホストによるルーム作成
  Future<void> setupRoom(String myId, List<CardModel> deck, CardModel firstCard) async {
    await _roomRef.set({
      'host': myId,
      'players': [myId],
      'playerHands': {myId: 5},
      'deck': deck.map((c) => {'number': c.number, 'suit': c.suit.name}).toList(),
      'field': {'number': firstCard.number, 'suit': firstCard.suit.name},
      'isInitialPhase': true,
      'currentTurnIndex': 0,
      'isDrawCompetitive': false,
      'lastPlayerId': 'system',
    });
  }

  // プレイヤーリストのみ更新
  Future<void> updatePlayers(List<String> players) async {
    await _roomRef.child('players').set(players);
  }

  // 手札枚数の同期
  Future<void> syncHandCount(String myId, int count) async {
    await _roomRef.child('playerHands').update({myId: count});
  }

  // カードを出す
  Future<void> playCard({
    required int nextTurnIndex,
    required CardModel card,
    required String myId,
  }) async {
    await _roomRef.update({
      'field': {'number': card.number, 'suit': card.suit.name},
      'isInitialPhase': false,
      'currentTurnIndex': nextTurnIndex,
      'isDrawCompetitive': false,
      'lastPlayerId': myId,
    });
  }

  // カードを引く
  Future<void> drawCard({
    required List<dynamic> remainingDeck,
    required int nextTurnIndex,
  }) async {
    await _roomRef.update({
      'deck': remainingDeck,
      'currentTurnIndex': nextTurnIndex,
      'isDrawCompetitive': true,
    });
  }

  // ホストによる場札の更新
  Future<void> flipCard(List<dynamic> nextDeck, CardModel nextCard) async {
    await _roomRef.update({
      'field': {'number': nextCard.number, 'suit': nextCard.suit.name},
      'deck': nextDeck,
      'lastPlayerId': 'system',
    });
  }

  // 汎用：スナップショット取得
  Future<DataSnapshot> getRoomSnapshot() => _roomRef.get();

  // ルームの削除（リセット）
  Future<void> deleteRoom() => _roomRef.remove();
}