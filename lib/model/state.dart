
import 'dart:math';
import 'dart:typed_data';

class GameState {
  // Liste a dimensione fissa per massime prestazioni
  Int8List _pieces = Int8List(0);

  bool _isPlayer1Turn = false;
  bool _checkmate = false;
  int _moves = 0;
  bool _repetition = false;

  List<int> _boardStates = [];

  int? _selectedPieceIndex;
  List<int> _validMoves = [];
  bool _volumeOff = false;
  bool _playVsCPU = false;
  bool _botTurn = false;
  bool _botColor = false;
  int _boardSize;
  int get size => _boardSize * _boardSize;
  final Random _random = Random();
  int? _oldIndex;
  int? _newIndex;
  List<int?> _oldMove = [];

  // LOGICA ZOBRIST
  late Uint64List _zobristTable;
  int _currentHash = 0;

  // --- LOGICA BITMASK ---
  BigInt _whiteMask = BigInt.zero;
  BigInt _blackMask = BigInt.zero;
  BigInt _kingMask = BigInt.zero;
  BigInt _unoccupiedMask = BigInt.zero;

  late BigInt _northEdge, _southEdge, _westEdge, _eastEdge;
  late BigInt _allEdges;
  late BigInt _baseHostileMask;
  int _centerIndex = 0;

  // --- LOGICA COORDINATE BORDI (LISTE) ---
  List<int> _northEdgeIndices = [];
  List<int> _southEdgeIndices = [];
  List<int> _westEdgeIndices = [];
  List<int> _eastEdgeIndices = [];

  // --- LOGICA LOOKUP TABLES (Raggi e Speciali) ---
  late List<List<List<int>>> _precomputedRays;
  late List<bool> _isSpecialCell;

  // Getter
  Int8List get pieces => _pieces;
  bool get isPlayer1Turn => _isPlayer1Turn;
  bool get checkmate => _checkmate;
  int get moves => _moves;
  bool get repetition => _repetition;
  List<int> get boardStates => _boardStates;
  int? get selectedPieceIndex => _selectedPieceIndex;
  List<int> get validMoves => _validMoves;
  bool get volumeOff => _volumeOff;
  bool get playVsCPU => _playVsCPU;
  bool get botTurn => _botTurn;
  bool get botColor => _botColor;
  int get boardSize => _boardSize;
  int? get oldIndex => _oldIndex;
  int? get newIndex => _newIndex;
  List<int?> get oldMove => _oldMove;
  int get currentHash => _currentHash;
  int get centerIndex => _centerIndex;

  List<List<List<int>>> get precomputedRays => _precomputedRays;
  List<bool> get isSpecialCell => _isSpecialCell;

  // Getter Liste Bordi
  List<int> get northEdgeIndices => _northEdgeIndices;
  List<int> get southEdgeIndices => _southEdgeIndices;
  List<int> get westEdgeIndices => _westEdgeIndices;
  List<int> get eastEdgeIndices => _eastEdgeIndices;

  // Getter Bitmask
  BigInt get unoccupiedMask => _unoccupiedMask;
  BigInt get whiteMask => _whiteMask;
  BigInt get blackMask => _blackMask;
  BigInt get kingMask => _kingMask;
  BigInt get allEdges => _allEdges;
  BigInt get northEdge => _northEdge;
  BigInt get southEdge => _southEdge;
  BigInt get westEdge => _westEdge;
  BigInt get eastEdge => _eastEdge;
  BigInt get baseHostileMask => _baseHostileMask;
  BigInt get effectiveHostileMask => _baseHostileMask & ~_kingMask;

  // Setter
  set pieces(Int8List value) => _pieces = value;
  set isPlayer1Turn(bool value) => _isPlayer1Turn = value;
  set checkmate(bool value) => _checkmate = value;
  set moves(int value) { if (value >= 0) _moves = value; }
  set repetition(bool value) => _repetition = value;
  set boardStates(List<int> value) => _boardStates = value;
  set selectedPieceIndex(int? value) => _selectedPieceIndex = value;
  set validMoves(List<int> value) => _validMoves = value;
  set volumeOff(bool value) => _volumeOff = value;
  set playVsCPU(bool value) => _playVsCPU = value;
  set botTurn(bool value) => _botTurn = value;
  set botColor(bool value) => _botColor = value;
  set boardSize(int value) { if (value >= 7 && value <= 15) _boardSize = value; }
  set oldIndex(value) => _oldIndex = value;
  set newIndex(value) => _newIndex = value;
  set oldMove(List<int?> value) => _oldMove = value;
  set centerIndex(int value) => _centerIndex = value;

  // Setter Liste Bordi
  set northEdgeIndices(List<int> value) => _northEdgeIndices = value;
  set southEdgeIndices(List<int> value) => _southEdgeIndices = value;
  set westEdgeIndices(List<int> value) => _westEdgeIndices = value;
  set eastEdgeIndices(List<int> value) => _eastEdgeIndices = value;

