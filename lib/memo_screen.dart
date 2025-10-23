
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MemoScreen extends StatefulWidget {
  const MemoScreen({super.key});

  @override
  MemoScreenState createState() => MemoScreenState();
}

class MemoScreenState extends State<MemoScreen> {
  final TextEditingController _controller = TextEditingController();
  late SharedPreferences _prefs;
  late DateTime _selectedDay;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // retrieve the selected day from the arguments
    final Object? arguments = ModalRoute.of(context)!.settings.arguments;
    if (arguments is DateTime) {
      _selectedDay = arguments;
    } else {
      // handle the case where the argument is not a DateTime
      // for example, by using the current date
      _selectedDay = DateTime.now();
    }
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
