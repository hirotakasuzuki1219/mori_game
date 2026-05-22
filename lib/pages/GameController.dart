import 'package:flutter/material.dart';
import 'package:mori_game/models/CardModel.dart';
import 'package:mori_game/services/FirebaseService.dart';
import 'package:mori_game/widgets/GameView.dart';
import 'dart:async';
import 'package:firebase_database/firebase_database.dart';

class GameController extends StatefulWidget {
  final String roomId;
  const GameController({super.key, required this.roomId});

  @override
  State<GameController> createState() => _GameControllerState();
}

class _GameControllerState extends State<GameController> {
  late final FirebaseService _db;
  StreamSubscription<DatabaseEvent>? _subscription;

  late String myId;
  String? hostId;
  List<CardModel> firebaseDeck = [];
  List<CardModel> myHand = [];
  List<String> playerIds = [];
  Map<String, int> handCounts = {};
  int fieldNumber = -1;
  Suit fieldSuit = Suit.joker;
  bool isInitialPhase = true;
  bool isInitializing = true;
  int currentTurnIndex = 0;
  bool isDrawCompetitive = false;
  String? lastPlayerId;

  @override
  void initState() {
    super.initState();
    _db = FirebaseService(widget.roomId);
    myId = DateTime.now().millisecondsSinceEpoch.toString();
    _listenToRoom();
    _initializeGame();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _listenToRoom() {
    _subscription = _db.roomStream.listen((event) {
      final data = event.snapshot.value as Map?;
      if (data == null || !mounted) return;
      setState(() {
        hostId = data['host']?.toString();
        playerIds = List<String>.from(data['players'] ?? []);
        currentTurnIndex = (data['currentTurnIndex'] as num? ?? 0).toInt();
        isDrawCompetitive = data['isDrawCompetitive'] ?? false;
        lastPlayerId = data['lastPlayerId']?.toString();
        if (data['playerHands'] != null) handCounts = Map<String, int>.from(data['playerHands']);
        if (data['deck'] != null) {
          firebaseDeck = (data['deck'] as List).map((i) => CardModel(
            number: (i['number'] as num).toInt(),
            suit: Suit.values.firstWhere((e) => e.name == i['suit']),
          )).toList();
        }
        final field = data['field'] as Map?;
        if (field != null) {
          fieldNumber = (field['number'] as num).toInt();
          fieldSuit = Suit.values.firstWhere((e) => e.name == field['suit']);
          isInitialPhase = data['isInitialPhase'] ?? true;
        }
      });
    });
  }

  Future<void> _initializeGame() async {
    setState(() => isInitializing = true);
    final snapshot = await _db.getRoomSnapshot();
    
    if (!snapshot.exists || snapshot.child('host').value == null) {
      await _setupNewRoom();
    } else {
      await _joinAsGuest();
    }
    setState(() => isInitializing = false);
  }

  Future<void> _setupNewRoom() async {
    List<CardModel> deck = _generateFullDeck()..shuffle();
    final hand = deck.sublist(0, 5);
    deck.removeRange(0, 5);
    final first = deck.removeLast();
    await _db.setupRoom(myId, deck, first);
    setState(() { myHand = hand; });
  }

  Future<void> _joinAsGuest() async {
    final snapshot = await _db.getRoomSnapshot();
    List<String> players = List<String>.from(snapshot.child('players').value as List);
    if (!players.contains(myId)) {
      players.add(myId);
      await _db.updatePlayers(players);
    }
    
    final deckData = snapshot.child('deck').value as List?;
    if (deckData != null && deckData.length >= 5) {
      List<CardModel> deck = deckData.map((i) => CardModel(
        number: (i['number'] as num).toInt(),
        suit: Suit.values.firstWhere((e) => e.name == i['suit']),
      )).toList();
      setState(() { myHand = deck.sublist(0, 5); });
      await _db.syncHandCount(myId, 5);
    }
  }

  void _playCard(CardModel card) async {
    int nextIdx = (playerIds.indexOf(myId) + 1) % playerIds.length;
    setState(() => myHand.remove(card));
    await _db.playCard(nextTurnIndex: nextIdx, card: card, myId: myId);
    await _db.syncHandCount(myId, myHand.length);
  }

  Future<void> _drawCard() async {
    if (firebaseDeck.isEmpty) return;
    final nextDeck = firebaseDeck.sublist(0, firebaseDeck.length - 1);
    final drawn = firebaseDeck.last;
    setState(() => myHand.add(drawn));
    await _db.drawCard(
      remainingDeck: nextDeck.map((c) => {'number': c.number, 'suit': c.suit.name}).toList(),
      nextTurnIndex: (currentTurnIndex + 1) % playerIds.length,
    );
    await _db.syncHandCount(myId, myHand.length);
  }

  Future<void> _flipInitial() async {
    if (firebaseDeck.isEmpty) return;
    final next = firebaseDeck.removeLast();
    await _db.flipCard(firebaseDeck.map((c) => {'number': c.number, 'suit': c.suit.name}).toList(), next);
  }

  List<CardModel> _generateFullDeck() {
    List<CardModel> d = [];
    for (var s in Suit.values) {
      if (s == Suit.joker) { d.add(CardModel(suit: s, number: 0)); }
      else { for (int i = 1; i <= 13; i++) { d.add(CardModel(suit: s, number: i)); } }
    }
    return d;
  }

  @override
  Widget build(BuildContext context) {
    if (isInitializing || fieldNumber == -1) {
      return const Scaffold(backgroundColor: Color(0xFF1B5E20), body: Center(child: CircularProgressIndicator(color: Colors.white)));
    }

    int myIdx = playerIds.indexOf(myId);
    bool isMyTurn = (currentTurnIndex % playerIds.length == myIdx);
    bool iAmDrawer = isDrawCompetitive && playerIds[(currentTurnIndex - 1 + playerIds.length) % playerIds.length] == myId;

    return Scaffold(
      backgroundColor: const Color(0xFF1B5E20),
      appBar: AppBar(
        title: Text('ルーム: ${widget.roomId} (${myId == hostId ? "ホスト" : "ゲスト"})'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: GameView(
          fieldNumber: fieldNumber, fieldSuit: fieldSuit, myHand: myHand,
          playerIds: playerIds, myId: myId, handCounts: handCounts,
          currentTurnIndex: currentTurnIndex, lastPlayerId: lastPlayerId,
          isInitialPhase: isInitialPhase, isMyTurn: isMyTurn,
          isHost: myId == hostId, iAmDrawer: iAmDrawer,
          onPlay: _playCard, onDraw: _drawCard, onFlip: _flipInitial,
          onMori: () => _showResultDialog("もり！！！", "勝利！敗者: $lastPlayerId さん"),
        ),
      ),
    );
  }

  void _showResultDialog(String t, String m) {
    showDialog(context: context, barrierDismissible: false, builder: (_) => AlertDialog(
      title: Text(t), content: Text(m),
      actions: [TextButton(onPressed: () { Navigator.pop(context); _db.deleteRoom().then((_) => _initializeGame()); }, child: const Text('リセット'))],
    ));
  }
}