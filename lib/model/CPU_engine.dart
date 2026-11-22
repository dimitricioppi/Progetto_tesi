
/*
import 'dart:math';
import 'dart:typed_data';
import '../model/state.dart';
import '../model/rules.dart';
import '../model/CPU_interactor.dart';

class Move {
  final int fromIndex;
  final int toIndex;
  Move(this.fromIndex, this.toIndex);
}

class _ScoredMove {
  final Move move;
  final int score;
  _ScoredMove(this.move, this.score);
}

class BotEngine {
  final GameState state;
  final Rules rules;
  final BotInteractor? interactor;

  final int _searchDepth = 5;
  int _nodeCount = 0;
  final int _nodeLimit = 90000;
  final int _beamWidth = 30;

  int _kingEscapeCount = 0;

  BotEngine({required this.state, required this.rules, this.interactor});

  static const int WIN_SCORE = 1000000;

  // --- FUNZIONI DI UTILITÀ ---

  bool _isThroneAdjacent(int index, int throneIndex, int sideSize) {
    return index == throneIndex - 1 ||
        index == throneIndex + 1 ||
        index == throneIndex - sideSize ||
        index == throneIndex + sideSize;
  }

  int _getManhattanDistToNearestCorner(int index, int sideSize) {
    int row = index ~/ sideSize;
    int col = index % sideSize;
    return min(row, sideSize - 1 - row) + min(col, sideSize - 1 - col);
  }

  /// Calcola i "gradi di libertà" del Re sulla sua riga e colonna attuali (Linea di vista pura).
  int _getKingMobility(Int8List p, int kIdx, int bSize) {
    if (kIdx == -1) return 0;
    int mob = 0;
    int r = kIdx ~/ bSize, c = kIdx % bSize;

    for (int row = r - 1; row >= 0; row--) { if (p[row * bSize + c] != 0) break; mob++; }
    for (int row = r + 1; row < bSize; row++) { if (p[row * bSize + c] != 0) break; mob++; }
    for (int col = c - 1; col >= 0; col--) { if (p[r * bSize + col] != 0) break; mob++; }
    for (int col = c + 1; col < bSize; col++) { if (p[r * bSize + col] != 0) break; mob++; }

    return mob;
  }

  // --- LOGICA DI GIOCO ---

  void calculateMove() {
    if (state.isPlayer1Turn != state.botColor) return;

    final Int8List simPieces = Int8List.fromList(state.pieces);
    final List<int> simHistory = List<int>.from(state.boardStates);
    _nodeCount = 0;

    final rootMoves = _generateMovesForColor(simPieces, state.botColor);
    if (rootMoves.isEmpty) return;

    for (final m in rootMoves) {
      if (_isWinningMove(m, simPieces)) {
        interactor?.executeMove(m.fromIndex, m.toIndex);
        return;
      }
    }

    final orderedRoot = _orderedAndTrimmedMoves(rootMoves, simPieces, state.botColor, simHistory);
    Move? bestMove;
    int bestScore = state.botColor ? -0x3fffffff : 0x3fffffff;

    for (final m in orderedRoot) {
      if (_nodeCount >= _nodeLimit) break;
      final prevP = Int8List.fromList(simPieces);
      _makeSimMove(m, simPieces, simHistory);

      final eval = _minimax(
        pieces: simPieces,
        history: simHistory,
        depth: _searchDepth - 1,
        alpha: -0x3fffffff,
        beta: 0x3fffffff,
        maximizingPlayer: !state.botColor,
      );

      simPieces.setAll(0, prevP);
      simHistory.removeLast();

      if (state.botColor) {
        if (eval > bestScore) { bestScore = eval; bestMove = m; }
      } else {
        if (eval < bestScore) { bestScore = eval; bestMove = m; }
      }
    }

    if (bestMove != null) interactor?.executeMove(bestMove.fromIndex, bestMove.toIndex);
  }

  int _minimax({required Int8List pieces, required List<int> history, required int depth, required int alpha, required int beta, required bool maximizingPlayer}) {
    final int kingIdx = pieces.indexOf(2);
    if (kingIdx == -1) return -WIN_SCORE - depth;
    if (state.isSpecialCell[kingIdx] && kingIdx != state.centerIndex) return WIN_SCORE + depth;
    if (++_nodeCount >= _nodeLimit || depth == 0) return _evaluate(pieces, kingIdx, depth);

    final moves = _orderedAndTrimmedMoves(_generateMovesForColor(pieces, maximizingPlayer), pieces, maximizingPlayer, history);
    if (moves.isEmpty) return maximizingPlayer ? (-WIN_SCORE - depth) : (WIN_SCORE + depth);

    if (maximizingPlayer) {
      int maxEval = -0x3fffffff;
      for (final m in moves) {
        final prevP = Int8List.fromList(pieces);
        _makeSimMove(m, pieces, history);
        final eval = _minimax(pieces: pieces, history: history, depth: depth - 1, alpha: alpha, beta: beta, maximizingPlayer: false);
        pieces.setAll(0, prevP); history.removeLast();
        maxEval = max(maxEval, eval);
        alpha = max(alpha, eval);
        if (beta <= alpha) break;
      }
      return maxEval;
    } else {
      int minEval = 0x3fffffff;
      for (final m in moves) {
        final prevP = Int8List.fromList(pieces);
        _makeSimMove(m, pieces, history);
        final eval = _minimax(pieces: pieces, history: history, depth: depth - 1, alpha: alpha, beta: beta, maximizingPlayer: true);
        pieces.setAll(0, prevP); history.removeLast();
        minEval = min(minEval, eval);
        beta = min(beta, eval);
        if (beta <= alpha) break;
      }
      return minEval;
    }
  }

  int _evaluate(Int8List p, int k, int depth) {
    final bSize = state.boardSize;
    int score = 0;

    if (k == state.centerIndex) score -= 300000;
    else if (_isThroneAdjacent(k, state.centerIndex, bSize)) score -= 150000;

    _kingEscapeCount = _countKingEscapeMoves(p, k, bSize);
    if (_kingEscapeCount > 0) score += (_kingEscapeCount >= 2) ? 90000 : 35000;

    score += (bSize - _getManhattanDistToNearestCorner(k, bSize)) * 5000;

    int kingMobility = _getKingMobility(p, k, bSize);
    score += kingMobility * 5000;

    int wCount = 0, bCount = 0;
    for (int piece in p) {
      if (piece == 1) wCount++; else if (piece == -1) bCount++;
    }
    score += (wCount * 1200) - (bCount * 2200);
    return score;
  }

  List<Move> _orderedAndTrimmedMoves(List<Move> moves, Int8List p, bool side, List<int> history) {
    final bSize = state.boardSize;
    final int kingIdx = p.indexOf(2);

    if (kingIdx == -1) return moves;

    int currentKingMobility = _getKingMobility(p, kingIdx, bSize);

    int lastOurFrom = -1;
    if (history.length >= 2) lastOurFrom = history[history.length - 2] ~/ 1000;
    final int capturedType = side ? -1 : 1;

    final scored = moves.map((m) {
      int s = 0;

      int movedPiece = p[m.fromIndex];
      p[m.toIndex] = movedPiece;
      p[m.fromIndex] = 0;
      List<int> captures = rules.capture(m.toIndex, p, state.size, bSize);
      bool isKingCaptured = false;

      for (int c in captures) {
        if (p[c] == 2) isKingCaptured = true;
        p[c] = 0;
      }

      int newKingIdx = (movedPiece == 2) ? m.toIndex : kingIdx;
      int newKingMobility = _getKingMobility(p, newKingIdx, bSize);
      bool inDanger = _isCellInDanger(m.toIndex, p, bSize);

      if (side) { // --- BIANCO ---
        if (movedPiece == 2) {
          if (state.isSpecialCell[m.toIndex]) s += WIN_SCORE;
          s += newKingMobility * 30000;
          s += (bSize - _getManhattanDistToNearestCorner(m.toIndex, bSize)) * 15000;
          if (inDanger) s -= 100000;
        } else {
          // Pedine Bianche
          if (captures.isNotEmpty) {
            if (!inDanger) s += 400000;
            else s -= 10000;
          }

          if (newKingMobility > currentKingMobility) {
            s += (currentKingMobility <= bSize / 2) ? 350000 : 200000;
            if (inDanger && captures.isNotEmpty) s += 150000;
          }

          if (inDanger && captures.isEmpty) s -= 150000;
        }
      } else { // --- NERO ---
        if (isKingCaptured) {
          s += WIN_SCORE;
        } else {
          // Calcola la potenziale mobilità del Re al turno successivo
          int maxNextKingMobility = newKingMobility;
          List<int> kingMoves = rules.calculateValidMoves(kingIdx, p, state.size, bSize);

          for (int km in kingMoves) {
            // Simuliamo temporaneamente lo spostamento del Re
            p[km] = 2;
            p[kingIdx] = 0;
            int futureMob = _getKingMobility(p, km, bSize);
            if (futureMob > maxNextKingMobility) {
              maxNextKingMobility = futureMob;
            }
            // Ripristiniamo
            p[kingIdx] = 2;
            p[km] = 0;
          }

          // Flag di fuga: o il re è già stato sbloccato, o può farlo alla prossima mossa
          bool grantsKingEscape = (newKingMobility >= currentKingMobility + (bSize ~/ 2)) ||
              (maxNextKingMobility >= currentKingMobility + (bSize ~/ 2));

          if (captures.isNotEmpty) {
            if (grantsKingEscape) {
              s -= 300000; // Veto Assoluto
            } else {
              s += 400000;
              if (inDanger) s -= 20000;
            }
          } else {
            if (inDanger) s -= 400000;

            if (grantsKingEscape || newKingMobility > currentKingMobility) {
              s -= 200000;
            } else if (newKingMobility < currentKingMobility) {
              s += 300000;
            }

            if (m.toIndex == lastOurFrom) s -= 80000;
            int distToKing = (m.toIndex ~/ bSize - newKingIdx ~/ bSize).abs() + (m.toIndex % bSize - newKingIdx % bSize).abs();
            if (!inDanger) s += (bSize - distToKing) * 2000;
          }
        }
      }

      // Unmake
      for (int c in captures) p[c] = (c == kingIdx) ? 2 : capturedType;
      p[m.fromIndex] = movedPiece;
      p[m.toIndex] = 0;

      return _ScoredMove(m, s);
    }).toList();

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(_beamWidth).map((sm) => sm.move).toList();
  }

  // --- HELPERS (Nuova gestione Sicurezza) ---

  bool _isCellInDanger(int idx, Int8List p, int b) {
    final int piece = p[idx]; if (piece == 0) return false;
    final bool isWhite = (piece > 0);

    int r = idx ~/ b;
    int c = idx % b;

    final List<int> dC = [0, 0, -1, 1]; // Nord, Sud, Ovest, Est
    final List<int> dR = [-1, 1, 0, 0];

    for(int i = 0; i < 4; i++) {
      int adjR = r + dR[i];
      int adjC = c + dC[i];
      if (adjR < 0 || adjR >= b || adjC < 0 || adjC >= b) continue;
      int adjIdx = adjR * b + adjC;

      bool isEnemyAdj = state.isSpecialCell[adjIdx] || (p[adjIdx] != 0 && (p[adjIdx] > 0) != isWhite);

      if (isEnemyAdj) {
        int oppR = r - dR[i];
        int oppC = c - dC[i];
        if (oppR < 0 || oppR >= b || oppC < 0 || oppC >= b) continue;
        int oppIdx = oppR * b + oppC;

        if (p[oppIdx] == 0 && !state.isSpecialCell[oppIdx]) {
          if (_canEnemyReach(oppIdx, p, b, isWhite)) return true;
        }
      }
    }
    return false;
  }

  bool _canEnemyReach(int targetIdx, Int8List p, int b, bool isWhiteTarget) {
    int r = targetIdx ~/ b;
    int c = targetIdx % b;

    // Raggio Nord
    for (int row = r - 1; row >= 0; row--) {
      int i = row * b + c;
      if (p[i] != 0) {
        if ((p[i] > 0) != isWhiteTarget && p[i] != 2) return true;
        break;
      }
    }
    // Raggio Sud
    for (int row = r + 1; row < b; row++) {
      int i = row * b + c;
      if (p[i] != 0) {
        if ((p[i] > 0) != isWhiteTarget && p[i] != 2) return true;
        break;
      }
    }
    // Raggio Ovest
    for (int col = c - 1; col >= 0; col--) {
      int i = r * b + col;
      if (p[i] != 0) {
        if ((p[i] > 0) != isWhiteTarget && p[i] != 2) return true;
        break;
      }
    }
    // Raggio Est
    for (int col = c + 1; col < b; col++) {
      int i = r * b + col;
      if (p[i] != 0) {
        if ((p[i] > 0) != isWhiteTarget && p[i] != 2) return true;
        break;
      }
    }
    return false;
  }

  int _countKingEscapeMoves(Int8List pieces, int kingIdx, int sideSize) {
    int escapes = 0;
    if (kingIdx < sideSize) {
      bool bL = false, bH = false;
      for (int i in state.northEdgeIndices) {
        if (i == kingIdx || pieces[i] == 0) continue;
        if (i < kingIdx) bL = true; else bH = true;
        if (bL && bH) break;
      }
      if (!bL) escapes++; if (!bH) escapes++;
    } else if (kingIdx >= pieces.length - sideSize) {
      bool bL = false, bH = false;
      for (int i in state.southEdgeIndices) {
        if (i == kingIdx || pieces[i] == 0) continue;
        if (i < kingIdx) bL = true; else bH = true;
        if (bL && bH) break;
      }
      if (!bL) escapes++; if (!bH) escapes++;
    } else if (kingIdx % sideSize == 0) {
      bool bL = false, bH = false;
      for (int i in state.westEdgeIndices) {
        if (i == kingIdx || pieces[i] == 0) continue;
        if (i < kingIdx) bL = true; else bH = true;
        if (bL && bH) break;
      }
      if (!bL) escapes++; if (!bH) escapes++;
    } else if (kingIdx % sideSize == sideSize - 1) {
      bool bL = false, bH = false;
      for (int i in state.eastEdgeIndices) {
        if (i == kingIdx || pieces[i] == 0) continue;
        if (i < kingIdx) bL = true; else bH = true;
        if (bL && bH) break;
      }
      if (!bL) escapes++; if (!bH) escapes++;
    }
    return escapes;
  }

  void _makeSimMove(Move m, Int8List p, List<int> history) {
    p[m.toIndex] = p[m.fromIndex]; p[m.fromIndex] = 0;
    for (int idx in rules.capture(m.toIndex, p, state.size, state.boardSize)) p[idx] = 0;
    history.add(m.fromIndex * 1000 + m.toIndex);
  }

  List<Move> _generateMovesForColor(Int8List p, bool color) {
    final moves = <Move>[];
    for (int i = 0; i < p.length; i++) {
      if (rules.pieceColor(i, p) == color) {
        for (int to in rules.calculateValidMoves(i, p, state.size, state.boardSize)) moves.add(Move(i, to));
      }
    }
    return moves;
  }

  bool _isWinningMove(Move m, Int8List p) => (p[m.fromIndex] == 2 && state.isSpecialCell[m.toIndex] && m.toIndex != state.centerIndex);
}

 */

