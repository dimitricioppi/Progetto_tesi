
import 'dart:typed_data';
import 'dart:collection';
import '../model/state.dart';
import '../model/rules.dart';
import '../model/CPU_engine.dart';

/// Motore Tattico: Decide la mossa migliore basandosi su euristiche e filtri sequenziali.
class TacticalEngine {

  final GameState state;
  final Rules rules;

  TacticalEngine({required this.state, required this.rules});

  Move? analyze() {
    return state.isPlayer1Turn ? _whiteStrategy() : _blackStrategy();
  }

  // ===========================================================================
  // ORCHESTRATORE BIANCO
  // ===========================================================================
  Move? _whiteStrategy() {
    Int8List p = Int8List.fromList(state.pieces);
    int bSize = state.boardSize;

    List<Move> safeMoves = _getSafeMoves(true);
    if (safeMoves.isEmpty) return null;

    int kIdx = p.indexOf(2);

    if (kIdx != -1) {
      List<(List<int>, int)> escapePaths = _escapeSearch(p, kIdx, 0);

      if (escapePaths.isNotEmpty) {
        List<Move> escapeFiltered = _handleWhiteEscape(safeMoves, p, kIdx, escapePaths, bSize);
        if (escapeFiltered.isNotEmpty) {
          safeMoves = escapeFiltered;
        }
      }
    }

    return _applyWhiteSieves(safeMoves, p, bSize);
  }

  // --- ESCAPE HANDLER BIANCO ---
  List<Move> _handleWhiteEscape(List<Move> safeMoves, Int8List p, int kIdx, List<(List<int>, int)> escapePaths, int bSize) {
    List<int> escapes = [];
    Set<int> escapeAdjacents = {};

    for (int i = 0; i < bSize * bSize; i++) {
      if (state.isSpecialCell[i] == true && i != state.centerIndex) {
        escapes.add(i);
        int r = i ~/ bSize;
        int c = i % bSize;
        if (r > 0) escapeAdjacents.add(i - bSize);
        if (r < bSize - 1) escapeAdjacents.add(i + bSize);
        if (c > 0) escapeAdjacents.add(i - 1);
        if (c < bSize - 1) escapeAdjacents.add(i + 1);
      }
    }

    for (Move m in safeMoves) {
      if (m.fromIndex == kIdx) {
        if (escapeAdjacents.contains(m.toIndex)) return [m];

        Int8List simP = Int8List.fromList(p);
        simP[m.toIndex] = simP[m.fromIndex];
        simP[m.fromIndex] = 0;

        List<int> nextKingMoves = rules.calculateValidMoves(m.toIndex, simP, state.size, bSize);
        int visibleEscapes = 0;
        int visibleAdjacents = 0;

        for (int esc in escapes) {
          if (nextKingMoves.contains(esc)) visibleEscapes++;
        }
        for (int adj in escapeAdjacents) {
          if (nextKingMoves.contains(adj)) visibleAdjacents++;
        }

        if (visibleEscapes >= 2 || visibleAdjacents >= 2) return [m];
      }
    }

    List<Move> blackSafe = _getSafeMoves(false);
    Move? blackBlock = _blockKingEscape(kIdx, escapePaths, blackSafe, bSize, p);

    if (blackBlock != null) {
      List<Move> counterBlocks = [];
      for (Move m in safeMoves) {
        if (_isStrictlyBetween(m.toIndex, blackBlock.fromIndex, blackBlock.toIndex, bSize)) {
          counterBlocks.add(m);
        }
      }
      return counterBlocks;
    } else {
      List<Move> kingRunMoves = [];
      int maxDist = -1;

      for (var path in escapePaths) {
        for (Move m in safeMoves) {
          if (m.fromIndex == kIdx && path.$1.contains(m.toIndex)) {
            int r1 = m.fromIndex ~/ bSize; int c1 = m.fromIndex % bSize;
            int r2 = m.toIndex ~/ bSize; int c2 = m.toIndex % bSize;
            int dist = (r1 - r2).abs() + (c1 - c2).abs();

            if (dist > maxDist) maxDist = dist;
            if (!kingRunMoves.contains(m)) kingRunMoves.add(m);
          }
        }
      }
      return kingRunMoves;
    }
  }