  GameState({required int boardSize}) : _boardSize = boardSize {
    _botColor = _random.nextBool();
    _pieces = Int8List(size); // Inizializzazione fisica dell'array
    _rebuildStaticStructures();
  }

  /// Ricostruisce solo i dati geografici e logici immutabili per quella boardSize
  void _rebuildStaticStructures() {
    _initZobristTable();
    _initSpatialData();
    _initBitmaskStructure();
  }

  void _initSpatialData() {
    _centerIndex = (size - 1) ~/ 2;
    _isSpecialCell = List.generate(size, (i) {
      return (i == 0 || i == _boardSize - 1 || i == size - _boardSize || i == size - 1 || i == _centerIndex);
    });

    // Inizializzazione liste coordinate bordi
    _northEdgeIndices = [for (int i = 0; i < _boardSize; i++) i];
    _southEdgeIndices = [for (int i = 0; i < _boardSize; i++) size - _boardSize + i];
    _westEdgeIndices = [for (int i = 0; i < _boardSize; i++) i * _boardSize];
    _eastEdgeIndices = [for (int i = 0; i < _boardSize; i++) i * _boardSize + _boardSize - 1];

    _precomputedRays = List.generate(size, (index) {
      int r = index ~/ _boardSize;
      int c = index % _boardSize;
      return [
        [for (int i = r - 1; i >= 0; i--) i * _boardSize + c],
        [for (int i = r + 1; i < _boardSize; i++) i * _boardSize + c],
        [for (int i = c - 1; i >= 0; i--) r * _boardSize + i],
        [for (int i = c + 1; i < _boardSize; i++) r * _boardSize + i],
      ];
    });
  }

  void _initZobristTable() {
    _zobristTable = Uint64List(size * 4);
    for (int i = 0; i < _zobristTable.length; i++) {
      _zobristTable[i] = (_random.nextInt(1 << 32) << 32) | _random.nextInt(1 << 32);
    }
  }

  void calculateFullHash() {
    _currentHash = 0;
    for (int i = 0; i < _pieces.length; i++) {
      if (_pieces[i] != 0) _currentHash ^= _zobristTable[_getZobristOffset(i, _pieces[i])].toInt();
    }
  }

  void updateHash(int index, int pieceValue) {
    if (pieceValue == 0) return;
    _currentHash ^= _zobristTable[_getZobristOffset(index, pieceValue)].toInt();
  }

  void _initBitmaskStructure() {
    _northEdge = BigInt.zero; _southEdge = BigInt.zero;
    _westEdge = BigInt.zero; _eastEdge = BigInt.zero;

    for (int i = 0; i < _boardSize; i++) {
      _northEdge |= (BigInt.one << i);
      _southEdge |= (BigInt.one << (size - _boardSize + i));
      _westEdge |= (BigInt.one << (i * _boardSize));
      _eastEdge |= (BigInt.one << (i * _boardSize + _boardSize - 1));
    }
    _allEdges = _northEdge | _southEdge | _westEdge | _eastEdge;
    _baseHostileMask = (BigInt.one << 0) | (BigInt.one << (_boardSize - 1)) |
    (BigInt.one << (size - _boardSize)) | (BigInt.one << (size - 1)) |
    (BigInt.one << _centerIndex);
  }

  void syncBitmasks() {
    _whiteMask = BigInt.zero; _blackMask = BigInt.zero;
    _kingMask = BigInt.zero; _unoccupiedMask = BigInt.zero;
    for (int i = 0; i < _pieces.length; i++) {
      if (_pieces[i] == 1) { _whiteMask |= (BigInt.one << i); }
      else if (_pieces[i] == -1) { _blackMask |= (BigInt.one << i); }
      else if (_pieces[i] == 2) { _kingMask |= (BigInt.one << i); _whiteMask |= (BigInt.one << i); }
      else if (_pieces[i] == 0) { _unoccupiedMask |= (BigInt.one << i); }
    }
  }

  void updateBitmask(int index, int pieceValue) {
    if (pieceValue == 0) return;
    BigInt bit = BigInt.one << index;
    _unoccupiedMask ^= bit;
    if (pieceValue == 1) _whiteMask ^= bit;
    else if (pieceValue == -1) _blackMask ^= bit;
    else if (pieceValue == 2) { _kingMask ^= bit; _whiteMask ^= bit; }
  }

  void initBoardSize(int s) {
    if (s == 1) _boardSize = 7;
    else if (s == 2) _boardSize = 9;
    else if (s == 3) _boardSize = 11;
    else if (s == 4) _boardSize = 13;
    else if (s == 5) _boardSize = 15;

    _pieces = Int8List(size); // Ricrea l'array solo al cambio dimensione fisica
    _rebuildStaticStructures();
  }

