
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