import 'dart:math';
import 'dart:typed_data';
import 'package:viking_chess/model/tactical_engine.dart';

import '../model/state.dart';
import '../model/rules.dart';
import '../model/CPU_interactor.dart';
import '../model/reactive_engine.dart';

class Move {
  final int fromIndex;
  final int toIndex;
  Move(this.fromIndex, this.toIndex);
}

class _ScoredMove {
  final Move move;
  final int score;
  _ScoredMove(this.move, this.score);
}

class BotEngine {
  final GameState state;
  final Rules rules;
  final BotInteractor? interactor;

  final int _searchDepth = 5;
  int _nodeCount = 0;
  final int _nodeLimit = 90000;
  final int _beamWidth = 30;

  int _kingEscapeCount = 0;

  BotEngine({required this.state, required this.rules, this.interactor});

  static const int WIN_SCORE = 1000000;

  // --- FUNZIONI DI UTILITÀ ---

  bool _isThroneAdjacent(int index, int throneIndex, int sideSize) {
    return index == throneIndex - 1 ||
        index == throneIndex + 1 ||
        index == throneIndex - sideSize ||
        index == throneIndex + sideSize;
  }

  int _getManhattanDistToNearestCorner(int index, int sideSize) {
    int row = index ~/ sideSize;
    int col = index % sideSize;
    return min(row, sideSize - 1 - row) + min(col, sideSize - 1 - col);
  }

