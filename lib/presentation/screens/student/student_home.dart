import 'dart:async';
import 'package:screen_protector/screen_protector.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:local_auth/local_auth.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/models/student_model.dart';
import '../../../data/app_data.dart' hide Student;
import '../auth/login_screen.dart';
import '../../../data/services/attendance_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/services/api_service.dart';
import '../../../data/services/notification_service.dart';
import '../../../data/services/socket_service.dart';
import '../../../data/services/announcement_service.dart';
import '../../widgets/custom_widgets.dart';
import '../../widgets/bottom_nav_shell.dart';
import '../support/request_support_screen.dart';
import '../profile/profile_screen.dart';
import '../../../data/services/announcement_service.dart';
import '../calendar/calendar_screen.dart';
import 'student_history_screen.dart';
import 'student_concerns_screen.dart';
import 'subject_attendance_screen.dart';
import '../../widgets/pubmat_popup.dart';

// NOTE: shared color constants are provided by `app_data.dart` (imported above).
// Removed local duplicates so the app uses a single source of truth for colors.

// ─── HELPERS ──────────────────────────────────────────────────────────────────

/// Parses "HH:MM - HH:MM" → (startMinutes, endMinutes) in minutes-since-midnight.
/// Returns null if the format is unrecognised.
(int, int)? _parseTimeRange(String raw) {
  // e.g. "14:00 - 16:00"
  final parts = raw.split('-');
  if (parts.length != 2) return null;
  int? toMinutes(String s) {
    final t = s.trim().split(':');
    if (t.length != 2) return null;
    final h = int.tryParse(t[0]);
    final m = int.tryParse(t[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }

  final start = toMinutes(parts[0]);
  final end = toMinutes(parts[1]);
  if (start == null || end == null) return null;
  return (start, end);
}

/// Returns true when the Philippine time (UTC+8) is inside [timeRange].
bool _isCurrentlyInSession(String timeRange) {
  final parsed = _parseTimeRange(timeRange);
  if (parsed == null) return false;
  final now = DateTime.now().toUtc().add(const Duration(hours: 8));
  final nowMinutes = now.hour * 60 + now.minute;
  return nowMinutes >= parsed.$1 && nowMinutes < parsed.$2;
}

// ─── STUDENT HOME ─────────────────────────────────────────────────────────────
class StudentHomeScreen extends StatefulWidget {
  final Student student;
  const StudentHomeScreen({super.key, required this.student});

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  // ── Attendance summary ──────────────────────────────────────────────────────
  AttendanceSummary _summary = const AttendanceSummary(
    present: 0,
    late: 0,
    absent: 0,
  );
  bool _loadingSummary = true;

  // MongoDB Polling fields
  ActiveSessionInfo? _activeSession;
  // ── Real-time subject clock ──────────────────────────────────────────────────
  Timer? _clockTimer;
  bool _subjectActive = false; // whether current PH time is inside the schedule
  Map<String, dynamic>? _sectionInfo;
  List<dynamic> _attendanceHistory = [];
  List<Map<String, dynamic>> _cloudAnnouncements = [];
  StreamSubscription? _announcementSub;


  // ── Teacher lookup (for Message Faculty) ───────────────────────────────────
  /// Map of role → teacher name, fetched once from Firebase.
  /// e.g. { 'classAdviser': 'Ma. Santos', 'subjectTeacher': 'Jobelle M. Javier', 'clubAdviser': '—' }
  final Map<String, String> _teacherNames = {
    'classAdviser': 'My Class Adviser',
    'subjectTeacher': 'Subject Teacher', // placeholder, updated in initState
    'clubAdviser': 'Club Adviser',
  };

  @override
  void initState() {
    super.initState();
    // Set subject placeholder now that widget is available
    _teacherNames['subjectTeacher'] =
        'Subject Teacher (${widget.student.subject})';
    _loadSummary();
    _startClock();
    _fetchTeacherNames();
    _startPolling();

    // ── JOIN SOCKET ROOMS FOR NOTIFICATIONS ─────────────────────────────────
    SocketService.joinRoom(widget.student.section);
    SocketService.joinRoom('ALL');

    // Show Pubmat Popup once per session
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const PubmatPopup(),
        );
      }
    });
  }

  StreamSubscription? _sessionSub;
  StreamSubscription? _notifSub;
  StreamSubscription? _recordSub;
  LiveStudentRecord? _myLiveRecord;

  void _startPolling() {
    // Replaced legacy polling with Firestore Stream
    _sessionSub = AttendanceService.streamActiveSession(
      subject: widget.student.subject,
      section: widget.student.section,
    ).listen((session) {
      if (mounted) {
        setState(() {
          _activeSession = session;
          
          if (_activeSession != null && _recordSub == null) {
            _recordSub = AttendanceService.streamStudentRecord(
              subject: widget.student.subject,
              section: widget.student.section,
              studentName: widget.student.name,
            ).listen((record) {
              if (mounted) {
                setState(() {
                  _myLiveRecord = record;
                });
                // Refresh summary when attendance is marked in real-time!
                _loadSummary();
              }
            });
          } else if (_activeSession == null && _recordSub != null) {
            _recordSub?.cancel();
            _recordSub = null;
            _myLiveRecord = null;
          }
        });
      }
    });

    _notifSub = NotificationService.notifications.listen((notif) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(notif['title'] ?? 'Notification', style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(notif['body'] ?? ''),
              ],
            ),
            backgroundColor: AppTheme.primary,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    });

    // Cloud Announcements Subscription
    _announcementSub = AnnouncementService.streamAnnouncements(widget.student.section).listen((events) {
      if (mounted) {
        setState(() {
          _cloudAnnouncements = events;
        });
      }
    });
  }

  // ── 1. Attendance summary ───────────────────────────────────────────────────
  Future<void> _loadSummary() async {
    final summary = await AttendanceService.getStudentSummary(
      name: widget.student.name,
      id: widget.student.id,
    );
    
    // Fetch real section info (for professor name/schedule)
    final section = await ApiService.getStudentSectionInfo();
    
    // Fetch real attendance history
    final history = await ApiService.getStudentAttendanceHistory(
      name: widget.student.name,
      id: widget.student.id,
    );

    // Fetch all professors assigned to this student's subjects
    final professors = await ApiService.getStudentProfessors();

    if (mounted) {
      setState(() {
        _summary = summary;
        _sectionInfo = section;
        _attendanceHistory = history;
        
        // Clear old list and populate with real professors
        _teacherNames.clear();
        for (var prof in professors) {
          final String name = prof['name'] ?? 'Unknown Teacher';
          final String subject = prof['subject'] ?? 'Subject Professor';
          // Use name as key to ensure it shows up in concerns dropdown
          _teacherNames[name] = name; 
        }

        // Fallback if no professors found from new endpoint
        if (_teacherNames.isEmpty && section != null && section['teacher'] != null) {
          final teacherData = section['teacher'];
          final String name = teacherData is Map ? (teacherData['name'] ?? 'Assigned Teacher') : teacherData.toString();
          _teacherNames['Subject Teacher'] = name;
        }

        _loadingSummary = false;
      });

      // S4: Absence Threshold Alerts
      if (summary.absent >= 3) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _showAbsenceWarning(summary.absent);
          }
        });
      }
    }
  }

  void _showAbsenceWarning(int count) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red),
            const SizedBox(width: 10),
            const Text('Excessive Absences', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Warning: You have accumulated $count absences. Excessive absences may lead to failing grades or mandatory parent conferences. Please coordinate with your professors immediately.',
          style: const TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('UNDERSTOOD', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              // Open concerns tab
              DefaultTabController.of(context).animateTo(2); 
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            child: const Text('CONTACT FACULTY', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }


  // ── 2. Real-time clock for subject activity ─────────────────────────────────
  void _startClock() {
    _subjectActive = _isCurrentlyInSession(widget.student.time);
    // tick every 30 s — cheap enough, responsive enough
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      final active = _isCurrentlyInSession(widget.student.time);
      if (active != _subjectActive) setState(() => _subjectActive = active);
    });
  }

  // ── 3. Fetch teacher names from Firebase ────────────────────────────────────
  Future<void> _fetchTeacherNames() async {
    // MongoDB version: Will be fetched from /api/teachers in the future
    if (mounted) {
      setState(() {
        _teacherNames['subjectTeacher'] =
            'Subject Teacher (${widget.student.subject})';
      });
    }
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _sessionSub?.cancel();
    _notifSub?.cancel();
    _announcementSub?.cancel();
    _recordSub?.cancel();
    super.dispose();
  }

  // ── CONTACT FACULTY MODAL ───────────────────────────────────────────────────
  void _openRestrictedMessaging(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ContactFacultySheet(
        student: widget.student,
        teacherNames: _teacherNames,
        onSent: (AppMessage msg) {
          AppData.teacherNotifs.insert(0, msg);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Message Sent Successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        },
      ),
    );
  }

  // ── BUILD ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return BottomNavShell(
      header: CustomHeader(
        title: 'STUDENT PORTAL',
        subtitle:
            'Hi, ${widget.student.name.split(',').first.toUpperCase()}!',
        userRole: 'STUDENT',
      ),
      labels: const ['Home', 'Records', 'Concerns', 'Calendar', 'Profile'],
      icons: const [
        Icons.dashboard_rounded,
        Icons.history_rounded,
        Icons.support_agent_rounded,
        Icons.calendar_month_rounded,
        Icons.person_rounded,
      ],

      pages: [
        // ─── TAB 0: HOME ──────────────────────────────────────────────
        _buildHomePage(),
        // ─── TAB 1: RECORDS ───────────────────────────────────────────
        StudentHistoryScreen(
          student: widget.student, 
          embedded: true,
          summary: _summary,
          sectionInfo: _sectionInfo,
          history: _attendanceHistory,
          activeSession: (_myLiveRecord != null && _myLiveRecord!.status != 'pending') ? null : _activeSession,
        ),
        // ─── TAB 2: CONCERNS ──────────────────────────────────────────
        StudentConcernsScreen(
          student: widget.student,
          teacherNames: _teacherNames,
        ),
        // ─── TAB 3: CALENDAR ──────────────────────────────────────────
        const CalendarScreen(embedded: true),
        // ─── TAB 4: PROFILE ───────────────────────────────────────────
        ProfileScreen(
          userName: widget.student.name,
          userRole: 'Student',
          embedded: true,
        ),
      ],
    );
  }

  void _handleQRScanned(String data) {
    // Data format: SUBJECT|SECTION|TIMESTAMP
    final parts = data.split('|');
    if (parts.length >= 2 &&
        parts[0] == widget.student.subject &&
        parts[1] == widget.student.section) {
      _markPresent();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid QR Code for this session!'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _markPresent() async {
    final result = await AttendanceService.markStudentPresent(
      studentName: widget.student.name,
      subject: widget.student.subject,
      section: widget.student.section,
    );
    if (mounted) {
      if (result == 'ERROR') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to mark attendance. Please try again.'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      final color = result == 'present'
          ? Colors.green
          : result == 'late'
          ? Colors.orange
          : Colors.red;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Marked as ${result.toUpperCase()}!'),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Refresh history and navigate to SubjectAttendanceScreen
      final newHistory = await ApiService.getStudentAttendanceHistory(
        name: widget.student.name,
        id: widget.student.id,
      );
      if (mounted) {
        setState(() {
          _attendanceHistory = newHistory;
        });

        final profName = _sectionInfo != null && _sectionInfo!['teacher'] != null
            ? (_sectionInfo!['teacher'] is Map
                ? _sectionInfo!['teacher']['name']
                : _sectionInfo!['teacher'].toString())
            : 'Assigned Teacher';

        final filteredLogs = (newHistory).where((h) => h['subject'] == widget.student.subject).map((h) {
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

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SubjectAttendanceScreen(
              subjectName: widget.student.subject,
              section: widget.student.section,
              professor: profName,
              logs: filteredLogs,
            ),
          ),
        );
      }
    }
  }

  // Helper method extracted from StudentHistoryScreen for month name
  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return month >= 1 && month <= 12 ? months[month - 1] : '';
  }

  Widget _buildHomePage() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
      children: [
        // ── TODAY'S SCHEDULE ────────────────────────────
        _buildSectionTitle("TODAY'S SCHEDULE"),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
            border: Border.all(color: _subjectActive ? AppTheme.primary.withOpacity(0.5) : Colors.transparent, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _subjectActive ? AppTheme.primary.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _subjectActive ? 'In Progress' : 'Upcoming',
                      style: TextStyle(
                        color: _subjectActive ? AppTheme.primary : Colors.grey.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Icon(Icons.class_rounded, color: _subjectActive ? AppTheme.primary : Colors.grey),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                widget.student.subject,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    'Section ${widget.student.section}',
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(width: 16),
                  const Icon(Icons.access_time_rounded, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    widget.student.time,
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // ── UPCOMING AGENDA & EVENTS ────────────────────────────
        _buildSectionTitle('LATEST ANNOUNCEMENTS'),
        _buildLatestAnnouncements(),
      ],
    );
  }

  Widget _buildLatestAnnouncements() {
    // 1. Collect from Cloud (Real-time synced)
    final List<Map<String, dynamic>> allEvents = List.from(_cloudAnnouncements);
    
    // 2. Merge with Local Cache (for backward compatibility/legacy entries)
    AppData.calendarEvents.forEach((date, events) {
      for (var e in events) {
        final invited = e['invitedSections'] as List<String>? ?? [];
        final target = e['targetType'] as String?;
        
        // Skip if specifically for Teachers
        if (target == 'Only Teachers') continue;

        if (invited.contains('ALL') || invited.contains(widget.student.section) || invited.isEmpty) {
          // Check if already in cloud list (to avoid duplicates)
          final bool exists = allEvents.any((ae) => ae['title'] == e['title'] && ae['dateTime'] == date);
          if (!exists) {
            final Map<String, dynamic> eventWithDate = Map.from(e);
            eventWithDate['dateTime'] = date;
            allEvents.add(eventWithDate);
          }
        }
      }
    });

    // Sort by date (descending)
    allEvents.sort((a, b) {
      final da = a['dateTime'] is String ? DateTime.parse(a['dateTime']) : a['dateTime'] as DateTime;
      final db = b['dateTime'] is String ? DateTime.parse(b['dateTime']) : b['dateTime'] as DateTime;
      return db.compareTo(da);
    });

    if (allEvents.isEmpty) {
      return SharedUI.buildEmptyState('No announcements from your teacher yet.');
    }

    return Column(
      children: allEvents.take(3).map((event) {
        final date = event['dateTime'] is String ? DateTime.parse(event['dateTime']) : event['dateTime'] as DateTime;
        final dateStr = "${date.month}/${date.day}/${date.year}";
        final bool isToday = date.year == DateTime.now().year && date.month == DateTime.now().month && date.day == DateTime.now().day;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 5)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                Positioned(
                  right: -20,
                  top: -20,
                  child: Icon(Icons.campaign_rounded, size: 100, color: AppTheme.primary.withOpacity(0.03)),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isToday ? Colors.orange.withOpacity(0.1) : AppTheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              isToday ? 'NEW' : 'ANNOUNCEMENT',
                              style: TextStyle(
                                color: isToday ? Colors.orange : AppTheme.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                          Text(dateStr, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        event['title'] ?? 'No Title',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        event['description'] ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.4),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _buildMiniInfo(Icons.access_time_rounded, event['time'] ?? 'Whole Day'),
                          const SizedBox(width: 16),
                          _buildMiniInfo(Icons.location_on_rounded, event['location'] ?? 'Campus'),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMiniInfo(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppTheme.primary.withOpacity(0.5)),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
      ],
    );
  }

  Widget _buildAgendaItem({required String title, required String date, required String type, required IconData icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
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
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      date,
                      style: const TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '• $type',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
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
}

// ─── CONTACT FACULTY BOTTOM SHEET (extracted widget for cleanliness) ──────────
class _ContactFacultySheet extends StatefulWidget {
  final Student student;
  final Map<String, String> teacherNames;
  final void Function(AppMessage) onSent;

  const _ContactFacultySheet({
    required this.student,
    required this.teacherNames,
    required this.onSent,
  });

  @override
  State<_ContactFacultySheet> createState() => _ContactFacultySheetState();
}

class _ContactFacultySheetState extends State<_ContactFacultySheet> {
  late String _recipient;
  String _topic = 'None of the above (Optional Excuse)';
  String? _selectedClub;
  final TextEditingController _msgCtrl = TextEditingController();

  // FIX 3: image picker support
  final ImagePicker _picker = ImagePicker();
  XFile? _attachedImage;
  Uint8List? _attachedImageBytes; // used for web-safe preview

  bool _isDocumentAttached = false;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _recipient = widget.teacherNames['classAdviser']!;
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  // ── Image helpers ─────────────────────────────────────────────────────────
  Future<void> _pickImage(ImageSource source) async {
    AppData.preventLock = true;
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1080,
    );
    Future.delayed(const Duration(milliseconds: 500), () {
      AppData.preventLock = false;
    });
    
    if (picked != null) {
      // Show simulated cloud upload progress
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                SizedBox(width: 15),
                Text('Uploading to cloud storage...'),
              ],
            ),
            backgroundColor: AppTheme.primary,
            duration: Duration(seconds: 1),
          ),
        );
      }
      
      // Read bytes — works on both web and native
      final bytes = await picked.readAsBytes();
      await Future.delayed(const Duration(seconds: 1)); // Simulate latency

      setState(() {
        _attachedImage = picked;
        _attachedImageBytes = bytes;
        _isDocumentAttached = true;
      });
    }
  }

  void _removeImage() {
    setState(() {
      _attachedImage = null;
      _attachedImageBytes = null;
      _isDocumentAttached = false;
    });
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: darkBlue),
              title: const Text('Take a Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: darkBlue),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Send logic ────────────────────────────────────────────────────────────
  void _confirmSend() async {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirm Submission', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          'Sending as ${widget.student.name}. '
          'False information may lead to disciplinary action.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              _submitFinalConcern();
            },
            child: const Text('CONFIRM', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _submitFinalConcern() async {
    setState(() => _isSending = true);
    
    String? attachmentUrl;
    
    try {
      // 1. Upload if there's an attachment
      if (_attachedImage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Uploading document...'), behavior: SnackBarBehavior.floating),
        );
        attachmentUrl = await ApiService.uploadDocument(_attachedImage!.path);
      }

      // 2. Submit to API
      final success = await ApiService.submitConcern({
        'message': '[$_topic]${_msgCtrl.text.isNotEmpty ? ' — ${_msgCtrl.text}' : ''}',
        'attachmentPath': attachmentUrl ?? _attachedImage?.path, // Fallback to local for simulation
        'type': _topic,
        'target': _recipient,
      });

      if (success && mounted) {
        final msgId = DateTime.now().millisecondsSinceEpoch.toString();
        final msg = AppMessage(
          msgId,
          '${widget.student.name} (${widget.student.section})',
          '[$_topic]${_msgCtrl.text.isNotEmpty ? ' — ${_msgCtrl.text}' : ''}',
          DateTime.now(),
          attachmentPath: attachmentUrl ?? _attachedImage?.path,
        );
        widget.onSent(msg);
        
        Navigator.pop(context); // Close sheet
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send concern. Please try again.'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool requiresExcuse = _topic == 'Absent Today (Needs Excuse)';
    final bool isClubExcuse = _topic == 'Club Activity Excuse';
    final bool canSend =
        (!requiresExcuse || _isDocumentAttached) &&
        (!isClubExcuse || _selectedClub != null);

    // Build recipient dropdown items from synced teacher names
    final recipientItems = [
      widget.teacherNames['classAdviser']!,
      widget.teacherNames['subjectTeacher']!,
      widget.teacherNames['clubAdviser']!,
    ];
    // Ensure current value is still valid
    if (!recipientItems.contains(_recipient)) _recipient = recipientItems[0];

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24,
        right: 24,
        top: 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Title ───────────────────────────────────────────────────────
            const Text(
              'Contact Faculty',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: darkBlue,
              ),
            ),
            Text(
              'Messaging as: ${widget.student.name} (${widget.student.section})',
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),

            // ── Send To (synced teacher names) ───────────────────────────────
            DropdownButtonFormField<String>(
              initialValue: _recipient,
              decoration: InputDecoration(
                labelText: 'Send To:',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              items: recipientItems
                  .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                  .toList(),
              onChanged: (v) => setState(() => _recipient = v!),
            ),
            const SizedBox(height: 15),

            // ── Topic ────────────────────────────────────────────────────────
            DropdownButtonFormField<String>(
              initialValue: _topic,
              decoration: InputDecoration(
                labelText: 'Topic:',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              items: const [
                'None of the above (Optional Excuse)',
                'Running Late (Optional Excuse)',
                'Absent Today (Needs Excuse)',
                'Club Activity Excuse',
              ].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
              onChanged: (v) => setState(() {
                _topic = v!;
                _isDocumentAttached = false;
                _attachedImage = null;
              }),
            ),
            const SizedBox(height: 15),

            // ── Club selector (conditional) ──────────────────────────────────
            if (isClubExcuse) ...[
              DropdownButtonFormField<String>(
                initialValue: _selectedClub,
                decoration: InputDecoration(
                  labelText: 'Select Club Enrolled:',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                items: ['Science Club', 'Math Club', 'Glee Club']
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedClub = v),
              ),
              const SizedBox(height: 15),
            ],

            // ── Message box ──────────────────────────────────────────────────
            TextField(
              controller: _msgCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                hintText: 'Optional details...',
              ),
            ),
            const SizedBox(height: 15),

            // ── FIX 3: Image attachment area ─────────────────────────────────
            if (_attachedImage != null) ...[
              // Preview + remove button
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: _attachedImageBytes != null
                        // Web-safe: use bytes for preview on all platforms
                        ? Image.memory(
                            _attachedImageBytes!,
                            width: double.infinity,
                            height: 180,
                            fit: BoxFit.cover,
                          )
                        : (!kIsWeb && _attachedImage != null)
                        ? Image.file(
                            File(_attachedImage!.path),
                            width: double.infinity,
                            height: 180,
                            fit: BoxFit.cover,
                          )
                        : const SizedBox(height: 180),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: _removeImage,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red.shade700,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // "Attached" pill
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, color: Colors.white, size: 16),
                    SizedBox(width: 6),
                    Text(
                      'Excuse Letter Attached',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Attach button
              ElevatedButton.icon(
                onPressed: _showImageSourceSheet,
                icon: const Icon(Icons.upload_file),
                label: Text(
                  requiresExcuse
                      ? 'Attach Excuse Letter (Required)'
                      : 'Attach Excuse Letter',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: requiresExcuse
                      ? Colors.orange
                      : Colors.grey.shade300,
                  foregroundColor: requiresExcuse
                      ? Colors.white
                      : Colors.black87,
                ),
              ),
            ],

            const SizedBox(height: 20),

            // ── Send button ──────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: canSend ? darkBlue : Colors.grey,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: canSend ? _confirmSend : null,
                child: _isSending 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text(
                      'SEND MESSAGE',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ─── LIVE SESSION BANNER + SCAN BUTTON ───────────────────────────────────────
class _LiveSessionBanner extends StatefulWidget {
  final Student student;
  final ActiveSessionInfo session;
  final bool alreadyScanned;
  final AttendanceRecord? currentRecord;

  const _LiveSessionBanner({
    required this.student,
    required this.session,
    required this.alreadyScanned,
    this.currentRecord,
  });

  @override
  State<_LiveSessionBanner> createState() => _LiveSessionBannerState();
}

class _LiveSessionBannerState extends State<_LiveSessionBanner> {
  bool _isGenerating = false;
  final _auth = LocalAuthentication();

  Future<void> _generateAndShowQR() async {
    if (widget.alreadyScanned) return;
    
    // Check if biometric is enabled in profile
    final prefs = await SharedPreferences.getInstance();
    final studentId = widget.student.id;
    final studentName = widget.student.name;
    
    // Check both ID-based and Name-based keys for maximum reliability
    bool isBiometricEnabled = false;
    if (studentId != null) {
      isBiometricEnabled = prefs.getBool('biometric_enabled_$studentId') ?? false;
    }
    if (!isBiometricEnabled) {
      isBiometricEnabled = prefs.getBool('biometric_enabled_$studentName') ?? false;
    }

    if (!isBiometricEnabled) {
      if (mounted) {
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

    setState(() => _isGenerating = true);
    try {
      final authenticated = await _auth.authenticate(
        localizedReason: 'Verify identity to generate attendance QR',
        options: const AuthenticationOptions(biometricOnly: false, stickyAuth: true),
      );
      if (authenticated) {
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => _StudentQRDialog(student: widget.student),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification failed or unavailable.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = widget.session.elapsedMinutes;
    final lateIn = widget.session.lateThresholdMinutes - elapsed;
    final absentIn = widget.session.absentThresholdMinutes - elapsed;

    Color bannerColor = Colors.green.shade700;
    String timeMsg = 'On time! $lateIn min before late.';
    if (elapsed >= widget.session.lateThresholdMinutes &&
        elapsed < widget.session.absentThresholdMinutes) {
      bannerColor = Colors.orange.shade700;
      timeMsg = 'You are LATE. $absentIn min before marked absent.';
    } else if (elapsed >= widget.session.absentThresholdMinutes) {
      bannerColor = Colors.red.shade700;
      timeMsg = 'Session closed. You have been marked ABSENT.';
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: bannerColor,
        borderRadius: BorderRadius.circular(15),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.circle, color: Colors.white, size: 10),
              const SizedBox(width: 8),
              Text(
                'LIVE SESSION: ${widget.student.subject}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            timeMsg,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 16),
          if (widget.alreadyScanned)
            _ScannedChip(widget.currentRecord!)
          else if (elapsed < widget.session.absentThresholdMinutes)
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _isGenerating ? null : _generateAndShowQR,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: _isGenerating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(
                            Icons.qr_code,
                            color: darkBlue,
                            size: 28,
                          ),
                    label: Text(
                      _isGenerating ? 'Generating...' : 'GENERATE ATTENDANCE QR',
                      style: const TextStyle(
                        color: darkBlue,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            )
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Scan window has closed. You are ABSENT.',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── STUDENT QR DIALOG ────────────────────────────────────────────────────────
class _StudentQRDialog extends StatefulWidget {
  final Student student;
  const _StudentQRDialog({required this.student});

  @override
  State<_StudentQRDialog> createState() => _StudentQRDialogState();
}

class _StudentQRDialogState extends State<_StudentQRDialog> with SingleTickerProviderStateMixin {
  late Timer _timer;
  late String _qrData;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    // Enable screenshot protection when QR is shown
    ScreenProtector.preventScreenshotOn();
    
    _updateQR();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _updateQR());
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
  }

  void _updateQR() {
    if (mounted) {
      setState(() {
        // STUDENT_NAME|SUBJECT|SECTION|TIMESTAMP|SESSION_CODE
        _qrData = '${widget.student.name}|${widget.student.subject}|${widget.student.section}|${DateTime.now().millisecondsSinceEpoch}';
      });
    }
  }

  @override
  void dispose() {
    // Disable screenshot protection when dialog is closed
    ScreenProtector.preventScreenshotOff();
    
    _timer.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Your Attendance QR', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: darkBlue)),
            const SizedBox(height: 8),
            Text(widget.student.name, style: const TextStyle(fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 20),
            AnimatedBuilder(
              animation: _pulseController,
              builder: (ctx, child) => Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withOpacity(0.2 + (_pulseController.value * 0.3)),
                      blurRadius: 10 + (_pulseController.value * 10),
                      spreadRadius: 2 + (_pulseController.value * 5),
                    )
                  ]
                ),
                child: child,
              ),
              child: QrImageView(
                data: _qrData,
                version: QrVersions.auto,
                size: 200.0,
              ),
            ),
            const SizedBox(height: 20),
            const Text('Show this to your teacher', style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CLOSE', style: TextStyle(fontWeight: FontWeight.bold, color: darkBlue)),
            )
          ],
        ),
      ),
    );
  }
}

// ─── SCANNED CHIP ─────────────────────────────────────────────────────────────
class _ScannedChip extends StatelessWidget {
  final AttendanceRecord record;
  const _ScannedChip(this.record);

  @override
  Widget build(BuildContext context) {
    final color = record.status == 'present'
        ? Colors.green.shade400
        : record.status == 'late'
        ? Colors.orange
        : Colors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(
            '${record.status.toUpperCase()} — Scanned at ${record.timein ?? ""}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── TODAY'S STATUS CARD ──────────────────────────────────────────────────────
class _TodayStatusCard extends StatelessWidget {
  final AttendanceRecord? record;
  const _TodayStatusCard({super.key, this.record});

  @override
  Widget build(BuildContext context) {
    if (record == null || record!.status == 'pending')
      return const SizedBox.shrink();
    final Map<String, Color> statusColors = {
      'present': Colors.green,
      'late': Colors.orange,
      'absent': Colors.red,
      'excused': Colors.blueGrey,
    };
    final color = statusColors[record!.status] ?? Colors.grey;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "TODAY'S STATUS: ${record!.status.toUpperCase()}",
                  style: TextStyle(fontWeight: FontWeight.bold, color: color),
                ),
                if (record!.timein != null)
                  Text(
                    'Time in: ${record!.timein}',
                    style: TextStyle(color: color, fontSize: 12),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── ATTENDANCE STAT ──────────────────────────────────────────────────────────
class _AttStat extends StatelessWidget {
  final String value, label;
  final Color color;
  const _AttStat(this.value, this.label, this.color);

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        value,
        style: TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
      Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
    ],
  );
}

// ─── STUDENT NOTIFICATIONS ────────────────────────────────────────────────────
class StudentNotifsScreen extends StatelessWidget {
  final String studentName;
  const StudentNotifsScreen({super.key, required this.studentName});

  @override
  Widget build(BuildContext context) {
    // Only show notifications that are specifically for this student.
    // A notification belongs to this student if:
    //   - It's a System message AND the body mentions their name (e.g. "Welcome, Rizal!")
    //   - OR the sender contains their name (messages sent to them by a teacher)
    final myNotifs = AppData.studentNotifs
        .where(
          (n) =>
              (n.sender == 'System' && n.body.contains(studentName)) ||
              n.sender.contains(studentName),
        )
        .toList();

    return Scaffold(
      backgroundColor: lightGrayBg,
      body: SafeArea(
        child: Column(
          children: [
            SharedUI.buildHeader(
              context,
              'MY NOTIFICATIONS',
              showBackButton: true,
            ),
            Expanded(
              child: myNotifs.isEmpty
                  ? SharedUI.buildEmptyState('No notifications yet.')
                  : ListView.builder(
                      padding: const EdgeInsets.all(24),
                      itemCount: myNotifs.length,
                      itemBuilder: (context, i) {
                        final n = myNotifs[i];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: const Border(
                              left: BorderSide(color: darkBlue, width: 4),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    n.sender,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: darkBlue,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    n.formattedTime,
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Text(
                                n.body,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ],
                          ),
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
