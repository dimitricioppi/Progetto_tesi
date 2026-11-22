

import 'dart:typed_data'; // NECESSARIO per Int8List
import '../model/state.dart';
import '../model/rules.dart';
import '../audio/sound.dart';
import '../model/CPU_engine.dart';
import '../model/CPU_interactor.dart';

class GameController {
  final void Function(String message) showWinDialog;
  final GameState state;
  final Rules rules;
  BotEngine? bot;
  BotInteractor? botInter;
  bool stopBot = false;

  GameController({required this.showWinDialog, required this.state})
      : rules = Rules(state) {
    botInter = BotInteractor(controller: this, state: state);
    bot = BotEngine(state: state, rules: rules, interactor: botInter);
    if (state.isPlayer1Turn == state.botColor && state.playVsCPU == true) {
      state.botTurn = true;
      bot?.calculateMove();
    }
  }

  // Seleziona un pezzo e calcola le mosse valide
  void selectPiece(int index, Int8List p, int size, int boardSize) {
    if (rules.pieceColor(index, p) == state.isPlayer1Turn &&
        (state.botTurn == false || state.playVsCPU == false)) {
      state.selectedPieceIndex = index;
      state.validMoves = rules.calculateValidMoves(index, p, size, boardSize);
    }
  }

  void deselect(int index) {
    state.selectedPieceIndex = null;
    state.validMoves = [];
  }

  void movePiece(int index, Int8List p, int size, int boardSize) {
    List<int> captured = [];
    int rep = 0;

    if (state.validMoves.contains(index)) {
      state.newIndex = index;
      state.oldIndex = state.selectedPieceIndex;

      int pezzoMosso = p[state.selectedPieceIndex!];

      // --- AGGIORNAMENTO SINCRONIZZATO: HASH E BITMASK ---
      // 1. Rimuoviamo il pezzo dalla posizione vecchia
      state.updateHash(state.selectedPieceIndex!, pezzoMosso);
      state.updateBitmask(state.selectedPieceIndex!, pezzoMosso);

      // 2. Aggiungiamo il pezzo nella posizione nuova
      state.updateHash(index, pezzoMosso);
      state.updateBitmask(index, pezzoMosso);
      // --------------------------------------------------

      p[index] = pezzoMosso;
      p[state.selectedPieceIndex!] = 0;

      state.oldMove.clear();
      state.oldMove.add(state.newIndex);
      state.oldMove.add(state.oldIndex);

      // La funzione capture ora usa le Bitmask internamente
      captured = rules.capture(index, p, size, boardSize, state.isPlayer1Turn);

      if (captured.isEmpty) {
        if (!state.volumeOff) playMoveSound();
      } else {
        if (!state.volumeOff) playCaptureSound();
        for (int removedIndex in captured) {
          // --- RIMOZIONE PEZZI CATTURATI ---
          state.updateHash(removedIndex, p[removedIndex]);
          state.updateBitmask(removedIndex, p[removedIndex]);
          // ---------------------------------
          p[removedIndex] = 0;
        }
      }

      state.moves = captured.isEmpty ? state.moves + 1 : 0;
      state.selectedPieceIndex = null;
      state.validMoves = [];

      state.boardStates.add(state.currentHash);

      int current = state.currentHash;
      for (int h in state.boardStates) {
        if (h == current) rep++;
      }

      if (rep >= 3) {
        state.repetition = true;
      }
      rep = 0;

      state.isPlayer1Turn = !state.isPlayer1Turn;
      checkForWin(size, boardSize, p);
      if (state.playVsCPU == true) {
        updateTurnFlags(state.isPlayer1Turn);
        bot?.calculateMove();
      }
    }
  }

  void movePieceBot(int index, Int8List p, int size, int boardSize) {
    List<int> captured = [];
    int rep = 0;

    if (stopBot == false) {
      state.newIndex = index;
      state.oldIndex = state.selectedPieceIndex;

      int pezzoMosso = p[state.selectedPieceIndex!];

      // --- AGGIORNAMENTO SINCRONIZZATO BOT: HASH E BITMASK ---
      state.updateHash(state.selectedPieceIndex!, pezzoMosso);
      state.updateBitmask(state.selectedPieceIndex!, pezzoMosso);

      state.updateHash(index, pezzoMosso);
      state.updateBitmask(index, pezzoMosso);
      // ------------------------------------------------------

      p[index] = pezzoMosso;
      p[state.selectedPieceIndex!] = 0;

      state.oldMove.clear();
      state.oldMove.add(state.newIndex);
      state.oldMove.add(state.oldIndex);

      captured = rules.capture(index, p, size, boardSize, state.isPlayer1Turn);

      if (captured.isEmpty) {
        if (!state.volumeOff) playMoveSound();
      } else {
        if (!state.volumeOff) playCaptureSound();
        for (int removedIndex in captured) {
          state.updateHash(removedIndex, p[removedIndex]);
          state.updateBitmask(removedIndex, p[removedIndex]);
          p[removedIndex] = 0;
        }
      }

      state.moves = captured.isEmpty ? state.moves + 1 : 0;
      state.selectedPieceIndex = null;
      state.validMoves = [];

      state.boardStates.add(state.currentHash);
      int current = state.currentHash;
      for (int h in state.boardStates) {
        if (h == current) rep++;
      }

      if (rep >= 3) {
        state.repetition = true;
      }
      rep = 0;

      state.isPlayer1Turn = !state.isPlayer1Turn;
      updateTurnFlags(state.isPlayer1Turn);
      checkForWin(size, boardSize, p);
    }
  }

