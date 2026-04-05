import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import 'export_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
    });
  }

  Future<void> _toggleNotifications(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', val);
    setState(() {
      _notificationsEnabled = val;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: const Icon(Icons.picture_as_pdf, color: AppTheme.primaryAccent),
            title: const Text('Export Report', style: TextStyle(color: AppTheme.textWhite)),
            trailing: const Icon(Icons.chevron_right, color: AppTheme.textMuted),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ExportScreen()));
            },
          ),
          const Divider(color: Colors.white12),
          SwitchListTile(
            secondary: const Icon(Icons.notifications, color: AppTheme.primaryAccent),
            title: const Text('Budget Alerts', style: TextStyle(color: AppTheme.textWhite)),
            subtitle: const Text('Get notified when limits reach 80% and 100%', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
            value: _notificationsEnabled,
            onChanged: _toggleNotifications,
            activeColor: AppTheme.primaryAccent,
          ),
          const Divider(color: Colors.white12),
          const ListTile(
            leading: Icon(Icons.info_outline, color: AppTheme.primaryAccent),
            title: Text('App Version', style: TextStyle(color: AppTheme.textWhite)),
            trailing: Text('BudgetBuddy v1.0.0', style: TextStyle(color: AppTheme.textMuted)),
          ),
        ],
      ),
    );
  }
}
