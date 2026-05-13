import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'api_service.dart';
import 'offline_service.dart';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'notification_service.dart';

class AttendanceService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- TEACHER: START SESSION ---
  static Future<void> startSession({
    required String teacherId,
    required String subject,
    required String section,
    required List<String> studentNames,
    int lateThresholdMinutes = 5,
    int absentThresholdMinutes = 10,
    bool isEvent = false,
  }) async {
    // 1. Sync with custom Backend (MongoDB) via JWT
    await ApiService.startSession(
      subject: subject,
      section: section,
      isEvent: isEvent,
      lateThresholdMinutes: lateThresholdMinutes,
      absentThresholdMinutes: absentThresholdMinutes,
    );

    final sessionId = '${subject}_$section';
    final String sessionCode = _generateRandomCode();
    
    // 2. Maintain Real-time Firestore for live UI
    try {
      // CLEAR OLD RECORDS FIRST to ensure a fresh start
      final oldRecords = await _db.collection('Sessions').doc(sessionId).collection('Records').get();
      if (oldRecords.docs.isNotEmpty) {
        final deleteBatch = _db.batch();
        for (var doc in oldRecords.docs) {
          deleteBatch.delete(doc.reference);
        }
        await deleteBatch.commit();
      }

      await _db.collection('Sessions').doc(sessionId).set({
        'teacherId': teacherId,
        'subject': subject,
        'section': section,
        'isEvent': isEvent,
        'startTime': FieldValue.serverTimestamp(),
        'lateThresholdMinutes': lateThresholdMinutes,
        'absentThresholdMinutes': absentThresholdMinutes,
        'isActive': true,
        'sessionCode': sessionCode,
        'codeUpdatedAt': FieldValue.serverTimestamp(),
      });

      // Initialize all students as pending in Firestore
      final batch = _db.batch();
      for (String name in studentNames) {
        final docRef = _db.collection('Sessions').doc(sessionId).collection('Records').doc(name);
        batch.set(docRef, {
          'studentName': name,
          'status': 'pending',
          'timestamp': null,
        });
      }
      await batch.commit();

      // Start periodic code refresh (every 15 mins)
      _startCodeRefreshTimer(sessionId);
    } catch (e) {
      // Firestore errors are non-fatal — the MongoDB backend is the source of truth.
      // The session can still function with manual overrides even if Firestore fails.
      print('Firestore session setup warning: $e');
    }
  }

  static String _generateRandomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return List.generate(6, (i) => chars[DateTime.now().millisecond % chars.length]).join();
  }

  static void _startCodeRefreshTimer(String sessionId) {
    Timer.periodic(const Duration(minutes: 15), (timer) async {
      final doc = await _db.collection('Sessions').doc(sessionId).get();
      if (!doc.exists || doc.data()?['isActive'] != true) {
        timer.cancel();
        return;
      }
      await _db.collection('Sessions').doc(sessionId).update({
        'sessionCode': _generateRandomCode(),
        'codeUpdatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  // --- STUDENT: SCAN / MARK PRESENT ---
  static Future<String> markStudentPresent({
    required String studentName,
    required String subject,
    required String section,
  }) async {
    // Proactive Connectivity Check for Offline Mode
    final connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult.contains(ConnectivityResult.none)) {
      print('AUTODEMY: No internet connection detected. Queuing attendance offline.');
      await OfflineService.queueAttendance(
        studentName: studentName,
        subject: subject,
        section: section,
      );
      return 'queued';
    }

    try {
      // 1. Sync with custom Backend (MongoDB)
      final success = await ApiService.markAttendance(
        subject: subject,
        section: section,
        studentName: studentName,
      );
      if (!success) {
        print('AUTODEMY: Backend sync returned false. Might be server error.');
        // Optionally queue it anyway if we suspect it's a network glitch not caught by connectivity
      }
    } catch (e) {
      if (e is SocketException || e.toString().contains('Failed host lookup')) {
        // We are likely offline despite connectivity check, queue it!
        await OfflineService.queueAttendance(
          studentName: studentName,
          subject: subject,
          section: section,
        );
        return 'queued';
      }
      return 'ERROR';
    }

    final sessionId = '${subject}_$section';
    final sessionDoc = await _db.collection('Sessions').doc(sessionId).get();
    
    if (!sessionDoc.exists || sessionDoc.data()?['isActive'] != true) {
      return 'ERROR';
    }

    final data = sessionDoc.data()!;
    final startTime = (data['startTime'] as Timestamp).toDate();
    final lateThreshold = data['lateThresholdMinutes'] as int;
    final absentThreshold = data['absentThresholdMinutes'] as int;
    
    final elapsedMinutes = DateTime.now().difference(startTime).inMinutes;
    
    String status = 'present';
    if (elapsedMinutes >= absentThreshold) {
      status = 'absent';
    } else if (elapsedMinutes >= lateThreshold) {
      status = 'late';
    }

    // 2. Maintain Real-time Firestore
    try {
      await _db.collection('Sessions').doc(sessionId).collection('Records').doc(studentName).set({
        'studentName': studentName,
        'status': status,
        'timestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Trigger local notification for the user
      NotificationService.showLocalNotification(
        'Attendance Recorded',
        'You have successfully marked attendance for $subject - $section as ${status.toUpperCase()}.',
        type: 'attendance',
      );
    } catch (e) {
      // Firestore has internal offline persistence, so this usually "works" locally
    }

    return status;
  }

  /// Special method for OfflineService to sync records when internet returns
  static Future<void> syncOfflineRecord({
    required String studentName,
    required String subject,
    required String section,
    required DateTime timestamp,
  }) async {
    // 1. Sync with MongoDB
    await ApiService.markAttendance(
      subject: subject,
      section: section,
      studentName: studentName,
      timestamp: timestamp,
    );

    // 2. Calculate status based on original timestamp vs session start
    final sessionId = '${subject}_$section';
    final sessionDoc = await _db.collection('Sessions').doc(sessionId).get();
    if (sessionDoc.exists) {
      final data = sessionDoc.data()!;
      final startTime = (data['startTime'] as Timestamp).toDate();
      final lateThreshold = data['lateThresholdMinutes'] ?? 5;
      final absentThreshold = data['absentThresholdMinutes'] ?? 10;
      
      final elapsedMinutes = timestamp.difference(startTime).inMinutes;
      
      String status = 'present';
      if (elapsedMinutes >= absentThreshold) {
        status = 'absent';
      } else if (elapsedMinutes >= lateThreshold) {
        status = 'late';
      }

      await _db.collection('Sessions').doc(sessionId).collection('Records').doc(studentName).set({
        'studentName': studentName,
        'status': status,
        'timestamp': Timestamp.fromDate(timestamp),
        'offline_synced': true,
      }, SetOptions(merge: true));
    }
  }

  // --- STUDENT/TEACHER: GET ACTIVE SESSION STREAM (Real-time Notification) ---
  static Stream<ActiveSessionInfo?> streamActiveSession({
    required String subject,
    required String section,
  }) {
    final sessionId = '${subject}_$section';
    return _db.collection('Sessions').doc(sessionId).snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data()?['isActive'] != true) return null;
      final data = snapshot.data()!;
      if (data['startTime'] == null) return null; // Wait for server timestamp
      
      return ActiveSessionInfo(
        subject: data['subject'],
        section: data['section'],
        startTimestamp: (data['startTime'] as Timestamp).toDate().millisecondsSinceEpoch,
        lateThresholdMinutes: data['lateThresholdMinutes'] ?? 5,
        absentThresholdMinutes: data['absentThresholdMinutes'] ?? 10,
        sessionCode: data['sessionCode'] ?? '',
      );
    });
  }

  // --- STUDENT/TEACHER: STREAM RECORDS ---
  static Stream<List<LiveStudentRecord>> streamSessionRecords(String subject, String section) {
    final sessionId = '${subject}_$section';
    return _db.collection('Sessions').doc(sessionId).collection('Records').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        String? timeStr;
        if (data['timestamp'] != null) {
          final dt = (data['timestamp'] as Timestamp).toDate();
          timeStr = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
        }
        return LiveStudentRecord(
          name: data['studentName'] ?? doc.id,
          status: data['status'] ?? 'pending',
          timein: timeStr,
          verified: data['timestamp'] != null,
        );
      }).toList();
    });
  }

  static Stream<LiveStudentRecord?> streamStudentRecord({
    required String subject,
    required String section,
    required String studentName,
  }) {
    final sessionId = '${subject}_$section';
    return _db.collection('Sessions').doc(sessionId).collection('Records').doc(studentName).snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      final data = snapshot.data()!;
      String? timeStr;
      if (data['timestamp'] != null) {
        final dt = (data['timestamp'] as Timestamp).toDate();
        timeStr = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
      return LiveStudentRecord(
        name: data['studentName'] ?? snapshot.id,
        status: data['status'] ?? 'pending',
        timein: timeStr,
        verified: data['timestamp'] != null,
      );
    });
  }

  static Future<Map<String, int>> endSession({
    required String subject,
    required String section,
    required List<LiveStudentRecord> records,
    required String reason,
  }) async {
    final sessionId = '${subject}_$section';
    
    // First update the local Firestore to signal session end
    await _db.collection('Sessions').doc(sessionId).update({
      'isActive': false,
      'endTime': FieldValue.serverTimestamp(),
      'endReason': reason,
    });
    
    // 1. Fetch the latest records DIRECTLY from Firestore to ensure we have the most recent data
    final recordsSnapshot = await _db.collection('Sessions').doc(sessionId).collection('Records').get();
    final List<LiveStudentRecord> latestRecords = recordsSnapshot.docs.map((doc) {
      final data = doc.data();
      return LiveStudentRecord(
        name: data['studentName'] ?? doc.id,
        status: data['status'] ?? 'pending',
        timein: data['timestamp'] != null ? (data['timestamp'] as Timestamp).toDate().toIso8601String() : null,
        verified: data['timestamp'] != null,
      );
    }).toList();

    // 2. Convert to API format & resolve PENDING to ABSENT
    final formattedRecords = latestRecords.map((r) {
      // KEEP PRESENT/LATE as is. Only convert PENDING to ABSENT.
      final resolvedStatus = (r.status == 'pending' || r.status.isEmpty) ? 'absent' : r.status;
      return {
        'name': r.name,
        'status': resolvedStatus,
        'timein': r.timein,
        'timestamp': DateTime.now().toIso8601String(),
      };
    }).toList();

    // 3. Send to MongoDB (Permanent Record)
    await ApiService.endSession(
      subject: subject,
      section: section,
      records: formattedRecords,
      reason: reason,
    );

    // 3. Clear Firestore session (Cleanup)
    final recordsRef = _db.collection('Sessions').doc(sessionId).collection('Records');
    final docs = await recordsRef.get();
    for (var doc in docs.docs) {
      await doc.reference.delete();
    }
    
    // Return summary count (based on resolved statuses)
    int p = latestRecords.where((r) => r.status == 'present').length;
    int l = latestRecords.where((r) => r.status == 'late').length;
    int a = latestRecords.where((r) => r.status == 'pending' || r.status == 'absent').length;
    
    return {'present': p, 'late': l, 'absent': a};
  }

  static Future<void> manualOverride({
    required String studentName,
    required String subject,
    required String section,
    required String newStatus,
  }) async {
    final sessionId = '${subject}_$section';
    await _db.collection('Sessions').doc(sessionId).collection('Records').doc(studentName).update({
      'status': newStatus,
    });
  }

  // Helper to get active session data for verification
  static Future<Map<String, dynamic>?> getActiveSession(String subject, String section) async {
    final sessionId = '${subject}_$section';
    final doc = await _db.collection('Sessions').doc(sessionId).get();
    if (doc.exists && doc.data()?['isActive'] == true) {
      return doc.data();
    }
    return null;
  }

  static Future<AttendanceSummary> getStudentSummary({String? name, String? id}) async {
    final history = await ApiService.getStudentAttendanceHistory(name: name, id: id);
    int present = 0;
    int late = 0;
    int absent = 0;

    for (var record in history) {
      if (record['status'] == 'present') present++;
      else if (record['status'] == 'late') late++;
      else if (record['status'] == 'absent') absent++;
    }

    return AttendanceSummary(present: present, late: late, absent: absent);
  }
}

