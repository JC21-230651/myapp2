
import 'dart:developer' as developer;

import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/foundation.dart';
import 'package:table_calendar/table_calendar.dart';

class CalendarState with ChangeNotifier {
  final DeviceCalendarPlugin _deviceCalendarPlugin = DeviceCalendarPlugin();

  Calendar? _selectedCalendar;
  Calendar? get selectedCalendar => _selectedCalendar;

  List<Calendar> _calendars = [];
  List<Calendar> get calendars => _calendars;

  Map<DateTime, List<Event>> _events = {};
  Map<DateTime, List<Event>> get events => _events;

  List<Event> _selectedEvents = [];
  List<Event> get selectedEvents => _selectedEvents;

  CalendarFormat _calendarFormat = CalendarFormat.month;
  CalendarFormat get calendarFormat => _calendarFormat;

  DateTime _focusedDay = DateTime.now();
  DateTime get focusedDay => _focusedDay;

  DateTime? _selectedDay;
  DateTime? get selectedDay => _selectedDay;

  CalendarState() {
    _selectedDay = _focusedDay;
    if (!kIsWeb) {
      _retrieveCalendars();
    }
  }

  Future<void> _retrieveCalendars() async {
    try {
      var permissionsGranted = await _deviceCalendarPlugin.hasPermissions();
      if (permissionsGranted.isSuccess && !permissionsGranted.data!) {
        permissionsGranted = await _deviceCalendarPlugin.requestPermissions();
        if (!permissionsGranted.isSuccess || !permissionsGranted.data!) {
          developer.log('Calendar permission denied.', name: 'CalendarState');
          return;
        }
      }

      final calendarsResult = await _deviceCalendarPlugin.retrieveCalendars();
      if (calendarsResult.isSuccess && calendarsResult.data != null) {
        _calendars = calendarsResult.data!;
        if (_calendars.isNotEmpty) {
          _selectedCalendar = _calendars.firstWhere(
            (cal) => cal.isReadOnly != true,
            orElse: () => _calendars.first,
          );
          await _fetchEvents();
        }
        notifyListeners();
      }
    } catch (e, s) {
      developer.log('Error retrieving calendars.',
          name: 'CalendarState', error: e, stackTrace: s);
    }
  }

  Future<void> _fetchEvents([DateTime? start, DateTime? end]) async {
    if (_selectedCalendar == null || kIsWeb) return;

    final startDate =
        start ?? DateTime(_focusedDay.year, _focusedDay.month - 1, 1);
    final endDate = end ?? DateTime(_focusedDay.year, _focusedDay.month + 2, 0);

    try {
      final eventsResult = await _deviceCalendarPlugin.retrieveEvents(
        _selectedCalendar!.id,
        RetrieveEventsParams(startDate: startDate, endDate: endDate),
      );

      if (eventsResult.isSuccess && eventsResult.data != null) {
        final newEvents = <DateTime, List<Event>>{};
        for (final event in eventsResult.data!) {
          if (event.start == null) continue;
          final day =
              DateTime(event.start!.year, event.start!.month, event.start!.day);
          newEvents[day] = [...newEvents[day] ?? [], event];
        }
        _events = newEvents;
        if (_selectedDay != null) {
          _selectedEvents = _getEventsForDay(_selectedDay!);
        }
        notifyListeners();
      }
    } catch (e, s) {
      developer.log('Error fetching events.',
          name: 'CalendarState', error: e, stackTrace: s);
    }
  }

  List<Event> _getEventsForDay(DateTime day) {
    return _events[DateTime(day.year, day.month, day.day)] ?? [];
  }

  void onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      _selectedDay = selectedDay;
      _focusedDay = focusedDay;
      _selectedEvents = _getEventsForDay(selectedDay);
      notifyListeners();
    }
  }

  void onPageChanged(DateTime focusedDay) {
    _focusedDay = focusedDay;
    if (!kIsWeb) {
      _fetchEvents();
    }
  }

  void onFormatChanged(CalendarFormat format) {
    if (_calendarFormat != format) {
      _calendarFormat = format;
      notifyListeners();
    }
  }

  void onCalendarChanged(String? calendarId) {
    if (calendarId != null) {
      _selectedCalendar =
          _calendars.firstWhere((cal) => cal.id == calendarId);
      _fetchEvents();
      notifyListeners();
    }
  }

  void setToday() {
    _focusedDay = DateTime.now();
    _selectedDay = _focusedDay;
    _selectedEvents = _getEventsForDay(_selectedDay!);
    notifyListeners();
  }

  Future<void> refreshEvents() async {
    await _fetchEvents();
  }
}
