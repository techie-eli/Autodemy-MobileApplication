import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../widgets/custom_widgets.dart';
import '../../widgets/bottom_nav_shell.dart';
import '../attendance/live_attendance.dart';
import '../auth/login_screen.dart';
import '../reports/report_module.dart';
import '../profile/profile_screen.dart';
import '../calendar/calendar_screen.dart';
import 'create_event_screen.dart';
import 'sections_screen.dart';
import 'attendance_history_screen.dart';
import 'attendance_hub_screen.dart';
import 'teacher_concerns_screen.dart';
import 'teacher_analytics_screen.dart';
import '../../../data/services/api_service.dart';
import '../../../data/app_data.dart';
import '../../../data/models/student_model.dart';

class TeacherHomeScreen extends StatefulWidget {
  final String teacherId;
  final String teacherName;

  const TeacherHomeScreen({
    super.key,
    required this.teacherId,
    required this.teacherName,
  });

  @override
  State<TeacherHomeScreen> createState() => _TeacherHomeScreenState();
}

class _TeacherHomeScreenState extends State<TeacherHomeScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _subjects = {};

  @override
  void initState() {
    super.initState();
    _fetchTeacherData();
  }

  Future<void> _fetchTeacherData() async {
    try {
      // Fetch in background without blocking the whole UI with a spinner
      final sections = await ApiService.getSections().timeout(const Duration(seconds: 10));
      
      final Map<String, dynamic> subjectMap = {};
      for (var s in sections) {
        // The backend already filters by teacher, but we can do a safety check if needed
        final subject = s['subject'] ?? 'Unknown Subject';
        if (!subjectMap.containsKey(subject)) {
          subjectMap[subject] = [];
        }
        subjectMap[subject].add(s['sectionName']);
      }

      if (mounted) {
        setState(() {
          _subjects = subjectMap;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Fetch Teacher Data Error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavShell(
      header: CustomHeader(
        title: 'TEACHER PANEL',
        subtitle: 'Hi, ${widget.teacherName}!',
        userRole: 'TEACHER',
      ),
      labels: const ['Home', 'Concerns', 'Calendar', 'Profile'],
      icons: const [
        Icons.dashboard_rounded,
        Icons.support_agent_rounded,
        Icons.calendar_month_rounded,
        Icons.person_rounded,
      ],
      pages: [
        // ─── TAB 0: HOME ──────────────────────────────────────────────
        _buildHomePage(),
        // ─── TAB 1: CONCERNS ──────────────────────────────────────────
        const TeacherConcernsScreen(),
        // ─── TAB 2: CALENDAR ──────────────────────────────────────────
        const CalendarScreen(embedded: true),
        // ─── TAB 3: PROFILE ───────────────────────────────────────────
        ProfileScreen(
          userName: widget.teacherName,
          userRole: 'Teacher',
          embedded: true,
        ),
      ],
    );
  }

  Widget _buildHomePage() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
      children: [
        _buildSectionTitle('ATTENDANCE SYSTEM'),
        ActionCard(
          icon: Icons.fact_check_rounded,
          title: 'Attendance Portal',
          subtitle: 'New Session or View History',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AttendanceHubScreen(teacherId: widget.teacherId)),
          ),
          iconColor: AppTheme.primary,
        ),
        const SizedBox(height: 24),
        _buildSectionTitle('EVENTS & ANNOUNCEMENTS'),
        ActionCard(
          icon: Icons.event_available_rounded,
          title: 'Make New Event',
          subtitle: 'Create special school events',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateEventScreen())),
          iconColor: AppTheme.accent,
        ),
        const SizedBox(height: 24),
        _buildSectionTitle('SETTINGS & SYNC'),
        ActionCard(
          icon: Icons.sync_rounded,
          title: 'Synchronize Logs',
          subtitle: 'Sync local data with cloud',
          onTap: () async {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Synchronizing students and sections...')),
            );
            
            try {
              final students = await ApiService.getAllUsers(); // Assuming this returns all, or filter for students
              final sections = await ApiService.getSections();
              
              setState(() {
                AppData.students = students
                  .where((u) => u['role'] == 'STUDENT')
                  .map((u) => Student.fromMap(u))
                  .toList();
                // Add mapping for AppData.sections if needed
              });

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Synchronization complete!'), backgroundColor: Colors.green),
                );
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Sync failed: $e'), backgroundColor: Colors.red),
                );
              }
            }
          },
          iconColor: Colors.orange,
        ),
        const SizedBox(height: 24),

      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: AppTheme.textSecondary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  void _showSelectSubjectSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Select Subject',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 24),
            if (_subjects.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text('No subjects assigned to you.',
                    style: TextStyle(color: Colors.grey)),
              )
            else
              ..._subjects.keys.map((subjectCode) => ListTile(
                    leading: const Icon(Icons.class_rounded,
                        color: AppTheme.primary),
                    title: Text(subjectCode,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LiveAttendanceScreen(
                            targetName: subjectCode,
                            isEvent: false,
                            teacherId: widget.teacherId,
                          ),
                        ),
                      );
                    },
                  )),
          ],
        ),
      ),
    );
  }
}