  // --- FILTRI PRIORITARI BIANCO ---
  Move _applyWhiteSieves(List<Move> moves, Int8List p, int bSize) {
    List<Move> currentList = List.from(moves);

    currentList = _sieveDefend(currentList, p, bSize, true);
    if (currentList.length == 1) return currentList.first;

    currentList = _sieveThreaten(currentList, p, bSize, true);
    if (currentList.length == 1) return currentList.first;

    currentList = _sieveWhiteKingMobility(currentList, p, bSize);
    if (currentList.length == 1) return currentList.first;

    currentList = _sieveWhitePawnMobility(currentList, p, bSize);
    if (currentList.length == 1) return currentList.first;

    currentList = _sieveStructure(currentList, p, bSize, true);
    return currentList.first;
  }

  // Filtro 3 (Bianco): Mobilità del Re
  List<Move> _sieveWhiteKingMobility(List<Move> inputMoves, Int8List p, int bSize) {
    List<Move> filtered = List.from(inputMoves);
    int maxMob = -1;
    Map<Move, int> mobilities = {};

    for (Move m in filtered) {
      Int8List simP = Int8List.fromList(p);
      simP[m.toIndex] = simP[m.fromIndex]; simP[m.fromIndex] = 0;

      int currentKIdx = simP.indexOf(2);
      if (currentKIdx != -1) {
        int mob = rules.calculateValidMoves(currentKIdx, simP, state.size, bSize).length;
        mobilities[m] = mob;
        if (mob > maxMob) maxMob = mob;
      }
    }

    filtered.removeWhere((m) => (mobilities[m] ?? -1) < maxMob);
    return filtered.isEmpty ? inputMoves : filtered;
  }

  // Filtro 4 (Bianco): Mobilità delle Pedine
  List<Move> _sieveWhitePawnMobility(List<Move> inputMoves, Int8List p, int bSize) {
    List<Move> filtered = List.from(inputMoves);
    int maxMob = -1;
    Map<Move, int> mobilities = {};

    for (Move m in filtered) {
      Int8List simP = Int8List.fromList(p);
      simP[m.toIndex] = simP[m.fromIndex]; simP[m.fromIndex] = 0;

      int mob = 0;
      for (int i = 0; i < simP.length; i++) {
        if (simP[i] == 1) {
          mob += rules.calculateValidMoves(i, simP, state.size, bSize).length;
        }
      }
      mobilities[m] = mob;
      if (mob > maxMob) maxMob = mob;
    }

    filtered.removeWhere((m) => mobilities[m]! < maxMob);
    return filtered.isEmpty ? inputMoves : filtered;
  }

  // ===========================================================================
  // ORCHESTRATORE NERO
  // ===========================================================================
  Move? _blackStrategy() {
    Int8List p = Int8List.fromList(state.pieces);
    int bSize = state.boardSize;
    Move? move;

    List<Move> safeMoves = _getSafeMoves(state.isPlayer1Turn);
    if (safeMoves.isEmpty) return null;

    int kIdx = p.indexOf(2);

    if (kIdx != -1) {
      List<(List<int>, int)> escapePaths = _escapeSearch(p, kIdx, 0);

      if(escapePaths.isNotEmpty) {
        move = _blockKingEscape(kIdx, escapePaths, safeMoves, bSize, p);
      }
      if (move != null) return move;
    }
    return _applySieves(safeMoves, p, bSize);
  }

  Move _applySieves(List<Move> safeMoves, Int8List p, int bSize) {
    List<Move> currentList = List.from(safeMoves);

    //currentList = _sieveReduceWhiteMobility(currentList, p, bSize);
    //if (currentList.length == 1) return currentList.first;

    currentList = _sieveDefend(currentList, p, bSize, false);
    if (currentList.length == 1) return currentList.first;

    currentList = _sieveThreaten(currentList, p, bSize, false);
    if (currentList.length == 1) return currentList.first;

    currentList = _sieveBlockLongestRay(currentList, p, bSize);
    if (currentList.length == 1) return currentList.first;

    currentList = _sieveStructure(currentList, p, bSize, false);
    return currentList.first;
  }

