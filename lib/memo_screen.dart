
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MemoScreen extends StatefulWidget {
  final DateTime? selectedDate;

  const MemoScreen({super.key, this.selectedDate});

  @override
  MemoScreenState createState() => MemoScreenState();
}

class MemoScreenState extends State<MemoScreen> {
  final TextEditingController _controller = TextEditingController();
  late SharedPreferences _prefs;
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = widget.selectedDate ?? DateTime.now();
    _loadMemo();
  }

  Future<void> _loadMemo() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      _controller.text = _prefs.getString(_selectedDay.toString()) ?? '';
    });
  }

  Future<void> _saveMemo(String text) async {
    await _prefs.setString(_selectedDay.toString(), text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${_selectedDay.month}/${_selectedDay.day}'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: TextField(
          controller: _controller,
          maxLines: null,
          expands: true,
          decoration: const InputDecoration(
            hintText: 'メモを入力',
            border: InputBorder.none,
          ),
          onChanged: _saveMemo,
        ),
      ),
    );
  }
}