  int _getKingMobility(Int8List p, int kIdx, int bSize) {
    if (kIdx == -1) return 0;
    int mob = 0;
    int r = kIdx ~/ bSize, c = kIdx % bSize;

    for (int row = r - 1; row >= 0; row--) { if (p[row * bSize + c] != 0) break; mob++; }
    for (int row = r + 1; row < bSize; row++) { if (p[row * bSize + c] != 0) break; mob++; }
    for (int col = c - 1; col >= 0; col--) { if (p[r * bSize + col] != 0) break; mob++; }
    for (int col = c + 1; col < bSize; col++) { if (p[r * bSize + col] != 0) break; mob++; }

    return mob;
  }

  // --- LOGICA DI GIOCO ---

  void calculateMove() {
    if (state.isPlayer1Turn != state.botColor) return;

    // 1. CHIAMATA AL REACTIVE ENGINE (Priorità Massima)
    // Se l'engine trova una mossa tattica (cattura, difesa, vittoria), la eseguiamo subito.
    final reactive = ReactiveEngine(state: state, rules: rules);
    final reactiveMove = reactive.analyze();

    if (reactiveMove != null) {
      interactor?.executeMove(reactiveMove.fromIndex, reactiveMove.toIndex);
      return; // Bypass completo del Minimax
    }

    // 1. CHIAMATA AL TACTICAL ENGINE (Priorità Secondaria)
    // Se l'engine trova una mossa tattica (cattura, difesa, vittoria), la eseguiamo subito.
    final tactical = TacticalEngine(state: state, rules: rules);
    final tacticalMove = tactical.analyze();

    if (tacticalMove != null) {
      interactor?.executeMove(tacticalMove.fromIndex, tacticalMove.toIndex);
      return; // Bypass completo del Minimax
    }

    // 2. LOGICA MINIMAX (Se il ReactiveEngine non ha trovato mosse prioritarie)
    final Int8List simPieces = Int8List.fromList(state.pieces);
    final List<int> simHistory = List<int>.from(state.boardStates);
    _nodeCount = 0;

    final rootMoves = _generateMovesForColor(simPieces, state.botColor);
    if (rootMoves.isEmpty) return;

    // Controllo vittoria immediata (Ridondante se il ReactiveEngine è ben fatto, ma sicuro)
    for (final m in rootMoves) {
      if (_isWinningMove(m, simPieces)) {
        interactor?.executeMove(m.fromIndex, m.toIndex);
        return;
      }
    }

    final orderedRoot = _orderedAndTrimmedMoves(rootMoves, simPieces, state.botColor, simHistory);
    Move? bestMove;
    int bestScore = state.botColor ? -0x3fffffff : 0x3fffffff;

    for (final m in orderedRoot) {
      if (_nodeCount >= _nodeLimit) break;
      final prevP = Int8List.fromList(simPieces);
      _makeSimMove(m, simPieces, simHistory);

      final eval = _minimax(
        pieces: simPieces,
        history: simHistory,
        depth: _searchDepth - 1,
        alpha: -0x3fffffff,
        beta: 0x3fffffff,
        maximizingPlayer: !state.botColor,
      );

      simPieces.setAll(0, prevP);
      simHistory.removeLast();

      if (state.botColor) {
        if (eval > bestScore) { bestScore = eval; bestMove = m; }
      } else {
        if (eval < bestScore) { bestScore = eval; bestMove = m; }
      }
    }

    if (bestMove != null) interactor?.executeMove(bestMove.fromIndex, bestMove.toIndex);
  }