  // --- ESCAPE SEARCH E RECURSIVE (Invariati) ---
  List<(List<int>, int)> _escapeSearch(Int8List p, int kingOriginalPos, int mode) {
    List<(List<int>, int)> shortestPaths = [];
    List<(List<int>, int)> pathCandidates = [];
    int shortestPathLengt = 999;
    Set<int> exploredCells = {};
    int kingPos = kingOriginalPos;
    int kingNodes = 0;
    List<List<int>> rays = state.precomputedRays[kingOriginalPos];
    List<List<int>> cardinalRays = [];
    List<int> currentPath = [];
    int minDistance = 90000;

    (Set<int>, int, int, List<int>, List<(List<int>, int)> , int, int) recursiveVar =
    (exploredCells, kingPos, kingNodes, currentPath, pathCandidates, minDistance, mode);

    for (final List<int> ray in rays) {
      cardinalRays.add(_movesInRay(p, kingOriginalPos, ray, mode));
    }

    for(List<int> cRay in cardinalRays) {
      recursiveVar = ({}, kingOriginalPos, 0, [kingOriginalPos], recursiveVar.$5, 90000, recursiveVar.$7);
      if(cRay.isNotEmpty && cRay.every((cell) => !recursiveVar.$1.contains(cell))){
        recursiveVar.$1.addAll(cRay);
        recursiveVar.$4.addAll(cRay);
        recursiveVar = (recursiveVar.$1, cRay.last, 1, recursiveVar.$4, recursiveVar.$5, recursiveVar.$6, recursiveVar.$7);

        if (state.isSpecialCell[recursiveVar.$2] == true && recursiveVar.$2 != state.centerIndex){
          recursiveVar.$5.add((List.from(recursiveVar.$4), 1));
        } else {
          recursiveVar = _recursiveSearch(p, recursiveVar.$1, recursiveVar.$2, recursiveVar.$3, recursiveVar.$4, recursiveVar.$5, recursiveVar.$6, recursiveVar.$7);
        }
      }
    }

    for ((List<int>, int) candidate in recursiveVar.$5){
      if (candidate.$2 < shortestPathLengt) shortestPathLengt = candidate.$2;
    }
    for ((List<int>, int) candidate in recursiveVar.$5){
      if (candidate.$2 <= shortestPathLengt) shortestPaths.add(candidate);
    }
    return shortestPaths;
  }

  List<int> _movesInRay(List<int> p, int index, List<int> ray, int mode){
    List<int> moves = [];
    for (final int target in ray) {
      if (p[target] != 0 && mode == 0) break;
      else if (p[target] > 0 && mode == 1) break;
      else if (p[target] < 0 && mode == 2) break;
      moves.add(target);
    }
    return moves;
  }

  (Set<int>, int, int, List<int>, List<(List<int>, int)>, int, int) _recursiveSearch(
      Int8List p, Set<int> exp, int kPos, int nodes, List<int> currentPath,
      List<(List<int>, int)> candidates, int minDistance, int mode){

    int startKpos = kPos;
    Set<int> startExp = Set.from(exp);
    List<List<int>> rays = state.precomputedRays[kPos];
    List<List<int>> directionRays = [];

    for (List<int> ray in rays) {
      directionRays.add(_movesInRay(p, kPos, ray, mode));
    }

    for (List<int> dRay in directionRays){
      if (nodes <= minDistance){
        kPos = startKpos;
        if (dRay.isNotEmpty && dRay.every((cell) => !exp.contains(cell))) {
          currentPath.addAll(dRay);
          exp.addAll(dRay);
          kPos = dRay.last;

          if (state.isSpecialCell[kPos] == true && kPos != state.centerIndex) {
            candidates.add((List.from(currentPath), nodes + 1));
            currentPath.removeWhere((elem) => dRay.contains(elem));
            exp.removeWhere((elem) => dRay.contains(elem));
            kPos = startKpos;
            if(nodes <= minDistance) minDistance = nodes;
          } else {
            for (int i = dRay.length; i > 0; i --){
              if(i > 0){
                (exp, _, _, _, candidates, minDistance, _) = _recursiveSearch(p, exp, kPos, nodes + 1, currentPath, candidates, minDistance, mode);
              }
              currentPath.removeLast();
              kPos = currentPath.last;
            }
          }
        }
      }
    }
    exp.removeWhere((elem) => !startExp.contains(elem));
    return (exp, startKpos, nodes, currentPath, candidates, minDistance, mode);
  }

