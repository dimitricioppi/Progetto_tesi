
import 'package:flutter/material.dart';
import 'package:viking_chess/view/color_selection.dart';
import '../model/state.dart';
import 'board.dart';


class GameModeSelection extends StatelessWidget {

  final int _boardSize;

  int get boardSize => _boardSize;

  const GameModeSelection({super.key, required int boardSize}) : _boardSize = boardSize;




  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueGrey,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Pulsante "Play vs Human"
            Container(
              margin: const EdgeInsets.symmetric(vertical: 20),
              child: ElevatedButton(
                onPressed: () {
                  final state = GameState(boardSize: _boardSize);
                  state.playVsCPU = false;   // setter
                  state.initPieces();        // inizializza i pezzi

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => Board(state: state), // passiamo lo stato
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  textStyle: const TextStyle(fontSize: 20),
                  backgroundColor: const Color.fromARGB(229, 255, 247, 103),
                ),
                child: const Text("Play vs Human"),
              ),
            ),
            // Pulsante "Play vs CPU"
            Container(
              margin: const EdgeInsets.symmetric(vertical: 20),
              child: ElevatedButton(
                onPressed: () {

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ColorSelection(boardSize: _boardSize),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  textStyle: const TextStyle(fontSize: 20),
                  backgroundColor: const Color.fromARGB(229, 255, 247, 103),
                ),
                child: const Text("Play vs CPU"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