  int _minimax({required Int8List pieces, required List<int> history, required int depth, required int alpha, required int beta, required bool maximizingPlayer}) {
    final int kingIdx = pieces.indexOf(2);
    if (kingIdx == -1) return -WIN_SCORE - depth;
    if (state.isSpecialCell[kingIdx] && kingIdx != state.centerIndex) return WIN_SCORE + depth;
    if (++_nodeCount >= _nodeLimit || depth == 0) return _evaluate(pieces, kingIdx, depth);

    final moves = _orderedAndTrimmedMoves(_generateMovesForColor(pieces, maximizingPlayer), pieces, maximizingPlayer, history);
    if (moves.isEmpty) return maximizingPlayer ? (-WIN_SCORE - depth) : (WIN_SCORE + depth);

    if (maximizingPlayer) {
      int maxEval = -0x3fffffff;
      for (final m in moves) {
        final prevP = Int8List.fromList(pieces);
        _makeSimMove(m, pieces, history);
        final eval = _minimax(pieces: pieces, history: history, depth: depth - 1, alpha: alpha, beta: beta, maximizingPlayer: false);
        pieces.setAll(0, prevP); history.removeLast();
        maxEval = max(maxEval, eval);
        alpha = max(alpha, eval);
        if (beta <= alpha) break;
      }
      return maxEval;
    } else {
      int minEval = 0x3fffffff;
      for (final m in moves) {
        final prevP = Int8List.fromList(pieces);
        _makeSimMove(m, pieces, history);
        final eval = _minimax(pieces: pieces, history: history, depth: depth - 1, alpha: alpha, beta: beta, maximizingPlayer: true);
        pieces.setAll(0, prevP); history.removeLast();
        minEval = min(minEval, eval);
        beta = min(beta, eval);
        if (beta <= alpha) break;
      }
      return minEval;
    }
  }

