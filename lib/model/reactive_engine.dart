


/*
import 'dart:typed_data';
import 'dart:math';
import '../model/state.dart';
import '../model/rules.dart';
import '../model/CPU_engine.dart';

class ReactiveEngine {
  final GameState state;
  final Rules rules;

  ReactiveEngine({required this.state, required this.rules});

  Move? analyze() {
    return state.isPlayer1Turn ? _whiteStrategy() : _blackStrategy();
  }

  // --- ORCHESTRATORE BIANCO ---
  Move? _whiteStrategy() {
    Int8List p = state.pieces;
    Move? move = _checkWhiteVictory(p);
    if (move != null) return move;

    move = _checkKingInDanger(p);
    if (move != null) return move;

    move = _checkWhiteCaptures(p);
    if (move != null) return move;

    return null;
  }

  // --- ORCHESTRATORE NERO ---
  Move? _blackStrategy() {
    Int8List p = state.pieces;
    Move? move = _checkBlackLethal(p);
    if (move != null) return move;

    move = _interceptKingEscape(p);
    if (move != null) return move;

    move = _checkBlackCaptures(p);
    if (move != null) return move;

    return null;
  }

  // ===========================================================================
  // LOGICA BIANCO
  // ===========================================================================

  Move? _checkWhiteVictory(Int8List p) {
    int kingIdx = p.indexOf(2);
    if (kingIdx == -1) return null;
    List<int> moves = rules.calculateValidMoves(kingIdx, p, state.size, state.boardSize);
    for (int t in moves) {
      if (state.isSpecialCell[t] && t != state.centerIndex) return Move(kingIdx, t);
    }
    return null;
  }

  Move? _checkKingInDanger(Int8List p) {
    int kIdx = p.indexOf(2);
    int b = state.boardSize;
    List<int> adjBlacks = [];
    int freeSpot = -1;
    final neighbors = [kIdx - b, kIdx + b, kIdx - 1, kIdx + 1];

    for (int n in neighbors) {
      if (n < 0 || n >= state.size) continue;
      if (p[n] == -1) adjBlacks.add(n);
      else if (p[n] == 0) freeSpot = n;
    }

    if (adjBlacks.length >= 3 && freeSpot != -1) {
      for (int blackIdx in adjBlacks) {
        for (int i = 0; i < p.length; i++) {
          if (p[i] == 1) {
            List<int> wMoves = rules.calculateValidMoves(i, p, state.size, b);
            for (int tm in wMoves) {
              int oldVal = p[tm]; p[tm] = 1; p[i] = 0;
              var caps = rules.capture(tm, p, state.size, b, state.isPlayer1Turn);
              p[i] = 1; p[tm] = oldVal;
              if (caps.contains(blackIdx)) return Move(i, tm);
            }
          }
        }
      }
      return _getBestEscapeMove(kIdx, p, b);
    }
    return null;
  }

  Move? _checkWhiteCaptures(Int8List p) {
    int b = state.boardSize;
    int kIdx = p.indexOf(2);
    List<Move> intralcioSafe = [];
    List<Move> otherSafe = [];
    List<Move> sacrificeMultikill = [];

    for (int i = 0; i < p.length; i++) {
      if (p[i] == 1) {
        List<int> moves = rules.calculateValidMoves(i, p, state.size, b);
        for (int m in moves) {
          List<int> targets = rules.capture(m, p, state.size, b, state.isPlayer1Turn);
          if (targets.isEmpty) continue;

          bool inDanger = _isCellInDanger(m, p, b, ignoreIndices: targets);

          if (!inDanger) {
            bool intralcia = targets.any((t) => (t ~/ b == kIdx ~/ b || t % b == kIdx % b));
            if (intralcia) intralcioSafe.add(Move(i, m));
            else otherSafe.add(Move(i, m));
          } else if (targets.length >= 2) {
            sacrificeMultikill.add(Move(i, m));
          }
        }
      }
    }
    if (intralcioSafe.isNotEmpty) return intralcioSafe[0];
    if (otherSafe.isNotEmpty) return otherSafe[0];
    if (sacrificeMultikill.isNotEmpty) return sacrificeMultikill[0];
    return null;
  }

  // ===========================================================================
  // LOGICA NERO
  // ===========================================================================

  Move? _checkBlackLethal(Int8List p) {
    int kIdx = p.indexOf(2);
    if (kIdx == -1 || _isAtEdge(kIdx)) return null;
    int b = state.boardSize;
    int surrounded = 0; int? gap;
    for (int n in [kIdx-b, kIdx+b, kIdx-1, kIdx+1]) {
      BigInt bitN = BigInt.one << n;
      if ((bitN & (state.blackMask | state.effectiveHostileMask)) != BigInt.zero) surrounded++;
      else if ((bitN & state.unoccupiedMask) != BigInt.zero) gap = n;
    }
    if (surrounded == 3 && gap != null) {
      for (int i = 0; i < p.length; i++) {
        if (p[i] == -1 && rules.calculateValidMoves(i, p, state.size, b).contains(gap)) return Move(i, gap);
      }
    }
    return null;
  }

  Move? _interceptKingEscape(Int8List p) {
    int kIdx = p.indexOf(2);
    int b = state.boardSize;
    List<int> kMoves = rules.calculateValidMoves(kIdx, p, state.size, b);
    int? escapeTarget;
    for (int t in kMoves) {
      if (state.isSpecialCell[t] && t != state.centerIndex) { escapeTarget = t; break; }
    }

    if (escapeTarget != null) {
      List<Move> safeBlockers = [];
      List<Move> riskyBlockers = [];
      for (int i = 0; i < p.length; i++) {
        if (p[i] == -1) {
          List<int> moves = rules.calculateValidMoves(i, p, state.size, b);
          for (int m in moves) {
            if (_isStrictlyBetween(m, kIdx, escapeTarget, b)) {
              if (!_isCellInDanger(m, p, b)) safeBlockers.add(Move(i, m));
              else riskyBlockers.add(Move(i, m));
            }
          }
        }
      }
      if (safeBlockers.isNotEmpty) return _getBestMobilityLimiter(safeBlockers, p, kIdx, b);
      if (riskyBlockers.isNotEmpty) return _getBestMobilityLimiter(riskyBlockers, p, kIdx, b);
    }
    return null;
  }

  Move? _checkBlackCaptures(Int8List p) {
    int b = state.boardSize;
    int kIdx = p.indexOf(2);

    List<Move> safeMulti = [];
    List<Move> safeSingle = [];
    List<Move> riskyMulti = [];
    List<Move> riskySingle = [];

    for (int i = 0; i < p.length; i++) {
      if (p[i] == -1) {
        List<int> moves = rules.calculateValidMoves(i, p, state.size, b);
        for (int m in moves) {
          List<int> targets = rules.capture(m, p, state.size, b, state.isPlayer1Turn);
          if (targets.isEmpty) continue;

          // VETO GEOMETRICO: Se la mossa libera il Re aumentando la mobilità
          if (_willIncreaseKingMobility(i, m, targets, kIdx, p, b)) continue;

          // VETO FUGA: Controlliamo se libera una casella speciale per il Re
          int oldFrom = p[i]; int oldTo = p[m];
          p[m] = oldFrom; p[i] = 0;
          bool freesEscape = rules.calculateValidMoves(kIdx, p, state.size, b)
              .any((kt) => state.isSpecialCell[kt] && kt != state.centerIndex);
          p[i] = oldFrom; p[m] = oldTo;

          if (!freesEscape) {
            bool inDanger = _isCellInDanger(m, p, b, ignoreIndices: targets);
            if (!inDanger) {
              if (targets.length >= 2) safeMulti.add(Move(i, m));
              else safeSingle.add(Move(i, m));
            } else {
              if (targets.length >= 2) riskyMulti.add(Move(i, m));
              else riskySingle.add(Move(i, m));
            }
          }
        }
      }
    }

    // Priorità del Nero: le catture "Safe" hanno la precedenza
    if (safeMulti.isNotEmpty) return safeMulti[0];
    if (safeSingle.isNotEmpty) return safeSingle[0];
    if (riskyMulti.isNotEmpty) return riskyMulti[0];
    if (riskySingle.isNotEmpty) return riskySingle[0];
    return null;
  }

  // ===========================================================================
  // HELPERS
  // ===========================================================================

  bool _willIncreaseKingMobility(int from, int to, List<int> targets, int kIdx, Int8List p, int b) {
    int kRow = kIdx ~/ b;
    int kCol = kIdx % b;

    // Verifichiamo se il pezzo che si muove o quelli catturati toccano la croce del Re
    bool fromOnLine = (from ~/ b == kRow || from % b == kCol);
    bool anyTargetOnLine = targets.any((t) => (t ~/ b == kRow || t % b == kCol));

    if (!fromOnLine && !anyTargetOnLine) return false;

    // Se la cella di arrivo 'to' finisce sulla linea del Re,
    // allora NON stiamo aumentando la mobilità (stiamo anzi creando un nuovo blocco).
    bool toOnSameLineAsRe = (to ~/ b == kRow || to % b == kCol);
    if (toOnSameLineAsRe) return false;

    // Se ci spostiamo FUORI dalla traiettoria o catturiamo lateralmente:
    // Controlliamo se 'from' o 'targets' erano gli ostacoli più vicini (tappi).
    if (fromOnLine && _isImmediateObstacle(kIdx, from, p, b)) return true;
    for (int t in targets) {
      if ((t ~/ b == kRow || t % b == kCol) && _isImmediateObstacle(kIdx, t, p, b)) return true;
    }

    return false;
  }

  bool _isImmediateObstacle(int kIdx, int objIdx, Int8List p, int b) {
    if (kIdx ~/ b == objIdx ~/ b) { // Riga
      int start = min(kIdx, objIdx) + 1;
      int end = max(kIdx, objIdx);
      for (int j = start; j < end; j++) if (p[j] != 0) return false;
      return true;
    }
    if (kIdx % b == objIdx % b) { // Colonna
      int start = min(kIdx, objIdx) + b;
      int end = max(kIdx, objIdx);
      for (int j = start; j < end; j += b) if (p[j] != 0) return false;
      return true;
    }
    return false;
  }

  bool _isCellInDanger(int idx, Int8List p, int b, {List<int>? ignoreIndices}) {
    int myColor = (p[idx] > 0) ? 1 : -1;
    for (int n in [idx - b, idx + b, idx - 1, idx + 1]) {
      if (n < 0 || n >= state.size) continue;
      if (ignoreIndices != null && ignoreIndices.contains(n)) continue;

      if (p[n] != 0 && (p[n] > 0) != (myColor > 0)) {
        int opp = idx + (idx - n);
        if (opp >= 0 && opp < state.size) {
          bool isOppHostile = (p[opp] != 0 && (p[opp] > 0) != (myColor > 0)) || state.isSpecialCell[opp];
          if (isOppHostile) return true;
        }
      }
    }
    return false;
  }

  Move? _getBestEscapeMove(int kIdx, Int8List p, int b) {
    List<int> kMoves = rules.calculateValidMoves(kIdx, p, state.size, b);
    int maxMob = -1; int? best;
    for (int km in kMoves) {
      int mob = _getMobilityAt(km, p, b);
      if (mob > maxMob) { maxMob = mob; best = km; }
    }
    return best != null ? Move(kIdx, best) : null;
  }

  bool _isAtEdge(int idx) {
    int b = state.boardSize;
    return idx < b || idx >= state.size - b || idx % b == 0 || idx % b == b - 1;
  }

  bool _isStrictlyBetween(int target, int start, int end, int b) {
    if (start ~/ b == end ~/ b && target ~/ b == start ~/ b) {
      return target > min(start, end) && target < max(start, end);
    }
    if (start % b == end % b && target % b == start % b) {
      return target > min(start, end) && target < max(start, end);
    }
    return false;
  }

  Move? _getBestMobilityLimiter(List<Move> candidates, Int8List p, int kIdx, int b) {
    Move? best; int minMob = 999;
    for (var m in candidates) {
      int mob = _getKingMobilityAfterMove(m, p, kIdx, b);
      if (mob < minMob) { minMob = mob; best = m; }
    }
    return best;
  }

  int _getMobilityAt(int idx, Int8List p, int b) {
    int count = 0;
    for (int n in [idx-b, idx+b, idx-1, idx+1]) {
      if (n >= 0 && n < state.size && p[n] == 0) count++;
    }
    return count;
  }

  int _getKingMobilityAfterMove(Move m, Int8List p, int kIdx, int b) {
    int oldTo = p[m.toIndex]; p[m.toIndex] = p[m.fromIndex]; p[m.fromIndex] = 0;
    int mob = rules.calculateValidMoves(kIdx, p, state.size, b).length;
    p[m.fromIndex] = p[m.toIndex]; p[m.toIndex] = oldTo;
    return mob;
  }
}

 */

