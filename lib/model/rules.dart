
import 'dart:typed_data';
import '../model/state.dart';

class Rules {
  final GameState state;
  Rules(this.state);

  // --- 1. CALCOLO MOSSE
  List<int> calculateValidMoves(int index, Int8List p, int size, int boardSize) {
    final List<int> moves = [];
    final bool isKing = (p[index] == 2);

    // Otteniamo i raggi precalcolati per questa posizione (Nord, Sud, Ovest, Est)
    final List<List<int>> rays = state.precomputedRays[index];

    for (final List<int> ray in rays) {
      for (final int target in ray) {
        // 1. Se incontriamo un pezzo (qualsiasi colore), il raggio si interrompe
        if (p[target] != 0) break;

        // 2. Controllo casella speciale tramite la mappa booleana precalcolata
        // Se è il Re, può fermarsi ovunque (incluse caselle speciali).
        // Se è una pedina, può fermarsi solo se la casella NON è speciale.
        if (isKing || !state.isSpecialCell[target]) {
          moves.add(target);
        }

        // Nota: se la casella è speciale e il pezzo è una pedina,
        // la mossa non viene aggiunta, ma il ciclo continua
        // permettendo di "scavalcare" il trono o gli angoli.
      }
    }

    return moves;
  }
  // --- 2. CATTURE E SHIELD WALL ---
  // p non fa nulla.
  List<int> capture(int index, Int8List p, int size, int boardSize, bool turn) {
    List<int> captures = [];
    BigInt friends = turn ? state.whiteMask : state.blackMask;
    BigInt enemies = turn ? state.blackMask : (state.whiteMask & ~state.kingMask);
    BigInt attackers = friends | state.effectiveHostileMask;

    final shifts = [-boardSize, boardSize, -1, 1];
    final edges = [state.northEdge, state.southEdge, state.westEdge, state.eastEdge];

    for (int i = 0; i < 4; i++) {
      int s = shifts[i];
      BigInt e = edges[i];
      BigInt source = BigInt.one << index;

      if ((source & e) != BigInt.zero) continue;
      BigInt neighborBit = (s > 0) ? source << s : source >> s.abs();
      if (neighborBit == BigInt.zero) continue;

      if ((neighborBit & (enemies | state.kingMask)) != BigInt.zero) {
        if ((neighborBit & e) != BigInt.zero) continue;
        BigInt farBit = (s > 0) ? neighborBit << s : neighborBit >> s.abs();

        if (farBit != BigInt.zero) {
          if ((neighborBit & state.kingMask) != BigInt.zero) {
            if (captureKingBitwise(neighborBit.bitLength - 1, boardSize)) {
              captures.add(neighborBit.bitLength - 1);
              state.checkmate = true;
            }
          } else if ((farBit & attackers) != BigInt.zero) {
            captures.add(neighborBit.bitLength - 1);
          }
        }
      }
    }
    if (!state.playVsCPU) captures.addAll(shieldWallBitwise(boardSize, turn));
    return captures;
  }

  List<int> shieldWallBitwise(int boardSize, bool turn) {
    List<int> toRemove = [];
    BigInt victims = turn ? state.blackMask : (state.whiteMask | state.kingMask);
    BigInt attackers = (turn ? state.whiteMask : state.blackMask) | state.effectiveHostileMask;
    List<BigInt> edges = [state.northEdge, state.southEdge, state.westEdge, state.eastEdge];

    for (BigInt edge in edges) {
      BigInt victimsOnEdge = victims & edge;
      while (victimsOnEdge != BigInt.zero) {
        BigInt firstPiece = victimsOnEdge & -victimsOnEdge;
        BigInt group = _findContiguousGroup(firstPiece, victimsOnEdge, boardSize, edge);
        victimsOnEdge &= ~group;

        BigInt cage = _getShieldWallCage(group, boardSize);
        if (cage != BigInt.zero && (cage & attackers) == cage) {
          for (int i = 0; i < state.size; i++) {
            if (((group & (BigInt.one << i)) != BigInt.zero) &&
                ((group & (BigInt.one << i) & state.kingMask) == BigInt.zero)) toRemove.add(i);
          }
        }
      }
    }
    return toRemove;
  }

