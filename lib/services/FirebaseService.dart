import 'package:firebase_database/firebase_database.dart';
import 'package:mori_game/models/CardModel.dart';

class FirebaseService {
  final String roomId;
  late final DatabaseReference _roomRef;

  FirebaseService(this.roomId) {
    _roomRef = FirebaseDatabase.instance.ref('rooms/$roomId');
  }

  Stream<DatabaseEvent> get roomStream => _roomRef.onValue;

  Future<void> setupRoom(String myId, List<CardModel> deck, {required bool isPrivate}) async {
    await _roomRef.set({
      'host': myId,
      'players': [myId],
      'playerHands': {myId: 5},
      'deck': deck.map((c) => {'number': c.number, 'suit': c.suit.name}).toList(),
      // 共有の鍵：初期状態は -1
      'field': {'number': -1, 'suit': 'joker'},
      'isInitialPhase': true,
      'currentTurnIndex': 0,
      'isDrawCompetitive': false,
      'lastPlayerId': 'system',
      'gameStarted': false,
      'isPrivate': isPrivate,
    });
  }

  Future<void> startGame() async {
    await _roomRef.update({'gameStarted': true});
  }

  Future<void> updatePlayers(List<String> players) async {
    await _roomRef.child('players').set(players);
  }

  Future<void> syncHandCount(String myId, int count) async {
    await _roomRef.child('playerHands').update({myId: count});
  }

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

  // ここが場札の共有に最も重要：field全体を上書き
  Future<void> flipCard(List<dynamic> nextDeck, CardModel nextCard) async {
    await _roomRef.update({
      'field': {'number': nextCard.number, 'suit': nextCard.suit.name},
      'deck': nextDeck,
      'lastPlayerId': 'system',
    });
  }

  Future<DataSnapshot> getRoomSnapshot() => _roomRef.get();
  Future<void> deleteRoom() => _roomRef.remove();
}