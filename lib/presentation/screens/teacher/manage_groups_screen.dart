import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class ManageGroupsScreen extends StatelessWidget {
  const ManageGroupsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Groups'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Text('List of clubs and groups will be here.'),
      ),
    );
  }
}
