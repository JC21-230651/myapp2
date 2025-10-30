
import 'dart:developer';
import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/material.dart';

class TaskState with ChangeNotifier {
  final DeviceCalendarPlugin _deviceCalendarPlugin = DeviceCalendarPlugin();
  Calendar? _selectedCalendar;
  List<Event> _tasks = [];

  List<Event> get tasks => _tasks;
  Calendar? get selectedCalendar => _selectedCalendar;

  TaskState() {
    _retrieveCalendarAndTasks();
  }

  Future<void> _retrieveCalendarAndTasks() async {
    try {
      var permissionsGranted = await _deviceCalendarPlugin.hasPermissions();
      if (permissionsGranted.isSuccess && !(permissionsGranted.data ?? false)) {
        permissionsGranted = await _deviceCalendarPlugin.requestPermissions();
        if (!permissionsGranted.isSuccess ||
            !(permissionsGranted.data ?? false)) {
          log('Permissions not granted');
          return;
        }
      }

      final calendarsResult = await _deviceCalendarPlugin.retrieveCalendars();
      if (calendarsResult.isSuccess && calendarsResult.data != null) {
        final calendars = calendarsResult.data!;
        if (calendars.isNotEmpty) {
          _selectedCalendar = calendars.firstWhere(
              (cal) => cal.isReadOnly == false,
              orElse: () => calendars.first);
          await fetchTasks();
        }
      }
    } catch (e, s) {
      log('Error retrieving calendars', error: e, stackTrace: s);
    }
  }

  Future<void> fetchTasks() async {
    if (_selectedCalendar == null) return;

    final now = DateTime.now();
    final endOfTime = DateTime(now.year + 5);
    final eventsResult = await _deviceCalendarPlugin.retrieveEvents(
      _selectedCalendar!.id,
      RetrieveEventsParams(startDate: now, endDate: endOfTime),
    );

    if (eventsResult.isSuccess && eventsResult.data != null) {
      _tasks = eventsResult.data!;
      notifyListeners();
    }
  }

  Future<bool> deleteTask(String? eventId) async {
    if (_selectedCalendar?.id == null || eventId == null) return false;

    try {
      final result =
          await _deviceCalendarPlugin.deleteEvent(_selectedCalendar!.id!, eventId);
      if (result.isSuccess) {
        await fetchTasks();
        return true;
      }
    } catch (e, s) {
      log('Error deleting task', error: e, stackTrace: s);
    }
    return false;
  }
}
