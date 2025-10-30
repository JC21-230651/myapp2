
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'health_state.dart';

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
