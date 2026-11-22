
import '../controller/game_controller.dart';
import '../model/state.dart';

class BotInteractor {
  final GameController controller;
  final GameState state;

  BotInteractor({
    required this.controller,
    required this.state,
  });

  void executeMove(int fromIndex, int toIndex) {
    state.selectedPieceIndex = fromIndex;

    // state.pieces sarà una Int8List, coerente con la firma
    // di movePieceBot che abbiamo aggiornato nel Controller.
    controller.movePieceBot(
      toIndex,
      state.pieces,
      state.size,
      state.boardSize,
    );
  }
}