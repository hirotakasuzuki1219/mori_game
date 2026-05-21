import 'package:mori_game/models/CardModel.dart';

class MoriLogic {
  /// もり判定のメインロジック
  static bool canMori({
    required int fieldNumber,
    required List<CardModel> hand,
    required String? lastPlayerId,
    required String myId,
    required bool isInitialPhase,
  }) {
    // 自分が直前に出した場合や、初期フェーズ、システムが場を出した直後は「もり」不可
    if (isInitialPhase || fieldNumber == -1 || lastPlayerId == myId || lastPlayerId == 'system') {
      return false;
    }

    // 手札が2枚の時：四則演算のいずれかで場の数字と一致するか
    if (hand.length == 2) {
      int a = hand[0].number;
      int b = hand[1].number;
      return _checkFourOperations(fieldNumber, a, b);
    }
    
    // 手札が1枚の時：相手が出した数字と自分の手札が一致
    if (hand.length == 1) {
      return hand[0].number == fieldNumber;
    }

    return false;
  }

  /// 四則演算（＋−×÷）の全パターンチェック
  static bool _checkFourOperations(int target, int a, int b) {
    return (a + b == target) ||
           (a - b == target) ||
           (b - a == target) ||
           (a * b == target) ||
           (b != 0 && a % b == 0 && a ~/ b == target) ||
           (a != 0 && b % a == 0 && b ~/ a == target);
  }
}