  Move? _blockKingEscape(int kIdx, List<(List<int>, int)> escapePaths, List<Move> safeMoves, int bSize, Int8List p) {
    Move? best;
    int maxInterceptions = -1;
    int closestIndex = 999;
    Int8List symP = Int8List.fromList(p);
    List<(List<int>, int)> interceptedPaths = [];
    List<(List<int>, int)> shortestInterceptedPaths = [];
    List<Move> blockingMoves = List.from(safeMoves);
    int minDist = 9999;
    int kingMobility = 0;
    int whiteMobility = 0;

    for (int i = 0; i < symP.length; i++){
      if(symP[i] > 0){
        int mobility = rules.calculateValidMoves(i, symP, state.size, state.boardSize).length;
        whiteMobility += mobility;
        if (symP[i] == 2) kingMobility = mobility;
      }
    }

    if (whiteMobility / 2 < kingMobility || whiteMobility < 5){
      int kIdx = symP.indexOf(2);
      List<List<int>> kRays = state.precomputedRays[kIdx];
      List<(Move, int)> trappingMoves = [];
      Move? returnMove;
      int minMobility = 99999;

      for(Move m in safeMoves){
        if (kRays.contains(m.toIndex)){
          int kM = -1;
          symP[m.fromIndex] = 0;
          symP[m.toIndex] = -1;
          kM = rules.calculateValidMoves(kIdx, symP, state.size, state.boardSize).length;
          trappingMoves.add((m, kM));
          symP[m.fromIndex] = -1;
          symP[m.toIndex] = 0;
        }
      }

      for ((Move, int) tM in trappingMoves){
        if(tM.$2 < minMobility){
          returnMove = tM.$1;
          minMobility = tM.$2;
        }
      }
      if(returnMove != null) return returnMove;
    }

    for (Move m in safeMoves) {
      int currentInterceptions = 0;
      for ((List<int>, int) path in escapePaths) {
        if (path.$1.indexOf(m.toIndex) != -1) currentInterceptions++;
      }
      if (currentInterceptions > 0) symP[m.fromIndex] = 0;
    }

    interceptedPaths = _escapeSearch(symP, kIdx, 0);
    symP = Int8List.fromList(p);

    for(int i = 0; i < escapePaths.length; i++){
      if (escapePaths[i].$2 < minDist) minDist = escapePaths[i].$2;
    }
    for(int i = 0; i < interceptedPaths.length; i++){
      if (interceptedPaths[i].$2 <= minDist) shortestInterceptedPaths.add(interceptedPaths[i]);
    }

    for(int i = 0; i < shortestInterceptedPaths.length; i++){
      int multiBolcked = 0;
      for (int j = 0; j < symP.length; j++){
        if (shortestInterceptedPaths[i].$1.contains(symP[j]) && symP[j] != 0){
          multiBolcked++;
        }
      }
      if (multiBolcked >= 2){
        shortestInterceptedPaths.removeAt(i);
      }
    }

    for (int j = 0; j < shortestInterceptedPaths.length; j++){
      for (Move m in safeMoves) {
        if (shortestInterceptedPaths[j].$1.contains(m.fromIndex) &&
            !shortestInterceptedPaths[j].$1.contains(m.toIndex)){
          blockingMoves.remove(m);
        }
      }
    }

    for (Move m in blockingMoves) {
      int currentInterceptions = 0;
      int minIdxInPaths = 999;
      for ((List<int>, int) path in escapePaths) {
        int idx = path.$1.indexOf(m.toIndex);
        if (idx != -1) {
          currentInterceptions++;
          if (idx < minIdxInPaths) minIdxInPaths = idx;
        }
      }
      if (currentInterceptions > 0) {
        if (currentInterceptions > maxInterceptions) {
          maxInterceptions = currentInterceptions;
          closestIndex = minIdxInPaths;
          best = m;
        } else if (currentInterceptions == maxInterceptions) {
          if (minIdxInPaths < closestIndex) {
            closestIndex = minIdxInPaths;
            best = m;
          }
        }
      }
    }
    return best;
  }

