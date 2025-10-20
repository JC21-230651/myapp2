
import 'package:flutter/material.dart';

class MemoScreen extends StatefulWidget {
  const MemoScreen({super.key});

  @override
  _MemoScreenState createState() => _MemoScreenState();
}

class _MemoScreenState extends State<MemoScreen> {
  final _memoController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final selectedDay = ModalRoute.of(context)!.settings.arguments as DateTime?;

    return Scaffold(
      appBar: AppBar(
        title: Text(selectedDay != null
            ? '${selectedDay.year}/${selectedDay.month}/${selectedDay.day}のメモ'
            : 'メモ'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: <Widget>[
            TextField(
              controller: _memoController,
              maxLines: 10,
              decoration: const InputDecoration(
                hintText: 'メモを入力してください',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Here you would save the memo
                Navigator.pop(context);
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }
}