  void checkForWin(int size, int boardSize, Int8List p) {
    bool draw = false;
    bool whiteWins = false;
    bool blackWins = false;

    // Vittoria Re negli angoli
    if (p[0] == 2 ||
        p[boardSize - 1] == 2 ||
        p[size - boardSize] == 2 ||
        p[size - 1] == 2) {
      whiteWins = true;
    }

    if (state.checkmate) blackWins = true;
    if (!p.any((piece) => piece == 2)) blackWins = true;

    if (state.playVsCPU == false) {
      if (rules.surround(p, size, boardSize)) blackWins = true;
      if (rules.fortress(p, size, boardSize)) whiteWins = true;
    }

    // Stalemate (Sonfitta dello stallato)
    if (state.isPlayer1Turn) {
      bool whiteStalemate = true;
      if (rules.stalemate(boardSize) == false) whiteStalemate = false;
      if (whiteStalemate) blackWins = true;
    } else {
      bool blackStalemate = true;
      if (rules.stalemate(boardSize) == false) blackStalemate = false;
      if (blackStalemate) whiteWins = true;
    }

    if (state.moves >= 100) {
      draw = true;
      state.moves = 0;
    }

    if (state.repetition) {
      blackWins = true;
      state.repetition = false;
    }

    if (whiteWins) {
      if (!state.volumeOff) playWinSound();
      showWinDialog("White wins!");
      stopBot = true;
    } else if (blackWins) {
      if (!state.volumeOff) playWinSound();
      showWinDialog("Black wins!");
      state.checkmate = false;
      stopBot = true;
    } else if (draw) {
      showWinDialog("Draw!");
      stopBot = true;
    }
  }

  void updateTurnFlags(bool turn) {
    state.botTurn = (state.isPlayer1Turn == state.botColor);
  }

  void resetGame() {
    state.initPieces();
    state.isPlayer1Turn = false;
    state.repetition = false;
    stopBot = false;

    if (state.isPlayer1Turn == state.botColor && state.playVsCPU == true) {
      state.botTurn = true;
      bot?.calculateMove();
    }
  }
}




