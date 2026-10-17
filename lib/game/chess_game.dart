import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../core/chess.dart';
import '../ai/ai_bridge.dart';
import '../core/chess_ai.dart';
import '../online/config.dart';
import '../ui/sound.dart';
import 'models.dart';

/// Owns the position, move history, AI turn scheduling and persistence.
class ChessGame extends ChangeNotifier {
  final GameConfig config;

  late Position position;
  final List<String> _fens = [];
  final List<int> _moves = [];
  final List<String> _sans = [];
  final List<int> _hashes = [];

  GameStatus status = GameStatus.playing;
  bool thinking = false;
  bool hintLoading = false;
  int? selectedSquare;
  List<int> selectedMoves = const [];
  int? lastMove;
  int? hintMove;
  List<int> promotionMoves = const [];
  String? aiNote;
  int moveSerial = 0;
  bool assisted = false;
  bool paused = false;
  bool manualOverride = false;
  bool botMatch = false;
  int? thinkingSide;
  int? forfeitWinner;
  String? forfeitReason;
  void Function(int move)? onLocalMove;

  bool _disposed = false;
  bool _applyingRemote = false;
  int _aiGeneration = 0;
  Timer? _autoMoveTimer;

  ChessGame({required this.config, SavedGame? resume, bool sound = true}) {
    AppSound.enabled = sound;
    if (resume != null) {
      _restore(resume);
    } else {
      _newGame();
    }
  }

  int get humanSide => config.humanSide;
  int get aiSide => 1 - humanSide;
  bool get isAiMode =>
      config.mode == GameMode.ai || config.mode == GameMode.aiVsAi;
  bool get isAiVsAi => config.mode == GameMode.aiVsAi;
  bool get isOnline => config.mode == GameMode.online;
  bool get isAssisted =>
      (config.mode == GameMode.ai || config.mode == GameMode.online) &&
      assisted;
  bool get isHumanTurn {
    switch (config.mode) {
      case GameMode.twoPlayers:
        return true;
      case GameMode.aiVsAi:
        return manualOverride;
      case GameMode.ai:
      case GameMode.online:
        return position.side == humanSide;
    }
  }

  bool get canInteract =>
      !thinking &&
      !status.isOver &&
      promotionMoves.isEmpty &&
      isHumanTurn &&
      !assisted;

  int get moveCount => _moves.length;
  List<String> get sanMoves => List.unmodifiable(_sans);
  List<int> get moves => List.unmodifiable(_moves);
  int get lastMoveNumber =>
      ((moveCount + 1) / 2).ceil();
  int? get checkSquare =>
      position.isInCheck() ? position.kingSquare[position.side] : null;
  bool get isBoardFlippedByDefault => humanSide == black;

  String get turnText {
    if (status == GameStatus.checkmate) {
      return position.side == white ? '黑方获胜' : '白方获胜';
    }
    if (status.isDraw) return '和棋';
    final side = position.side == white ? '白方' : '黑方';
    if (position.isInCheck()) return '$side被将军';
    return '$side走棋';
  }

  String get resultTitle {
    switch (status) {
      case GameStatus.checkmate:
        return position.side == white ? '黑方胜' : '白方胜';
      case GameStatus.stalemate:
        return '和棋';
      case GameStatus.insufficientMaterial:
        return '和棋';
      case GameStatus.fiftyMove:
        return '和棋';
      case GameStatus.threefold:
        return '和棋';
      case GameStatus.forfeit:
        return forfeitWinner == white ? '白方胜' : '黑方胜';
      case GameStatus.playing:
        return '';
    }
  }

  String get resultSubtitle {
    switch (status) {
      case GameStatus.checkmate:
        return '将死 · Checkmate';
      case GameStatus.stalemate:
        return '逼和 · 无子可动';
      case GameStatus.insufficientMaterial:
        return '子力不足 · 无法将死';
      case GameStatus.fiftyMove:
        return '五十回合规则';
      case GameStatus.threefold:
        return '三次重复局面';
      case GameStatus.forfeit:
        return forfeitReason ?? '对手认输';
      case GameStatus.playing:
        return '';
    }
  }