import 'dart:typed_data';
import 'dart:math';
import '../model/state.dart';
import '../model/rules.dart';
import '../model/CPU_engine.dart';

class ReactiveEngine {
  final GameState state;
  final Rules rules;

  ReactiveEngine({required this.state, required this.rules});

  Move? analyze() {
    return state.isPlayer1Turn ? _whiteStrategy() : _blackStrategy();
  }

  // --- ORCHESTRATORE BIANCO ---
  Move? _whiteStrategy() {
    Int8List p = state.pieces;
    Move? move = _checkWhiteVictory(p);
    if (move != null) return move;

    move = _checkKingInDanger(p);
    if (move != null) return move;

    move = _checkWhiteCaptures(p);
    if (move != null) return move;

    return null;
  }

  // --- ORCHESTRATORE NERO ---
  Move? _blackStrategy() {
    Int8List p = state.pieces;
    Move? move = _checkBlackLethal(p);
    if (move != null) return move;

    move = _interceptKingEscape(p);
    if (move != null) return move;

    // NUOVO: Prevenzione forchette e piazzamenti vincenti del Re
    move = _interceptKingFork(p);
    if (move != null) return move;

    move = _checkBlackCaptures(p);
    if (move != null) return move;

    return null;
  }

  // ===========================================================================
  // LOGICA BIANCO
  // ===========================================================================

