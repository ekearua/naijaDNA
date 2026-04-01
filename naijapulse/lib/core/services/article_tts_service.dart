import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

enum ArticleTtsPlaybackState { idle, loading, playing, paused, error }

class ArticleTtsService extends ChangeNotifier {
  ArticleTtsService() {
    _tts.setStartHandler(() {
      _state = ArticleTtsPlaybackState.playing;
      _errorMessage = null;
      notifyListeners();
    });
    _tts.setCompletionHandler(() {
      unawaited(_handleParagraphCompletion());
    });
    _tts.setCancelHandler(() {
      _state = ArticleTtsPlaybackState.idle;
      _errorMessage = null;
      notifyListeners();
    });
    _tts.setPauseHandler(() {
      _state = ArticleTtsPlaybackState.paused;
      _errorMessage = null;
      notifyListeners();
    });
    _tts.setErrorHandler((message) {
      _state = ArticleTtsPlaybackState.error;
      _errorMessage = message;
      notifyListeners();
    });
    _tts.setProgressHandler((text, start, end, word) {
      if (_currentParagraphIndex < 0 ||
          _currentParagraphIndex >= _paragraphs.length) {
        return;
      }
      final paragraph = _paragraphs[_currentParagraphIndex];
      final overallOffset = (_currentSegmentStartOffset + end).clamp(
        0,
        paragraph.length,
      );
      _currentCharacterOffset = overallOffset;
      _currentParagraphProgress = paragraph.isEmpty
          ? 0
          : overallOffset / paragraph.length;
      notifyListeners();
    });
  }

  final FlutterTts _tts = FlutterTts();

  ArticleTtsPlaybackState _state = ArticleTtsPlaybackState.idle;
  String? _errorMessage;
  List<String> _paragraphs = const <String>[];
  int _currentParagraphIndex = -1;
  int _currentCharacterOffset = 0;
  int _currentSegmentStartOffset = 0;
  double _currentParagraphProgress = 0;
  bool _pauseRequested = false;
  bool _stopRequested = false;

  ArticleTtsPlaybackState get state => _state;
  String? get errorMessage => _errorMessage;
  int get currentParagraphIndex => _currentParagraphIndex;
  double get currentParagraphProgress => _currentParagraphProgress.clamp(0, 1);
  List<String> get paragraphs => List.unmodifiable(_paragraphs);
  bool get isSpeaking =>
      _state == ArticleTtsPlaybackState.playing ||
      _state == ArticleTtsPlaybackState.loading;

  Future<void> speakParagraphs(List<String> paragraphs) async {
    final normalizedParagraphs = paragraphs
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    if (normalizedParagraphs.isEmpty) {
      _state = ArticleTtsPlaybackState.error;
      _errorMessage = 'No readable text is available for this story yet.';
      notifyListeners();
      return;
    }

    _paragraphs = normalizedParagraphs;
    _currentParagraphIndex = 0;
    _currentCharacterOffset = 0;
    _currentSegmentStartOffset = 0;
    _currentParagraphProgress = 0;
    _pauseRequested = false;
    _stopRequested = false;
    _state = ArticleTtsPlaybackState.loading;
    _errorMessage = null;
    notifyListeners();

    await _tts.awaitSpeakCompletion(true);
    await _tts.setSpeechRate(0.47);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);
    await _tts.stop();
    await _speakParagraphAt(0);
  }

  Future<void> pause() async {
    if (_state != ArticleTtsPlaybackState.playing &&
        _state != ArticleTtsPlaybackState.loading) {
      return;
    }
    _pauseRequested = true;
    await _tts.pause();
    _state = ArticleTtsPlaybackState.paused;
    notifyListeners();
  }

  Future<void> resume() async {
    if (_paragraphs.isEmpty || _currentParagraphIndex < 0) {
      _state = ArticleTtsPlaybackState.error;
      _errorMessage = 'No previous article audio is available to restart.';
      notifyListeners();
      return;
    }

    _pauseRequested = false;
    _stopRequested = false;
    await _tts.awaitSpeakCompletion(true);
    await _speakParagraphAt(
      _currentParagraphIndex,
      startOffset: _currentCharacterOffset,
    );
  }

  Future<void> stop() async {
    _stopRequested = true;
    await _tts.stop();
    _paragraphs = const <String>[];
    _currentParagraphIndex = -1;
    _currentCharacterOffset = 0;
    _currentSegmentStartOffset = 0;
    _currentParagraphProgress = 0;
    _state = ArticleTtsPlaybackState.idle;
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> _handleParagraphCompletion() async {
    if (_stopRequested || _pauseRequested) {
      return;
    }
    final nextIndex = _currentParagraphIndex + 1;
    if (nextIndex >= _paragraphs.length) {
      _state = ArticleTtsPlaybackState.idle;
      _errorMessage = null;
      _currentParagraphProgress = 1;
      notifyListeners();
      return;
    }
    await _speakParagraphAt(nextIndex);
  }

  Future<void> _speakParagraphAt(int index, {int startOffset = 0}) async {
    if (index < 0 || index >= _paragraphs.length) {
      return;
    }

    final paragraph = _paragraphs[index];
    final resolvedStartOffset = _resolveResumeOffset(paragraph, startOffset);
    final segment = paragraph.substring(resolvedStartOffset).trimLeft();
    if (segment.isEmpty) {
      await _handleParagraphCompletion();
      return;
    }

    _currentParagraphIndex = index;
    _currentSegmentStartOffset = resolvedStartOffset;
    _currentCharacterOffset = resolvedStartOffset;
    _currentParagraphProgress = paragraph.isEmpty
        ? 0
        : resolvedStartOffset / paragraph.length;
    _state = ArticleTtsPlaybackState.loading;
    _errorMessage = null;
    notifyListeners();
    await _tts.speak(segment);
  }

  int _resolveResumeOffset(String paragraph, int requestedOffset) {
    if (requestedOffset <= 0) {
      return 0;
    }
    if (requestedOffset >= paragraph.length - 1) {
      return paragraph.length - 1;
    }

    final safeOffset = requestedOffset.clamp(0, paragraph.length - 1);
    final candidates = <int>[
      paragraph.lastIndexOf('. ', safeOffset),
      paragraph.lastIndexOf('! ', safeOffset),
      paragraph.lastIndexOf('? ', safeOffset),
      paragraph.lastIndexOf('; ', safeOffset),
      paragraph.lastIndexOf(', ', safeOffset),
    ]..removeWhere((index) => index < 0);

    if (candidates.isEmpty) {
      final whitespaceOffset = paragraph.lastIndexOf(' ', safeOffset);
      return whitespaceOffset > 0 ? whitespaceOffset + 1 : safeOffset;
    }

    final best = candidates.reduce((a, b) => a > b ? a : b);
    return (best + 2).clamp(0, paragraph.length - 1);
  }
}
