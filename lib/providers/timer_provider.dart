import 'dart:async';
import 'package:flutter/material.dart';
import '../services/fcm_service.dart';

enum TimerState { idle, studying, onBreak, paused }
enum TimerMode { stopwatch, countdown, pomodoro }

class TimerProvider extends ChangeNotifier {
  TimerState _state = TimerState.idle;
  TimerMode _mode = TimerMode.stopwatch;
  Timer? _timer;

  int _secondsElapsed = 0;
  int _pomodoroSecondsLeft = 25 * 60;
  int _pomodoroRound = 0;
  int _completedPomodoros = 0;

  // Countdown timer specific properties
  int _countdownSecondsLeft = 0;
  int _initialCountdownSeconds = 0;

  String? _currentSubjectId;
  String? _currentSubjectName;
  DateTime? _sessionStartTime;

  int studyDurationMinutes = 25;
  int shortBreakMinutes = 5;
  int longBreakMinutes = 15;
  int roundsBeforeLongBreak = 4;

  // ── Getters ──────────────────────────────────────────────

  TimerState get state => _state;
  TimerMode get mode => _mode;
  int get secondsElapsed => _secondsElapsed;
  int get pomodoroSecondsLeft => _pomodoroSecondsLeft;
  int get countdownSecondsLeft => _countdownSecondsLeft;
  int get pomodoroRound => _pomodoroRound;
  int get completedPomodoros => _completedPomodoros;
  String? get currentSubjectId => _currentSubjectId;
  String? get currentSubjectName => _currentSubjectName;
  DateTime? get sessionStartTime => _sessionStartTime;

  // Checks if timer is actively running
  bool get isRunning =>
      _state == TimerState.studying || _state == TimerState.onBreak;

