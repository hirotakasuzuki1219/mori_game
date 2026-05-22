import 'package:mori_game/models/CardModel.dart';

class MoriLogic {
  static bool canMori({
    required int fieldNumber,
    required List<CardModel> hand,
    required String? lastPlayerId,
    required String myId,
    required bool isInitialPhase,
  }) {
    if (isInitialPhase || fieldNumber == -1 || lastPlayerId == myId || lastPlayerId == 'system') {
      return false;
    }

    if (hand.length == 2) {
      int a = hand[0].number;
      int b = hand[1].number;
      return _checkFourOperations(fieldNumber, a, b);
    }
    
    if (hand.length == 1) {
      return hand[0].number == fieldNumber;
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