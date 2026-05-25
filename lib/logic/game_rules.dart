import '../features/game/game_board_view.dart';

class GameRules {
  /// バースト判定
  /// カードを引いて7枚になり、かつそのカードが出せない場合に敗北
  static bool isBurst(int handCount, bool canPlayDrawnCard) {
    return handCount >= 7 && !canPlayDrawnCard;
  }

  /// もり判定ロジック
  static bool isValidMori(int fieldNumber, List<CardWidget> selectedCards) {
    if (fieldNumber == -1 || selectedCards.isEmpty) return false;

    // ジョーカーを除いた純粋な数字カードのリストを作成
    final numbers = selectedCards
        .where((c) => c.suit != Suit.joker)
        .map((c) => c.number)
        .toList();
    
    // ジョーカーが含まれているか（枚数カウント除外ルール用）
    // ルール：ジョーカーは枚数にはカウントされない
    int effectiveCount = numbers.length;

    if (effectiveCount == 1) {
      return numbers[0] == fieldNumber;
    }
    
    if (effectiveCount == 2) {
      int a = numbers[0];
      int b = numbers[1];
      return (a + b == fieldNumber) ||
             (a - b == fieldNumber) || (b - a == fieldNumber) ||
             (a * b == fieldNumber) ||
             (b != 0 && a % b == 0 && a ~/ b == fieldNumber) ||
             (a != 0 && b % a == 0 && a ~/ b == fieldNumber);
    }

    if (effectiveCount >= 3) {
      int sum = numbers.fold(0, (prev, n) => prev + n);
      return sum == fieldNumber;
    }

    return false;
  }

  /// 通常プレイ判定
  static bool canPlayNormal(int fieldNumber, Suit fieldSuit, CardWidget card) {
    if (fieldNumber == -1) return true;

    // 場がジョーカーなら何でも出せる
    if (fieldSuit == Suit.joker) return true;
    
    // 同じスート or 同じ数字
    return card.number == fieldNumber || card.suit == fieldSuit;
  }
}