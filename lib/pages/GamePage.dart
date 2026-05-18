import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:mori_game/models/CardModel.dart';
import 'package:mori_game/logic/MoriLogic.dart';
import 'package:mori_game/widgets/CardWidget.dart';
import 'dart:async';

class GamePage extends StatefulWidget {
  const GamePage({super.key});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  final DatabaseReference _roomRef = FirebaseDatabase.instance.ref('rooms/test_room');
  StreamSubscription<DatabaseEvent>? _roomSubscription;

  List<CardModel> deck = [];   
  List<CardModel> myHand = []; 
  
  // 場の状態
  int fieldNumber = 0;
  Suit fieldSuit = Suit.joker;
  bool isInitialPhase = true;

  @override
  void initState() {
    super.initState();
    _setupGame();
    _listenToRoom();
  }

  @override
  void dispose() {
    _roomSubscription?.cancel();
    super.dispose();
  }

  // Firebaseの監視
  void _listenToRoom() {
    _roomSubscription = _roomRef.onValue.listen((event) {
      final data = event.snapshot.value as Map?;
      if (data == null) return;

      final field = data['field'] as Map?;
      if (field != null) {
        setState(() {
          fieldNumber = field['number'];
          fieldSuit = Suit.values.firstWhere(
            (e) => e.name == field['suit'],
            orElse: () => Suit.joker,
          );
          // isInitialPhaseの同期
          isInitialPhase = data['isInitialPhase'] ?? true;
        });
      }
    });
  }

  void _setupGame() {
    // 山札生成
    List<CardModel> newDeck = [];
    for (var suit in Suit.values) {
      if (suit == Suit.joker) {
        newDeck.add(CardModel(suit: suit, number: 0));
      } else {
        for (int i = 1; i <= 13; i++) {
          newDeck.add(CardModel(suit: suit, number: i));
        }
      }
    }
    newDeck.shuffle();

    setState(() {
      deck = newDeck;
      myHand = deck.sublist(0, 5);
      deck.removeRange(0, 5);
    });

    // 【重要】最初は必ずJOKERからスタート
    _roomRef.set({
      'field': {
        'number': 0,
        'suit': Suit.joker.name,
      },
      'isInitialPhase': true,
      'status': 'playing'
    });
  }

  // 山札から引く
  void _drawCard() {
    if (deck.isEmpty) return;
    setState(() {
      myHand.add(deck.removeLast());
      // 7枚制限の敗北判定
      if (myHand.length == 7 && !_hasPlayableCard()) {
        _showResultDialog("負け", "出せるカードがなく、7枚に達しました。");
      }
    });
  }

  bool _hasPlayableCard() {
    if (fieldSuit == Suit.joker) return true;
    return myHand.any((c) => c.number == fieldNumber || c.suit == fieldSuit);
  }

  // カードを出す処理
  void _playCard(CardModel card) {
    bool canPlay = false;

    if (fieldSuit == Suit.joker) {
      canPlay = true; // 場がJOKERなら何でも出せる
    } else if (isInitialPhase) {
      if (card.number == fieldNumber) canPlay = true; // 初期は数字一致のみ
    } else {
      if (card.number == fieldNumber || card.suit == fieldSuit) canPlay = true; // 通常
    }

    if (canPlay) {
      _updateFirebaseField(card);
    }
  }

  // Firebaseの「場」を更新する
  void _updateFirebaseField(CardModel card) {
    // 自分の手札から削除
    setState(() {
      myHand.remove(card);
    });

    // Firebaseの値を更新（これにより他全員の画面が listen 経由で更新される）
    _roomRef.update({
      'field': {
        'number': card.number,
        'suit': card.suit.name,
      },
      'isInitialPhase': false, // 誰かが出した時点で初期フェーズ終了
    }).then((_) {
      print("Firebase field updated successfully");
    }).catchError((error) {
      print("Failed to update field: $error");
    });
  }

  void _showResultDialog(String title, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () { Navigator.pop(context); _setupGame(); }, child: const Text('リセット')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // もり判定
    bool canMori = !isInitialPhase && fieldSuit != Suit.joker &&
                   (MoriLogic.checkNormalMori(fieldNumber, myHand) ||
                    MoriLogic.checkSpecialMori(fieldNumber, myHand));

    return Scaffold(
      backgroundColor: const Color(0xFF1B5E20),
      appBar: AppBar(title: const Text('もり - Firebase対戦'), backgroundColor: Colors.transparent),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 山札
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: GestureDetector(
              onTap: _drawCard,
              child: Container(
                width: 70, height: 100,
                decoration: BoxDecoration(
                  color: Colors.blueGrey[900],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Center(child: Text('ドロー', style: TextStyle(color: Colors.white))),
              ),
            ),
          ),

          // 中央：場
          Column(
            children: [
              Text(
                fieldSuit == Suit.joker ? '【開始】好きなカードを出せ！' : '場のカード', 
                style: const TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold)
              ),
              const SizedBox(height: 10),
              CardWidget(
                card: CardModel(suit: fieldSuit, number: fieldNumber),
                onTap: () {},
              ),
            ],
          ),

          // 下部
          Container(
            padding: const EdgeInsets.only(bottom: 30),
            child: Column(
              children: [
                ElevatedButton(
                  onPressed: canMori ? () => _showResultDialog("もり！", "勝利！") : null,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent),
                  child: const Text('もり！'),
                ),
                const SizedBox(height: 20),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: myHand.map((card) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: CardWidget(card: card, onTap: () => _playCard(card)),
                    )).toList(),
                  ),
                ),
                const SizedBox(height: 10),
                Text('手札: ${myHand.length}/7', style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}