  int _evaluate(Int8List p, int k, int depth) {
    final bSize = state.boardSize;
    int score = 0;

    if (k == state.centerIndex) score -= 300000;
    else if (_isThroneAdjacent(k, state.centerIndex, bSize)) score -= 150000;

    _kingEscapeCount = _countKingEscapeMoves(p, k, bSize);
    if (_kingEscapeCount > 0) score += (_kingEscapeCount >= 2) ? 90000 : 35000;

    score += (bSize - _getManhattanDistToNearestCorner(k, bSize)) * 5000;

    int kingMobility = _getKingMobility(p, k, bSize);
    score += kingMobility * 5000;

    int wCount = 0, bCount = 0;
    for (int piece in p) {
      if (piece == 1) wCount++; else if (piece == -1) bCount++;
    }
    score += (wCount * 1200) - (bCount * 2200);
    return score;
  }

  List<Move> _orderedAndTrimmedMoves(List<Move> moves, Int8List p, bool side, List<int> history) {
    final bSize = state.boardSize;
    final int kingIdx = p.indexOf(2);

    if (kingIdx == -1) return moves;

    int currentKingMobility = _getKingMobility(p, kingIdx, bSize);

    int lastOurFrom = -1;
    if (history.length >= 2) lastOurFrom = history[history.length - 2] ~/ 1000;
    final int capturedType = side ? -1 : 1;

    final scored = moves.map((m) {
      int s = 0;

      int movedPiece = p[m.fromIndex];
      p[m.toIndex] = movedPiece;
      p[m.fromIndex] = 0;
      List<int> captures = rules.capture(m.toIndex, p, state.size, bSize, state.isPlayer1Turn);
      bool isKingCaptured = false;

      for (int c in captures) {
        if (p[c] == 2) isKingCaptured = true;
        p[c] = 0;
      }

      int newKingIdx = (movedPiece == 2) ? m.toIndex : kingIdx;
      int newKingMobility = _getKingMobility(p, newKingIdx, bSize);
      bool inDanger = _isCellInDanger(m.toIndex, p, bSize);

      if (side) { // --- BIANCO ---
        if (movedPiece == 2) {
          if (state.isSpecialCell[m.toIndex]) s += WIN_SCORE;
          s += newKingMobility * 30000;
          s += (bSize - _getManhattanDistToNearestCorner(m.toIndex, bSize)) * 15000;
          if (inDanger) s -= 100000;
        } else {
          if (captures.isNotEmpty) {
            if (!inDanger) s += 400000;
            else s -= 10000;
          }
          if (newKingMobility > currentKingMobility) {
            s += (currentKingMobility <= bSize / 2) ? 350000 : 200000;
            if (inDanger && captures.isNotEmpty) s += 150000;
          }
          if (inDanger && captures.isEmpty) s -= 150000;
        }
      } else { // --- NERO ---
        if (isKingCaptured) {
          s += WIN_SCORE;
        } else {
          int maxNextKingMobility = newKingMobility;
          List<int> kingMoves = rules.calculateValidMoves(kingIdx, p, state.size, bSize);
          for (int km in kingMoves) {
            p[km] = 2; p[kingIdx] = 0;
            int futureMob = _getKingMobility(p, km, bSize);
            if (futureMob > maxNextKingMobility) maxNextKingMobility = futureMob;
            p[kingIdx] = 2; p[km] = 0;
          }

          bool grantsKingEscape = (newKingMobility >= currentKingMobility + (bSize ~/ 2)) ||
              (maxNextKingMobility >= currentKingMobility + (bSize ~/ 2));

          if (captures.isNotEmpty) {
            if (grantsKingEscape) s -= 300000;
            else {
              s += 400000;
              if (inDanger) s -= 20000;
            }
          } else {
            if (inDanger) s -= 400000;
            if (grantsKingEscape || newKingMobility > currentKingMobility) {
              s -= 200000;
            } else if (newKingMobility < currentKingMobility) {
              s += 300000;
            }
            if (m.toIndex == lastOurFrom) s -= 80000;
            int distToKing = (m.toIndex ~/ bSize - newKingIdx ~/ bSize).abs() + (m.toIndex % bSize - newKingIdx % bSize).abs();
            if (!inDanger) s += (bSize - distToKing) * 2000;
          }
        }
      }

      for (int c in captures) p[c] = (c == kingIdx) ? 2 : capturedType;
      p[m.fromIndex] = movedPiece;
      p[m.toIndex] = 0;

      return _ScoredMove(m, s);
    }).toList();

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(_beamWidth).map((sm) => sm.move).toList();
  }