  bool get humanWon {
    if (status == GameStatus.forfeit) return forfeitWinner == humanSide;
    if (status != GameStatus.checkmate) return false;
    return position.side == aiSide;
  }

  void _newGame() {
    position = Position.initial();
    _fens
      ..clear()
      ..add(position.toFen());
    _moves.clear();
    _sans.clear();
    _hashes
      ..clear()
      ..add(position.hash);
    status = GameStatus.playing;
    thinking = false;
    hintLoading = false;
    selectedSquare = null;
    selectedMoves = const [];
    lastMove = null;
    hintMove = null;
    promotionMoves = const [];
    aiNote = null;
    moveSerial = 0;
    assisted = false;
    paused = false;
    manualOverride = false;
    thinkingSide = null;
    forfeitWinner = null;
    forfeitReason = null;
    _applyingRemote = false;
    _autoMoveTimer?.cancel();
    _aiGeneration++;
    if (isAiVsAi) {
      _scheduleAutoMove(delay: const Duration(milliseconds: 500));
    } else if (config.mode == GameMode.ai && humanSide == black) {
      scheduleMicrotask(_startAi);
    }
  }

  void startNewGame() {
    _newGame();
    _safeNotify();
    _persist();
  }

  void _restore(SavedGame saved) {
    _fens.addAll(saved.fens);
    _moves.addAll(saved.moves);
    _sans.addAll(saved.sans);
    _hashes.addAll(saved.fens.map((f) => Position.fromFen(f).hash));
    position = Position.fromFen(saved.fens.last);
    lastMove = _moves.isEmpty ? null : _moves.last;
    moveSerial = _moves.length;
    assisted = false;
    paused = false;
    thinkingSide = null;
    _refreshStatus();
    if (isAiVsAi && status == GameStatus.playing) {
      _scheduleAutoMove(delay: const Duration(milliseconds: 500));
    } else if (config.mode == GameMode.ai &&
        status == GameStatus.playing &&
        position.side == aiSide) {
      scheduleMicrotask(_startAi);
    }
  }

  void select(int square) {
    if (thinking || status.isOver || promotionMoves.isNotEmpty) return;
    if ((isAiVsAi && !manualOverride) || assisted) return;
    if ((config.mode == GameMode.ai || config.mode == GameMode.online) &&
        position.side != humanSide) {
      return;
    }

    hintMove = null;
    final piece = position.pieceAt(square);

    if (selectedSquare != null) {
      final matches =
          selectedMoves.where((m) => moveTo(m) == square).toList(growable: false);
      if (matches.isNotEmpty) {
        if (matches.any((m) => movePromotion(m) != 0)) {
          promotionMoves = matches;
          _safeNotify();
          return;
        }
        _applyMove(matches.first, fromAi: false);
        return;
      }
    }

    if (piece != 0 && colorOf(piece) == position.side) {
      if (selectedSquare == square) {
        selectedSquare = null;
        selectedMoves = const [];
      } else {
        selectedSquare = square;
        selectedMoves = position.legalMovesFrom(square);
        AppSound.select();
      }
    } else {
      selectedSquare = null;
      selectedMoves = const [];
    }
    _safeNotify();
  }

  void completePromotion(int type) {
    if (promotionMoves.isEmpty) return;
    final move = promotionMoves.firstWhere(
      (m) => movePromotion(m) == type,
      orElse: () => promotionMoves.first,
    );
    promotionMoves = const [];
    _applyMove(move, fromAi: false);
  }

  void cancelPromotion() {
    promotionMoves = const [];
    selectedSquare = null;
    selectedMoves = const [];
    _safeNotify();
  }

