
import 'package:flutter/material.dart';
import 'package:device_calendar/device_calendar.dart';
import 'package:intl/intl.dart';
import './event_edit_screen.dart';

class TaskScreen extends StatefulWidget {
  const TaskScreen({super.key});

  @override
  _TaskScreenState createState() => _TaskScreenState();
}

class _TaskScreenState extends State<TaskScreen> {
  final DeviceCalendarPlugin _deviceCalendarPlugin = DeviceCalendarPlugin();
  Calendar? _selectedCalendar;
  List<Event> _tasks = [];

  @override
  void initState() {
    super.initState();
    _retrieveCalendarAndTasks();
  }

  Future<void> _retrieveCalendarAndTasks() async {
    try {
      var permissionsGranted = await _deviceCalendarPlugin.hasPermissions();
      if (permissionsGranted.isSuccess && !(permissionsGranted.data ?? false)) {
        permissionsGranted = await _deviceCalendarPlugin.requestPermissions();
        if (!permissionsGranted.isSuccess || !(permissionsGranted.data ?? false)) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('カレンダーへのアクセス権限がありません。タスク機能を利用できません。'),
            ));
            return;
        }
      }

      final calendarsResult = await _deviceCalendarPlugin.retrieveCalendars();
      if (calendarsResult.isSuccess && calendarsResult.data != null) {
        final calendars = calendarsResult.data!;
        if (calendars.isNotEmpty) {
          _selectedCalendar = calendars.firstWhere((cal) => cal.isReadOnly == false, orElse: () => calendars.first);
          _fetchTasks();
        }
      }
    } catch (e) {
      print(e);
    }
  }

  Future<void> _fetchTasks() async {
    if (_selectedCalendar == null) return;

    final now = DateTime.now();
    final endOfTime = DateTime(now.year + 5);
    final eventsResult = await _deviceCalendarPlugin.retrieveEvents(
      _selectedCalendar!.id,
      RetrieveEventsParams(startDate: now, endDate: endOfTime),
    );

    if (eventsResult.isSuccess && eventsResult.data != null) {
      setState(() {
        _tasks = eventsResult.data!;
      });
    }
  }

  Future<void> _deleteTask(String eventId) async {
    if (_selectedCalendar?.id == null) return;

    try {
      final result = await _deviceCalendarPlugin.deleteEvent(_selectedCalendar!.id!, eventId);
      if (result.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('タスクを削除しました。')));
        _fetchTasks();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('タスクの削除に失敗しました。')));
      }
    } catch (e) {
      print(e);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('エラーが発生しました: $e')));
    }
  }

  Future<void> _navigateAndEditTask(Event? task) async {
    if (_selectedCalendar == null) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EventEditScreen(
          event: task,
          calendar: _selectedCalendar!,
        ),
      ),
    );

    if (result == true) {
      _fetchTasks();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('タスク一覧'),
      ),
      body: _tasks.isEmpty
          ? const Center(child: Text('タスクはありません。'))
          : ListView.builder(
              itemCount: _tasks.length,
              itemBuilder: (context, index) {
                final task = _tasks[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  child: ListTile(
                    title: Text(task.title ?? 'タイトルなし'),
                    subtitle: Text(task.start != null ? DateFormat('yyyy/MM/dd HH:mm').format(task.start!) : ''),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteTask(task.eventId!),
                    ),
                    onTap: () => _navigateAndEditTask(task),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateAndEditTask(null),
        backgroundColor: Colors.teal,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
