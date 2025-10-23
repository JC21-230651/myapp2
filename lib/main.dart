
import 'dart:async';
import 'dart:developer' as developer;

import 'package:device_calendar/device_calendar.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:health/health.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:pedometer/pedometer.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';

import 'event_edit_screen.dart';
import 'firebase_options.dart';
import 'memo_screen.dart';
import 'notification_service.dart';
import 'notification_setting_screen.dart';
import 'register_screen.dart';
import 'task_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (!kIsWeb) {
    final NotificationService notificationService = NotificationService();
    await notificationService.init();
    await notificationService.requestPermissions();
  }

  await initializeDateFormatting('ja_JP', null);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CalendarState()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => HealthState()),
      ],
      child: const MyApp(),
    ),
  );
}

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const MyHomePage(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/memo',
      builder: (context, state) {
        final DateTime? selectedDate = state.extra as DateTime?;
        return MemoScreen(selectedDate: selectedDate);
      },
    ),
    GoRoute(
      path: '/weekly_report',
      builder: (context, state) => const WeeklyReportScreen(),
    ),
    GoRoute(
      path: '/notification_setting',
      builder: (context, state) => const NotificationSettingScreen(),
    ),
    GoRoute(
      path: '/event/edit',
      builder: (context, state) {
        final Map<String, dynamic> args = state.extra as Map<String, dynamic>;
        return EventEditScreen(
          event: args['event'] as Event?,
          calendar: args['calendar'] as Calendar,
          selectedDate: args['selectedDate'] as DateTime?,
        );
      },
    ),
  ],
);

class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  void toggleTheme() {
    _themeMode =
        _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: _router,
      title: 'Calendar & Health App',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        textTheme: GoogleFonts.notoSansJpTextTheme(
          Theme.of(context).textTheme,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
        ),
      ),
      darkTheme: ThemeData.dark().copyWith(
        textTheme: GoogleFonts.notoSansJpTextTheme(
          ThemeData.dark().textTheme,
        ),
        colorScheme: ColorScheme.fromSwatch(
            primarySwatch: Colors.teal, brightness: Brightness.dark),
      ),
      themeMode: Provider.of<ThemeProvider>(context).themeMode,
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  MyHomePageState createState() => MyHomePageState();
}

class MyHomePageState extends State<MyHomePage> {
  int _selectedIndex = 0;

  static const List<Widget> _widgetOptions = <Widget>[
    CalendarScreen(),
    TaskScreen(),
    AddScreen(),
    HealthScreen(),
    MoreScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    if (index == 3) {
      // When tapping on the Health tab, refresh health data.
      context.read<HealthState>().init();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month),
            label: 'カレンダー',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.check_circle_outline),
            label: 'タスク',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.add), label: '追加'),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite_border),
            label: 'ヘルスケア',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.more_horiz), label: 'その他'),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.teal,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}