  Move? _checkWhiteVictory(Int8List p) {
    int kingIdx = p.indexOf(2);
    if (kingIdx == -1) return null;
    List<int> moves = rules.calculateValidMoves(kingIdx, p, state.size, state.boardSize);
    for (int t in moves) {
      if (state.isSpecialCell[t] && t != state.centerIndex) return Move(kingIdx, t);
    }
    return null;
  }

  Move? _checkKingInDanger(Int8List p) {
    int kIdx = p.indexOf(2);
    int b = state.boardSize;
    List<int> adjBlacks = [];
    int freeSpot = -1;
    final neighbors = [kIdx - b, kIdx + b, kIdx - 1, kIdx + 1];

    for (int n in neighbors) {
      if (n < 0 || n >= state.size) continue;
      if (p[n] == -1) adjBlacks.add(n);
      else if (p[n] == 0) freeSpot = n;
    }

    if (adjBlacks.length >= 3 && freeSpot != -1) {
      for (int blackIdx in adjBlacks) {
        for (int i = 0; i < p.length; i++) {
          if (p[i] == 1) {
            List<int> wMoves = rules.calculateValidMoves(i, p, state.size, b);
            for (int tm in wMoves) {
              int oldVal = p[tm]; p[tm] = 1; p[i] = 0;
              var caps = rules.capture(tm, p, state.size, b, state.isPlayer1Turn);
              p[i] = 1; p[tm] = oldVal;
              if (caps.contains(blackIdx)) return Move(i, tm);
            }
          }
        }
      }
      return _getBestEscapeMove(kIdx, p, b);
    }
    return null;
  }

