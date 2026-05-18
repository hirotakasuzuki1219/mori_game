import 'package:flutter/material.dart';
import 'package:mori_game/models/CardModel.dart';
import 'package:mori_game/logic/MoriLogic.dart';
import 'package:mori_game/widgets/CardWidget.dart';

class GamePage extends StatefulWidget {
  const GamePage({super.key});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  List<CardModel> deck = [];   
  List<CardModel> myHand = []; 
  
  int fieldNumber = 0;
  Suit fieldSuit = Suit.joker;
  bool isInitialPhase = true; // 開始時のみのフェーズ管理

  @override
  void initState() {
    super.initState();
    _startNewGame();
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

    setState(() {
      deck = newDeck;
      myHand = deck.sublist(0, 5);
      deck.removeRange(0, 5);
      isInitialPhase = true;
      
      // 最初の有効な1枚が決まるまで自動でめくる
      _determineInitialFieldCard();
    });
  }

  // 開始時のみ：誰も出せない場合は山札をめくり続ける
  void _determineInitialFieldCard() {
    if (deck.isEmpty) return;

    final nextCard = deck.removeLast();
    
    // 自分（または参加者）がその数字を持っているかチェック
    bool anyoneHasNumber = myHand.any((c) => c.number == nextCard.number);

    setState(() {
      fieldNumber = nextCard.number;
      fieldSuit = nextCard.suit;
    });

    if (!anyoneHasNumber) {
      // 誰の手札にも同じ数字がないなら、少し待って次をめくる（演出用）
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted && isInitialPhase) {
          _determineInitialFieldCard();
        }
      });
    } else {
      // 誰かが持っているならプレイ開始
      setState(() {
        isInitialPhase = false;
      });
    }
  }

  bool _hasPlayableCard() {
    return myHand.any((card) {
      if (fieldSuit == Suit.joker) return true;
      if (card.number == fieldNumber) return true;
      if (card.suit == fieldSuit) return true;
      return false;
    });
  }

  void _drawCard() {
    if (deck.isEmpty || isInitialPhase) return;

    setState(() {
      CardModel drawnCard = deck.removeLast();
      myHand.add(drawnCard);

      if (myHand.length == 7) {
        if (!_hasPlayableCard()) {
          _showResultDialog("バースト", "7枚目を引きましたが、出せるカードがないため負けです。");
        }
      }
    });
  }

  void _playCard(CardModel card) {
    if (isInitialPhase) {
      // 初期フェーズは同じ数字しか出せない（割り込み）
      if (card.number == fieldNumber) {
        _executePlay(card);
      } else {
        _showErrorSnackBar('最初は同じ数字の人しか出せません！');
      }
      return;
    }

    // 通常プレイ：同じマーク or 同じ数字
    if (fieldSuit == Suit.joker || card.number == fieldNumber || card.suit == fieldSuit) {
      _executePlay(card);
    } else {
      _showErrorSnackBar('出せません！');
    }
  }

  void _executePlay(CardModel card) {
    setState(() {
      fieldNumber = card.number;
      fieldSuit = card.suit;
      myHand.remove(card);
      isInitialPhase = false; // 誰かが出せば確実に初期フェーズ終了
    });
    if (myHand.isEmpty) {
      _showResultDialog("勝利！", "出し切りました！");
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(milliseconds: 500)),
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
      appBar: AppBar(title: const Text('もり - 正式ルール練習'), backgroundColor: Colors.transparent, elevation: 0),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 山札
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Column(
              children: [
                GestureDetector(
                  onTap: _drawCard,
                  child: Container(
                    width: 70, height: 100,
                    decoration: BoxDecoration(
                      color: isInitialPhase ? Colors.grey : Colors.blueGrey[900],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Center(child: Text(isInitialPhase ? '待機中' : 'ドロー', style: const TextStyle(color: Colors.white))),
                  ),
                ),
                Text('残り: ${deck.length}枚', style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),

          // 中央：場
          Column(
            children: [
              Text(isInitialPhase ? '初期札を選定中...' : '場のカード', 
                style: TextStyle(color: isInitialPhase ? Colors.orange : Colors.white70, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              CardWidget(
                card: CardModel(suit: fieldSuit, number: fieldNumber),
                onTap: () {},
              ),
              if (isInitialPhase) 
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(color: Colors.orange, strokeWidth: 2),
                ),
            ],
          ),

          // 下部
          Container(
            padding: const EdgeInsets.only(bottom: 30),
            child: Column(
              children: [
                ElevatedButton(
                  onPressed: canMori ? () => _showResultDialog("もり成功！", "おめでとうございます！") : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orangeAccent,
                    disabledBackgroundColor: Colors.white10,
                    padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  child: const Text('もり！', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 20),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: myHand.map((card) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: CardWidget(card: card, onTap: () => _playCard(card)),
                      )).toList(),
                    ),
                  ),
                ),
                Text('手札: ${myHand.length} / 7枚', style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}