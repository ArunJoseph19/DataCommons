import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pedometer/pedometer.dart';
import 'package:intl/intl.dart';
import '../../../../core/models/step_record.dart';
import '../../../../core/services/data_repository.dart';
import '../../gps_traces/providers/gps_provider.dart';

/// State for the step counter feature.
class StepCounterState {
  final bool isTracking;
  final int todaySteps;
  final int sessionSteps;
  final List<StepRecord> weeklyRecords;
  final String status; // 'walking', 'stopped', 'unknown'

  const StepCounterState({
    this.isTracking = false,
    this.todaySteps = 0,
    this.sessionSteps = 0,
    this.weeklyRecords = const [],
    this.status = 'unknown',
  });

  StepCounterState copyWith({
    bool? isTracking,
    int? todaySteps,
    int? sessionSteps,
    List<StepRecord>? weeklyRecords,
    String? status,
  }) =>
      StepCounterState(
        isTracking: isTracking ?? this.isTracking,
        todaySteps: todaySteps ?? this.todaySteps,
        sessionSteps: sessionSteps ?? this.sessionSteps,
        weeklyRecords: weeklyRecords ?? this.weeklyRecords,
        status: status ?? this.status,
      );
}

class StepNotifier extends StateNotifier<StepCounterState> {
  final DataRepository _repo;
  StreamSubscription? _stepSub;
  StreamSubscription? _statusSub;
  int? _sessionStartSteps;
  Timer? _saveTimer;

  StepNotifier(this._repo) : super(const StepCounterState()) {
    _loadWeeklyData();
  }

  Future<void> _loadWeeklyData() async {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    final format = DateFormat('yyyy-MM-dd');
    final records = await _repo.getStepRecordsRange(
      format.format(weekAgo),
      format.format(now),
    );
    state = state.copyWith(weeklyRecords: records);

    // Load today's steps
    final todayRecords = await _repo.getStepRecordsByDate(format.format(now));
    if (todayRecords.isNotEmpty) {
      state = state.copyWith(todaySteps: todayRecords.first.sessionSteps);
    }
  }

  /// Start tracking steps.
  void startTracking() {
    _sessionStartSteps = null;

    _stepSub = Pedometer.stepCountStream.listen((event) {
      _sessionStartSteps ??= event.steps;
      final sessionSteps = event.steps - (_sessionStartSteps ?? event.steps);

      state = state.copyWith(
        todaySteps: state.todaySteps + (sessionSteps - state.sessionSteps),
        sessionSteps: sessionSteps,
      );
    });

    _statusSub = Pedometer.pedestrianStatusStream.listen((event) {
      state = state.copyWith(status: event.status);
    });

    // Save to DB every 30 seconds
    _saveTimer = Timer.periodic(const Duration(seconds: 30), (_) => _save());

    state = state.copyWith(isTracking: true, sessionSteps: 0);
  }

  /// Stop tracking.
  void stopTracking() {
    _stepSub?.cancel();
    _stepSub = null;
    _statusSub?.cancel();
    _statusSub = null;
    _saveTimer?.cancel();
    _saveTimer = null;

    _save();

    state = state.copyWith(isTracking: false);
    _loadWeeklyData();
  }

  Future<void> _save() async {
    final now = DateTime.now();
    final date = DateFormat('yyyy-MM-dd').format(now);
    await _repo.insertStepRecord(StepRecord(
      cumulativeSteps: state.todaySteps,
      sessionSteps: state.todaySteps,
      timestamp: now,
      date: date,
    ));
  }

  @override
  void dispose() {
    _stepSub?.cancel();
    _statusSub?.cancel();
    _saveTimer?.cancel();
    super.dispose();
  }
}

final stepProvider = StateNotifierProvider<StepNotifier, StepCounterState>((ref) {
  return StepNotifier(ref.watch(dataRepositoryProvider));
});
