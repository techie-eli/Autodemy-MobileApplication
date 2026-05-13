import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import '../attendance/student_qr_code_screen.dart';
import '../../../core/theme/app_theme.dart';
import '../../widgets/bottom_nav_shell.dart';
import '../../../data/services/attendance_service.dart';
import 'subject_attendance_screen.dart';
import '../../../data/models/student_model.dart';

class StudentHistoryScreen extends StatelessWidget {
  final Student student;
  final bool embedded;
  final Map<String, dynamic>? sectionInfo;
  final List<dynamic>? history;
  final AttendanceSummary? summary;
  final ActiveSessionInfo? activeSession;

  
  const StudentHistoryScreen({
    super.key, 
    required this.student, 
    this.embedded = false,
    this.summary,
    this.sectionInfo,
    this.history,
    this.activeSession,
  });



  @override
  Widget build(BuildContext context) {
    final topPadding = embedded ? MediaQuery.of(context).padding.top + 24 : 24.0;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: embedded ? Colors.transparent : AppTheme.background,
        appBar: embedded ? PreferredSize(
          preferredSize: Size.fromHeight(topPadding + 60),
          child: Padding(
            padding: EdgeInsets.only(top: topPadding),
            child: const TabBar(
              isScrollable: false,
              labelColor: AppTheme.primary,
              unselectedLabelColor: AppTheme.textSecondary,
              indicatorColor: AppTheme.primary,
              indicatorWeight: 3,
              labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              tabs: [
                Tab(text: 'Attendance'),
                Tab(text: 'My Subjects'),
              ],
            ),
          ),
        ) : AppBar(
          title: const Text('My Records'),
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Attendance'),
              Tab(text: 'Subjects'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildAttendanceTab(context),
            _buildSubjectsTab(context),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceTab(BuildContext context) {
    return StreamBuilder<ActiveSessionInfo?>(
      stream: AttendanceService.streamActiveSession(
        subject: student.subject,
        section: student.section,
      ),
      builder: (context, sessionSnapshot) {
        final activeSession = sessionSnapshot.data;

        return StreamBuilder<LiveStudentRecord?>(
          stream: activeSession == null 
            ? Stream.value(null) 
            : AttendanceService.streamStudentRecord(
                subject: student.subject,
                section: student.section,
                studentName: student.name,
              ),
          builder: (context, recordSnapshot) {
            final liveRecord = recordSnapshot.data;
            
            // 1. Process Historical Records
            final List<Map<String, String>> records = (history ?? []).map((h) {
              DateTime? dt = h['date'] != null ? DateTime.parse(h['date'].toString()).toLocal() : null;
              String dateStr = dt != null ? '${_getMonthName(dt.month)} ${dt.day}, ${dt.year}' : 'Unknown Date';
              
              DateTime? timeDt = h['time'] != null ? DateTime.parse(h['time'].toString()).toLocal() : null;
              String timeStr = timeDt != null 
                  ? '${timeDt.hour % 12 == 0 ? 12 : timeDt.hour % 12}:${timeDt.minute.toString().padLeft(2, '0')} ${timeDt.hour >= 12 ? 'PM' : 'AM'}' 
                  : '--:--';

              return {
                'subject': h['subject']?.toString() ?? 'Unknown',
                'date': dateStr,
                'status': h['status']?.toString().toLowerCase() ?? 'absent',
                'time': timeStr,
              };
            }).toList();

            // 2. Add Active Session to the top if it exists
            if (activeSession != null) {
              final status = liveRecord?.status ?? 'pending';
              final now = DateTime.now();
              
              // Only add if not already in history (to avoid duplicates when session just ended)
              final isAlreadyInHistory = records.any((r) => 
                r['subject'] == activeSession.subject && 
                r['date'] == '${_getMonthName(now.month)} ${now.day}, ${now.year}'
              );

              if (!isAlreadyInHistory) {
                records.insert(0, {
                  'subject': activeSession.subject,
                  'date': '${_getMonthName(now.month)} ${now.day}, ${now.year}',
                  'status': status,
                  'time': liveRecord?.timein ?? '--:--',
                  'isLive': 'true',
                });
              }
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
              children: [
                // ── Recent Records List
                const Text(
                  'RECENT LOGS',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textSecondary,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 16),
                if (records.isEmpty)
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 40),
                        Icon(Icons.history_rounded, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        const Text('No attendance records yet.', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                else
                  ...records.map((r) => _buildRecordTile(r)).toList(),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSubjectsTab(BuildContext context) {
    String profName = 'Assigned Teacher';
    if (sectionInfo != null && sectionInfo!['teacher'] != null) {
      final t = sectionInfo!['teacher'];
      profName = (t is Map) ? (t['name'] ?? 'Assigned Teacher') : t.toString();
    }
    
    final String schedule = (sectionInfo != null && sectionInfo!['schedule'] != null)
        ? sectionInfo!['schedule']
        : student.time.isNotEmpty ? student.time : 'TBA';

    final List<Map<String, String>> subjects = [
      if (student.subject.isNotEmpty)
        {
          'name': student.subject,
          'section': student.section,
          'prof': profName,
          'days': 'Mon - Fri',
          'time': schedule,
        }
    ];


    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
      children: [
        if (activeSession != null) ...[
          _buildActiveSessionPanel(context),
          const SizedBox(height: 24),
        ],


        const Text(
          'ENROLLED SUBJECTS',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppTheme.textSecondary,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 16),
        if (subjects.isEmpty)
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 40),
                Icon(Icons.class_rounded, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                const Text('Not enrolled in any subjects yet.', style: TextStyle(color: Colors.grey)),
              ],
            ),
          )
        else
          ...subjects.map((s) {
            final filteredLogs = (history ?? []).where((h) => h['subject'] == s['name']).map((h) {
              DateTime? dt = h['date'] != null ? DateTime.parse(h['date'].toString()).toLocal() : null;
              String dateStr = dt != null ? '${_getMonthName(dt.month)} ${dt.day}, ${dt.year}' : 'Unknown Date';
              
              DateTime? timeDt = h['time'] != null ? DateTime.parse(h['time'].toString()).toLocal() : null;
              String timeStr = timeDt != null 
                  ? '${timeDt.hour % 12 == 0 ? 12 : timeDt.hour % 12}:${timeDt.minute.toString().padLeft(2, '0')} ${timeDt.hour >= 12 ? 'PM' : 'AM'}' 
                  : '--:--';

              return {
                'date': dateStr,
                'status': h['status']?.toString() ?? 'absent',
                'time': timeStr,
              };
            }).toList();

            return InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SubjectAttendanceScreen(
                    subjectName: s['name']!,
                    section: s['section']!,
                    professor: s['prof']!,
                    logs: filteredLogs,
                  ),
                ),
              ),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.book_rounded, color: AppTheme.primary),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s['name']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textPrimary)),
                            const SizedBox(height: 4),
                            Text('Section: ${s['section']}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                          ],
                        ),
                      ),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('PROFESSOR', style: TextStyle(color: AppTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(
                              s['prof']!, 
                              style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600, fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(height: 1, color: Color(0xFFF5F5F5)),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded, size: 14, color: AppTheme.textSecondary),
                      const SizedBox(width: 8),
                    Text(s['days']!, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                    const Spacer(),
                    const Icon(Icons.access_time_rounded, size: 14, color: AppTheme.textSecondary),
                    const SizedBox(width: 8),
                    Text(s['time']!, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    ],
  );
}

  Widget _buildActiveSessionPanel(BuildContext context) {
    if (activeSession == null) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primary, Color(0xFF3F51B5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'ACTIVE ATTENDANCE SESSION',
                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '${activeSession!.subject} - ${activeSession!.section}',
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const Text(
            'Session started! Please mark your attendance.',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),

          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _handleAttendanceMarking(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Text('MARK ATTENDANCE NOW', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  void _handleAttendanceMarking(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final studentId = student.id;
    final studentName = student.name;

    bool isBiometricEnabled = false;
    if (studentId != null) {
      isBiometricEnabled = prefs.getBool('biometric_enabled_$studentId') ?? false;
    }
    if (!isBiometricEnabled) {
      isBiometricEnabled = prefs.getBool('biometric_enabled_$studentName') ?? false;
    }

    if (!isBiometricEnabled) {
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Text('Security Required', style: TextStyle(fontWeight: FontWeight.bold)),
            content: const Text('To use secure attendance, please enable "Biometric Login" in your Profile settings first.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
            ],
          ),
        );
      }
      return;
    }

    if (!context.mounted) return;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Identity Verification',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please verify your identity to generate QR',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 32),
            _buildAuthOption(
              context: ctx,
              icon: Icons.security_rounded,
              title: 'Verify Identity',
              subtitle: 'Biometric or PIN confirmation',
              onTap: () async {
                final auth = LocalAuthentication();
                try {
                  final didAuth = await auth.authenticate(
                    localizedReason: 'Please verify your identity to generate your attendance QR',
                    options: const AuthenticationOptions(
                      biometricOnly: false, // Allows PIN/Pattern fallback
                      stickyAuth: true,
                    ),
                  );
                  if (didAuth) {
                    Navigator.pop(ctx);
                    if (context.mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => StudentQRCodeScreen(
                            studentName: student.name,
                            subject: activeSession!.subject,
                            section: activeSession!.section,
                            sessionCode: activeSession!.sessionCode,
                          ),
                        ),
                      );
                    }
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Authentication failed: $e'), backgroundColor: Colors.red),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuthOption({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppTheme.primary, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(subtitle, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordTile(Map<String, String> record) {
    final status = record['status']!;
    final isLive = record['isLive'] == 'true';
    
    final color = status == 'present'
        ? Colors.green
        : status == 'late'
        ? Colors.orange
        : status == 'pending'
        ? AppTheme.primary
        : Colors.red;

    final icon = status == 'present'
        ? Icons.check_circle_rounded
        : status == 'late'
        ? Icons.access_time_filled_rounded
        : status == 'pending'
        ? Icons.hourglass_top_rounded
        : Icons.cancel_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isLive ? AppTheme.primary.withOpacity(0.3) : Colors.grey.withOpacity(0.1), width: isLive ? 1.5 : 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      record['subject']!,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textPrimary),
                    ),
                    if (isLive) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)),
                        child: const Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  record['date']!,
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.login_rounded, size: 12, color: Colors.grey.shade400),
                  const SizedBox(width: 4),
                  Text(
                    record['time']!,
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              )
            ],
          ),
        ],
      ),
    );
  }

  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }
}
