import '../features/game/game_board_view.dart';

/// 数学的な判定ルールのみを司る。
class GameRules {
  static bool canMori({
    required int fieldNumber,
    required List<CardWidget> hand,
    required String? lastPlayerId,
    required String myId,
    required bool isInitialPhase,
  }) {
    if (isInitialPhase || fieldNumber == -1 || lastPlayerId == myId || lastPlayerId == 'system') {
      return false;
    }

    if (hand.length == 1) {
      return hand[0].number == fieldNumber;
    }
    
    if (hand.length == 2) {
      return _checkFourOperations(fieldNumber, hand[0].number, hand[1].number);
    }

    return false;
  }

  static bool _checkFourOperations(int target, int a, int b) {
    return (a + b == target) ||
           (a - b == target) ||
           (b - a == target) ||
           (a * b == target) ||
           (b != 0 && a % b == 0 && a ~/ b == target) ||
           (a != 0 && b % a == 0 && b ~/ a == target);
  }
}