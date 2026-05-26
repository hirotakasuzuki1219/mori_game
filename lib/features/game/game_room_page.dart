import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';
import '../../services/firebase_db.dart';
import '../../logic/game_rules.dart';
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

  // 内部状態（State）
  List<CardWidget> myHand = [];
  List<int> selectedIndices = [];
  String? hostId;
  List<String> playerIds = [];
  Map<String, int> handCounts = {};
  int fieldNumber = -1;
  Suit fieldSuit = Suit.joker;
  int currentTurn = 0;
  bool isInitialPhase = true;
  String? lastPlayerId;
  List<CardWidget> deck = [];

  // 「もり・もり返し」システム用の状態
  String moriPhase = 'none'; // 'none', 'mori_declared', 'finished'
  String? lastMoriPlayerId;  // 最後に「もり」を宣言した人（暫定勝者）
  String? loserPlayerId;     // 「もり」を宣言された人（暫定敗者）
  Timer? _moriTimer;         // もり返し受付用のホスト側タイマー
  String _lastTrackedMoriPlayer = ''; // タイマー重複防止用

  // ホスト判定ゲッター
  bool get isHost => myId == hostId;

  @override
  void initState() {
    super.initState();
    _db = FirebaseDB(widget.roomId);
    _init();
  }

  Future<void> _init() async {
    final snap = await _db.getSnapshot();
    if (!snap.exists) {
      // ホスト：山札作成と初期化
      List<CardWidget> fullDeck = _generateDeck()..shuffle();
      final hand = fullDeck.sublist(0, 5);
      fullDeck.removeRange(0, 5);
      await _db.setupRoom(myId, fullDeck, widget.isPrivate);
      setState(() => myHand = hand);
    } else {
      // ゲスト：参加処理（すでにホストがカードをめくっている場合は入室不可にする処理の土台）
      bool isStarted = snap.child('gameStarted').value == true;
      if (isStarted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showErrorDialog("このゲームは既に開始されているため、入室できません。");
        });
        return;
      }

      List<String> p = snap.child('players').exists 
          ? List<String>.from(snap.child('players').value as List) : [];
      if (!p.contains(myId)) p.add(myId);
      await _db.updateGameStatus({'players': p, 'playerHands/$myId': 5});
      setState(() => myHand = _generateDeck().take(5).toList());
    }
    _sub = _db.roomStream.listen(_onData);
  }

  void _onData(DatabaseEvent event) {
    final data = event.snapshot.value as Map?;
    if (data == null || !mounted) return;
    setState(() {
      hostId = data['host'];
      playerIds = List<String>.from(data['players'] ?? []);
      currentTurn = data['currentTurnIndex'] ?? 0;
      lastPlayerId = data['lastPlayerId'];
      if (data['playerHands'] != null) handCounts = Map<String, int>.from(data['playerHands']);
      
      if (data['field'] != null) {
        fieldNumber = data['field']['number'];
        fieldSuit = Suit.values.firstWhere((e) => e.name == data['field']['suit'], orElse: () => Suit.joker);
      }
      if (data['deck'] != null) {
        deck = (data['deck'] as List).map((i) => CardWidget(
          number: i['number'], 
          suit: Suit.values.firstWhere((e) => e.name == i['suit'])
        )).toList();
      }
      isInitialPhase = data['isInitialPhase'] ?? true;

      // --- もり・もり返しフェーズの同期 ---
      moriPhase = data['moriPhase'] ?? 'none';
      lastMoriPlayerId = data['lastMoriPlayerId'];
      loserPlayerId = data['loserPlayerId'];

      // ホスト端末のみ：新たなもり・もり返しを検知したら5秒タイマーを始動/再始動
      if (isHost && moriPhase == 'mori_declared') {
        if (_lastTrackedMoriPlayer != lastMoriPlayerId) {
          _lastTrackedMoriPlayer = lastMoriPlayerId ?? '';
          _moriTimer?.cancel();
          _moriTimer = Timer(const Duration(seconds: 5), () {
            // 5秒間誰からもり返されなければ終了ステータスへ
            _db.updateGameStatus({'moriPhase': 'finished'});
          });
        }
      }

      // もりフェーズ終了時の勝敗ダイアログ表示
      if (moriPhase == 'finished' && lastMoriPlayerId != null) {
        _moriTimer?.cancel();
        _showGameOver(lastMoriPlayerId == myId ? "勝利！(もり成功)" : 
                      (loserPlayerId == myId ? "敗北...(もりを宣言されました)" : "ゲーム終了"));
      }

      // 通常プレイでの勝利、またはバーストによる直接終了の監視
      if (data['winnerId'] != null) {
        _showGameOver(data['winnerId'] == myId ? "勝利！" : "敗北...");
      }
    });
  }

  // カードタップ時の挙動（通常プレイ・割り込み・複数枚選択の切り替え）
  void _onCardTap(int index) {
    // もり宣言受付中は、手札の通常プレイによる提出は不可（もり・もり返しボタンの選択のみ有効）
    if (moriPhase == 'mori_declared') {
      _toggleSelection(index);
      return;
    }

    final card = myHand[index];
    int myIdx = playerIds.indexOf(myId);
    bool isMyTurn = (currentTurn % playerIds.length == myIdx);
    
    bool isJokerField = (fieldSuit == Suit.joker);
    bool isInterrupt = (!isMyTurn && card.number == fieldNumber && fieldNumber != -1);
    bool canPlayInTurn = isMyTurn && GameRules.canPlayNormal(fieldNumber, fieldSuit, card);

    // 自分のターンで出せるカード、またはターン外での同じ数字（割り込み）、または場がジョーカー
    if (canPlayInTurn || isInterrupt || isJokerField) {
      _executePlay([card]);
      return;
    }

    // 条件に合わない場合は「もり」のための複数枚選択モード
    _toggleSelection(index);
  }

  void _toggleSelection(int index) {
    setState(() {
      if (selectedIndices.contains(index)) {
        selectedIndices.remove(index);
      } else {
        selectedIndices.add(index);
      }
    });
  }

  // もり・もり返しボタンを押した時の処理
  void _onMori() {
    final selectedCards = selectedIndices.map((i) => myHand[i]).toList();
    
    if (GameRules.isValidMori(fieldNumber, selectedCards)) {
      if (moriPhase == 'none') {
        // 通常のもり：自滅チェック（直前にカードを出したのが自分なら宣言不可）
        if (lastPlayerId == myId) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('自滅はできません！')));
          return;
        }
        _db.updateGameStatus({
          'moriPhase': 'mori_declared',
          'lastMoriPlayerId': myId,     // 自分が暫定勝者
          'loserPlayerId': lastPlayerId // 出した人が暫定敗者
        });
      } else if (moriPhase == 'mori_declared') {
        // もり返し：自滅ルールは適用されない（場が自分のカードでもOK）
        _db.updateGameStatus({
          'lastMoriPlayerId': myId,          // 自分が新たな暫定勝者
          'loserPlayerId': lastMoriPlayerId, // 直前の宣言者が新たな敗者
        });
      }
      
      // もり・もり返しに成功したカードを手札から消費
      _executePlay(selectedCards, isMoriAction: true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('計算が合いません！')));
    }
  }

  // ドロー処理（バースト判定含む）
  void _onDraw() {
    if (deck.isEmpty || moriPhase == 'mori_declared') return;
    
    final drawn = deck.last;
    bool canPlayDrawnCard = GameRules.canPlayNormal(fieldNumber, fieldSuit, drawn);
    
    // 引いて7枚になり、かつそのカードが出せない場合はバースト敗北
    if (GameRules.isBurst(myHand.length + 1, canPlayDrawnCard)) {
      _db.updateGameStatus({'winnerId': 'other_players'}); // 自分以外が勝利扱い
      _showGameOver("バースト！手札が7枚になり、出せるカードがありません。");
      return;
    }

    setState(() {
      myHand.add(drawn);
      selectedIndices.clear();
    });

    // ドローした瞬間、次の人も出す権利がある（早い者勝ち）ためターンを移行
    _db.updateGameStatus({
      'deck': deck.sublist(0, deck.length - 1).map((c) => {'number': c.number, 'suit': c.suit.name}).toList(),
      'playerHands/$myId': myHand.length,
      'currentTurnIndex': (currentTurn + 1) % playerIds.length, 
    });
  }

  // プレイおよびカード消費の実行
  void _executePlay(List<CardWidget> cards, {bool isMoriAction = false}) {
    if (cards.isEmpty) return;
    final lastCard = cards.last;
    int myIdx = playerIds.indexOf(myId);
    int nextTurnIndex = (myIdx + 1) % playerIds.length;

    setState(() {
      for (var c in cards) {
        myHand.removeWhere((h) => h.number == c.number && h.suit == c.suit);
      }
      selectedIndices.clear();
    });

    Map<String, dynamic> updates = {
      'field': {'number': lastCard.number, 'suit': lastCard.suit.name},
      'playerHands/$myId': myHand.length,
    };

    // 通常のカード提出時のみ、ターンの移行や初期フェーズの終了を行う
    if (!isMoriAction) {
      updates['lastPlayerId'] = myId;
      updates['currentTurnIndex'] = nextTurnIndex; // カードを出した人の隣の人へ
      updates['isInitialPhase'] = false;           // 通常プレイ開始のため初期フェーズ終了
      updates['gameStarted'] = true;               // 新規入室を制限するフラグをON
    }

    _db.updateGameStatus(updates);

    // 通常プレイで手札が0枚になったら勝利確定
    if (myHand.isEmpty && !isMoriAction) {
      _db.updateGameStatus({'winnerId': myId});
    }
  }

  // 最初のみ：ホストが山札をめくる処理
  void _onFlip() {
    if (!isHost || deck.isEmpty) return;

    final flippedCard = deck.last;
    final newDeck = deck.sublist(0, deck.length - 1);

    _db.updateGameStatus({
      'field': {'number': flippedCard.number, 'suit': flippedCard.suit.name},
      'deck': newDeck.map((c) => {'number': c.number, 'suit': c.suit.name}).toList(),
      'isInitialPhase': true, 
      'lastPlayerId': 'system',
      'gameStarted': true, // ホストがめくった時点でゲストは新規入室不可
    });
  }

  List<CardWidget> _generateDeck() {
    return [
      for (var s in Suit.values) 
        if (s != Suit.joker) 
          for (var i = 1; i <= 13; i++) CardWidget(number: i, suit: s),
      const CardWidget(number: 0, suit: Suit.joker)
    ];
  }

  void _showGameOver(String msg) {
    showDialog(
      context: context, 
      barrierDismissible: false, 
      builder: (_) => AlertDialog(
        title: Text(msg), 
        actions: [
          TextButton(
            onPressed: () {
              _moriTimer?.cancel();
              Navigator.popUntil(context, (r) => r.isFirst);
            }, 
            child: const Text("ロビーへ")
          )
        ]
      )
    );
  }

  void _showErrorDialog(String msg) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("入室エラー"),
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("戻る"))
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return GameBoardView(
      roomId: widget.roomId, 
      fieldNumber: fieldNumber, 
      fieldSuit: fieldSuit,
      myHand: myHand, 
      selectedIndices: selectedIndices, 
      playerIds: playerIds,
      myId: myId, 
      handCounts: handCounts, 
      currentTurnIndex: currentTurn,
      isHost: isHost, 
      lastPlayerId: lastPlayerId, 
      isInitialPhase: isInitialPhase,
      moriPhase: moriPhase, // game_board_view側でのもり返しテキスト切り替え用
      onCardTap: _onCardTap, 
      onMori: _onMori, 
      onDraw: _onDraw, 
      onFlip: _onFlip,
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    _moriTimer?.cancel();
    super.dispose();
  }
}