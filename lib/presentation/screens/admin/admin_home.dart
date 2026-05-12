import 'package:flutter/material.dart';
import '../../../data/services/api_service.dart';
import '../../../data/app_data.dart';
import '../../../data/models/student_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../widgets/custom_widgets.dart';
import '../../widgets/bottom_nav_shell.dart';
import '../auth/login_screen.dart';
import '../reports/report_module.dart';
import '../profile/profile_screen.dart';
import '../calendar/calendar_screen.dart';
import 'admin_stub_screens.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});
  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  void _showStatus(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppTheme.error : AppTheme.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavShell(
      header: const CustomHeader(
        title: 'ADMIN PANEL',
        subtitle: 'School Management System',
        userRole: 'ADMIN',
      ),
      labels: const ['Home', 'Reports', 'Concerns', 'Calendar', 'Profile'],
      icons: const [
        Icons.dashboard_rounded,
        Icons.assessment_rounded,
        Icons.support_agent_rounded,
        Icons.calendar_month_rounded,
        Icons.person_rounded,
      ],
      pages: [
        // ─── TAB 0: HOME ──────────────────────────────────────────────
        _buildHomePage(),
        // ─── TAB 1: REPORTS ───────────────────────────────────────────
        const ReportModuleScreen(embedded: true, userRole: 'ADMIN'),
        // ─── TAB 2: CONCERNS ──────────────────────────────────────────
        const AdminConcernsScreen(),
        // ─── TAB 3: CALENDAR ──────────────────────────────────────────
        const CalendarScreen(embedded: true, userRole: 'ADMIN'),
        // ─── TAB 4: PROFILE ───────────────────────────────────────────
        const ProfileScreen(
          userName: 'Administrator',
          userRole: 'Admin',
          embedded: true,
        ),
      ],
    );
  }

  Widget _buildHomePage() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
      children: [
        _buildSectionTitle('ACADEMIC MANAGEMENT'),
        ActionCard(
          icon: Icons.calendar_month_rounded,
          title: 'Academic Years',
          subtitle: 'Manage school years and terms',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AcademicYearsScreen())),
          iconColor: Colors.deepOrange,
        ),
        const SizedBox(height: 12),
        _buildSectionTitle('USER ACCOUNT MANAGEMENT'),
        ActionCard(
          icon: Icons.person_add_alt_1_rounded,
          title: 'Teacher Accounts',
          subtitle: 'Manage faculty credentials and roles',
          onTap: () => _manageAccounts("Teacher"),
        ),
        ActionCard(
          icon: Icons.group_add_rounded,
          title: 'Student Accounts',
          subtitle: 'Manage student profiles and enrollment',
          onTap: () => _manageAccounts("Student"),
        ),
        const SizedBox(height: 24),
        _buildSectionTitle('SYSTEM & CONFIGURATION'),
        ActionCard(
          icon: Icons.terminal_rounded,
          title: 'System Logs',
          subtitle: 'Monitor system changes and events',
          onTap: _viewSystemLogs,
          iconColor: Colors.blueGrey,
        ),
        ActionCard(
          icon: Icons.settings_rounded,
          title: 'Global Configuration',
          subtitle: 'Manage system-wide settings',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GlobalConfigScreen())),
        ),
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

  void _manageAccounts(String type) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AccountEntryScreen(userType: type)),
    );
  }

  Widget _buildDialogAction(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      onTap: onTap,
    );
  }

  void _showAddAccountForm(String type) {
    // Use the modern reusable dialog from custom_widgets
    showAddAccountDialog(context, type, onSave: ApiService.addUser)
        .then((created) {
      if (created == true) {
        _showStatus('Account Created!');
      }
    });
  }

  void _viewSystemLogs() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.background,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 24),
            const Text('SYSTEM ACTIVITY LOGS', 
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppTheme.textSecondary, letterSpacing: 1.5)),
            const SizedBox(height: 20),
            Expanded(
              child: FutureBuilder<List<dynamic>>(
                future: ApiService.getSystemLogs(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Text('No activity logs found.'));
                  }
                  
                  final logs = snapshot.data!;
                  return ListView.builder(
                    itemCount: logs.length,
                    itemBuilder: (context, index) {
                      final log = logs[index];
                      final bool isActive = log['isActive'] ?? false;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isActive ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isActive ? Icons.sensors_rounded : Icons.history_rounded,
                                color: isActive ? Colors.green : Colors.grey,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${log['subject']} • ${log['section']}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  Text(
                                    isActive ? 'Currently Active Session' : 'Completed Session',
                                    style: TextStyle(color: isActive ? Colors.green : AppTheme.textSecondary, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              log['records']?.length?.toString() ?? '0',
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppTheme.primary),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}