  // ===========================================================================
  // FILTRI UNIFICATI (ATTACCO, DIFESA, STRUTTURA)
  // ===========================================================================

  List<Move> _sieveDefend(List<Move> inputMoves, Int8List p, int bSize, bool isWhite) {
    int currentThreats = _countThreatenedPieces(p, bSize, isWhite);
    if (currentThreats == 0) return inputMoves;

    List<Move> filtered = List.from(inputMoves);
    for (int i = filtered.length - 1; i >= 0; i--) {
      Int8List simP = Int8List.fromList(p);
      Move m = filtered[i];
      simP[m.toIndex] = simP[m.fromIndex];
      simP[m.fromIndex] = 0;

      if (_countThreatenedPieces(simP, bSize, isWhite) >= currentThreats) {
        filtered.removeAt(i);
      }
    }
    return filtered.isEmpty ? inputMoves : filtered;
  }

  List<Move> _sieveThreaten(List<Move> inputMoves, Int8List p, int bSize, bool isWhite) {
    List<Move> filtered = List.from(inputMoves);

    for (int i = filtered.length - 1; i >= 0; i--) {
      Int8List simP = Int8List.fromList(p);
      Move m = filtered[i];
      simP[m.toIndex] = simP[m.fromIndex];
      simP[m.fromIndex] = 0;
      bool canCapture = false;

      for (int idx = 0; idx < simP.length; idx++) {
        if (isWhite ? simP[idx] > 0 : simP[idx] < 0) {
          List<int> myMoves = rules.calculateValidMoves(idx, simP, state.size, bSize);
          for (int target in myMoves) {
            Int8List finalP = Int8List.fromList(simP);
            finalP[target] = finalP[idx];
            finalP[idx] = 0;

            if (rules.capture(target, finalP, state.size, bSize, isWhite).isNotEmpty) {
              canCapture = true;
              break;
            }
          }
        }
        if (canCapture) break;
      }
      if (!canCapture) filtered.removeAt(i);
    }

    if (filtered.isEmpty) return inputMoves;

    if (isWhite) {
      int kingIndex = p.indexOf(2);
      List<Move> kingMenace = [];
      for (Move m in filtered) {
        if (m.fromIndex == kingIndex) {
          kingMenace.add(m);
        }
      }
      if (kingMenace.isNotEmpty) {
        filtered = kingMenace;
      }
    }

    return filtered;
  }

  List<Move> _sieveStructure(List<Move> inputMoves, Int8List p, int bSize, bool isWhite) {
    List<Move> filtered = List.from(inputMoves);
    for (int i = filtered.length - 1; i >= 0; i--) {
      Move m = filtered[i];
      int t = m.toIndex, r = t ~/ bSize, c = t % bSize;
      bool hasAlly = false;

      for (int dr = -1; dr <= 1; dr++) {
        for (int dc = -1; dc <= 1; dc++) {
          if (dr == 0 && dc == 0) continue;
          int nr = r + dr, nc = c + dc;
          if (nr >= 0 && nr < bSize && nc >= 0 && nc < bSize) {
            if (isWhite ? p[nr * bSize + nc] > 0 : p[nr * bSize + nc] < 0) {
              hasAlly = true;
              break;
            }
          }
        }
        if (hasAlly) break;
      }
      if (!hasAlly) filtered.removeAt(i);
    }
    return filtered.isEmpty ? inputMoves : filtered;
  }