  // --- HELPERS ---

  bool _isCellInDanger(int idx, Int8List p, int b) {
    final int piece = p[idx]; if (piece == 0) return false;
    final bool isWhite = (piece > 0);
    int r = idx ~/ b, c = idx % b;
    final List<int> dC = [0, 0, -1, 1], dR = [-1, 1, 0, 0];

    for(int i = 0; i < 4; i++) {
      int adjR = r + dR[i], adjC = c + dC[i];
      if (adjR < 0 || adjR >= b || adjC < 0 || adjC >= b) continue;
      int adjIdx = adjR * b + adjC;
      bool isEnemyAdj = state.isSpecialCell[adjIdx] || (p[adjIdx] != 0 && (p[adjIdx] > 0) != isWhite);

      if (isEnemyAdj) {
        int oppR = r - dR[i], oppC = c - dC[i];
        if (oppR < 0 || oppR >= b || oppC < 0 || oppC >= b) continue;
        int oppIdx = oppR * b + oppC;
        if (p[oppIdx] == 0 && !state.isSpecialCell[oppIdx]) {
          if (_canEnemyReach(oppIdx, p, b, isWhite)) return true;
        }
      }
    }
    return false;
  }

  bool _canEnemyReach(int targetIdx, Int8List p, int b, bool isWhiteTarget) {
    int r = targetIdx ~/ b, c = targetIdx % b;
    for (var dir in [[-1, 0], [1, 0], [0, -1], [0, 1]]) {
      for (int dist = 1; dist < b; dist++) {
        int nr = r + dir[0] * dist, nc = c + dir[1] * dist;
        if (nr < 0 || nr >= b || nc < 0 || nc >= b) break;
        int i = nr * b + nc;
        if (p[i] != 0) {
          if ((p[i] > 0) != isWhiteTarget && p[i] != 2) return true;
          break;
        }
      }
    }
    return false;
  }