/*
import 'dart:typed_data';
import '../model/state.dart';
import '../model/rules.dart';
import '../audio/sound.dart';
import '../model/CPU_engine.dart';
import '../model/CPU_interactor.dart';

class GameController {
  final void Function(String message) showWinDialog;
  final GameState state;
  final Rules rules;
  BotEngine? bot;
  BotInteractor? botInter;
  bool stopBot = false;

  GameController({required this.showWinDialog, required this.state})
      : rules = Rules(state) {
    botInter = BotInteractor(controller: this, state: state);
    bot = BotEngine(state: state, rules: rules, interactor: botInter);

    // Inizializziamo la maschera vuota
    state.validMovesMask = BigInt.zero;

    if (state.isPlayer1Turn == state.botColor && state.playVsCPU == true) {
      state.botTurn = true;
      bot?.calculateMove();
    }
  }

  // Seleziona un pezzo e calcola le mosse valide (Assegna alla Maschera)
  void selectPiece(int index, Int8List p, int size, int boardSize) {
    if (rules.pieceColor(index, p) == state.isPlayer1Turn &&
        (state.botTurn == false || state.playVsCPU == false)) {
      state.selectedPieceIndex = index;
      // Il setter validMovesMask aggiornerà internamente anche la lista validMoves per la UI
      state.validMovesMask = rules.calculateValidMoves(index, p, size, boardSize);
    }
  }

  void deselect(int index) {
    state.selectedPieceIndex = null;
    state.validMovesMask = BigInt.zero;
  }

  void movePiece(int index, Int8List p, int size, int boardSize) {
    List<int> captured = [];
    int rep = 0;

    // Verifica bitwise sulla maschera
    if ((state.validMovesMask & (BigInt.one << index)) != BigInt.zero) {
      state.newIndex = index;
      state.oldIndex = state.selectedPieceIndex;

      int pezzoMosso = p[state.selectedPieceIndex!];

      // Aggiornamento Hash e Bitmask
      state.updateHash(state.selectedPieceIndex!, pezzoMosso);
      state.updateBitmask(state.selectedPieceIndex!, pezzoMosso);

      state.updateHash(index, pezzoMosso);
      state.updateBitmask(index, pezzoMosso);

      p[index] = pezzoMosso;
      p[state.selectedPieceIndex!] = 0;

      state.oldMove.clear();
      state.oldMove.add(state.newIndex);
      state.oldMove.add(state.oldIndex);

      captured = rules.capture(index, p, size, boardSize);

      if (captured.isEmpty) {
        if (!state.volumeOff) playMoveSound();
      } else {
        if (!state.volumeOff) playCaptureSound();
        for (int removedIndex in captured) {
          state.updateHash(removedIndex, p[removedIndex]);
          state.updateBitmask(removedIndex, p[removedIndex]);
          p[removedIndex] = 0;
        }
      }

      state.moves = captured.isEmpty ? state.moves + 1 : 0;
      state.selectedPieceIndex = null;
      state.validMovesMask = BigInt.zero;

      state.boardStates.add(state.currentHash);

      int current = state.currentHash;
      for (int h in state.boardStates) {
        if (h == current) rep++;
      }

      if (rep >= 3) {
        state.repetition = true;
      }
      rep = 0;

      state.isPlayer1Turn = !state.isPlayer1Turn;
      checkForWin(size, boardSize, p);
      if (state.playVsCPU == true) {
        updateTurnFlags(state.isPlayer1Turn);
        bot?.calculateMove();
      }
    }
  }

  void movePieceBot(int index, Int8List p, int size, int boardSize) {
    List<int> captured = [];
    int rep = 0;

    if (stopBot == false) {
      state.newIndex = index;
      state.oldIndex = state.selectedPieceIndex;

      int pezzoMosso = p[state.selectedPieceIndex!];

      // Aggiornamento Hash e Bitmask BOT
      state.updateHash(state.selectedPieceIndex!, pezzoMosso);
      state.updateBitmask(state.selectedPieceIndex!, pezzoMosso);

      state.updateHash(index, pezzoMosso);
      state.updateBitmask(index, pezzoMosso);

      p[index] = pezzoMosso;
      p[state.selectedPieceIndex!] = 0;

      state.oldMove.clear();
      state.oldMove.add(state.newIndex);
      state.oldMove.add(state.oldIndex);

      captured = rules.capture(index, p, size, boardSize);

      if (captured.isEmpty) {
        if (!state.volumeOff) playMoveSound();
      } else {
        if (!state.volumeOff) playCaptureSound();
        for (int removedIndex in captured) {
          state.updateHash(removedIndex, p[removedIndex]);
          state.updateBitmask(removedIndex, p[removedIndex]);
          p[removedIndex] = 0;
        }
      }

      state.moves = captured.isEmpty ? state.moves + 1 : 0;
      state.selectedPieceIndex = null;
      state.validMovesMask = BigInt.zero;

      state.boardStates.add(state.currentHash);
      int current = state.currentHash;
      for (int h in state.boardStates) {
        if (h == current) rep++;
      }

      if (rep >= 3) {
        state.repetition = true;
      }
      rep = 0;

      state.isPlayer1Turn = !state.isPlayer1Turn;
      updateTurnFlags(state.isPlayer1Turn);
      checkForWin(size, boardSize, p);
    }
  }

  void checkForWin(int size, int boardSize, Int8List p) {
    bool draw = false;
    bool whiteWins = false;
    bool blackWins = false;

    if (p[0] == 2 ||
        p[boardSize - 1] == 2 ||
        p[size - boardSize] == 2 ||
        p[size - 1] == 2) {
      whiteWins = true;
    }

    if (state.checkmate) blackWins = true;
    if (!p.any((piece) => piece == 2)) blackWins = true;

    if (state.playVsCPU == false) {
      if (rules.surround(p, size, boardSize)) blackWins = true;
      if (rules.fortress(p, size, boardSize)) whiteWins = true;
    }

    if (state.isPlayer1Turn) {
      if (rules.stalemate(boardSize)) blackWins = true;
    } else {
      if (rules.stalemate(boardSize)) whiteWins = true;
    }

    if (state.moves >= 100) {
      draw = true;
      state.moves = 0;
    }

    if (state.repetition) {
      blackWins = true;
      state.repetition = false;
    }

    if (whiteWins) {
      if (!state.volumeOff) playWinSound();
      showWinDialog("White wins!");
      stopBot = true;
    } else if (blackWins) {
      if (!state.volumeOff) playWinSound();
      showWinDialog("Black wins!");
      state.checkmate = false;
      stopBot = true;
    } else if (draw) {
      showWinDialog("Draw!");
      stopBot = true;
    }
  }

  void updateTurnFlags(bool turn) {
    state.botTurn = (state.isPlayer1Turn == state.botColor);
  }

  void resetGame() {
    state.initPieces();
    state.isPlayer1Turn = false;
    state.repetition = false;
    state.validMovesMask = BigInt.zero;
    stopBot = false;

    if (state.isPlayer1Turn == state.botColor && state.playVsCPU == true) {
      state.botTurn = true;
      bot?.calculateMove();
    }
  }
}

 */