  // --- FILTRI SPECIFICI (Nero) ---
  List<Move> _sieveBlockLongestRay(List<Move> inputMoves, Int8List originalP, int bSize) {
    Int8List p = Int8List.fromList(originalP);
    int maxRayLength = 0;
    List<MapEntry<int, List<int>>> allLongestRays = [];

    for (int i = 0; i < p.length; i++) {
      if (p[i] > 0) {
        List<int> validMoves = rules.calculateValidMoves(i, p, state.size, bSize);
        List<List<int>> rays = _extractDirectionalRays(i, validMoves, bSize);
        for (var currentRay in rays) {
          if (currentRay.length > maxRayLength) {
            maxRayLength = currentRay.length;
            allLongestRays = [MapEntry(i, currentRay)];
          } else if (currentRay.length == maxRayLength && maxRayLength > 0) {
            allLongestRays.add(MapEntry(i, currentRay));
          }
        }
      }
    }

    if (maxRayLength == 0) return inputMoves;
    List<Move> filtered = List.from(inputMoves);

    for (int i = filtered.length - 1; i >= 0; i--) {
      Move m = filtered[i];
      bool hitsMaxRay = allLongestRays.any((entry) => entry.value.contains(m.toIndex));

      bool opensWorse = false;
      if (hitsMaxRay) {
        Int8List simP = Int8List.fromList(p);
        simP[m.toIndex] = simP[m.fromIndex]; simP[m.fromIndex] = 0;
        if (_getGlobalMaxRayLength(simP, bSize) > maxRayLength) opensWorse = true;
      }
      if (!hitsMaxRay || opensWorse) filtered.removeAt(i);
    }

    if (filtered.isEmpty) return inputMoves;

    int maxCuts = 0;
    Map<Move, int> counts = {};
    for (Move m in filtered) {
      int c = allLongestRays.where((entry) => entry.value.contains(m.toIndex)).length;
      counts[m] = c;
      if (c > maxCuts) maxCuts = c;
    }
    for (int i = filtered.length - 1; i >= 0; i--) {
      if (counts[filtered[i]]! < maxCuts) filtered.removeAt(i);
    }
    return filtered.isEmpty ? inputMoves : filtered;
  }

  List<Move> _sieveReduceWhiteMobility(List<Move> inputMoves, Int8List p, int bSize) {
    int currentMob = _getTotalWhiteMoves(p, bSize);
    List<Move> filtered = List.from(inputMoves);
    for (int i = filtered.length - 1; i >= 0; i--) {
      Int8List simP = Int8List.fromList(p);
      Move m = filtered[i];
      simP[m.toIndex] = simP[m.fromIndex]; simP[m.fromIndex] = 0;
      if (_getTotalWhiteMoves(simP, bSize) >= currentMob) filtered.removeAt(i);
    }
    return filtered.isEmpty ? inputMoves : filtered;
  }

  // ===========================================================================
  // SICUREZZA E MOTORE DI BASE
  // ===========================================================================
  List<Move> _getSafeMoves(bool isWhiteTurn) {
    Int8List p = Int8List.fromList(state.pieces);
    List<Move> safe = [];
    for (int i = 0; i < p.length; i++) {
      int pieceAt = p[i];
      if (isWhiteTurn ? pieceAt > 0 : pieceAt < 0) {
        List<int> mvs = rules.calculateValidMoves(i, p, state.size, state.boardSize);
        for (int j = 0; j < mvs.length; j++) {
          if (_isMoveSafe(i, mvs[j], p, isWhiteTurn) == true) {
            safe.add(Move(i, mvs[j]));
          }
        }
      }
    }
    return safe;
  }