  Move? _checkWhiteCaptures(Int8List p) {
    int b = state.boardSize;
    int kIdx = p.indexOf(2);
    List<Move> intralcioSafe = [];
    List<Move> otherSafe = [];
    List<Move> sacrificeMultikill = [];

    for (int i = 0; i < p.length; i++) {
      if (p[i] == 1) {
        List<int> moves = rules.calculateValidMoves(i, p, state.size, b);
        for (int m in moves) {
          List<int> targets = rules.capture(m, p, state.size, b, state.isPlayer1Turn);
          if (targets.isEmpty) continue;

          bool inDanger = _isCellInDanger(m, p, b, ignoreIndices: targets);

          if (!inDanger) {
            bool intralcia = targets.any((t) => (t ~/ b == kIdx ~/ b || t % b == kIdx % b));
            if (intralcia) intralcioSafe.add(Move(i, m));
            else otherSafe.add(Move(i, m));
          } else if (targets.length >= 2) {
            sacrificeMultikill.add(Move(i, m));
          }
        }
      }
    }
    if (intralcioSafe.isNotEmpty) return intralcioSafe[0];
    if (otherSafe.isNotEmpty) return otherSafe[0];
    if (sacrificeMultikill.isNotEmpty) return sacrificeMultikill[0];
    return null;
  }

