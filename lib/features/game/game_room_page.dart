import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';
import '../../services/firebase_db.dart';
import 'game_board_view.dart';

class GameRoomPage extends StatefulWidget {
  final String roomId;
  final bool isPrivate;
  const GameRoomPage({super.key, required this.roomId, this.isPrivate = false});

  @override
  State<GameRoomPage> createState() => _GameRoomPageState();
}

class _GameRoomPageState extends State<GameRoomPage> {
  late final FirebaseDB _db;
  StreamSubscription? _sub;
  String myId = DateTime.now().millisecondsSinceEpoch.toString();

  // State管理
  String? hostId;
  List<CardWidget> deck = [];
  List<CardWidget> myHand = [];
  List<String> playerIds = [];
  Map<String, int> handCounts = {};
  int fieldNumber = -1;
  Suit fieldSuit = Suit.joker;
  bool isInitialPhase = true;
  int currentTurn = 0;
  String? lastPlayerId;

  @override
  void initState() {
    super.initState();
    _db = FirebaseDB(widget.roomId);
    _initialize();
  }

  Future<void> _initialize() async {
    final snap = await _db.getSnapshot();
    if (!snap.exists) {
      await _setupNewRoom();
    } else {
      await _joinRoom();
    }
    _sub = _db.roomStream.listen(_onData);
  }

  void _onData(DatabaseEvent event) {
    final data = event.snapshot.value as Map?;
    if (data == null || !mounted) return;
    setState(() {
      hostId = data['host'];
      playerIds = snapToList(data['players']);
      currentTurn = data['currentTurnIndex'] ?? 0;
      lastPlayerId = data['lastPlayerId'];
      if (data['playerHands'] != null) handCounts = Map<String, int>.from(data['playerHands']);
      if (data['field'] != null) {
        fieldNumber = data['field']['number'];
        fieldSuit = Suit.values.firstWhere((e) => e.name == data['field']['suit'], orElse: () => Suit.joker);
      }
      if (data['deck'] != null) {
        deck = (data['deck'] as List).map((i) => CardWidget(number: i['number'], suit: Suit.values.firstWhere((e) => e.name == i['suit']))).toList();
      }
      isInitialPhase = data['isInitialPhase'] ?? true;
    });
  }

  List<String> snapToList(dynamic data) => data == null ? [] : List<String>.from(data);

  Future<void> _setupNewRoom() async {
    List<CardWidget> fullDeck = _genDeck()..shuffle();
    final hand = fullDeck.sublist(0, 5);
    fullDeck.removeRange(0, 5);
    await _db.setupRoom(myId, fullDeck, widget.isPrivate);
    setState(() => myHand = hand);
  }

  Future<void> _joinRoom() async {
    final snap = await _db.getSnapshot();
    List<String> p = snapToList(snap.child('players').value);
    if (!p.contains(myId)) p.add(myId);
    await _db.updateGameStatus({'players': p, 'playerHands/$myId': 5});
    // 山札から5枚受け取る
    final List d = snap.child('deck').value as List;
    setState(() {
      myHand = d.reversed.take(5).map((i) => CardWidget(number: i['number'], suit: Suit.values.firstWhere((e) => e.name == i['suit']))).toList();
    });
  }

  void _onPlay(CardWidget card) {
    if (fieldNumber == -1) return;
    setState(() => myHand.remove(card));
    _db.playCard((currentTurn + 1) % playerIds.length, card, myId);
    _db.updateGameStatus({'playerHands/$myId': myHand.length});
  }

  void _onDraw() {
    if (deck.isEmpty || fieldNumber == -1) return;
    final drawnCard = deck.last;
    final newDeckData = deck.sublist(0, deck.length - 1).map((c) => {'number': c.number, 'suit': c.suit.name}).toList();
    
    setState(() => myHand.add(drawnCard));
    _db.updateGameStatus({
      'deck': newDeckData,
      'playerHands/$myId': myHand.length,
      'currentTurnIndex': (currentTurn + 1) % playerIds.length,
    });
  }

  void _onFlip() {
    if (deck.isEmpty) return;
    final first = deck.last;
    final newDeckData = deck.sublist(0, deck.length - 1).map((c) => {'number': c.number, 'suit': c.suit.name}).toList();
    _db.updateGameStatus({
      'gameStarted': true,
      'isInitialPhase': false,
      'field': {'number': first.number, 'suit': first.suit.name},
      'deck': newDeckData,
      'lastPlayerId': 'system',
    });
  }

  List<CardWidget> _genDeck() {
    return [for (var s in Suit.values) if (s != Suit.joker) for (var i = 1; i <= 13; i++) CardWidget(number: i, suit: s), const CardWidget(number: 0, suit: Suit.joker)];
  }

  @override
  Widget build(BuildContext context) {
    return GameBoardView(
      roomId: widget.roomId, fieldNumber: fieldNumber, fieldSuit: fieldSuit,
      myHand: myHand, playerIds: playerIds, myId: myId, handCounts: handCounts,
      isMyTurn: playerIds.isNotEmpty && currentTurn % playerIds.length == playerIds.indexOf(myId),
      isHost: myId == hostId, lastPlayerId: lastPlayerId, isInitialPhase: isInitialPhase,
      onPlay: _onPlay, onDraw: _onDraw, onFlip: _onFlip, onMori: () => _showWinDialog(),
    );
  }

  void _showWinDialog() {
    showDialog(context: context, builder: (_) => AlertDialog(title: const Text("勝利！"), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))]));
  }

  @override
  void dispose() { _sub?.cancel(); super.dispose(); }
}