// A helper for handling calendar permissions securely.
Future<bool> _requestCalendarPermissions(
    DeviceCalendarPlugin deviceCalendarPlugin) async {
  final permissionsGranted = await deviceCalendarPlugin.hasPermissions();
  if (permissionsGranted.isSuccess && permissionsGranted.data == true) {
    return true;
  }

  final requestedPermissions = await deviceCalendarPlugin.requestPermissions();
  return requestedPermissions.isSuccess && requestedPermissions.data == true;
}

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
      final hasPermission =
          await _requestCalendarPermissions(_deviceCalendarPlugin);
      if (!hasPermission) {
        developer.log('Calendar permission denied.', name: 'CalendarState');
        return;
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
        _selectedEvents = _getEventsForDay(_selectedDay!);
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

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final calendarState = Provider.of<CalendarState>(context);

    return Scaffold(
      appBar: AppBar(
        title: _buildCalendarDropdown(context, calendarState),
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
            eventLoader: (day) =>
                calendarState.events[DateTime(day.year, day.month, day.day)] ??
                [],
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
          Expanded(child: _buildEventList(context, calendarState)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateAndEditEvent(context, calendarState, null),
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
              : CalendarFormat.month),
    );
  }

  Widget _buildCalendarDropdown(
      BuildContext context, CalendarState calendarState) {
    if (kIsWeb || calendarState.calendars.isEmpty) {
      return const Text('カレンダー');
    }
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: calendarState.selectedCalendar?.id,
        onChanged: (String? newValue) =>
            calendarState.onCalendarChanged(newValue),
        items:
            calendarState.calendars.map<DropdownMenuItem<String>>((Calendar calendar) {
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

  Widget _buildEventList(BuildContext context, CalendarState calendarState) {
    if (kIsWeb) {
      return const Center(child: Text("カレンダー機能はWeb版では利用できません。"));
    }
    if (calendarState.selectedEvents.isEmpty) {
      return const Center(child: Text('今日の予定はありません'));
    }
    return ListView.builder(
      itemCount: calendarState.selectedEvents.length,
      itemBuilder: (context, index) {
        final event = calendarState.selectedEvents[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: ListTile(
            title: Text(event.title ?? 'タイトルなし'),
            subtitle: Text(event.description ?? ''),
            leading: _buildEventLeading(event),
            onTap: () => _navigateAndEditEvent(context, calendarState, event),
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
      BuildContext context, CalendarState calendarState, Event? event) async {
    if (calendarState.selectedCalendar == null || kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('この機能はWeb版では利用できません。')));
      return;
    }
    final result = await context.push('/event/edit', extra: {
      'event': event,
      'calendar': calendarState.selectedCalendar!,
      'selectedDate': calendarState.selectedDay,
    });

    if (result == true) {
      calendarState.refreshEvents();
    }
  }
}

class AddScreen extends StatefulWidget {
  const AddScreen({super.key});

  @override
  AddScreenState createState() => AddScreenState();
}

class AddScreenState extends State<AddScreen> {
  late SharedPreferences _prefs;
  final _stepsController = TextEditingController();
  final _sleepController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadGoals();
  }

  @override
  void dispose() {
    _stepsController.dispose();
    _sleepController.dispose();
    super.dispose();
  }

  Future<void> _loadGoals() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      _stepsController.text = (_prefs.getInt('stepGoal') ?? 10000).toString();
      _sleepController.text = (_prefs.getInt('sleepGoal') ?? 8).toString();
    });
  }

  Future<void> _saveGoals() async {
    final stepGoal = int.tryParse(_stepsController.text) ?? 10000;
    final sleepGoal = int.tryParse(_sleepController.text) ?? 8;
    await _prefs.setInt('stepGoal', stepGoal);
    await _prefs.setInt('sleepGoal', sleepGoal);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('目標設定')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextField(
                controller: _stepsController,
                decoration: const InputDecoration(
                  labelText: '毎日の目標歩数',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _sleepController,
                decoration: const InputDecoration(
                  labelText: '毎日の目標睡眠時間（時間）',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  _saveGoals();
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('目標を保存しました')));
                  FocusScope.of(context).unfocus();
                },
                child: const Text('保存'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
      _initPedometer();
      await _fetchHealthData();
      await _retrieveTodaysEvents();
      await _fetchWeeklyHealthData();
    }
    notifyListeners();
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
        final yesterday = now.subtract(const Duration(days: 1));
        List<HealthDataPoint> healthData = await _health.getHealthDataFromTypes(
          startTime: yesterday,
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
    if (!await _requestCalendarPermissions(_deviceCalendarPlugin)) {
      developer.log("Calendar permission denied for today's events.",
          name: 'HealthState');
      return;
    }
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

class HealthScreen extends StatelessWidget {
  const HealthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final healthState = Provider.of<HealthState>(context);
    final today = DateFormat('yyyy/M/d E', 'ja_JP').format(DateTime.now());
    final eventText = healthState.todaysEvents.isNotEmpty
        ? healthState.todaysEvents.first.title ?? '今日の予定はありません'
        : '今日の予定はありません';
    final progress = healthState.stepGoal > 0
        ? (healthState.steps / healthState.stepGoal).clamp(0.0, 1.0)
        : 0.0;

    return Scaffold(
      appBar: AppBar(title: const Text('ヘルスケア')),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.teal),
              child: Text(
                'メニュー',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            ListTile(
              title: const Text('今日のデータ'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              title: const Text('週間レポート'),
              onTap: () => context.push('/weekly_report'),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              today,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            if (kIsWeb)
              const Text(
                "ヘルスケア機能はWeb版では利用できません。",
                style: TextStyle(color: Colors.red),
              )
            else ...[
              LinearProgressIndicator(
                value: progress,
                minHeight: 10,
                backgroundColor: Colors.grey[300],
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Icon(Icons.directions_walk, size: 40),
                  const SizedBox(width: 10),
                  Text(
                    '${healthState.steps}歩',
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Text(
                '目標: ${healthState.stepGoal}歩',
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Icon(Icons.bedtime, size: 40),
                  const SizedBox(width: 10),
                  Text(
                    '${healthState.sleepHours.toStringAsFixed(1)}h',
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const Text(
                '睡眠時間',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ],
            const SizedBox(height: 80),
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Image.network('https://i.imgur.com/8x81gdH.png', height: 200),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(204),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.black),
                      ),
                      child: Text(
                        eventText,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('その他')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.notifications_active),
            title: const Text('通知設定'),
            subtitle: const Text('薬の服用時間などを通知します'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              if (kIsWeb) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('この機能はWeb版では利用できません。')),
                );
                return;
              }
              context.push('/notification_setting');
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.person_add),
            title: const Text('会員登録'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              context.push('/register');
            },
          ),
        ],
      ),
    );
  }
}

class WeeklyReportScreen extends StatelessWidget {
  const WeeklyReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final healthState = Provider.of<HealthState>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('週間レポート')),
      body: kIsWeb
          ? const Center(child: Text("週間レポート機能はWeb版では利用できません。"))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildChart('睡眠 (時間)', healthState.sleepData),
                  const SizedBox(height: 40),
                  _buildChart('歩数', healthState.stepsData),
                ],
              ),
            ),
    );
  }

  Widget _buildChart(String title, List<BarChartGroupData> data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 250,
          child: BarChart(
            BarChartData(
              barGroups: data,
              alignment: BarChartAlignment.spaceAround,
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      const style = TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      );
                      final week = ['月', '火', '水', '木', '金', '土', '日'];
                      return SideTitleWidget(
                        axisSide: meta.axisSide,
                        child: Text(week[value.toInt()], style: style),
                      );
                    },
                    reservedSize: 32,
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              borderData: FlBorderData(show: false),
              gridData: const FlGridData(show: true, drawVerticalLine: false),
            ),
          ),
        ),
      ],
    );
  }
}
