import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/app_data.dart';
import '../../../data/models/student_model.dart';
import '../../../data/services/attendance_service.dart';
import '../../../data/services/api_service.dart';
import '../../../data/services/notification_service.dart';
import '../../../data/services/socket_service.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ocr_scanner_screen.dart';

// NOTE: darkBlue, yellowButton, lightGrayBg come from app_data.dart — NOT redefined here.

class LiveAttendanceScreen extends StatefulWidget {
  final String targetName; // Subject or Event Name
  final String? section;     // Section Name (if not an event)
  final bool isEvent;
  final String teacherId;
  final List<String>? initialStudents;

  const LiveAttendanceScreen({
    super.key,
    required this.targetName,
    this.section,
    this.isEvent = false,
    required this.teacherId,
    this.initialStudents,
  });

  @override
  State<LiveAttendanceScreen> createState() => _LiveAttendanceScreenState();
}

class _LiveAttendanceScreenState extends State<LiveAttendanceScreen> {
  Timer? _timer;
  Duration _elapsedTime = Duration.zero;
  bool _isClosing = false;
  bool _overtimeActive = false;
  bool _sessionStarted = false;
  bool _isStarting = false;

  List<LiveStudentRecord> _roster = [];
  List<Student> _sectionStudents = [];

  int _lateThreshold = 5;
  int _absentThreshold = 10;

  String get _subject => widget.targetName;
  String get _section => widget.section ?? widget.targetName;


  @override
  void initState() {
    super.initState();
    
    // IMMEDIATELY POPULATE ROSTER FROM PASSED DATA
    if (widget.initialStudents != null && widget.initialStudents!.isNotEmpty) {
      _sectionStudents = widget.initialStudents!.map((name) => Student(
        name: name,
        section: widget.section ?? '',
      )).toList().cast<Student>();
      
      _roster = widget.initialStudents!.map((name) => LiveStudentRecord(
        name: name,
        status: 'pending',
        verified: true,
      )).toList();
    }
    
    _buildSectionList();
  }

  void _buildSectionList() {
    if (widget.initialStudents != null && widget.initialStudents!.isNotEmpty) {
      // Data already passed from previous screen
      return;
    }

    if (widget.isEvent) {
      try {
        final event = AppData.events.firstWhere((e) => e.name == widget.targetName);
        _sectionStudents = event.invitedSections.contains('ALL')
            ? List.from(AppData.students)
            : AppData.students
                .where((s) => event.invitedSections.contains(s.section))
                .toList();
      } catch (_) {
        _sectionStudents = [];
      }
    } else {
      // Use the actual section name for filtering students
      _sectionStudents = AppData.students
          .where((s) => s.section == _section)
          .toList();
      
      // Fallback if empty and maybe a club
      if (_sectionStudents.isEmpty && _section.toLowerCase().contains('club')) {
        _sectionStudents = List.from(AppData.students);
      }
    }

    // Initialize roster immediately so we are never empty
    _roster = _sectionStudents.map((s) => LiveStudentRecord(
      name: s.name,
      status: 'pending',
      verified: true,
    )).toList();
  }


  StreamSubscription? _recordsSub;

