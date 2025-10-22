
import 'dart:async';
import 'package:flutter/foundation.dart'; // Import kIsWeb
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:device_calendar/device_calendar.dart';
import 'package:pedometer/pedometer.dart';
import 'package:health/health.dart';
import 'package:fl_chart/fl_chart.dart';
import 'firebase_options.dart';
import './register_screen.dart';
import './memo_screen.dart';
import './task_screen.dart';
import './event_edit_screen.dart';
import './notification_service.dart';
import './notification_setting_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  final NotificationService notificationService = NotificationService();

  // Initialize notifications only on non-web platforms
  if (!kIsWeb) {
    await notificationService.init();
    await notificationService.requestPermissions();
  }

  initializeDateFormatting('ja_JP', null).then((_) => runApp(const MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Calendar & Health App',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
        ),
      ),
      home: const MyHomePage(),
      routes: {
        '/register': (context) => const RegisterScreen(),
        '/memo': (context) => const MemoScreen(),
        '/weekly_report': (context) => const WeeklyReportScreen(),
        '/notification_setting': (context) => const NotificationSettingScreen(),
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _selectedIndex = 0;

  // AddScreen and HealthScreen are now stateful and require keys for updates
  final List<Widget> _widgetOptions = <Widget>[
    const CalendarScreen(),
    const TaskScreen(),
    AddScreen(key: UniqueKey()),
    HealthScreen(key: UniqueKey()),
    const MoreScreen(),
  ];

  void _onItemTapped(int index) {
    // When navigating away from AddScreen, refresh HealthScreen data
    if (_selectedIndex == 2 && index != 2) {
      setState(() {
        _widgetOptions[3] = HealthScreen(key: UniqueKey());
      });
    }
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _widgetOptions,
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
          BottomNavigationBarItem(
            icon: Icon(Icons.add),
            label: '追加',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite_border),
            label: 'ヘルスケア',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.more_horiz),
            label: 'その他',
          ),
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
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  _CalendarScreenState createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final DeviceCalendarPlugin _deviceCalendarPlugin = DeviceCalendarPlugin();
  Calendar? _selectedCalendar;
  List<Calendar> _calendars = [];
  Map<DateTime, List<Event>> _events = {};
  List<Event> _selectedEvents = [];

  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    if (!kIsWeb) {
      _retrieveCalendars();
    }
  }

  Future<void> _retrieveCalendars() async {
    // On web, this function is not called.
    try {
      var permissionsGranted = await _deviceCalendarPlugin.hasPermissions();
      if (permissionsGranted.isSuccess && !(permissionsGranted.data ?? false)) {
        permissionsGranted = await _deviceCalendarPlugin.requestPermissions();
        if (!permissionsGranted.isSuccess || !(permissionsGranted.data ?? false)) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('カレンダーへのアクセス権限がありません。機能を利用するには設定から権限を許可してください。'),
            duration: Duration(seconds: 5),
          ));
          return;
        }
      }

      final calendarsResult = await _deviceCalendarPlugin.retrieveCalendars();
      if (calendarsResult.isSuccess && calendarsResult.data != null) {
        setState(() {
          _calendars = calendarsResult.data!;
          if (_calendars.isNotEmpty) {
            _selectedCalendar = _calendars.firstWhere((cal) => cal.isReadOnly == false, orElse: () => _calendars.first);
            _fetchEvents();
          }
        });
      }
    } catch (e) {
      // print(e);
    }
  }

  Future<void> _fetchEvents([DateTime? start, DateTime? end]) async {
    if (_selectedCalendar == null || kIsWeb) return;

    final startDate = start ?? DateTime(_focusedDay.year, _focusedDay.month - 1, 1);
    final endDate = end ?? DateTime(_focusedDay.year, _focusedDay.month + 2, 0);

    final eventsResult = await _deviceCalendarPlugin.retrieveEvents(
      _selectedCalendar!.id,
      RetrieveEventsParams(startDate: startDate, endDate: endDate),
    );

    if (eventsResult.isSuccess && eventsResult.data != null) {
      final newEvents = <DateTime, List<Event>>{};
      for (final event in eventsResult.data!) {
        if (event.start == null) continue;
        final day = DateTime(event.start!.year, event.start!.month, event.start!.day);
        if (newEvents[day] == null) {
          newEvents[day] = [];
        }
        newEvents[day]!.add(event);
      }
      setState(() {
        _events = newEvents;
        _selectedEvents = _getEventsForDay(_selectedDay!);
      });
    }
  }

  List<Event> _getEventsForDay(DateTime day) {
    if (kIsWeb) return [];
    return _events[DateTime(day.year, day.month, day.day)] ?? [];
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
        _selectedEvents = _getEventsForDay(selectedDay);
      });
    }
  }

  void _onPageChanged(DateTime focusedDay) {
    _focusedDay = focusedDay;
    if (!kIsWeb) {
      _fetchEvents();
    }
  }

  Future<void> _navigateAndEditEvent(Event? event) async {
    if (_selectedCalendar == null || kIsWeb) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('この機能はWeb版では利用できません。'),
        ));
        return;
    }
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EventEditScreen(
          event: event,
          calendar: _selectedCalendar!,
          selectedDate: _selectedDay,
        ),
      ),
    );

    if (result == true) {
      _fetchEvents();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _buildCalendarDropdown(),
        actions: [
          IconButton(icon: const Icon(Icons.today), onPressed: () => setState(() {
            _focusedDay = DateTime.now();
            _selectedDay = _focusedDay;
            _selectedEvents = _getEventsForDay(_selectedDay!);
          })),
          _buildFormatButton(),
        ],
      ),
      body: Column(
        children: [
          TableCalendar<Event>(
            locale: 'ja_JP',
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            calendarFormat: _calendarFormat,
            eventLoader: _getEventsForDay,
            onDaySelected: _onDaySelected,
            onPageChanged: _onPageChanged,
            onFormatChanged: (format) {
              if (_calendarFormat != format) {
                setState(() {
                  _calendarFormat = format;
                });
              }
            },
            calendarStyle: const CalendarStyle(
              todayDecoration: BoxDecoration(color: Colors.teal, shape: BoxShape.circle),
              selectedDecoration: BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
            ),
            headerStyle: const HeaderStyle(titleCentered: true, formatButtonVisible: false),
          ),
          const Divider(),
          Expanded(
            child: _buildEventList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateAndEditEvent(null),
        backgroundColor: Colors.teal,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildFormatButton(){
      if (_calendarFormat == CalendarFormat.month) return IconButton(icon: const Icon(Icons.view_week_outlined), onPressed: ()=>setState(()=>_calendarFormat = CalendarFormat.week));
      if (_calendarFormat == CalendarFormat.week) return IconButton(icon: const Icon(Icons.view_day_outlined), onPressed: ()=>setState(()=>_calendarFormat = CalendarFormat.twoWeeks));
      return IconButton(icon: const Icon(Icons.calendar_month_outlined), onPressed: ()=>setState(()=>_calendarFormat = CalendarFormat.month));
  }

  Widget _buildCalendarDropdown() {
    if (kIsWeb || _calendars.isEmpty) return const Text('カレンダー');
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: _selectedCalendar?.id,
        onChanged: (String? newValue) {
          if (newValue != null) {
            setState(() {
              _selectedCalendar = _calendars.firstWhere((cal) => cal.id == newValue);
              _fetchEvents();
            });
          }
        },
        items: _calendars.map<DropdownMenuItem<String>>((Calendar calendar) {
          return DropdownMenuItem<String>(
            value: calendar.id,
            child: Text(calendar.name ?? 'No Name', style: const TextStyle(color: Colors.black87)),
          );
        }).toList(),
        selectedItemBuilder: (BuildContext context) {
            return _calendars.map<Widget>((Calendar cal) {
              return Center(child: Text(cal.name ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis));
            }).toList();
        },
        icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
        dropdownColor: Colors.white,
      ),
    );
  }

  Widget _buildEventList() {
    if (kIsWeb) {
        return const Center(child: Text("カレンダー機能はWeb版では利用できません。"));
    }
    return ListView.builder(
      itemCount: _selectedEvents.length,
      itemBuilder: (context, index) {
        final event = _selectedEvents[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: ListTile(
            title: Text(event.title ?? 'タイトルなし'),
            subtitle: Text(event.description ?? ''),
            leading: _buildEventLeading(event),
            onTap: () => _navigateAndEditEvent(event),
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
}

class AddScreen extends StatefulWidget {
  const AddScreen({super.key});

  @override
  _AddScreenState createState() => _AddScreenState();
}

class _AddScreenState extends State<AddScreen> {
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
      appBar: AppBar(
        title: const Text('目標設定'),
      ),
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('目標を保存しました')),
                  );
                  // Hide keyboard
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

class HealthScreen extends StatefulWidget {
  const HealthScreen({super.key});

  @override
  _HealthScreenState createState() => _HealthScreenState();
}

class _HealthScreenState extends State<HealthScreen> {
  late Stream<StepCount> _stepCountStream;
  int _steps = 0;
  double _sleepHours = 0.0;
  int _stepGoal = 10000;
  List<Event> _todaysEvents = [];
  final Health _health = Health();

  @override
  void initState() {
    super.initState();
    _loadStepGoal();
    if (!kIsWeb) {
      _stepCountStream = Pedometer.stepCountStream;
      _stepCountStream.listen((stepCount) {
        if (mounted) {
          setState(() {
            _steps = stepCount.steps;
          });
        }
      });
      _fetchHealthData();
      _retrieveTodaysEvents();
    }
  }
  
  Future<void> _loadStepGoal() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
        setState(() {
            _stepGoal = prefs.getInt('stepGoal') ?? 10000;
        });
    }
  }

  Future<void> _fetchHealthData() async {
    if (kIsWeb) return;
    final types = [HealthDataType.SLEEP_IN_BED];
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));

    await _health.requestAuthorization(types);
    List<HealthDataPoint> healthData = await _health.getHealthDataFromTypes(startTime: yesterday, endTime: now, types: types);
    double totalSleep = 0;
    for (var data in healthData) {
      totalSleep += (data.value as NumericHealthValue).numericValue.toDouble();
    }
    if(mounted){
      setState(() {
        _sleepHours = totalSleep / 60;
      });
    }
  }

  void _retrieveTodaysEvents() async {
    if (kIsWeb) return;
    final deviceCalendarPlugin = DeviceCalendarPlugin();
    var permissionsGranted = await deviceCalendarPlugin.hasPermissions();
    if (permissionsGranted.isSuccess && !(permissionsGranted.data ?? false)) {
      permissionsGranted = await deviceCalendarPlugin.requestPermissions();
      if (!permissionsGranted.isSuccess || !(permissionsGranted.data ?? false)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('カレンダーへのアクセス権限がありません。今日の予定を表示できません。'),
          duration: Duration(seconds: 3),
        ));
        return;
      }
    }

    final calendarsResult = await deviceCalendarPlugin.retrieveCalendars();
    final calendars = calendarsResult.data;
    if (calendars != null && calendars.isNotEmpty) {
      final calendar = calendars.first;
      final now = DateTime.now();
      if (calendar.id != null) {
        final eventsResult = await deviceCalendarPlugin.retrieveEvents(
          calendar.id!,
          RetrieveEventsParams(
            startDate: DateTime(now.year, now.month, now.day),
            endDate: DateTime(now.year, now.month, now.day, 23, 59),
          ),
        );
        if (eventsResult.isSuccess && mounted) {
          setState(() {
            _todaysEvents = eventsResult.data ?? [];
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = DateFormat('yyyy/M/d E', 'ja_JP').format(DateTime.now());
    final eventText = _todaysEvents.isNotEmpty ? _todaysEvents.first.title ?? '今日の予定はありません' : '今日の予定はありません';
    final progress = _stepGoal > 0 ? (_steps / _stepGoal).clamp(0.0, 1.0) : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ヘルスケア'),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.teal,
              ),
              child: Text('メニュー', style: TextStyle(color: Colors.white, fontSize: 24)),
            ),
            ListTile(
              title: const Text('今日のデータ'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('週間レポート'),
              onTap: () {
                Navigator.pushNamed(context, '/weekly_report');
              },
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(today, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            if (kIsWeb) 
                const Text("ヘルスケア機能はWeb版では利用できません。", style: TextStyle(color: Colors.red))
            else ...[
                LinearProgressIndicator(value: progress, minHeight: 10, backgroundColor: Colors.grey[300], valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange)),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Icon(Icons.directions_walk, size: 40),
                    const SizedBox(width: 10),
                    Text('$_steps歩', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold)),
                  ],
                ),
                Text('目標: $_stepGoal歩', style: const TextStyle(fontSize: 16, color: Colors.grey)),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Icon(Icons.bedtime, size: 40),
                    const SizedBox(width: 10),
                    Text('${_sleepHours.toStringAsFixed(1)}h', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold)),
                  ],
                ),
                const Text('睡眠時間', style: TextStyle(fontSize: 16, color: Colors.grey)),
            ],
            const SizedBox(height: 80), // Replaced Spacer
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
                        color: Colors.white.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.black),
                      ),
                      child: Text(eventText, style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20), // Replaced Spacer
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
      appBar: AppBar(
        title: const Text('その他'),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.notifications_active),
            title: const Text('通知設定'),
            subtitle: const Text('薬の服用時間などを通知します'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
                if(kIsWeb) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('この機能はWeb版では利用できません。'),
                    ));
                    return;
                }
              Navigator.pushNamed(context, '/notification_setting');
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.person_add),
            title: const Text('会員登録'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              Navigator.pushNamed(context, '/register');
            },
          ),
        ],
      ),
    );
  }
}

