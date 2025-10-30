
import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import 'calendar_state.dart';
import 'task_state.dart';

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CalendarState()),
        ChangeNotifierProvider(create: (_) => TaskState()),
      ],
      child: const _CalendarScreenContent(),
    );
  }
}

class _CalendarScreenContent extends StatelessWidget {
  const _CalendarScreenContent();

  @override
  Widget build(BuildContext context) {
    final calendarState = Provider.of<CalendarState>(context);
    final taskState = Provider.of<TaskState>(context);

    return Scaffold(
      appBar: AppBar(
        title: _buildCalendarDropdown(context, calendarState, taskState),
        actions: [
          IconButton(
            icon: const Icon(Icons.today),
            onPressed: () => calendarState.setToday(),
          ),
          _buildFormatButton(calendarState),
        ],
      ),
      body: Column(
        children: [
          TableCalendar<Event>(
            locale: 'ja_JP',
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: calendarState.focusedDay,
            selectedDayPredicate: (day) =>
                isSameDay(calendarState.selectedDay, day),
            calendarFormat: calendarState.calendarFormat,
            eventLoader: (day) {
              final events = calendarState.events[
                      DateTime(day.year, day.month, day.day)] ??
                  [];
              final tasks = taskState.tasks
                  .where((task) => isSameDay(task.start, day))
                  .toList();
              return events + tasks;
            },
            onDaySelected: calendarState.onDaySelected,
            onPageChanged: calendarState.onPageChanged,
            onFormatChanged: calendarState.onFormatChanged,
            calendarStyle: const CalendarStyle(
              todayDecoration: BoxDecoration(
                color: Colors.teal,
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: Colors.orange,
                shape: BoxShape.circle,
              ),
            ),
            headerStyle: const HeaderStyle(
              titleCentered: true,
              formatButtonVisible: false,
            ),
          ),
          const Divider(),
          Expanded(
            child: _buildEventList(context, calendarState, taskState),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () =>
            _navigateAndEditEvent(context, calendarState, taskState, null),
        backgroundColor: Colors.teal,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildFormatButton(CalendarState calendarState) {
    return IconButton(
      icon: Icon(calendarState.calendarFormat == CalendarFormat.month
          ? Icons.view_week_outlined
          : Icons.calendar_month_outlined),
      onPressed: () => calendarState.onFormatChanged(
        calendarState.calendarFormat == CalendarFormat.month
            ? CalendarFormat.week
            : CalendarFormat.month,
      ),
    );
  }

  Widget _buildCalendarDropdown(
    BuildContext context,
    CalendarState calendarState,
    TaskState taskState,
  ) {
    if (kIsWeb || calendarState.calendars.isEmpty) {
      return const Text('カレンダー');
    }
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: calendarState.selectedCalendar?.id,
        onChanged: (String? newValue) {
          calendarState.onCalendarChanged(newValue);
          taskState.fetchTasks();
        },
        items: calendarState.calendars
            .map<DropdownMenuItem<String>>((Calendar calendar) {
          return DropdownMenuItem<String>(
            value: calendar.id,
            child: Text(
              calendar.name ?? 'No Name',
              style: const TextStyle(color: Colors.black87),
            ),
          );
        }).toList(),
        selectedItemBuilder: (BuildContext context) {
          return calendarState.calendars.map<Widget>((Calendar cal) {
            return Center(
              child: Text(
                cal.name ?? '',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList();
        },
        icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
        dropdownColor: Colors.white,
      ),
    );
  }

  Widget _buildEventList(
    BuildContext context,
    CalendarState calendarState,
    TaskState taskState,
  ) {
    if (kIsWeb) {
      return const Center(child: Text("カレンダー機能はWeb版では利用できません。"));
    }
    final selectedEvents = calendarState.selectedEvents;
    final selectedTasks = taskState.tasks
        .where((task) => isSameDay(task.start, calendarState.selectedDay))
        .toList();

    if (selectedEvents.isEmpty && selectedTasks.isEmpty) {
      return const Center(child: Text('今日の予定はありません'));
    }

    final allItems = [...selectedEvents, ...selectedTasks];

    return ListView.builder(
      itemCount: allItems.length,
      itemBuilder: (context, index) {
        final item = allItems[index];
        final isTask = taskState.tasks.contains(item);

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: ListTile(
            title: Text(item.title ?? 'タイトルなし'),
            subtitle: Text(item.description ?? ''),
            leading: _buildEventLeading(item),
            trailing: isTask ? const Icon(Icons.check_circle, color: Colors.green) : null,
            onTap: () =>
                _navigateAndEditEvent(context, calendarState, taskState, item),
          ),
        );
      },
    );
  }

  Widget _buildEventLeading(Event event) {
    if (event.allDay ?? false) {
      return const Icon(Icons.check_box_outline_blank, color: Colors.grey);
    }
    if (event.start == null || event.end == null) return const SizedBox();
    final format = DateFormat('HH:mm');
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(format.format(event.start!.toLocal())),
        Text(format.format(event.end!.toLocal())),
      ],
    );
  }

  void _navigateAndEditEvent(
    BuildContext context,
    CalendarState calendarState,
    TaskState taskState,
    Event? event,
  ) async {
    if (calendarState.selectedCalendar == null || kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('この機能はWeb版では利用できません。')),
      );
      return;
    }
    final result = await context.push(
      '/event/edit',
      extra: {
        'event': event,
        'calendar': calendarState.selectedCalendar!,
        'selectedDate': calendarState.selectedDay,
      },
    );

    if (result == true) {
      await calendarState.refreshEvents();
      await taskState.fetchTasks();
    }
  }
}