  void initPieces() {
    // 1. Pulizia dell'array esistente (senza ricrearlo per non perdere i puntatori)
    _pieces.fillRange(0, _pieces.length, 0);
    _oldIndex = null;
    _oldMove.clear();
    _checkmate = false;
    _boardStates.clear();

    // 2. Setup dei pezzi per le varie configurazioni
    if (_boardSize == 7) {
      _setInitial(3, -1); _setInitial(10, -1); _setInitial(21, -1); _setInitial(22, -1);
      _setInitial(26, -1); _setInitial(27, -1); _setInitial(38, -1); _setInitial(45, -1);
      _setInitial(23, 1); _setInitial(25, 1); _setInitial(31, 1); _setInitial(17, 1);
      _setInitial(24, 2);
    } else if (_boardSize == 9) {
      for (int i = 3; i < 6; i++) _pieces[i] = -1;
      for (int i = 75; i < 78; i++) _pieces[i] = -1;
      for (int i = 35; i < 38; i++) _pieces[i] = -1;
      for (int i = 43; i < 46; i++) _pieces[i] = -1;
      _setInitial(13, -1); _setInitial(67, -1); _setInitial(27, -1); _setInitial(53, -1);
      _setInitial(38, 1); _setInitial(39, 1); _setInitial(41, 1); _setInitial(42, 1);
      _setInitial(49, 1); _setInitial(31, 1); _setInitial(22, 1); _setInitial(58, 1);
      _setInitial(40, 2);
    } else if (_boardSize == 11) {
      for (int i = 3; i < 8; i++) _pieces[i] = -1;
      for (int i = 113; i < 118; i++) _pieces[i] = -1;
      for (int i = 54; i < 57; i++) _pieces[i] = -1;
      for (int i = 64; i < 67; i++) _pieces[i] = -1;
      for (int i = 76; i < 78; i++) _pieces[i] = -1;
      for (int i = 43; i < 45; i++) _pieces[i] = -1;
      _setInitial(16, -1); _setInitial(33, -1); _setInitial(87, -1); _setInitial(104, -1);
      for (int i = 48; i < 51; i++) _pieces[i] = 1;
      for (int i = 58; i < 60; i++) _pieces[i] = 1;
      for (int i = 61; i < 63; i++) _pieces[i] = 1;
      for (int i = 70; i < 73; i++) _pieces[i] = 1;
      _setInitial(38, 1); _setInitial(82, 1);
      _setInitial(60, 2);
    } else if (_boardSize == 13) {
      for (int i = 3; i < 10; i++) _pieces[i] = -1;
      for (int i = 159; i < 166; i++) _pieces[i] = -1;
      for (int i = 77; i < 80; i++) _pieces[i] = -1;
      for (int i = 89; i < 92; i++) _pieces[i] = -1;
      _setInitial(19, -1); _setInitial(149, -1); _setInitial(104, -1); _setInitial(65, -1);
      _setInitial(52, -1); _setInitial(39, -1); _setInitial(103, -1); _setInitial(116, -1);
      _setInitial(129, -1); _setInitial(117, -1); _setInitial(64, -1); _setInitial(51, -1);
      for (int i = 81; i < 84; i++) _pieces[i] = 1;
      for (int i = 85; i < 88; i++) _pieces[i] = 1;
      _setInitial(97, 1); _setInitial(110, 1); _setInitial(123, 1);
      _setInitial(71, 1); _setInitial(58, 1); _setInitial(45, 1);
      _setInitial(98, 1); _setInitial(96, 1); _setInitial(70, 1); _setInitial(72, 1);
      _setInitial(84, 2);
    } else if (_boardSize == 15) {
      for (int i = 4; i < 11; i++) _pieces[i] = -1;
      for (int i = 214; i < 221; i++) _pieces[i] = -1;
      for (int i = 89; i < 92; i++) _pieces[i] = -1;
      for (int i = 103; i < 106; i++) _pieces[i] = -1;
      for (int i = 119; i < 122; i++) _pieces[i] = -1;
      for (int i = 133; i < 136; i++) _pieces[i] = -1;
      for (int i = 149; i < 151; i++) _pieces[i] = -1;
      for (int i = 74; i < 76; i++) _pieces[i] = -1;
      _setInitial(60, -1); _setInitial(164, -1); _setInitial(107, -1); _setInitial(117, -1);
      _setInitial(21, -1); _setInitial(23, -1); _setInitial(37, -1);
      _setInitial(201, -1); _setInitial(203, -1); _setInitial(187, -1);
      for (int i = 113; i < 116; i++) _pieces[i] = 1;
      for (int i = 109; i < 112; i++) _pieces[i] = 1;
      for (int i = 96; i < 99; i++) _pieces[i] = 1;
      for (int i = 126; i < 129; i++) _pieces[i] = 1;
      _setInitial(142, 1); _setInitial(157, 1); _setInitial(82, 1); _setInitial(67, 1);
      _setInitial(140, 1); _setInitial(144, 1); _setInitial(80, 1); _setInitial(84, 1);
      _setInitial(112, 2);
    }

    // 3. Sincronizzazione logica finale
    syncBitmasks();
    calculateFullHash();
    _boardStates.add(_currentHash);
  }

  int _getZobristOffset(int index, int pieceValue) => (index * 4) + (pieceValue + 1);
  void _setInitial(int index, int val) { if (index < _pieces.length) _pieces[index] = val; }
}

