

import 'package:flutter/material.dart';
import '../model/state.dart';
import 'board.dart';


class ColorSelection extends StatelessWidget {

  final int _boardSize;

  int get boardSize => _boardSize;

  const ColorSelection({super.key, required int boardSize}) : _boardSize = boardSize;


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueGrey,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Pulsante "Bianco"
            Container(
              margin: const EdgeInsets.symmetric(vertical: 20),
              child: ElevatedButton(
                onPressed: () {
                  final state = GameState(boardSize: _boardSize);
                  state.playVsCPU = true;   // setter
                  state.botColor = true;
                  state.initPieces();        // inizializza i pezzi

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => Board(state: state),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  textStyle: const TextStyle(fontSize: 20),
                  backgroundColor: const Color.fromARGB(229, 255, 247, 103),
                ),
                child: const Text("Defenders"),
              ),
            ),
            // Pulsante "Nero"
            Container(
              margin: const EdgeInsets.symmetric(vertical: 20),
              child: ElevatedButton(
                onPressed: () {

                  /// Passarlo al controller.
                  /// Bisogna trasferire questa funzione al controller e sostiturire
                  /// quello che c'è qui con una funzione che chiama il controller.
                  final state = GameState(boardSize: _boardSize);
                  state.playVsCPU = true;    // setter
                  state.botColor = false;
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
                child: const Text("Attachers"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