  int _countKingEscapeMoves(Int8List pieces, int kingIdx, int sideSize) {
    int escapes = 0;
    if (kingIdx < sideSize) {
      bool bL = false, bH = false;
      for (int i in state.northEdgeIndices) {
        if (i == kingIdx || pieces[i] == 0) continue;
        if (i < kingIdx) bL = true; else bH = true;
      }
      if (!bL) escapes++; if (!bH) escapes++;
    } else if (kingIdx >= pieces.length - sideSize) {
      bool bL = false, bH = false;
      for (int i in state.southEdgeIndices) {
        if (i == kingIdx || pieces[i] == 0) continue;
        if (i < kingIdx) bL = true; else bH = true;
      }
      if (!bL) escapes++; if (!bH) escapes++;
    } else if (kingIdx % sideSize == 0) {
      bool bL = false, bH = false;
      for (int i in state.westEdgeIndices) {
        if (i == kingIdx || pieces[i] == 0) continue;
        if (i < kingIdx) bL = true; else bH = true;
      }
      if (!bL) escapes++; if (!bH) escapes++;
    } else if (kingIdx % sideSize == sideSize - 1) {
      bool bL = false, bH = false;
      for (int i in state.eastEdgeIndices) {
        if (i == kingIdx || pieces[i] == 0) continue;
        if (i < kingIdx) bL = true; else bH = true;
      }
      if (!bL) escapes++; if (!bH) escapes++;
    }
    return escapes;
  }

  void _makeSimMove(Move m, Int8List p, List<int> history) {
    p[m.toIndex] = p[m.fromIndex]; p[m.fromIndex] = 0;
    for (int idx in rules.capture(m.toIndex, p, state.size, state.boardSize, state.isPlayer1Turn)) p[idx] = 0;
    history.add(m.fromIndex * 1000 + m.toIndex);
  }

  List<Move> _generateMovesForColor(Int8List p, bool color) {
    final moves = <Move>[];
    for (int i = 0; i < p.length; i++) {
      if (rules.pieceColor(i, p) == color) {
        for (int to in rules.calculateValidMoves(i, p, state.size, state.boardSize)) moves.add(Move(i, to));
      }
    }
    return moves;
  }

  bool _isWinningMove(Move m, Int8List p) => (p[m.fromIndex] == 2 && state.isSpecialCell[m.toIndex] && m.toIndex != state.centerIndex);
}