class WeeklyReportScreen extends StatefulWidget {
  const WeeklyReportScreen({super.key});

  @override
  _WeeklyReportScreenState createState() => _WeeklyReportScreenState();
}

class _WeeklyReportScreenState extends State<WeeklyReportScreen> {
  final Health _health = Health();
  List<BarChartGroupData> _sleepData = [];
  List<BarChartGroupData> _stepsData = [];

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _fetchWeeklyHealthData();
    }
  }

  Future<void> _fetchWeeklyHealthData() async {
    if(kIsWeb) return;
    final types = [HealthDataType.SLEEP_IN_BED, HealthDataType.STEPS];
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));

    await _health.requestAuthorization(types);
    List<HealthDataPoint> healthData = await _health.getHealthDataFromTypes(startTime: sevenDaysAgo, endTime: now, types: types);

    if (mounted) {
      setState(() {
        _sleepData = _generateChartData(healthData, HealthDataType.SLEEP_IN_BED);
        _stepsData = _generateChartData(healthData, HealthDataType.STEPS);
      });
    }
  }

  List<BarChartGroupData> _generateChartData(List<HealthDataPoint> healthData, HealthDataType dataType) {
    List<double> weeklyData = List.filled(7, 0.0);
    for (var data in healthData) {
      if (data.type == dataType) {
        final dayIndex = data.dateFrom.weekday - 1;
        weeklyData[dayIndex] += (data.value as NumericHealthValue).numericValue.toDouble();
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
            color: dataType == HealthDataType.SLEEP_IN_BED ? Colors.lightBlue : Colors.orange,
            width: 16,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('週間レポート'),
      ),
      body: kIsWeb 
        ? const Center(child: Text("週間レポート機能はWeb版では利用できません。"))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildChart('睡眠 (時間)', _sleepData),
                const SizedBox(height: 40),
                _buildChart('歩数', _stepsData),
              ],
            ),
      ),
    );
  }
  
  Widget _buildChart(String title, List<BarChartGroupData> data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
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
                      const style = TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14);
                      final week = ['月','火','水','木','金','土','日'];
                      return SideTitleWidget(axisSide: meta.axisSide, child: Text(week[value.toInt()], style: style));
                    },
                    reservedSize: 32,
                  ),
                ),
                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
