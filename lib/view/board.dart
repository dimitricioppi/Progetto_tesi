
/*

import 'package:flutter/material.dart';
import '../model/state.dart';
import '../view/piece.dart';
import '../controller/game_controller.dart';
import 'menu.dart';

class Board extends StatefulWidget {
  final GameState state;
  const Board({super.key, required this.state});

  @override
  BoardState createState() => BoardState();
}

class BoardState extends State<Board> {
  late GameController controller;

  @override
  void initState() {
    super.initState();
    // Inizializza i pezzi (che ora usa internamente Int8List e fillRange)
    widget.state.initPieces();
    controller = GameController(
      showWinDialog: showWinDialog,
      state: widget.state,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Variabili locali per scansionabilità e performance
    final int size = widget.state.size;
    final int sideSize = widget.state.boardSize;
    final int center = (size - 1) ~/ 2; // Divisione intera veloce

    // Indici degli angoli (hostile boxes)
    final int upL = 0;
    final int upR = sideSize - 1;
    final int downL = size - sideSize;
    final int downR = size - 1;
    final List<int> hostileBoxes = [upL, upR, downL, downR];

    return Container(
      color: Colors.blueGrey,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: MediaQuery.of(context).size.width + 20,
            width: MediaQuery.of(context).size.width - 20,
            alignment: Alignment.center,
            color: Colors.blueGrey,
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: size,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: sideSize,
              ),
              itemBuilder: (context, index) {
                // Lettura diretta dal buffer Int8List dello stato
                final int pieceValue = widget.state.pieces[index];
                final bool isKing = (pieceValue == 2);

                final bool isSelected = index == widget.state.selectedPieceIndex;
                final bool isValidMove = widget.state.validMoves.contains(index);
                final bool isOldPos = widget.state.oldMove.contains(index);

                // Determinazione stile cella
                int cellType = 0; // 0: normale, 1: angolo, 2: centro
                if (hostileBoxes.contains(index)) {
                  cellType = 1;
                } else if (index == center) {
                  cellType = 2;
                }

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (pieceValue != 0) {
                        controller.selectPiece(
                          index,
                          widget.state.pieces,
                          size,
                          sideSize,
                        );
                      } else if (isValidMove) {
                        controller.movePiece(
                          index,
                          widget.state.pieces,
                          size,
                          sideSize,
                        );
                      } else {
                        controller.deselect(index);
                      }
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: cellType == 1
                          ? Colors.brown
                          : cellType == 2
                          ? Colors.black
                          : const Color.fromARGB(150, 232, 186, 126),
                      border: Border.all(
                        color: Colors.black,
                        width: 1.5,
                      ),
                    ),
                    child: Stack(
                      children: [
                        // Overlay di stato (Movimenti/Selezione)
                        if (isSelected)
                          Container(color: Colors.yellow.withValues(alpha: 0.4)),
                        if (isValidMove)
                          Container(color: Colors.green.withValues(alpha: 0.4)),
                        if (isOldPos)
                          Container(color: Colors.redAccent.withValues(alpha: 0.4)),

                        // Rendering del pezzo
                        if (pieceValue != 0)
                          Center(
                            child: Piece(
                              isPlayer1: pieceValue,
                              isKing: isKing,
                              isBigBoard: sideSize > 11,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 20),

          // Pulsantiera
          Wrap(
            spacing: 10,
            children: [
              _buildActionButton('New Game', () {
                setState(() {
                  controller.resetGame();
                });
              }),
              _buildActionButton(widget.state.volumeOff ? "Unmute" : "Mute", () {
                setState(() {
                  widget.state.volumeOff = !widget.state.volumeOff;
                });
              }),
            ],
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: _buildActionButton("Return to menu", () {
              // Pulizia stato prima di uscire
              widget.state.initPieces();

              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => MainMenu()),
                    (route) => false,
              );
            }),
          ),
        ],
      ),
    );
  }

  // Widget helper per i bottoni
  Widget _buildActionButton(String text, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        backgroundColor: const Color.fromARGB(229, 255, 247, 103),
        foregroundColor: Colors.black,
      ),
      child: Text(text),
    );
  }

  void showWinDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false, // Obbligatorio per forzare il restart
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(message),
          actions: [
            TextButton(
              child: const Text("Restart Game"),
              onPressed: () {
                setState(() {
                  controller.resetGame();
                });
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}

 */

import 'package:flutter/material.dart';
import '../model/state.dart';
import '../view/piece.dart';
import '../controller/game_controller.dart';
import 'menu.dart';

class Board extends StatefulWidget {
  final GameState state;
  const Board({super.key, required this.state});

  @override
  BoardState createState() => BoardState();
}

