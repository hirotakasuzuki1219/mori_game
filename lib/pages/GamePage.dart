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
  
  int fieldNumber = 0;
  Suit fieldSuit = Suit.joker;
  bool isInitialPhase = true;

  @override
  void initState() {
    super.initState();
    _startNewGame();
    _listenToRoom();
  }

  @override
  void dispose() {
    _roomSubscription?.cancel();
    super.dispose();
  }

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
          isInitialPhase = data['isInitialPhase'] ?? true;
        });
      }
    });
  }

  void _startNewGame() {
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

    List<CardModel> initialHand = newDeck.sublist(0, 5);
    newDeck.removeRange(0, 5);

    final firstCard = newDeck.removeLast();

    setState(() {
      deck = newDeck;
      myHand = initialHand;
    });

    _roomRef.set({
      'field': {
        'number': firstCard.number,
        'suit': firstCard.suit.name,
      },
      'isInitialPhase': true,
      'status': 'playing'
    });
  }

  // 山札からカードを引く処理
  void _drawCard() {
    if (deck.isEmpty || isInitialPhase) return;

    // 【修正箇所】手札が7枚の時のルールチェック
    if (myHand.length == 7) {
      if (_hasPlayableCard()) {
        // 出せるカードがある場合は引けない
        _showErrorSnackBar('出せるカードがあるため、これ以上引けません！');
        return;
      } else {
        // 出せるカードがないのに7枚からさらに引こうとしたら負け（バースト）
        _showResultDialog("バースト", "7枚で出せるカードがなく、山札を引いたため負けです。");
        return;
      }
    }

    setState(() {
      myHand.add(deck.removeLast());
      
      // 引いた結果7枚になり、かつ出せるカードが一切ない場合はその瞬間に負け
      if (myHand.length == 7 && !_hasPlayableCard()) {
        _showResultDialog("バースト", "7枚目を引きましたが、出せるカードがないため負けです。");
      }
    });
  }

  bool _hasPlayableCard() {
    if (fieldSuit == Suit.joker) return true;
    return myHand.any((c) => c.number == fieldNumber || c.suit == fieldSuit);
  }

  void _playCard(CardModel card) {
    bool canPlay = false;

    if (fieldSuit == Suit.joker) {
      canPlay = true; 
    } else if (isInitialPhase) {
      if (card.number == fieldNumber) canPlay = true;
    } else {
      if (card.number == fieldNumber || card.suit == fieldSuit) canPlay = true;
    }

    if (canPlay) {
      _updateFirebaseField(card);
    }
  }

  void _updateFirebaseField(CardModel card) {
    setState(() {
      myHand.remove(card);
    });

    _roomRef.update({
      'field': {
        'number': card.number,
        'suit': card.suit.name,
      },
      'isInitialPhase': false, 
    });
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(milliseconds: 1500)),
    );
  }

  void _showResultDialog(String title, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () { Navigator.pop(context); _startNewGame(); }, child: const Text('リセット')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool canMori = !isInitialPhase && fieldSuit != Suit.joker &&
                   (MoriLogic.checkNormalMori(fieldNumber, myHand) ||
                    MoriLogic.checkSpecialMori(fieldNumber, myHand));

    return Scaffold(
      backgroundColor: const Color(0xFF1B5E20),
      appBar: AppBar(title: const Text('もり - 同期プレイ'), backgroundColor: Colors.transparent),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: GestureDetector(
              onTap: _drawCard,
              child: Container(
                width: 70, height: 100,
                decoration: BoxDecoration(
                  color: isInitialPhase ? Colors.grey : Colors.blueGrey[900],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Center(child: Text('ドロー', style: TextStyle(color: Colors.white))),
              ),
            ),
          ),

          Column(
            children: [
              Text(
                isInitialPhase ? '【初期】同じ数字を出せ！' : '共有の場', 
                style: const TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold)
              ),
              const SizedBox(height: 10),
              CardWidget(
                card: CardModel(suit: fieldSuit, number: fieldNumber),
                onTap: () {},
              ),
            ],
          ),

          Container(
            padding: const EdgeInsets.only(bottom: 30),
            child: Column(
              children: [
                ElevatedButton(
                  onPressed: canMori ? () => _showResultDialog("もり！", "成功！") : null,
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
                Text('手札: ${myHand.length}/7', 
                  style: TextStyle(
                    color: myHand.length >= 7 ? Colors.redAccent : Colors.white70,
                    fontWeight: myHand.length >= 7 ? FontWeight.bold : FontWeight.normal
                  )
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}