  BigInt _findContiguousGroup(BigInt source, BigInt mask, int boardSize, BigInt edge) {
    BigInt group = source;
    bool horizontal = (edge == state.northEdge || edge == state.southEdge);

    // Espansione lineare per trovare i pezzi contigui (senza buchi)
    if (horizontal) {
      BigInt pE = source;
      while ((pE & ~state.eastEdge) != BigInt.zero) {
        pE = pE << 1;
        if ((pE & mask) == BigInt.zero) break;
        group |= pE;
      }
      BigInt pW = source;
      while ((pW & ~state.westEdge) != BigInt.zero) {
        pW = pW >> 1;
        if ((pW & mask) == BigInt.zero) break;
        group |= pW;
      }
    } else {
      BigInt pS = source;
      while ((pS & ~state.southEdge) != BigInt.zero) {
        pS = pS << boardSize;
        if ((pS & mask) == BigInt.zero) break;
        group |= pS;
      }
      BigInt pN = source;
      while ((pN & ~state.northEdge) != BigInt.zero) {
        pN = pN >> boardSize;
        if ((pN & mask) == BigInt.zero) break;
        group |= pN;
      }
    }
    return group;
  }

  BigInt _getShieldWallCage(BigInt group, int boardSize) {
    BigInt north = (group & ~state.northEdge) >> boardSize;
    BigInt south = (group & ~state.southEdge) << boardSize;
    BigInt east = (group & ~state.eastEdge) << 1;
    BigInt west = (group & ~state.westEdge) >> 1;
    return (north | south | east | west) & ~group;
  }

  // --- 3. REGOLE RE, VITTORIA E STALLO ---
  bool captureKingBitwise(int kingPos, int boardSize) {
    BigInt kingBit = BigInt.one << kingPos;
    int arms = 0;

    // 1. Generazione bracci con maschere anti-wrapping
    BigInt n = (kingBit & ~state.northEdge) >> boardSize;
    BigInt s = (kingBit & ~state.southEdge) << boardSize;
    BigInt w = (kingBit & ~state.westEdge) >> 1;
    BigInt e = (kingBit & ~state.eastEdge) << 1;

    // 2. Incremento del contatore per ogni braccio valido sulla scacchiera
    if (n != BigInt.zero) arms++;
    if (s != BigInt.zero) arms++;
    if (w != BigInt.zero) arms++;
    if (e != BigInt.zero) arms++;

    // 3. Early Exit: Se non ci sono 4 bracci, il Re è su un bordo/angolo e non può morire
    if (arms < 4) return false;

    // 4. Definizione ostili (Solo Nero + Caselle Speciali)
    BigInt hostiles = state.blackMask | state.effectiveHostileMask;

    // 5. Verifica: tutti i vicini devono far parte della maschera ostile
    BigInt neighbors = n | s | w | e;
    return (neighbors & hostiles) == neighbors;
  }

  bool stalemate(int boardSize) {
    BigInt staled = state.isPlayer1Turn ? (state.whiteMask & ~state.kingMask) : state.blackMask;
    BigInt staledKing = state.kingMask;

    BigInt n = ((staled & ~state.northEdge) >> boardSize);
    BigInt s = ((staled & ~state.southEdge) << boardSize);
    BigInt e = ((staled & ~state.eastEdge) << 1);
    BigInt w = ((staled & ~state.westEdge) >> 1);

    BigInt staleCloud = n | s | e | w;
    BigInt freeMoves = staleCloud & (state.unoccupiedMask & ~state.baseHostileMask);

    if (state.isPlayer1Turn) {
      BigInt nk = ((staledKing & ~state.northEdge) >> boardSize);
      BigInt sk = ((staledKing & ~state.southEdge) << boardSize);
      BigInt ek = ((staledKing & ~state.eastEdge) << 1);
      BigInt wk = ((staledKing & ~state.westEdge) >> 1);
      BigInt freeKingMoves = (nk | sk | ek | wk) & state.unoccupiedMask;
      freeMoves |= freeKingMoves;
    }

    return freeMoves == BigInt.zero;
  }