  void _applyMove(int move, {required bool fromAi}) {
    final san = position.sanFor(move);
    final isCapture = moveIsCapture(move);
    position.makeMove(move);

    _fens.add(position.toFen());
    _moves.add(move);
    _sans.add(san);
    _hashes.add(position.hash);
    lastMove = move;
    selectedSquare = null;
    selectedMoves = const [];
    promotionMoves = const [];
    hintMove = null;
    moveSerial++;
    if (manualOverride && !fromAi) manualOverride = false;
    _refreshStatus();

    if (position.isInCheck()) {
      AppSound.check();
    } else if (isCapture) {
      AppSound.capture();
    } else {
      AppSound.move();
    }

    if (isOnline && !_applyingRemote) {
      onLocalMove?.call(move);
    }
    _safeNotify();
    _persist();

    if (isOnline) {
      if (assisted &&
          status == GameStatus.playing &&
          position.side == humanSide) {
        _scheduleAutoMove(delay: const Duration(milliseconds: 300));
      }
      return;
    }

    if (isAiMode && status == GameStatus.playing) {
      if (isAiVsAi) {
        _scheduleAutoMove(delay: const Duration(milliseconds: 550));
      } else if (assisted) {
        _scheduleAutoMove(delay: const Duration(milliseconds: 280));
      } else if (!fromAi) {
        _scheduleAutoMove();
      }
    }
  }

  /// Applies a move received from the online opponent.
  void applyRemoteMove(int move) {
    if (!isOnline || status.isOver) return;
    if (position.side == humanSide) return;
    if (!position.legalMoves().contains(move)) return;
    _applyingRemote = true;
    _applyMove(move, fromAi: true);
    _applyingRemote = false;
  }

  void endWithForfeit(int winner, {String reason = '对手认输'}) {
    if (status.isOver) return;
    forfeitWinner = winner;
    forfeitReason = reason;
    status = GameStatus.forfeit;
    thinking = false;
    hintLoading = false;
    thinkingSide = null;
    _autoMoveTimer?.cancel();
    _aiGeneration++;
    _safeNotify();
    _persist();
  }

  void _scheduleAutoMove({Duration delay = Duration.zero}) {
    if (_disposed || status.isOver || paused) return;
    if (isAiVsAi && manualOverride) return;

    if (isOnline) {
      if (!assisted || position.side != humanSide) return;
    } else {
      if (!isAiMode) return;
      final bool shouldMove = isAiVsAi || assisted || position.side == aiSide;
      if (!shouldMove) return;
    }
    if (thinking) return;

    _autoMoveTimer?.cancel();
    if (delay == Duration.zero) {
      scheduleMicrotask(() {
        if (!_disposed) _startAi();
      });
    } else {
      _autoMoveTimer = Timer(delay, () {
        if (!_disposed) _startAi();
      });
    }
  }

