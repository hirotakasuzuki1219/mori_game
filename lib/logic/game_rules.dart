import '../features/game/game_board_view.dart';

class GameRules {
  /// バースト判定
  /// 引いて7枚になり、かつそのカードが出せない場合に敗北
  static bool isBurst(int handCount, bool canPlayDrawnCard) {
    return handCount >= 7 && !canPlayDrawnCard;
  }

  /// もり判定ロジック
  static bool isValidMori(int fieldNumber, List<CardWidget> selectedCards) {
    if (fieldNumber == -1 || selectedCards.isEmpty) return false;

    // ルール：ジョーカーは手札の枚数にはカウントされないため、除外したリストを作成
    final numbers = selectedCards
        .where((c) => c.suit != Suit.joker)
        .map((c) => c.number)
        .toList();
    
    int effectiveCount = numbers.length;

    // 1枚の場合（一致）
    if (effectiveCount == 1) {
      return numbers[0] == fieldNumber;
    }
    
    // 2枚の場合（四則演算）
    if (effectiveCount == 2) {
      int a = numbers[0];
      int b = numbers[1];
      return (a + b == fieldNumber) ||
             (a - b == fieldNumber) || (b - a == fieldNumber) ||
             (a * b == fieldNumber) ||
             (b != 0 && a % b == 0 && a ~/ b == fieldNumber) ||
             (a != 0 && b % a == 0 && b ~/ a == fieldNumber);
    }

    // 3枚以上の場合（すべての和）
    if (effectiveCount >= 3) {
      int sum = numbers.fold(0, (prev, n) => prev + n);
      return sum == fieldNumber;
    }

    return false;
  }

  /// 通常プレイ判定
  static bool canPlayNormal(int fieldNumber, Suit fieldSuit, CardWidget card) {
    if (fieldNumber == -1) return true; // 初期状態
    // ルール：場にジョーカーが出た場合は、早い者勝ちでどんなカードも出せる
    if (fieldSuit == Suit.joker) return true;
    
    return card.number == fieldNumber || card.suit == fieldSuit;
  }
}