  bool surround(Int8List p, int size, int boardSize) {
    BigInt whites = state.whiteMask;
    if (whites == BigInt.zero) return false;
    BigInt filled = state.allEdges;
    BigInt flowable = state.unoccupiedMask | whites;
    BigInt last;
    do {
      last = filled;
      BigInt n = (filled & ~state.northEdge) >> boardSize;
      BigInt s = (filled & ~state.southEdge) << boardSize;
      BigInt e = (filled & ~state.eastEdge) << 1;
      BigInt w = (filled & ~state.westEdge) >> 1;
      filled = (filled | ((n | s | e | w) & flowable)) | state.allEdges;
    } while (filled != last);
    return (filled & whites) == BigInt.zero;
  }

  // --- 4. FORTEZZA E UTILITY ---
  bool fortress(Int8List p, int size, int boardSize) {
    for (int i = 0; i < p.length; i++) if (p[i] == 2) return checkFort(i, p, size, boardSize);
    return false;
  }

  bool checkFort(int index, Int8List p, int size, int boardSize) {
    if ((state.kingMask & state.allEdges) == BigInt.zero) return false;
    if (calculateValidMoves(index, p, size, boardSize)/*.isEmpty*/ == BigInt.zero) return false;
    List<int> queue = [index]; Set<int> visited = {index}; int head = 0;
    while (head < queue.length) {
      int pos = queue[head++];
      final neighbors = [pos - boardSize, pos + boardSize, pos - 1, pos + 1];
      for (int n in neighbors) {
        if (n >= 0 && n < p.length && !visited.contains(n)) {
          if (p[n] == 0) { visited.add(n); queue.add(n); }
          else if (p[n] == -1) return false;
          else if (p[n] == 1 && capturable(n, pos, p, size, boardSize)) return false;
        }
      }
    }
    return true;
  }

  bool capturable(int index, int orthogonal, Int8List p, int size, int boardSize) {
    if ((orthogonal == index - 1) || (orthogonal == index + 1)) {
      if (index ~/ boardSize == 0 || index ~/ boardSize == boardSize - 1) return false;
      return !(p[index + boardSize] == 1 || p[index - boardSize] == 1);
    } else {
      if (index % boardSize == 0 || index % boardSize == boardSize - 1) return false;
      return !(p[index + 1] == 1 || p[index - 1] == 1);
    }
  }

  bool? pieceColor(int index, Int8List p) {
    if (p[index] > 0) return true;
    if (p[index] < 0) return false;
    return null;
  }
}


