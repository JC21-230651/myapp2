
import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

class EventEditScreen extends StatefulWidget {
  final Event? event;
  final Calendar calendar;
  final DateTime? selectedDate;

  const EventEditScreen({
    super.key,
    this.event,
    required this.calendar,
    this.selectedDate,
  });

  @override
  EventEditScreenState createState() => EventEditScreenState();
}

class EventEditScreenState extends State<EventEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  late DateTime _startDate;
  late TimeOfDay _startTime;
  late DateTime _endDate;
  late TimeOfDay _endTime;
  bool _allDay = false;

  final DeviceCalendarPlugin _deviceCalendarPlugin = DeviceCalendarPlugin();

  @override
  void initState() {
    super.initState();
    if (widget.event != null) {
      _titleController.text = widget.event!.title ?? '';
      _descriptionController.text = widget.event!.description ?? '';
      _startDate = widget.event!.start!.toLocal();
      _endDate = widget.event!.end!.toLocal();
      _allDay = widget.event!.allDay ?? false;
    } else {
      final now = widget.selectedDate ?? DateTime.now();
      _startDate = now;
      _endDate = now.add(const Duration(hours: 1));
      _allDay = false;
    }
    _startTime = TimeOfDay.fromDateTime(_startDate);
    _endTime = TimeOfDay.fromDateTime(_endDate);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.event == null ? '予定の追加' : '予定の編集'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _saveEvent,
          ),
          if (widget.event != null)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _deleteEvent,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'タイトル',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'タイトルを入力してください';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              SwitchListTile(
                title: const Text('終日'),
                value: _allDay,
                onChanged: (bool value) {
                  setState(() {
                    _allDay = value;
                  });
                },
                activeThumbColor: Colors.teal,
              ),
              const SizedBox(height: 10),
              _buildDateTimePicker('開始', _startDate, _startTime, (date, time) {
                setState(() {
                  _startDate = date;
                  _startTime = time;
                  if (_startDate.isAfter(_endDate)) {
                    _endDate = _startDate;
                    _endTime = _startTime;
                  }
                });
              }),
              const SizedBox(height: 20),
              _buildDateTimePicker('終了', _endDate, _endTime, (date, time) {
                setState(() {
                  _endDate = date;
                  _endTime = time;
                });
              }),
              const SizedBox(height: 20),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: '説明',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 4,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateTimePicker(String label, DateTime date, TimeOfDay time,
      Function(DateTime, TimeOfDay) onConfirm) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            Expanded(
              flex: 2,
              child: InkWell(
                onTap: () async {
                  final newDate = await showDatePicker(
                    context: context,
                    initialDate: date,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (newDate != null) {
                    onConfirm(newDate, time);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(DateFormat('yyyy/MM/dd').format(date)),
                ),
              ),
            ),
            if (!_allDay) const SizedBox(width: 10),
            if (!_allDay)
              Expanded(
                flex: 1,
                child: InkWell(
                  onTap: () async {
                    final newTime = await showTimePicker(
                      context: context,
                      initialTime: time,
                    );
                    if (newTime != null) {
                      onConfirm(date, newTime);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(time.format(context)),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _saveEvent() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final start = _combineDateAndTime(_startDate, _startTime);
    final end = _combineDateAndTime(_endDate, _endTime);

    if (!_allDay && start.isAfter(end)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('終了時刻は開始時刻より後に設定してください。')),
      );
      return;
    }

    final eventToSave = Event(
      widget.calendar.id,
      eventId: widget.event?.eventId,
      title: _titleController.text,
      description: _descriptionController.text,
      start: tz.TZDateTime.from(start, tz.local),
      end: tz.TZDateTime.from(end, tz.local),
      allDay: _allDay,
    );

    final result = await _deviceCalendarPlugin.createOrUpdateEvent(eventToSave);
    if (!mounted) return;
    if (result?.isSuccess == true) {
      Navigator.pop(context, true); // 変更があったことを通知
    }
  }

  Future<void> _deleteEvent() async {
    if (widget.event?.eventId != null) {
      final result = await _deviceCalendarPlugin.deleteEvent(
        widget.calendar.id!,
        widget.event!.eventId!,
      );
      if (!mounted) return;
      if (result.isSuccess) {
        Navigator.pop(context, true); // 変更があったことを通知
      }
    }
  }

  DateTime _combineDateAndTime(DateTime date, TimeOfDay time) {
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }
}
