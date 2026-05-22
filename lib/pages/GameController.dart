import 'package:flutter/material.dart';
import 'package:mori_game/models/CardModel.dart';
import 'package:mori_game/services/FirebaseService.dart';
import 'package:mori_game/widgets/GameView.dart';
import 'dart:async';
import 'package:firebase_database/firebase_database.dart';

class GameController extends StatefulWidget {
  final String roomId;
  final bool isPrivate;
  const GameController({super.key, required this.roomId, this.isPrivate = false});

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
        if (data['playerHands'] != null) {
          handCounts = Map<String, int>.from(data['playerHands']);
        }
        
        // デッキの同期
        if (data['deck'] != null) {
          firebaseDeck = (data['deck'] as List).map((i) => CardModel(
            number: (i['number'] as num).toInt(),
            suit: Suit.values.firstWhere((e) => e.name == i['suit']),
          )).toList();
        }

        // 場札の同期（ここが重要）
        final field = data['field'] as Map?;
        if (field != null) {
          fieldNumber = (field['number'] as num).toInt();
          fieldSuit = Suit.values.firstWhere((e) => e.name == field['suit'], orElse: () => Suit.joker);
          isInitialPhase = data['isInitialPhase'] ?? true;
        }
      });
    });
  }

  Future<void> _initializeGame() async {
    setState(() => isInitializing = true);
    final snapshot = await _db.getRoomSnapshot();
    
    // 途中入室チェック（ホスト以外）
    if (snapshot.exists && snapshot.child('gameStarted').value == true) {
      if (!mounted) return;
      // すでに自分がプレイヤーリストにいれば続行、いなければ拒否
      List<String> pList = snapshot.child('players').exists ? List<String>.from(snapshot.child('players').value as List) : [];
      if (!pList.contains(myId)) {
        _showErrorAndExit("この部屋は既にゲームが開始されています。");
        return;
      }
    }

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
    await _db.setupRoom(myId, deck, isPrivate: widget.isPrivate);
    setState(() { myHand = hand; });
  }

  Future<void> _joinAsGuest() async {
    final snapshot = await _db.getRoomSnapshot();
    List<String> players = List<String>.from(snapshot.child('players').value as List);
    if (!players.contains(myId)) {
      players.add(myId);
      await _db.updatePlayers(players);
    }
    await _db.syncHandCount(myId, 5);
    // 手札の分配ロジック（簡易版：本来はデッキから引くべきだが、初期化時は共通の5枚）
    setState(() { myHand = firebaseDeck.take(5).toList(); }); 
  }

  void _playCard(CardModel card) async {
    if (fieldNumber == -1) return;
    int nextIdx = (playerIds.indexOf(myId) + 1) % playerIds.length;
    setState(() => myHand.remove(card));
    await _db.playCard(nextTurnIndex: nextIdx, card: card, myId: myId);
    await _db.syncHandCount(myId, myHand.length);
  }

  Future<void> _drawCard() async {
    if (firebaseDeck.isEmpty || fieldNumber == -1) return;
    final drawn = firebaseDeck.last;
    final nextDeckData = firebaseDeck.sublist(0, firebaseDeck.length - 1)
        .map((c) => {'number': c.number, 'suit': c.suit.name}).toList();
    
    setState(() => myHand.add(drawn));
    await _db.drawCard(
      remainingDeck: nextDeckData,
      nextTurnIndex: (currentTurnIndex + 1) % playerIds.length,
    );
    await _db.syncHandCount(myId, myHand.length);
  }

  Future<void> _flipInitial() async {
    if (firebaseDeck.isEmpty) return;
    if (fieldNumber == -1) { await _db.startGame(); }
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

  void _showErrorAndExit(String msg) {
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text("エラー"), content: Text(msg),
      actions: [TextButton(onPressed: () => Navigator.popUntil(context, (r) => r.isFirst), child: const Text("戻る"))],
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (isInitializing) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    int myIdx = playerIds.indexOf(myId);
    bool isMyTurn = (currentTurnIndex % playerIds.length == myIdx);
    return Scaffold(
      backgroundColor: const Color(0xFF1B5E20),
      appBar: AppBar(title: Text('部屋: ${widget.roomId}'), backgroundColor: Colors.transparent),
      body: GameView(
        fieldNumber: fieldNumber, fieldSuit: fieldSuit, myHand: myHand,
        playerIds: playerIds, myId: myId, handCounts: handCounts,
        currentTurnIndex: currentTurnIndex, lastPlayerId: lastPlayerId,
        isInitialPhase: isInitialPhase, isMyTurn: isMyTurn,
        isHost: myId == hostId, iAmDrawer: false,
        onPlay: _playCard, onDraw: _drawCard, onFlip: _flipInitial,
        onMori: () => _showResultDialog(),
      ),
    );
  }

  void _showResultDialog() {
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text("もり！"), content: const Text("あなたの勝利です！"),
      actions: [TextButton(onPressed: () { Navigator.pop(context); _db.deleteRoom(); }, child: const Text("終了"))],
    ));
  }
}