  // ===========================================================================
  // LOGICA NERO
  // ===========================================================================

  Move? _checkBlackLethal(Int8List p) {
    int kIdx = p.indexOf(2);
    if (kIdx == -1 || _isAtEdge(kIdx)) return null;
    int b = state.boardSize;
    int surrounded = 0; int? gap;
    for (int n in [kIdx-b, kIdx+b, kIdx-1, kIdx+1]) {
      BigInt bitN = BigInt.one << n;
      if ((bitN & (state.blackMask | state.effectiveHostileMask)) != BigInt.zero) surrounded++;
      else if ((bitN & state.unoccupiedMask) != BigInt.zero) gap = n;
    }
    if (surrounded == 3 && gap != null) {
      for (int i = 0; i < p.length; i++) {
        if (p[i] == -1 && rules.calculateValidMoves(i, p, state.size, b).contains(gap)) return Move(i, gap);
      }
    }
    return null;
  }

  Move? _interceptKingEscape(Int8List p) {
    int kIdx = p.indexOf(2);
    int b = state.boardSize;
    List<int> kMoves = rules.calculateValidMoves(kIdx, p, state.size, b);
    int? escapeTarget;
    for (int t in kMoves) {
      if (state.isSpecialCell[t] && t != state.centerIndex) { escapeTarget = t; break; }
    }

    if (escapeTarget != null) {
      List<Move> safeBlockers = [];
      List<Move> riskyBlockers = [];
      for (int i = 0; i < p.length; i++) {
        if (p[i] == -1) {
          List<int> moves = rules.calculateValidMoves(i, p, state.size, b);
          for (int m in moves) {
            if (_isStrictlyBetween(m, kIdx, escapeTarget, b)) {
              if (!_isCellInDanger(m, p, b)) safeBlockers.add(Move(i, m));
              else riskyBlockers.add(Move(i, m));
            }
          }
        }
      }
      if (safeBlockers.isNotEmpty) return _getBestMobilityLimiter(safeBlockers, p, kIdx, b);
      if (riskyBlockers.isNotEmpty) return _getBestMobilityLimiter(riskyBlockers, p, kIdx, b);
    }
    return null;
  }