  Future<void> _startSession() async {
    if (_isStarting) return;
    setState(() => _isStarting = true);

    try {
      await AttendanceService.startSession(
        teacherId: widget.teacherId,
        subject: _subject,
        section: _section,
        studentNames: _sectionStudents.map<String>((s) => s.name).toList(),
        lateThresholdMinutes: _lateThreshold,
        absentThresholdMinutes: _absentThreshold,
      );

      AppData.addLog("A live attendance session was started for ${widget.targetName}.");

      NotificationService.simulateNotification(
        'Attendance Started!',
        'Live attendance for ${widget.targetName} is now open. Please scan or use biometrics.',
        type: 'attendance_start'
      );

      // Replace Polling with Real-time Firestore Stream
      _recordsSub = AttendanceService.streamSessionRecords(_subject, _section).listen(
        (records) {
          if (mounted) {
            setState(() {
              if (records.isNotEmpty) {
                _roster = records;
              }
            });
          }
        },
        onError: (error) {
          debugPrint('Firestore stream error: $error');
          // Stream errors are non-fatal; the roster still has local data
        },
      );

      // Sub for elapsed time calculation
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted && _sessionStarted) {
          setState(() {
            _elapsedTime += const Duration(seconds: 1);
          });
        }
      });

      if (mounted) {
        setState(() {
          _sessionStarted = true;
          _isStarting = false;
          _elapsedTime = Duration.zero;
        });
      }
    } catch (e) {
      debugPrint('Start Session Error: $e');
      if (mounted) {
        setState(() => _isStarting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start session: $e'),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: 'RETRY',
              textColor: Colors.white,
              onPressed: _startSession,
            ),
          ),
        );
      }
    }
  }

  Future<void> _scanStudentQR() async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => Scaffold(
        appBar: AppBar(title: const Text('Scan Student QR')),
        body: MobileScanner(
          onDetect: (capture) {
            final List<Barcode> barcodes = capture.barcodes;
            if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
              Navigator.pop(ctx, barcodes.first.rawValue);
            }
          },
        ),
      ),
    );

    if (result != null) {
      // Data format: STUDENT_NAME|SUBJECT|SECTION|TIMESTAMP|SESSION_CODE
      final parts = result.split('|');
      if (parts.length >= 5) {
        final studentName = parts[0];
        final subject = parts[1];
        final section = parts[2];
        final timestampStr = parts[3];
        final scannedCode = parts[4];

        if (subject == _subject && section == _section) {
          // Fetch latest session info to verify code
          final activeInfo = await AttendanceService.getActiveSession(_subject, _section);
          final currentCode = activeInfo?['sessionCode'] ?? '';

          if (scannedCode != currentCode) {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('QR Code is outdated! (Rolling code changed)'), backgroundColor: Colors.orange));
            return;
          }

          final timestamp = int.tryParse(timestampStr);
          if (timestamp != null) {
            final elapsedScan = DateTime.now().millisecondsSinceEpoch - timestamp;
            if (elapsedScan < 15000) { // less than 15 seconds old
              await _markPresentByTeacher(studentName);
            } else {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('QR Code expired! Tell student to generate a new one.'), backgroundColor: Colors.red));
            }
          } else {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid QR Data'), backgroundColor: Colors.red));
          }
        } else {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('QR Code belongs to a different session.'), backgroundColor: Colors.red));
        }
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid QR format.'), backgroundColor: Colors.red));
      }
    }
  }

  void _openOCRScanner() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => OCRScannerScreen(
          studentNames: _roster.map((r) => r.name).toList(),
        ),
      ),
    );

    if (result != null) {
      await _markPresentByTeacher(result);
    }
  }

  Future<void> _markPresentByTeacher(String studentName) async {
    final result = await AttendanceService.markStudentPresent(
      studentName: studentName,
      subject: _subject,
      section: _section,
    );
    if (mounted) {
      if (result == 'ERROR') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to mark attendance. Please try again.'), backgroundColor: Colors.redAccent),
        );
      } else {
        final color = result == 'present' ? Colors.green : result == 'late' ? Colors.orange : Colors.red;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$studentName marked as ${result.toUpperCase()}!'), backgroundColor: color),
        );
      }
    }
  }

  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return "$h:$m:$s";
  }

  void _openManualOverride(LiveStudentRecord record) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Grab handle
            Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
            ),
            const SizedBox(height: 24),
            Text('Update Status', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade500, letterSpacing: 1.2)),
            const SizedBox(height: 8),
            Text(record.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF1A237E))),
            const SizedBox(height: 30),
            for (final status in ['present', 'late', 'absent', 'excused'])
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: _statusColor(status).withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _statusColor(status).withOpacity(0.2)),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  leading: CircleAvatar(backgroundColor: _statusColor(status).withOpacity(0.2), child: Icon(Icons.circle, color: _statusColor(status), size: 16)),
                  title: Text(status.toUpperCase(), style: TextStyle(fontWeight: FontWeight.bold, color: _statusColor(status), letterSpacing: 1)),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: () async {
                    await AttendanceService.manualOverride(
                      studentName: record.name,
                      subject: _subject,
                      section: _section,
                      newStatus: status,
                    );
                    
                    // Send real-time notification to the student
                    SocketService.sendNotification({
                      'room': _section,
                      'title': 'Attendance Update',
                      'body': '${record.name}, your attendance for $_subject has been marked as ${status.toUpperCase()}.',
                      'type': 'attendance',
                    });

                    AppData.addLog("Attendance for ${record.name} was manually set to $status.");
                    
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Marked ${record.name} as ${status.toUpperCase()}'),
                          backgroundColor: _statusColor(status),
                          behavior: SnackBarBehavior.floating,
                        )
                      );
                      Navigator.pop(ctx);
                    }
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'present': return Colors.green.shade600;
      case 'late':    return Colors.orange.shade600;
      case 'absent':  return Colors.red.shade600;
      case 'excused': return Colors.blueGrey.shade600;
      case 'pending': return Colors.grey.shade500;
      default:        return Colors.grey.shade400;
    }
  }

  void _promptEndSession() {
    if (!_sessionStarted) {
      Navigator.pop(context);
      return;
    }

    String? selectedReason;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle),
                  child: Icon(Icons.warning_amber_rounded, size: 40, color: Colors.red.shade700),
                ),
                const SizedBox(height: 20),
                Text('End Live Session?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.red.shade800)),
                const SizedBox(height: 8),
                const Text('Please select a reason for closing.', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 24),
                for (final entry in {
                  'Finished':  'Class Finished Normally',
                  'Early':     'Early Dismissal',
                  'Emergency': 'Emergency',
                  'Accident':  'Accidental Start',
                }.entries)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: selectedReason == entry.key ? Colors.red.shade300 : Colors.grey.shade200),
                      borderRadius: BorderRadius.circular(12),
                      color: selectedReason == entry.key ? Colors.red.shade50 : Colors.white,
                    ),
                    child: RadioListTile<String>(
                      value: entry.key,
                      groupValue: selectedReason,
                      onChanged: (v) => setDialogState(() => selectedReason = v),
                      title: Text(entry.value, style: TextStyle(fontWeight: selectedReason == entry.key ? FontWeight.bold : FontWeight.normal)),
                      activeColor: Colors.red.shade700,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text('CANCEL', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: selectedReason == null
                            ? null
                            : () {
                                Navigator.pop(ctx);
                                _requireTeacherAuth(selectedReason!);
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text('CONFIRM', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _requireTeacherAuth(String reason) async {
    final prefs = await SharedPreferences.getInstance();
    final user = await ApiService.getUserData();
    final userId = user?['id']?.toString();
    final userName = user?['name']?.toString() ?? '';

    bool isBiometricEnabled = false;
    if (userId != null) {
      isBiometricEnabled = prefs.getBool('biometric_enabled_$userId') ?? false;
    }
    if (!isBiometricEnabled) {
      isBiometricEnabled = prefs.getBool('biometric_enabled_$userName') ?? false;
    }

    if (!isBiometricEnabled) {
      // If biometrics not enabled in profile, proceed without it
      await _finalizeSession(reason);
      return;
    }

    final auth = LocalAuthentication();
    try {
      AppData.preventLock = true;
      final didAuth = await auth.authenticate(
        localizedReason: 'Teacher authorization required to finalize and sync this session.',
        options: const AuthenticationOptions(biometricOnly: false, stickyAuth: true),
      );
      AppData.preventLock = false;

      if (didAuth) {
        await _finalizeSession(reason);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Authentication failed. Session not finalized.')));
        }
      }
    } catch (e) {
      AppData.preventLock = false;
      // Fallback for devices without biometric support
      await _finalizeSession(reason);
    }
  }

  Future<void> _finalizeSession(String reason) async {
    if (!mounted) return;
    setState(() => _isClosing = true);

    _timer?.cancel();

    if (reason != 'Accident') {
      final summary = await AttendanceService.endSession(
        subject: _subject,
        section: _section,
        records: _roster,
        reason: reason,
      );

      if (!mounted) return;

      final now = DateTime.now();
      final formatted = '${now.month}/${now.day}/${now.year}';
      AppData.pastSessions.insert(
        0,
        PastSession(
          widget.targetName,
          formatted,
          summary['present'] ?? 0,
          summary['late'] ?? 0,
          summary['absent'] ?? 0,
          reason,
        ),
      );
      AppData.addLog("An attendance session was completed for ${widget.targetName}.");
      NotificationService.simulateNotification(
        'Attendance Closed',
        'Live attendance for ${widget.targetName} has ended. View your records for status.',
        type: 'attendance_end',
        room: _section, // Target specific section
      );
    } else {
      // Still end the session in Firestore even if it was an accident
      await AttendanceService.endSession(
        subject: _subject,
        section: _section,
        records: [],
        reason: 'Cancelled: Accidental Start',
      );
      AppData.addLog("An accidental session for ${widget.targetName} was cancelled.");
      NotificationService.simulateNotification(
        'Session Cancelled',
        'The attendance session for ${widget.targetName} was cancelled.',
        type: 'attendance_cancel',
        room: _section,
      );
    }

    if (mounted) {
      setState(() => _isClosing = false);
      _showCompletionDialog(reason);
    }
  }

  void _showCompletionDialog(String reason) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Column(
          children: [
            Icon(Icons.check_circle_outline_rounded, color: Colors.green, size: 64),
            SizedBox(height: 16),
            Text('Session Completed', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'The attendance session for ${widget.targetName} has been successfully saved to history.',
          textAlign: TextAlign.center,
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx); // Pop dialog
              Navigator.pop(context); // Pop screen
            },
            child: const Text('BACK TO HOME', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx); // Pop dialog
              _resetForNewSession();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: AppTheme.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('NEW SESSION', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _resetForNewSession() {
    // Clean up old session state
    _timer?.cancel();
    _recordsSub?.cancel();
    _recordsSub = null;
    
    setState(() {
      _sessionStarted = false;
      _elapsedTime = Duration.zero;
      _overtimeActive = false;
      _isStarting = false;
      _roster = []; // CRITICAL: Clear the old roster list
      
      // Re-fetch section students to ensure we have the list ready for _startSession
      _buildSectionList();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _recordsSub?.cancel();
    super.dispose();
  }

  int get _presentCount => _roster.where((r) => r.status == 'present').length;
  int get _lateCount    => _roster.where((r) => r.status == 'late').length;
  int get _pendingCount => _roster.where((r) => r.status == 'pending').length;
  int get _absentCount  => _roster.where((r) => r.status == 'absent').length;

  @override
  Widget build(BuildContext context) {
    final isOvertime = _elapsedTime.inHours >= 2 && !_overtimeActive;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _promptEndSession();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA), // AppTheme.background
        floatingActionButton: _sessionStarted
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  FloatingActionButton.extended(
                    heroTag: 'manual',
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Tap on a student name in the list to mark them manually!'), duration: Duration(seconds: 3))
                      );
                    },
                    backgroundColor: Colors.white,
                    icon: const Icon(Icons.touch_app_rounded, color: Color(0xFF1A237E)),
                    label: const Text('MANUAL', style: TextStyle(color: Color(0xFF1A237E), fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 12),
                  FloatingActionButton.extended(
                    heroTag: 'scan',
                    onPressed: _scanStudentQR,
                    backgroundColor: isOvertime ? Colors.red.shade600 : const Color(0xFF1A237E),
                    icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
                    label: const Text('SCAN QR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  FloatingActionButton(
                    onPressed: _openOCRScanner,
                    backgroundColor: Colors.teal,
                    mini: true,
                    child: const Icon(Icons.camera_alt_rounded, color: Colors.white),
                  ),
                ],
              )
            : null,
        bottomNavigationBar: _sessionStarted ? _buildEndSessionBar() : null,
        body: Column(
          children: [
            // ── HEADER ────────────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isOvertime 
                      ? [Colors.red.shade900, Colors.red.shade700] 
                      : [const Color(0xFF1A237E), Colors.blue.shade800],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 5))
                ],
              ),
              padding: const EdgeInsets.fromLTRB(20, 50, 20, 30),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                        onPressed: _promptEndSession,
                      ),
                      Expanded(
                        child: Text(
                          'LIVE: ${widget.targetName}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20, letterSpacing: 1.2),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                  if (_sessionStarted) ...[
                    const SizedBox(height: 10),
                    Text(
                      _formatDuration(_elapsedTime),
                      style: TextStyle(
                        color: isOvertime ? Colors.white : const Color(0xFFFFD600), // AppTheme.accent
                        fontSize: 54,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'monospace',
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _ThresholdChip('⏰ Late: ${_lateThreshold}m', Colors.orangeAccent),
                        const SizedBox(width: 10),
                        _ThresholdChip('🚫 Absent: ${_absentThreshold}m', Colors.redAccent),
                      ],
                    ),
                    if (isOvertime) ...[
                      const SizedBox(height: 15),
                      ElevatedButton(
                        onPressed: () => setState(() => _overtimeActive = true),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFD600),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                        child: const Text('APPROVE OVERTIME', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ] else ...[
                    const SizedBox(height: 10),
                    Text(
                      '${_roster.length} Students Pending',
                      style: const TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                  ],
                ],
              ),
            ),

            // ── BODY ──────────────────────────────────────────────────
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                switchInCurve: Curves.easeIn,
                switchOutCurve: Curves.easeOut,
                child: !_sessionStarted
                    ? _buildSetupView()
                    : _buildLiveView(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSetupView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle),
                  child: const Icon(Icons.timer_outlined, size: 48, color: Color(0xFF1A237E)),
                ),
                const SizedBox(height: 20),
                Text(
                  '${_sectionStudents.length} Students Total',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF101828)),
                ),
                const SizedBox(height: 8),
                const Text('Set your attendance thresholds below.', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 30),
                _buildThresholdRow('Late Threshold (min)', _lateThreshold, 1, 15, (v) => setState(() => _lateThreshold = v), Colors.orange),
                const SizedBox(height: 20),
                _buildThresholdRow('Absent Threshold (min)', _absentThreshold, 2, 30, (v) => setState(() => _absentThreshold = v), Colors.red),
              ],
            ),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 64,
            child: ElevatedButton.icon(
              onPressed: _isStarting ? null : _startSession,
              icon: _isStarting
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.play_arrow_rounded, color: Colors.black87, size: 30),
              label: Text(
                _isStarting ? 'STARTING...' : 'START SESSION',
                style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 1.5),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFD600),
                elevation: 8,
                shadowColor: const Color(0xFFFFD600).withOpacity(0.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveView() {
    return Column(
      children: [
        // Live Stats Bar overlapping slightly
        Transform.translate(
          offset: const Offset(0, -20),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _StatBadge('$_presentCount', 'PRESENT', Colors.green.shade600),
                _StatBadge('$_lateCount',    'LATE',    Colors.orange.shade600),
                _StatBadge('$_pendingCount', 'PENDING', Colors.grey.shade600),
                _StatBadge('$_absentCount',  'ABSENT',  Colors.red.shade600),
              ],
            ),
          ),
        ),
        
        // Roster List
        Expanded(
          child: _roster.isEmpty
              ? const Center(child: Text('Waiting for students to scan...', style: TextStyle(color: Colors.grey, fontSize: 16)))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100), // padding for FAB
                  itemCount: _roster.length,
                  itemBuilder: (context, i) {
                    final r = _roster[i];
                    final sColor = _statusColor(r.status);
                    return GestureDetector(
                      onTap: () => _openManualOverride(r),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: sColor.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: sColor.withOpacity(0.2), width: 1),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: sColor.withOpacity(0.2),
                              radius: 24,
                              child: Text(
                                r.name.substring(0, 1).toUpperCase(),
                                style: TextStyle(color: sColor, fontWeight: FontWeight.bold, fontSize: 20),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(r.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF101828))),
                                  const SizedBox(height: 4),
                                  if (r.timein != null)
                                    Row(
                                      children: [
                                        Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
                                        const SizedBox(width: 4),
                                        Text(r.timein!, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: sColor,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    r.status.toUpperCase(),
                                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEndSessionBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: _promptEndSession,
            icon: const Icon(Icons.power_settings_new_rounded, color: Colors.white),
            label: const Text('END SESSION', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThresholdRow(String label, int value, int min, int max, ValueChanged<int> onChanged, Color activeColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            Text('$value min', style: TextStyle(fontWeight: FontWeight.bold, color: activeColor, fontSize: 16)),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: activeColor,
            inactiveTrackColor: activeColor.withOpacity(0.2),
            thumbColor: activeColor,
            overlayColor: activeColor.withOpacity(0.2),
            trackHeight: 6,
          ),
          child: Slider(
            value: value.toDouble(),
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: max - min,
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
      ],
    );
  }


}

// ─── HELPERS ─────────────────────────────────────────────────────────────────
class _ThresholdChip extends StatelessWidget {
  final String label;
  final Color color;
  const _ThresholdChip(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _StatBadge(this.value, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.bold, color: color)),
        Text(label,
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}