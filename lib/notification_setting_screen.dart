
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import './notification_service.dart';

class NotificationSettingScreen extends StatefulWidget {
  const NotificationSettingScreen({super.key});

  @override
  _NotificationSettingScreenState createState() =>
      _NotificationSettingScreenState();
}

class _NotificationSettingScreenState extends State<NotificationSettingScreen> {
  TimeOfDay? _selectedTime;
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    _loadSavedTime();
  }

  Future<void> _loadSavedTime() async {
    final prefs = await SharedPreferences.getInstance();
    final hour = prefs.getInt('notification_hour');
    final minute = prefs.getInt('notification_minute');

    if (hour != null && minute != null) {
      setState(() {
        _selectedTime = TimeOfDay(hour: hour, minute: minute);
      });
    }
  }

  Future<void> _saveTime(TimeOfDay time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('notification_hour', time.hour);
    await prefs.setInt('notification_minute', time.minute);
  }

  Future<void> _openTimePicker() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );

    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
      await _saveTime(picked);
      await _notificationService.scheduleDailyNotification(
        id: 0,
        title: 'お薬の時間です',
        body: '忘れずに服用しましょう。',
        time: picked,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('通知を${picked.format(context)}に設定しました')),
      );
    }
  }

  Future<void> _cancelNotification() async {
    await _notificationService.cancelNotification(0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('notification_hour');
    await prefs.remove('notification_minute');
    setState(() {
      _selectedTime = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('通知をキャンセルしました')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('通知設定'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_selectedTime != null)
              Text(
                '設定時刻: ${_selectedTime!.format(context)}',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _openTimePicker,
              child: const Text('通知時刻を設定'),
            ),
            const SizedBox(height: 10),
            if (_selectedTime != null)
              TextButton(
                onPressed: _cancelNotification,
                child: const Text('通知をキャンセル', style: TextStyle(color: Colors.red)),
              ),
          ],
        ),
      ),
    );
  }
}