  // --- NUOVO: _interceptKingFork ---
  /// Cerca se il Re ha mosse che preparano una vittoria imparabile (Forchette o adiacenze alle fughe).
  /// Se sì, tenta di bloccare quel percorso.
  Move? _interceptKingFork(Int8List p) {
    int kIdx = p.indexOf(2);
    if (kIdx == -1) return null;
    int b = state.boardSize;

    List<int> escapes = [];
    Set<int> escapeAdjacents = {};

    // 1. Mappiamo le celle di fuga e le loro adiacenze dirette
    for (int i = 0; i < b * b; i++) {
      if (state.isSpecialCell[i] == true && i != state.centerIndex) {
        escapes.add(i);
        int r = i ~/ b;
        int c = i % b;
        if (r > 0) escapeAdjacents.add(i - b);
        if (r < b - 1) escapeAdjacents.add(i + b);
        if (c > 0) escapeAdjacents.add(i - 1);
        if (c < b - 1) escapeAdjacents.add(i + 1);
      }
    }

    List<int> kMoves = rules.calculateValidMoves(kIdx, p, state.size, b);
    int? dangerTarget;

    // 2. Analizziamo ogni potenziale mossa del Re
    for (int km in kMoves) {

      // Proprietà 1: Se la mossa atterra in un'adiacenza di fuga, è mortale
      if (escapeAdjacents.contains(km)) {
        dangerTarget = km;
        break;
      }

      // Prepariamo la simulazione per le proprietà 2 e 3
      Int8List simP = Int8List.fromList(p);
      simP[km] = simP[kIdx];
      simP[kIdx] = 0;
      List<int> nextKingMoves = rules.calculateValidMoves(km, simP, state.size, b);

      int visibleEscapes = 0;
      int visibleAdjacents = 0;

      for (int esc in escapes) {
        if (nextKingMoves.contains(esc)) visibleEscapes++;
      }
      for (int adj in escapeAdjacents) {
        if (nextKingMoves.contains(adj)) visibleAdjacents++;
      }

      // Proprietà 2 e 3: Se ha almeno 2 raggi verso fughe o adiacenze, è una forchetta mortale
      if (visibleEscapes >= 2 || visibleAdjacents >= 2) {
        dangerTarget = km;
        break;
      }
    }

    // 3. Se abbiamo individuato la cella "tattica" del Re, dobbiamo tagliargli la strada
    if (dangerTarget != null) {
      List<Move> safeBlockers = [];
      List<Move> riskyBlockers = [];

      for (int i = 0; i < p.length; i++) {
        if (p[i] == -1) { // Pezzo nero
          List<int> moves = rules.calculateValidMoves(i, p, state.size, b);
          for (int m in moves) {
            // Sfruttiamo l'helper per vedere se la pedina può mettersi tra il Re e la casella bersaglio
            if (_isStrictlyBetween(m, kIdx, dangerTarget, b)) {
              if (!_isCellInDanger(m, p, b)) {
                safeBlockers.add(Move(i, m));
              } else {
                riskyBlockers.add(Move(i, m));
              }
            }
          }
        }
      }

      // Priorità ai blocchi sicuri. In caso di disperazione, accettiamo i blocchi suicidi.
      if (safeBlockers.isNotEmpty) return _getBestMobilityLimiter(safeBlockers, p, kIdx, b);
      if (riskyBlockers.isNotEmpty) return _getBestMobilityLimiter(riskyBlockers, p, kIdx, b);
    }

    return null;
  }

  Move? _checkBlackCaptures(Int8List p) {
    int b = state.boardSize;
    int kIdx = p.indexOf(2);

    List<Move> safeMulti = [];
    List<Move> safeSingle = [];
    List<Move> riskyMulti = [];
    List<Move> riskySingle = [];

    for (int i = 0; i < p.length; i++) {
      if (p[i] == -1) {
        List<int> moves = rules.calculateValidMoves(i, p, state.size, b);
        for (int m in moves) {
          List<int> targets = rules.capture(m, p, state.size, b, state.isPlayer1Turn);
          if (targets.isEmpty) continue;

          // VETO GEOMETRICO: Se la mossa libera il Re aumentando la mobilità
          if (_willIncreaseKingMobility(i, m, targets, kIdx, p, b)) continue;

          // VETO FUGA: Controlliamo se libera una casella speciale per il Re
          int oldFrom = p[i]; int oldTo = p[m];
          p[m] = oldFrom; p[i] = 0;
          bool freesEscape = rules.calculateValidMoves(kIdx, p, state.size, b)
              .any((kt) => state.isSpecialCell[kt] && kt != state.centerIndex);
          p[i] = oldFrom; p[m] = oldTo;

          if (!freesEscape) {
            bool inDanger = _isCellInDanger(m, p, b, ignoreIndices: targets);
            if (!inDanger) {
              if (targets.length >= 2) safeMulti.add(Move(i, m));
              else safeSingle.add(Move(i, m));
            } else {
              if (targets.length >= 2) riskyMulti.add(Move(i, m));
              else riskySingle.add(Move(i, m));
            }
          }
        }
      }
    }

    // Priorità del Nero: le catture "Safe" hanno la precedenza
    if (safeMulti.isNotEmpty) return safeMulti[0];
    if (safeSingle.isNotEmpty) return safeSingle[0];
    if (riskyMulti.isNotEmpty) return riskyMulti[0];
    if (riskySingle.isNotEmpty) return riskySingle[0];
    return null;
  }

  // ===========================================================================
  // HELPERS
  // ===========================================================================