  Future<void> _startAi() async {
    if (_disposed || thinking || status.isOver || paused) return;
    if (!isAiMode && !isOnline) return;
    if (isOnline && !assisted) return;
    if (isAiVsAi && manualOverride) return;

    final mover = position.side;
    if (config.mode == GameMode.ai && !assisted && mover != aiSide) return;
    if (isOnline && mover != humanSide) return;

    thinking = true;
    thinkingSide = mover;
    hintMove = null;
    _safeNotify();

    final generation = ++_aiGeneration;

    // For an online bot match, keep a human-like tempo instead of answering
    // instantly. The opponent is presented as a regular online player.
    if (botMatch) {
      await Future<void>.delayed(
        Duration(milliseconds: 450 + Random().nextInt(700)),
      );
      if (_disposed || generation != _aiGeneration) return;
    }

    final fen = position.toFen();
    final legalMoves = position.legalMoves();
    final int level = assisted ? 3 : config.difficulty.index;

    // Optional local large-model brain for regular AI turns. The bridge can
    // only choose from the legal moves below, and anything invalid falls back
    // to the engine. AI 托管 always uses the strongest (master) engine search.
    if (AiBridge.enabled && !assisted && legalMoves.isNotEmpty) {
      final recent = _sans.length > 10
          ? _sans.sublist(_sans.length - 10)
          : List<String>.of(_sans);
      final options = <AiMoveOption>[
        for (final move in legalMoves)
          AiMoveOption(id: uciForMove(move), label: position.sanFor(move)),
      ];
      final llmId = await AiBridge.chooseMove(
        game: 'chess',
        state: 'FEN: $fen\n最近着法: ${recent.isEmpty ? '无' : recent.join(' ')}',
        moves: options,
        player: mover,
        level: level,
      );
      if (_disposed || generation != _aiGeneration) return;
      if (llmId != null) {
        for (final move in legalMoves) {
          if (uciForMove(move) == llmId) {
            thinking = false;
            thinkingSide = null;
            aiNote = '本地模型 · ${OnlineConfig.aiModel}';
            _applyMove(move, fromAi: true);
            return;
          }
        }
      }
    }

    final seed = DateTime.now().microsecondsSinceEpoch & 0x7FFFFFFF;
    Map<String, Object?>? result;
    try {
      result = await compute<Map<String, Object?>, Map<String, Object?>?>(
        aiCompute,
        {
          'fen': fen,
          'level': level,
          'seed': seed,
        },
      );
    } catch (_) {
      result = null;
    }

    if (_disposed || generation != _aiGeneration) return;
    thinking = false;
    thinkingSide = null;
    if (result != null &&
        status == GameStatus.playing &&
        position.side == mover &&
        position.toFen() == fen) {
      final move = result['move'];
      if (move is int && position.legalMoves().contains(move)) {
        aiNote = assisted
            ? '大师引擎 · 深度 ${result['depth']}'
            : '深度 ${result['depth']} · 评分 ${result['score']}';
        _applyMove(move, fromAi: true);
        return;
      }
    }
    _safeNotify();
  }

  Future<void> requestHint() async {
    if (_disposed ||
        thinking ||
        hintLoading ||
        status.isOver ||
        promotionMoves.isNotEmpty ||
        isAiVsAi ||
        assisted ||
        (config.mode == GameMode.ai && position.side != humanSide)) {
      return;
    }
    hintLoading = true;
    hintMove = null;
    _safeNotify();

    final fen = position.toFen();
    final seed = DateTime.now().microsecondsSinceEpoch & 0x7FFFFFFF;
    Map<String, Object?>? result;
    try {
      result = await compute<Map<String, Object?>, Map<String, Object?>?>(
        aiCompute,
        {
          'fen': fen,
          'level': 2,
          'seed': seed,
        },
      );
    } catch (_) {
      result = null;
    }
    if (_disposed) return;
    hintLoading = false;
    if (result != null &&
        status == GameStatus.playing &&
        position.toFen() == fen &&
        (position.side == humanSide || !isAiMode)) {
      final move = result['move'];
      if (move is int && position.legalMoves().contains(move)) {
        hintMove = move;
        AppSound.select();
      }
    }
    _safeNotify();
  }

  void toggleAssisted() {
    if ((config.mode != GameMode.ai && config.mode != GameMode.online) ||
        status.isOver) {
      return;
    }
    assisted = !assisted;
    if (assisted) {
      _scheduleAutoMove();
    } else {
      _autoMoveTimer?.cancel();
      if (thinking && thinkingSide == humanSide) {
        _aiGeneration++;
        thinking = false;
        thinkingSide = null;
      }
    }
    _safeNotify();
  }

  void togglePaused() {
    if (!isAiVsAi) return;
    paused = !paused;
    if (paused) {
      _autoMoveTimer?.cancel();
      manualOverride = false;
      if (thinking) {
        _aiGeneration++;
        thinking = false;
        thinkingSide = null;
      }
    } else if (status == GameStatus.playing) {
      _scheduleAutoMove(delay: const Duration(milliseconds: 350));
    }
    _safeNotify();
  }