  // Formatted display time
  String get formattedTime {
    if (_mode == TimerMode.pomodoro) {
      final mins = _pomodoroSecondsLeft ~/ 60;
      final secs = _pomodoroSecondsLeft % 60;
      return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    } else if (_mode == TimerMode.countdown) {
      final mins = _countdownSecondsLeft ~/ 60;
      final secs = _countdownSecondsLeft % 60;
      return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    
    final hours = _secondsElapsed ~/ 3600;
    final mins  = (_secondsElapsed % 3600) ~/ 60;
    final secs  = _secondsElapsed % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
             '${mins.toString().padLeft(2, '0')}:'
             '${secs.toString().padLeft(2, '0')}';
    }
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  // Progress for timer dial (0.0 to 1.0)
  double get timerProgress {
    if (_mode == TimerMode.pomodoro) {
      final total = _state == TimerState.onBreak
          ? _getBreakDuration() * 60
          : studyDurationMinutes * 60;
      if (total == 0) return 0;
      return 1 - (_pomodoroSecondsLeft / total);
    } else if (_mode == TimerMode.countdown) {
      if (_initialCountdownSeconds == 0) return 0;
      return 1 - (_countdownSecondsLeft / _initialCountdownSeconds);
    }
    // For stopwatch, return progress of current minute
    return (_secondsElapsed % 60) / 60;
  }

  // ── Controls ─────────────────────────────────────────────

  void startStudying(String subjectId, String subjectName) {
    _currentSubjectId = subjectId;
    _currentSubjectName = subjectName;
    _sessionStartTime = DateTime.now();
    _secondsElapsed = 0;
    _state = TimerState.studying;

    if (_mode == TimerMode.pomodoro) {
      _pomodoroSecondsLeft = studyDurationMinutes * 60;
    } else if (_mode == TimerMode.countdown) {
      if (_countdownSecondsLeft == 0) {
        _countdownSecondsLeft = 25 * 60; // default 25 mins
        _initialCountdownSeconds = 25 * 60;
      }
    }

    _startTick();
    notifyListeners();
  }

  void setCountdownDuration(int minutes) {
    if (isRunning) return;
    _countdownSecondsLeft = minutes * 60;
    _initialCountdownSeconds = minutes * 60;
    notifyListeners();
  }

  void customizePomodoro({
    required int focusMins,
    required int shortBreakMins,
    required int longBreakMins,
    required int rounds,
  }) {
    studyDurationMinutes = focusMins;
    shortBreakMinutes = shortBreakMins;
    longBreakMinutes = longBreakMins;
    roundsBeforeLongBreak = rounds;
    
    if (_mode == TimerMode.pomodoro && _state == TimerState.idle) {
      _pomodoroSecondsLeft = studyDurationMinutes * 60;
    }
    notifyListeners();
  }

  void pauseResume() {
    if (_state == TimerState.paused) {
      _state = TimerState.studying;
      _startTick();
    } else if (_state == TimerState.studying || _state == TimerState.onBreak) {
      _state = TimerState.paused;
      _timer?.cancel();
    }
    notifyListeners();
  }

  int stopAndGetDuration() {
    _timer?.cancel();
    int minutes = 0;
    if (_mode == TimerMode.countdown) {
      minutes = (_initialCountdownSeconds - _countdownSecondsLeft) ~/ 60;
    } else {
      minutes = _secondsElapsed ~/ 60;
    }
    
    _state = TimerState.idle;
    _secondsElapsed = 0;
    _pomodoroRound = 0;
    _pomodoroSecondsLeft = studyDurationMinutes * 60;
    _countdownSecondsLeft = _initialCountdownSeconds;
    _currentSubjectId = null;
    _currentSubjectName = null;
    notifyListeners();
    return minutes;
  }

  void setMode(TimerMode newMode) {
    if (isRunning) return;
    _mode = newMode;
    if (newMode == TimerMode.pomodoro) {
      _pomodoroSecondsLeft = studyDurationMinutes * 60;
    } else if (newMode == TimerMode.countdown) {
      _countdownSecondsLeft = _initialCountdownSeconds > 0 ? _initialCountdownSeconds : 25 * 60;
    }
    notifyListeners();
  }

  void skipBreak() {
    if (_state != TimerState.onBreak) return;
    _state = TimerState.studying;
    _pomodoroSecondsLeft = studyDurationMinutes * 60;
    notifyListeners();
  }

  // ── Internal Timer ────────────────────────────────────────

  void _startTick() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_mode == TimerMode.pomodoro) {
        _tickPomodoro();
      } else if (_mode == TimerMode.countdown) {
        _tickCountdown();
      } else {
        _secondsElapsed++;
      }
      notifyListeners();
    });
  }

  void _tickCountdown() {
    if (_countdownSecondsLeft > 0) {
      _countdownSecondsLeft--;
      _secondsElapsed++;
    } else {
      _timer?.cancel();
      _state = TimerState.idle;
      FCMService().triggerTimerNotification(
        title: 'Countdown Complete! ⏰',
        body: 'Well done! Your countdown study timer has finished.',
      );
    }
  }

  void _tickPomodoro() {
    if (_pomodoroSecondsLeft > 0) {
      _pomodoroSecondsLeft--;
      if (_state == TimerState.studying) {
        _secondsElapsed++;
      }
    } else {
      _handlePomodoroPhaseEnd();
    }
  }

  void _handlePomodoroPhaseEnd() {
    if (_state == TimerState.studying) {
      _pomodoroRound++;
      _completedPomodoros++;
      _state = TimerState.onBreak;
      _pomodoroSecondsLeft = _getBreakDuration() * 60;
      FCMService().triggerTimerNotification(
        title: 'Study Session Finished! 🍅',
        body: 'Time for a break! Take a ${_getBreakDuration()} minute rest.',
      );
    } else {
      _state = TimerState.studying;
      _pomodoroSecondsLeft = studyDurationMinutes * 60;
      FCMService().triggerTimerNotification(
        title: 'Break Over! 📚',
        body: 'Time to focus again. Get ready to study!',
      );
    }
    notifyListeners();
  }

  int _getBreakDuration() {
    return (_pomodoroRound % roundsBeforeLongBreak == 0)
        ? longBreakMinutes
        : shortBreakMinutes;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}