class BoardState extends State<Board> {
  late GameController controller;
  // Notifier per notificare alla Grid quale indice è cambiato
  final ValueNotifier<int?> _updateNotifier = ValueNotifier<int?>(null);

  @override
  void initState() {
    super.initState();
    widget.state.initPieces();
    controller = GameController(
      showWinDialog: showWinDialog,
      state: widget.state,
    );
  }

  @override
  void dispose() {
    _updateNotifier.dispose();
    super.dispose();
  }

  // Helper per calcolare il tipo di cella una sola volta
  int _getCellType(int index, int sideSize, int size, int center) {
    if (index == 0 || index == sideSize - 1 || index == size - sideSize || index == size - 1) return 1;
    if (index == center) return 2;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final int size = widget.state.size;
    final int sideSize = widget.state.boardSize;
    final int center = (size - 1) ~/ 2;

    return Container(
      color: Colors.blueGrey,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: MediaQuery.of(context).size.width + 20,
            width: MediaQuery.of(context).size.width - 20,
            alignment: Alignment.center,
            color: Colors.blueGrey,
            child: RepaintBoundary( // Ottimizzazione 1: Isola il disegno della griglia
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                itemCount: size,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: sideSize,
                ),
                itemBuilder: (context, index) {
                  final int cellType = _getCellType(index, sideSize, size, center);

                  // Ottimizzazione 2: Usiamo un widget specializzato per ogni cella
                  return BoardTile(
                    index: index,
                    state: widget.state,
                    controller: controller,
                    cellType: cellType,
                    // Passiamo una funzione che scatena il rebuild solo se necessario
                    onMoveExecuted: (Function action) => setState(() => action()),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 20),
          _buildControls(),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Column(
      children: [
        Wrap(
          spacing: 10,
          children: [
            _buildActionButton('New Game', () => setState(() => controller.resetGame())),
            _buildActionButton(widget.state.volumeOff ? "Unmute" : "Mute",
                    () => setState(() => widget.state.volumeOff = !widget.state.volumeOff)),
          ],
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: _buildActionButton("Return to menu", () {
            widget.state.initPieces();
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => MainMenu()),
                  (route) => false,
            );
          }),
        ),
      ],
    );
  }

  Widget _buildActionButton(String text, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        backgroundColor: const Color.fromARGB(229, 255, 247, 103),
        foregroundColor: Colors.black,
      ),
      child: Text(text),
    );
  }

  void showWinDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(message),
        actions: [
          TextButton(
            child: const Text("Restart Game"),
            onPressed: () {
              setState(() => controller.resetGame());
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}

// --- NUOVO WIDGET OTTIMIZZATO PER LA SINGOLA CELLA ---

class BoardTile extends StatelessWidget {
  final int index;
  final GameState state;
  final GameController controller;
  final int cellType;
  final Function(Function) onMoveExecuted;

  const BoardTile({
    super.key,
    required this.index,
    required this.state,
    required this.controller,
    required this.cellType,
    required this.onMoveExecuted,
  });

  @override
  Widget build(BuildContext context) {
    // Estraiamo i valori necessari dallo stato
    final int pieceValue = state.pieces[index];
    final bool isSelected = index == state.selectedPieceIndex;
    final bool isValidMove = state.validMoves.contains(index);
    //final bool isValidMove = (state.validMovesMask & (BigInt.one << index)) != BigInt.zero;
    final bool isOldPos = state.oldMove.contains(index);

    return GestureDetector(
      onTap: () {
        // Qui sta il trucco: chiamiamo setState della Board solo se effettivamente
        // avviene un'azione che richiede un refresh completo o un cambio turno.
        if (pieceValue != 0) {
          onMoveExecuted(() => controller.selectPiece(index, state.pieces, state.size, state.boardSize)); // Trigger per mostrare la selezione
        } else if (isValidMove) {
          onMoveExecuted(() => controller.movePiece(index, state.pieces, state.size, state.boardSize)); // Trigger per muovere
        } else {
          onMoveExecuted(() => controller.deselect(index));
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: cellType == 1 ? Colors.brown :
          cellType == 2 ? Colors.black :
          const Color.fromARGB(150, 232, 186, 126),
          border: Border.all(color: Colors.black, width: 0.8),
        ),
        child: Stack(
          children: [
            if (isSelected) Container(color: Colors.yellow.withValues(alpha: 0.4)),
            if (isValidMove) Container(color: Colors.green.withValues(alpha: 0.4)),
            if (isOldPos) Container(color: Colors.redAccent.withValues(alpha: 0.4)),
            if (pieceValue != 0)
              Center(
                child: Piece(
                  isPlayer1: pieceValue,
                  isKing: pieceValue == 2,
                  isBigBoard: state.boardSize > 11,
                ),
              ),
          ],
        ),
      ),
    );
  }
}