  /// Lets the player take over one turn in AI-vs-AI mode.
  void toggleManualOverride() {
    if (!isAiVsAi || status.isOver) return;
    if (manualOverride) {
      manualOverride = false;
      _safeNotify();
      _scheduleAutoMove(delay: const Duration(milliseconds: 350));
      return;
    }
    _autoMoveTimer?.cancel();
    if (thinking) {
      _aiGeneration++;
      thinking = false;
      thinkingSide = null;
    }
    paused = false;
    manualOverride = true;
    _safeNotify();
  }

  void undo() {
    if (isOnline) return;
    final wasThinking = thinking;
    _autoMoveTimer?.cancel();
    thinking = false;
    thinkingSide = null;
    hintLoading = false;
    _aiGeneration++;

    if (_fens.length <= 1) {
      _safeNotify();
      return;
    }

    if (isAiVsAi) {
      _popOne();
      paused = true;
      assisted = false;
      manualOverride = false;
    } else if (config.mode == GameMode.twoPlayers) {
      _popOne();
    } else {
      assisted = false;
      if (wasThinking) {
        _popOne();
      } else {
        if (position.side == humanSide && _fens.length > 1) {
          _popOne();
        }
        if (_fens.length > 1 && position.side != humanSide) {
          _popOne();
        }
      }
      while (position.side != humanSide && _fens.length > 1) {
        _popOne();
      }
    }

    if (config.mode == GameMode.ai &&
        !assisted &&
        status == GameStatus.playing &&
        position.side == aiSide) {
      scheduleMicrotask(_startAi);
    }

    _safeNotify();
    _persist();
  }

  void _popOne() {
    if (_fens.length <= 1) return;
    _fens.removeLast();
    if (_moves.isNotEmpty) _moves.removeLast();
    if (_sans.isNotEmpty) _sans.removeLast();
    if (_hashes.isNotEmpty) _hashes.removeLast();
    position = Position.fromFen(_fens.last);
    lastMove = _moves.isEmpty ? null : _moves.last;
    selectedSquare = null;
    selectedMoves = const [];
    promotionMoves = const [];
    hintMove = null;
    aiNote = null;
    _refreshStatus();
  }

  void _refreshStatus() {
    forfeitWinner = null;
    forfeitReason = null;
    final hash = position.hash;
    var repetitions = 0;
    for (final h in _hashes) {
      if (h == hash) repetitions++;
    }
    status = position.computeStatus(repetitions: max(1, repetitions));
    if (status.isOver) {
      thinking = false;
      hintLoading = false;
      thinkingSide = null;
      _autoMoveTimer?.cancel();
    }
  }

  /// Pieces captured by [capturerColor], strongest first.
  List<int> capturedPiecesFor(int capturerColor) {
    const initial = {pawn: 8, knight: 2, bishop: 2, rook: 2, queen: 1};
    final victim = 1 - capturerColor;
    final counts = <int, int>{};
    for (var sq = 0; sq < 64; sq++) {
      final piece = position.pieceAt(sq);
      if (piece != 0 && colorOf(piece) == victim) {
        counts[typeOf(piece)] = (counts[typeOf(piece)] ?? 0) + 1;
      }
    }
    final result = <int>[];
    for (final type in const [queen, rook, bishop, knight, pawn]) {
      final missing = (initial[type] ?? 0) - (counts[type] ?? 0);
      for (var i = 0; i < missing; i++) {
        result.add(makePiece(victim, type));
      }
    }
    return result;
  }

  int get whiteMaterial => position.materialFor(white);
  int get blackMaterial => position.materialFor(black);

  void setSound(bool enabled) {
    AppSound.enabled = enabled;
    unawaited(GameStorage.saveSound(enabled));
    _safeNotify();
  }

  void _persist() {
    if (isOnline) return;
    if (_moves.isEmpty || status.isOver) {
      unawaited(GameStorage.clearGame());
      return;
    }
    unawaited(GameStorage.saveGame(SavedGame(
      config: config,
      fens: List.of(_fens),
      moves: List.of(_moves),
      sans: List.of(_sans),
      savedAt: DateTime.now(),
    )));
  }

  void _safeNotify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _aiGeneration++;
    _autoMoveTimer?.cancel();
    super.dispose();
  }
}
