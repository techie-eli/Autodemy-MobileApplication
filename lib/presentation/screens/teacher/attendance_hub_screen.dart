import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../widgets/custom_widgets.dart';
import 'sections_screen.dart';
import 'attendance_history_screen.dart';

class AttendanceHubScreen extends StatelessWidget {
  final String teacherId;
  const AttendanceHubScreen({super.key, required this.teacherId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          const CustomHeader(
            title: 'ATTENDANCE SYSTEM',
            subtitle: 'Choose an action to continue',
            showBackButton: true,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 20),
                _buildLargeHubCard(
                  context,
                  title: 'NEW ATTENDANCE',
                  subtitle: 'Start a live session for your sections',
                  icon: Icons.add_task_rounded,
                  color: AppTheme.accent,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => SectionsScreen(teacherId: teacherId)),
                  ),
                ),
                const SizedBox(height: 24),
                _buildLargeHubCard(
                  context,
                  title: 'PREVIOUS ATTENDANCE',
                  subtitle: 'View and download past records',
                  icon: Icons.history_rounded,
                  color: Colors.white,
                  textColor: AppTheme.primary,
                  isOutlined: true,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => AttendanceHistoryScreen(teacherId: teacherId)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLargeHubCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    Color textColor = AppTheme.primary,
    bool isOutlined = false,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 150,
        decoration: BoxDecoration(
          color: isOutlined ? Colors.white : color,
          borderRadius: BorderRadius.circular(32),
          border: isOutlined ? Border.all(color: AppTheme.primary.withOpacity(0.2), width: 2) : null,
          boxShadow: [
            BoxShadow(
              color: (isOutlined ? Colors.black : color).withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -15,
              bottom: -15,
              child: Icon(
                icon,
                size: 100,
                color: (isOutlined ? AppTheme.primary : Colors.white).withOpacity(0.1),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: isOutlined ? AppTheme.primary : AppTheme.primary, size: 36),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    style: TextStyle(
                      color: isOutlined ? AppTheme.primary : AppTheme.primary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: (isOutlined ? AppTheme.primary : AppTheme.primary).withOpacity(0.6),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