  bool _isMoveSafe(int from, int to, Int8List originalP, bool isWhiteTurn) {
    int bSize = state.boardSize;
    Int8List simP = Int8List.fromList(originalP);
    int movedPiece = simP[from];

    simP[from] = 0;
    simP[to] = movedPiece;

    int r = to ~/ bSize;
    int c = to % bSize;

    for (int i = 0; i < simP.length; i++) {
      int currentPiece = simP[i];

      if (currentPiece == 0) continue;
      if (isWhiteTurn && currentPiece > 0) continue;
      if (!isWhiteTurn && currentPiece < 0) continue;

      List<int> enemyMoves = rules.calculateValidMoves(i, simP, state.size, bSize);

      for (int m in enemyMoves) {
        if (m == to - bSize || m == to + bSize ||
            (m == to - 1 && to % bSize != 0) ||
            (m == to + 1 && to % bSize != bSize - 1)) {

          simP[i] = 0;
          simP[m] = currentPiece;

          bool nHostile = (r > 0) && (state.isSpecialCell[to - bSize] || (isWhiteTurn ? simP[to - bSize] == -1 : simP[to - bSize] > 0));
          bool sHostile = (r < bSize - 1) && (state.isSpecialCell[to + bSize] || (isWhiteTurn ? simP[to + bSize] == -1 : simP[to + bSize] > 0));
          bool wHostile = (c > 0) && (state.isSpecialCell[to - 1] || (isWhiteTurn ? simP[to - 1] == -1 : simP[to - 1] > 0));
          bool eHostile = (c < bSize - 1) && (state.isSpecialCell[to + 1] || (isWhiteTurn ? simP[to + 1] == -1 : simP[to + 1] > 0));

          if (movedPiece == 2) {
            if (nHostile && sHostile && wHostile && eHostile) return false;
          } else {
            if ((nHostile && sHostile) || (wHostile && eHostile)) return false;
          }

          simP[i] = currentPiece;
          simP[m] = 0;
        }
      }
    }
    return true;
  }

  // ===========================================================================
  // HELPERS
  // ===========================================================================

  int _countThreatenedPieces(Int8List p, int bSize, bool isWhite) {
    Set<int> threatened = {};
    for (int i = 0; i < p.length; i++) {
      if (isWhite ? p[i] < 0 : p[i] > 0) {
        List<int> enemyMoves = rules.calculateValidMoves(i, p, state.size, bSize);
        for (int em in enemyMoves) {
          Int8List simP = Int8List.fromList(p);
          simP[em] = simP[i];
          simP[i] = 0;
          List<int> caps = rules.capture(em, simP, state.size, bSize, !isWhite);
          threatened.addAll(caps);
        }
      }
    }
    return threatened.length;
  }

  int _distToEdge(int idx, int bSize) {
    int r = idx ~/ bSize;
    int c = idx % bSize;
    int distRow = r < (bSize - 1 - r) ? r : (bSize - 1 - r);
    int distCol = c < (bSize - 1 - c) ? c : (bSize - 1 - c);
    return distRow < distCol ? distRow : distCol;
  }

  bool _isStrictlyBetween(int target, int start, int end, int b) {
    if (start ~/ b == end ~/ b && target ~/ b == start ~/ b) {
      int minVal = start < end ? start : end;
      int maxVal = start > end ? start : end;
      return target > minVal && target < maxVal;
    }
    if (start % b == end % b && target % b == start % b) {
      int minVal = start < end ? start : end;
      int maxVal = start > end ? start : end;
      return target > minVal && target < maxVal;
    }
    return false;
  }

  int _getGlobalMaxRayLength(Int8List p, int bSize) {
    int maxL = 0;
    for (int i = 0; i < p.length; i++) {
      if (p[i] > 0) {
        List<int> vMoves = rules.calculateValidMoves(i, p, state.size, bSize);
        List<List<int>> rays = _extractDirectionalRays(i, vMoves, bSize);
        for (var r in rays) if (r.length > maxL) maxL = r.length;
      }
    }
    return maxL;
  }

  List<List<int>> _extractDirectionalRays(int start, List<int> validMoves, int bSize) {
    List<int> n = [], s = [], e = [], w = [];
    int sr = start ~/ bSize, sc = start % bSize;
    for (int m in validMoves) {
      int mr = m ~/ bSize, mc = m % bSize;
      if (mc == sc) { if (mr < sr) n.add(m); else s.add(m); }
      else if (mr == sr) { if (mc < sc) w.add(m); else e.add(m); }
    }
    return [n, s, e, w];
  }

  int _getTotalWhiteMoves(Int8List p, int bSize) {
    int total = 0;
    for (int i = 0; i < p.length; i++) {
      if (p[i] > 0) total += rules.calculateValidMoves(i, p, state.size, bSize).length;
    }
    return total;
  }
}