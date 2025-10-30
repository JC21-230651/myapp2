
import 'dart:async';
import 'dart:developer' as developer;

import 'package:device_calendar/device_calendar.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:pedometer/pedometer.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HealthState with ChangeNotifier {
  final Health _health = Health();
  final DeviceCalendarPlugin _deviceCalendarPlugin = DeviceCalendarPlugin();

  int _steps = 0;
  int get steps => _steps;

  double _sleepHours = 0.0;
  double get sleepHours => _sleepHours;

  int _stepGoal = 10000;
  int get stepGoal => _stepGoal;

  List<Event> _todaysEvents = [];
  List<Event> get todaysEvents => _todaysEvents;

  StreamSubscription<StepCount>? _stepCountSubscription;

  List<BarChartGroupData> _sleepData = [];
  List<BarChartGroupData> get sleepData => _sleepData;
  List<BarChartGroupData> _stepsData = [];
  List<BarChartGroupData> get stepsData => _stepsData;

  HealthState() {
    init();
  }

  Future<void> init() async {
    await _loadStepGoal();
    if (!kIsWeb) {
      await _requestPermissions();
      _initPedometer();
      await _fetchHealthData();
      await _retrieveTodaysEvents();
      await _fetchWeeklyHealthData();
    }
    notifyListeners();
  }

  Future<void> _requestPermissions() async {
    final types = [
      HealthDataType.STEPS,
      HealthDataType.SLEEP_IN_BED,
    ];
    await _health.requestAuthorization(types);

    final permissionsGranted = await _deviceCalendarPlugin.hasPermissions();
    if (permissionsGranted.isSuccess && permissionsGranted.data == true) {
      return;
    }
    final requestedPermissions = await _deviceCalendarPlugin.requestPermissions();
    if (!requestedPermissions.isSuccess || requestedPermissions.data != true) {
      developer.log("Calendar permission denied for today's events.",
          name: 'HealthState');
    }
  }

  void _initPedometer() {
    _stepCountSubscription?.cancel();
    _stepCountSubscription = Pedometer.stepCountStream.listen((stepCount) {
      _steps = stepCount.steps;
      notifyListeners();
    });
  }

  Future<void> _loadStepGoal() async {
    final prefs = await SharedPreferences.getInstance();
    _stepGoal = prefs.getInt('stepGoal') ?? 10000;
  }

  Future<void> _fetchHealthData() async {
    final types = [HealthDataType.SLEEP_IN_BED];
    if (await _health.requestAuthorization(types)) {
      try {
        final now = DateTime.now();
        final midnight = DateTime(now.year, now.month, now.day);
        List<HealthDataPoint> healthData = await _health.getHealthDataFromTypes(
          startTime: midnight,
          endTime: now,
          types: types,
        );
        double totalSleep = healthData.fold(
            0,
            (sum, data) =>
                sum + (data.value as NumericHealthValue).numericValue.toDouble());
        _sleepHours = totalSleep / 60;
      } catch (e, s) {
        developer.log('Error fetching health data.',
            name: 'HealthState', error: e, stackTrace: s);
      }
    }
  }

  Future<void> _retrieveTodaysEvents() async {
    try {
      final calendarsResult = await _deviceCalendarPlugin.retrieveCalendars();
      if (calendarsResult.isSuccess && calendarsResult.data?.isNotEmpty == true) {
        final calendar = calendarsResult.data!.first;
        final now = DateTime.now();
        final eventsResult = await _deviceCalendarPlugin.retrieveEvents(
          calendar.id!,
          RetrieveEventsParams(
            startDate: DateTime(now.year, now.month, now.day),
            endDate: DateTime(now.year, now.month, now.day, 23, 59),
          ),
        );
        if (eventsResult.isSuccess) {
          _todaysEvents = eventsResult.data ?? [];
        }
      }
    } catch (e, s) {
      developer.log("Error retrieving today's events.",
          name: 'HealthState', error: e, stackTrace: s);
    }
  }

  Future<void> _fetchWeeklyHealthData() async {
    final types = [HealthDataType.SLEEP_IN_BED, HealthDataType.STEPS];
    if (await _health.requestAuthorization(types)) {
      try {
        final now = DateTime.now();
        final sevenDaysAgo = now.subtract(const Duration(days: 7));
        List<HealthDataPoint> healthData = await _health.getHealthDataFromTypes(
          startTime: sevenDaysAgo,
          endTime: now,
          types: types,
        );
        _sleepData = _generateChartData(healthData, HealthDataType.SLEEP_IN_BED);
        _stepsData = _generateChartData(healthData, HealthDataType.STEPS);
      } catch (e, s) {
        developer.log('Error fetching weekly health data.',
            name: 'HealthState', error: e, stackTrace: s);
      }
    }
  }

  List<BarChartGroupData> _generateChartData(
    List<HealthDataPoint> healthData,
    HealthDataType dataType,
  ) {
    List<double> weeklyData = List.filled(7, 0.0);
    for (var data in healthData) {
      if (data.type == dataType) {
        final dayIndex = data.dateFrom.weekday - 1;
        weeklyData[dayIndex] +=
            (data.value as NumericHealthValue).numericValue.toDouble();
      }
    }

    if (dataType == HealthDataType.SLEEP_IN_BED) {
      for (int i = 0; i < weeklyData.length; i++) {
        weeklyData[i] /= 60; // Convert minutes to hours
      }
    }

    return List.generate(7, (index) {
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: weeklyData[index],
            color: dataType == HealthDataType.SLEEP_IN_BED
                ? Colors.lightBlue
                : Colors.orange,
            width: 16,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      );
    });
  }

  @override
  void dispose() {
    _stepCountSubscription?.cancel();
    super.dispose();
  }
}