/*
import 'dart:typed_data';
import '../model/state.dart';

class Rules {
  final GameState state;
  Rules(this.state);

  // --- 1. CALCOLO MOSSE (Restituisce Maschera Bitwise) ---
  BigInt calculateValidMoves(int index, Int8List p, int size, int boardSize) {
    BigInt sourceBit = BigInt.one << index;
    bool isKing = (p[index] == 2);
    BigInt emptySpaces = state.unoccupiedMask;
    BigInt movesMask = BigInt.zero;

    int row = index ~/ boardSize;
    int col = index % boardSize;

    final shifts = [1, -1, boardSize, -boardSize];
    final distances = [
      (boardSize - 1) - col, // Est
      col,                   // Ovest
      (boardSize - 1) - row, // Sud
      row                    // Nord
    ];

    for (int i = 0; i < 4; i++) {
      int d = distances[i];
      if (d <= 0) continue;

      int s = shifts[i];
      BigInt propagator = sourceBit;

      for (int step = 0; step < d; step++) {
        BigInt nextStep = (s > 0) ? propagator << s : propagator >> s.abs();

        if ((nextStep & emptySpaces) == BigInt.zero) break;

        movesMask |= nextStep;
        propagator = nextStep;
      }
    }

    if (!isKing) movesMask &= ~state.baseHostileMask;

    return movesMask;
  }

  // --- 2. CATTURE E SHIELD WALL ---
  List<int> capture(int index, Int8List p, int size, int boardSize) {
    List<int> captures = [];
    BigInt friends = state.isPlayer1Turn ? state.whiteMask : state.blackMask;
    BigInt enemies = state.isPlayer1Turn ? state.blackMask : (state.whiteMask & ~state.kingMask);
    BigInt attackers = friends | state.effectiveHostileMask;

    final shifts = [-boardSize, boardSize, -1, 1];
    final edges = [state.northEdge, state.southEdge, state.westEdge, state.eastEdge];

    for (int i = 0; i < 4; i++) {
      int s = shifts[i];
      BigInt e = edges[i];
      BigInt source = BigInt.one << index;

      if ((source & e) != BigInt.zero) continue;
      BigInt neighborBit = (s > 0) ? source << s : source >> s.abs();
      if (neighborBit == BigInt.zero) continue;

      if ((neighborBit & (enemies | state.kingMask)) != BigInt.zero) {
        if ((neighborBit & e) != BigInt.zero) continue;
        BigInt farBit = (s > 0) ? neighborBit << s : neighborBit >> s.abs();

        if (farBit != BigInt.zero) {
          if ((neighborBit & state.kingMask) != BigInt.zero) {
            if (captureKingBitwise(neighborBit.bitLength - 1, boardSize)) {
              captures.add(neighborBit.bitLength - 1);
              state.checkmate = true;
            }
          } else if ((farBit & attackers) != BigInt.zero) {
            captures.add(neighborBit.bitLength - 1);
          }
        }
      }
    }
    if (!state.playVsCPU) captures.addAll(shieldWallBitwise(boardSize));
    return captures;
  }

  List<int> shieldWallBitwise(int boardSize) {
    List<int> toRemove = [];
    BigInt victims = state.isPlayer1Turn ? state.blackMask : (state.whiteMask & ~state.kingMask);
    BigInt attackers = (state.isPlayer1Turn ? state.whiteMask : state.blackMask) | state.effectiveHostileMask;
    List<BigInt> edges = [state.northEdge, state.southEdge, state.westEdge, state.eastEdge];

    for (BigInt edge in edges) {
      BigInt victimsOnEdge = victims & edge;
      while (victimsOnEdge != BigInt.zero) {
        BigInt firstPiece = victimsOnEdge & -victimsOnEdge;
        BigInt group = _findContiguousGroup(firstPiece, victimsOnEdge, boardSize, edge);
        victimsOnEdge &= ~group;

        BigInt cage = _getShieldWallCage(group, boardSize);
        if (cage != BigInt.zero && (cage & attackers) == cage) {
          for (int i = 0; i < state.size; i++) {
            if ((group & (BigInt.one << i)) != BigInt.zero) toRemove.add(i);
          }
        }
      }
    }
    return toRemove;
  }

  BigInt _findContiguousGroup(BigInt source, BigInt mask, int boardSize, BigInt edge) {
    BigInt group = source;
    bool horizontal = (edge == state.northEdge || edge == state.southEdge);

    if (horizontal) {
      BigInt pE = source;
      while ((pE & ~state.eastEdge) != BigInt.zero) {
        pE = pE << 1;
        if ((pE & mask) == BigInt.zero) break;
        group |= pE;
      }
      BigInt pW = source;
      while ((pW & ~state.westEdge) != BigInt.zero) {
        pW = pW >> 1;
        if ((pW & mask) == BigInt.zero) break;
        group |= pW;
      }
    } else {
      BigInt pS = source;
      while ((pS & ~state.southEdge) != BigInt.zero) {
        pS = pS << boardSize;
        if ((pS & mask) == BigInt.zero) break;
        group |= pS;
      }
      BigInt pN = source;
      while ((pN & ~state.northEdge) != BigInt.zero) {
        pN = pN >> boardSize;
        if ((pN & mask) == BigInt.zero) break;
        group |= pN;
      }
    }
    return group;
  }

  BigInt _getShieldWallCage(BigInt group, int boardSize) {
    BigInt north = (group & ~state.northEdge) >> boardSize;
    BigInt south = (group & ~state.southEdge) << boardSize;
    BigInt east = (group & ~state.eastEdge) << 1;
    BigInt west = (group & ~state.westEdge) >> 1;
    return (north | south | east | west) & ~group;
  }

  // --- 3. REGOLE RE, VITTORIA E STALLO ---
  bool captureKingBitwise(int kingPos, int boardSize) {
    BigInt kingBit = BigInt.one << kingPos;
    BigInt cross = BigInt.zero;
    if (kingPos >= boardSize) cross |= (kingBit >> boardSize);
    if (kingPos < state.size - boardSize) cross |= (kingBit << boardSize);
    if (kingPos % boardSize > 0) cross |= (kingBit >> 1);
    if (kingPos % boardSize < boardSize - 1) cross |= (kingBit << 1);
    return (cross & (state.blackMask | state.effectiveHostileMask)) == cross;
  }

  bool stalemate(int boardSize) {
    BigInt staled = state.isPlayer1Turn ? (state.whiteMask & ~state.kingMask) : state.blackMask;
    BigInt staledKing = state.kingMask;

    BigInt n = ((staled & ~state.northEdge) >> boardSize);
    BigInt s = ((staled & ~state.southEdge) << boardSize);
    BigInt e = ((staled & ~state.eastEdge) << 1);
    BigInt w = ((staled & ~state.westEdge) >> 1);

    BigInt staleCloud = n | s | e | w;
    BigInt freeMoves = staleCloud & (state.unoccupiedMask & ~state.baseHostileMask);

    if (state.isPlayer1Turn) {
      BigInt nk = ((staledKing & ~state.northEdge) >> boardSize);
      BigInt sk = ((staledKing & ~state.southEdge) << boardSize);
      BigInt ek = ((staledKing & ~state.eastEdge) << 1);
      BigInt wk = ((staledKing & ~state.westEdge) >> 1);
      BigInt freeKingMoves = (nk | sk | ek | wk) & state.unoccupiedMask;
      freeMoves |= freeKingMoves;
    }

    return freeMoves == BigInt.zero;
  }

  bool surround(Int8List p, int size, int boardSize) {
    BigInt whites = state.whiteMask;
    if (whites == BigInt.zero) return false;
    BigInt filled = state.allEdges;
    BigInt flowable = state.unoccupiedMask | whites;
    BigInt last;
    do {
      last = filled;
      BigInt n = (filled & ~state.northEdge) >> boardSize;
      BigInt s = (filled & ~state.southEdge) << boardSize;
      BigInt e = (filled & ~state.eastEdge) << 1;
      BigInt w = (filled & ~state.westEdge) >> 1;
      filled = (filled | ((n | s | e | w) & flowable)) | state.allEdges;
    } while (filled != last);
    return (filled & whites) == BigInt.zero;
  }

  // --- 4. FORTEZZA E UTILITY ---
  bool fortress(Int8List p, int size, int boardSize) {
    for (int i = 0; i < p.length; i++) if (p[i] == 2) return checkFort(i, p, size, boardSize);
    return false;
  }

  bool checkFort(int index, Int8List p, int size, int boardSize) {
    if ((state.kingMask & state.allEdges) == BigInt.zero) return false;
    if (calculateValidMoves(index, p, size, boardSize) == BigInt.zero) return false;
    List<int> queue = [index]; Set<int> visited = {index}; int head = 0;
    while (head < queue.length) {
      int pos = queue[head++];
      final neighbors = [pos - boardSize, pos + boardSize, pos - 1, pos + 1];
      for (int n in neighbors) {
        if (n >= 0 && n < p.length && !visited.contains(n)) {
          if (p[n] == 0) { visited.add(n); queue.add(n); }
          else if (p[n] == -1) return false;
          else if (p[n] == 1 && capturable(n, pos, p, size, boardSize)) return false;
        }
      }
    }
    return true;
  }

  bool capturable(int index, int orthogonal, Int8List p, int size, int boardSize) {
    if ((orthogonal == index - 1) || (orthogonal == index + 1)) {
      if (index ~/ boardSize == 0 || index ~/ boardSize == boardSize - 1) return false;
      return !(p[index + boardSize] == 1 || p[index - boardSize] == 1);
    } else {
      if (index % boardSize == 0 || index % boardSize == boardSize - 1) return false;
      return !(p[index + 1] == 1 || p[index - 1] == 1);
    }
  }

  bool? pieceColor(int index, Int8List p) {
    if (p[index] > 0) return true;
    if (p[index] < 0) return false;
    return null;
  }
}

 */