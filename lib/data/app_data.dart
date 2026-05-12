// ==========================================
// 1. app_data.dart 
// ==========================================
import 'package:flutter/material.dart';
import 'models/student_model.dart';

const Color darkBlue = Color(0xFF1B365D);
const Color lightGrayBg = Color(0xFFF0F2F5);
const Color yellowButton = Color(0xFFFFD54F);

// --- DATA MODELS ---
class AppMessage {
  String id; 
  String sender; 
  String body; 
  DateTime time; 
  String target; 
  String status; // 'PENDING', 'APPROVED', 'DISAPPROVED'
  String? attachmentPath;

  AppMessage(
    this.id, 
    this.sender, 
    this.body, 
    this.time, {
    this.target = "All", 
    this.status = "PENDING",
    this.attachmentPath,
  });

  String get formattedTime {
    int h = time.hour % 12; if (h == 0) h = 12;
    return "${time.month}/${time.day}/${time.year} $h:${time.minute.toString().padLeft(2, '0')} ${time.hour >= 12 ? 'PM' : 'AM'}";
  }
}

class LeaveRequest {
  String studentName; String section; String reason; bool hasWetSignature; String status; DateTime submittedAt;
  LeaveRequest(this.studentName, this.section, this.reason, this.hasWetSignature, this.status, this.submittedAt);
  String get formattedDate => "${submittedAt.month}/${submittedAt.day}/${submittedAt.year}";
}

class PastSession {
  String sectionName; String date; int present; int late; int absent; String reason;
  PastSession(this.sectionName, this.date, this.present, this.late, this.absent, this.reason);
}

// ==========================================
// SIMULATED CLOUD DATABASE
// ==========================================
class AppData {
  // Flag to prevent biometric lock during OS-level dialogs (camera, local_auth, etc)
  static bool preventLock = false;
  static ValueNotifier<bool> biometricEnabled = ValueNotifier(false);
  static ValueNotifier<String> currentUserName = ValueNotifier('');
  static ValueNotifier<bool> isLocked = ValueNotifier(true);
  static List<String> systemChangeLogs = ['System successfully started.'];
  static List<AppMessage> adminStudentLoginLogs = [];
  static List<AppMessage> adminTeacherLoginLogs = [];

  static List<String> currentUserRoles = ['SUBJECT_TEACHER', 'CLASS_ADVISER', 'CLUB_ADVISER', 'STRAND_COORDINATOR', 'CFC'];

  static List<AppMessage> pendingAnnouncements = [];
  static List<AppMessage> activeAnnouncements = [];

  static List<AppMessage> teacherNotifs = [];
  static List<AppMessage> studentNotifs = [];

  static List<LeaveRequest> leaveRequests = [];

  static List<PastSession> pastSessions = [];

  static List<Section> sections = [];

  static List<SchoolEvent> events = [];
  static List<Student> students = [];
  
  static Map<DateTime, List<dynamic>> calendarEvents = {};

  static double getGlobalAttendanceRate() {
    if (pastSessions.isEmpty) return 1.0;
    int totalP = pastSessions.fold(0, (sum, s) => sum + s.present);
    int totalAll = pastSessions.fold(0, (sum, s) => sum + s.present + s.late + s.absent);
    return totalAll == 0 ? 1.0 : totalP / totalAll;
  }

  static void addLog(String message) {
    int h = DateTime.now().hour % 12; if (h == 0) h = 12;
    String time = "$h:${DateTime.now().minute.toString().padLeft(2, '0')} ${DateTime.now().hour >= 12 ? 'PM' : 'AM'}";
    systemChangeLogs.insert(0, "[$time] $message");
  }
}

class Section { String name; String days; String timeBlock; bool isClub; Section(this.name, this.days, this.timeBlock, {this.isClub = false}); }
class SchoolEvent { String name; List<String> invitedSections; SchoolEvent(this.name, this.invitedSections); }

// ==========================================
// REUSABLE UI COMPONENTS
// ==========================================
class SharedUI {
  static Widget buildHeader(BuildContext context, String name, {bool showBackButton = false, VoidCallback? onLogout}) {
    return Container(
      width: double.infinity, color: darkBlue, padding: const EdgeInsets.only(left: 20, right: 20, top: 30, bottom: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            if (showBackButton) IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20), onPressed: () => Navigator.pop(context)),
            const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.calendar_month, color: Colors.white, size: 30),
              Text('AUTODEMY', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            ]),
          ]),
          Row(
            children: [
              ValueListenableBuilder<String>(
                valueListenable: AppData.currentUserName,
                builder: (context, currentName, _) {
                  return Text(
                    'HI, $currentName!\nWELCOME BACK!',
                    textAlign: TextAlign.right,
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  );
                },
              ),
              if (onLogout != null) ...[
                const SizedBox(width: 15),
                GestureDetector(onTap: onLogout, child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.red.shade700, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.logout, color: Colors.white, size: 20))),
              ]
            ],
          )
        ],
      ),
    );
  }

  static Widget buildListItemCard(IconData icon, String text, {Color iconColor = Colors.black87, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 15), padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))]),
        child: Row(
          children: [
            Icon(icon, size: 30, color: iconColor), const SizedBox(width: 20),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87))),
            if (onTap != null) const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  static Widget buildEmptyState(String message) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.inbox, size: 60, color: Colors.grey.shade400), const SizedBox(height: 15), Text(message, style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold))]));
  }
}