  bool _willIncreaseKingMobility(int from, int to, List<int> targets, int kIdx, Int8List p, int b) {
    int kRow = kIdx ~/ b;
    int kCol = kIdx % b;

    // Verifichiamo se il pezzo che si muove o quelli catturati toccano la croce del Re
    bool fromOnLine = (from ~/ b == kRow || from % b == kCol);
    bool anyTargetOnLine = targets.any((t) => (t ~/ b == kRow || t % b == kCol));

    if (!fromOnLine && !anyTargetOnLine) return false;

    // Se la cella di arrivo 'to' finisce sulla linea del Re,
    // allora NON stiamo aumentando la mobilità (stiamo anzi creando un nuovo blocco).
    bool toOnSameLineAsRe = (to ~/ b == kRow || to % b == kCol);
    if (toOnSameLineAsRe) return false;

    // Se ci spostiamo FUORI dalla traiettoria o catturiamo lateralmente:
    // Controlliamo se 'from' o 'targets' erano gli ostacoli più vicini (tappi).
    if (fromOnLine && _isImmediateObstacle(kIdx, from, p, b)) return true;
    for (int t in targets) {
      if ((t ~/ b == kRow || t % b == kCol) && _isImmediateObstacle(kIdx, t, p, b)) return true;
    }

    return false;
  }

  bool _isImmediateObstacle(int kIdx, int objIdx, Int8List p, int b) {
    if (kIdx ~/ b == objIdx ~/ b) { // Riga
      int start = min(kIdx, objIdx) + 1;
      int end = max(kIdx, objIdx);
      for (int j = start; j < end; j++) if (p[j] != 0) return false;
      return true;
    }
    if (kIdx % b == objIdx % b) { // Colonna
      int start = min(kIdx, objIdx) + b;
      int end = max(kIdx, objIdx);
      for (int j = start; j < end; j += b) if (p[j] != 0) return false;
      return true;
    }
    return false;
  }

  bool _isCellInDanger(int idx, Int8List p, int b, {List<int>? ignoreIndices}) {
    int myColor = (p[idx] > 0) ? 1 : -1;
    for (int n in [idx - b, idx + b, idx - 1, idx + 1]) {
      if (n < 0 || n >= state.size) continue;
      if (ignoreIndices != null && ignoreIndices.contains(n)) continue;

      if (p[n] != 0 && (p[n] > 0) != (myColor > 0)) {
        int opp = idx + (idx - n);
        if (opp >= 0 && opp < state.size) {
          bool isOppHostile = (p[opp] != 0 && (p[opp] > 0) != (myColor > 0)) || state.isSpecialCell[opp];
          if (isOppHostile) return true;
        }
      }
    }
    return false;
  }

  Move? _getBestEscapeMove(int kIdx, Int8List p, int b) {
    List<int> kMoves = rules.calculateValidMoves(kIdx, p, state.size, b);
    int maxMob = -1; int? best;
    for (int km in kMoves) {
      int mob = _getMobilityAt(km, p, b);
      if (mob > maxMob) { maxMob = mob; best = km; }
    }
    return best != null ? Move(kIdx, best) : null;
  }

  bool _isAtEdge(int idx) {
    int b = state.boardSize;
    return idx < b || idx >= state.size - b || idx % b == 0 || idx % b == b - 1;
  }

  bool _isStrictlyBetween(int target, int start, int end, int b) {
    if (start ~/ b == end ~/ b && target ~/ b == start ~/ b) {
      return target > min(start, end) && target < max(start, end);
    }
    if (start % b == end % b && target % b == start % b) {
      return target > min(start, end) && target < max(start, end);
    }
    return false;
  }

  Move? _getBestMobilityLimiter(List<Move> candidates, Int8List p, int kIdx, int b) {
    Move? best; int minMob = 999;
    for (var m in candidates) {
      int mob = _getKingMobilityAfterMove(m, p, kIdx, b);
      if (mob < minMob) { minMob = mob; best = m; }
    }
    return best;
  }

  int _getMobilityAt(int idx, Int8List p, int b) {
    int count = 0;
    for (int n in [idx-b, idx+b, idx-1, idx+1]) {
      if (n >= 0 && n < state.size && p[n] == 0) count++;
    }
    return count;
  }

  int _getKingMobilityAfterMove(Move m, Int8List p, int kIdx, int b) {
    int oldTo = p[m.toIndex]; p[m.toIndex] = p[m.fromIndex]; p[m.fromIndex] = 0;
    int mob = rules.calculateValidMoves(kIdx, p, state.size, b).length;
    p[m.fromIndex] = p[m.toIndex]; p[m.toIndex] = oldTo;
    return mob;
  }
}