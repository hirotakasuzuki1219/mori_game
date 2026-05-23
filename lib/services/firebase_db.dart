import 'package:firebase_database/firebase_database.dart';
import '../features/game/game_board_view.dart';

/// Firebaseとの通信をカプセル化。
class FirebaseDB {
  final String roomId;
  late final DatabaseReference _roomRef;

  FirebaseDB(this.roomId) {
    _roomRef = FirebaseDatabase.instance.ref('rooms/$roomId');
  }

  Stream<DatabaseEvent> get roomStream => _roomRef.onValue;

  Future<void> setupRoom(String myId, List<CardWidget> deck, bool isPrivate) async {
    await _roomRef.set({
      'host': myId,
      'players': [myId],
      'playerHands': {myId: 5},
      'deck': deck.map((c) => {'number': c.number, 'suit': c.suit.name}).toList(),
      'field': {'number': -1, 'suit': 'joker'},
      'isInitialPhase': true,
      'currentTurnIndex': 0,
      'isDrawCompetitive': false,
      'gameStarted': false,
      'isPrivate': isPrivate,
    });
  }

  Future<void> playCard(int nextTurn, CardWidget card, String myId) async {
    await _roomRef.update({
      'field': {'number': card.number, 'suit': card.suit.name},
      'isInitialPhase': false,
      'currentTurnIndex': nextTurn,
      'lastPlayerId': myId,
    });
  }

  Future<void> updateGameStatus(Map<String, dynamic> updates) => _roomRef.update(updates);
  Future<DataSnapshot> getSnapshot() => _roomRef.get();
  Future<void> deleteRoom() => _roomRef.remove();
}