// --- DATA MODELS ---

class AttendanceSummary {
  final int present, late, absent;
  const AttendanceSummary({required this.present, required this.late, required this.absent});
  int get total => present + late + absent;
}

class AttendanceRecord {
  final String status;
  final String? timein;
  final bool verified;

  AttendanceRecord({required this.status, this.timein, required this.verified});

  factory AttendanceRecord.fromMap(Map<String, dynamic> map) {
    return AttendanceRecord(
      status: map['status'] ?? 'pending',
      timein: map['timestamp']?.toString(),
      verified: true,
    );
  }
}

class LiveStudentRecord {
  final String name;
  final String status;
  final String? timein;
  final bool verified;

  LiveStudentRecord({required this.name, required this.status, this.timein, required this.verified});
}

class ActiveSessionInfo {
  final String subject;
  final String section;
  final int startTimestamp;
  final int lateThresholdMinutes;
  final int absentThresholdMinutes;
  final String sessionCode;

  const ActiveSessionInfo({
    required this.subject,
    required this.section,
    required this.startTimestamp,
    required this.lateThresholdMinutes,
    required this.absentThresholdMinutes,
    required this.sessionCode,
  });

  DateTime get startTime => DateTime.fromMillisecondsSinceEpoch(startTimestamp);
  int get elapsedMinutes => DateTime.now().difference(startTime).inMinutes;
}