import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'attendance_service.dart';
import 'dart:async';

class OfflineService {
  static late Box _queueBox;
  static bool _isSyncing = false;

  static Future<void> init() async {
    await Hive.initFlutter();
    _queueBox = await Hive.openBox('attendance_queue');
    
    // Start listening for connectivity changes
    Connectivity().onConnectivityChanged.listen((results) {
      if (results.any((r) => r != ConnectivityResult.none)) {
        _syncQueue();
      }
    });

    // Initial sync attempt
    _syncQueue();
  }

  static Future<void> queueAttendance({
    required String studentName,
    required String subject,
    required String section,
  }) async {
    final key = '${subject}_${section}_${studentName}_${DateTime.now().millisecondsSinceEpoch}';
    await _queueBox.put(key, {
      'studentName': studentName,
      'subject': subject,
      'section': section,
      'timestamp': DateTime.now().toIso8601String(),
    });
    print('AUTODEMY: Attendance queued offline for $studentName');
  }

  static Future<void> _syncQueue() async {
    if (_isSyncing || _queueBox.isEmpty) return;
    _isSyncing = true;

    final keys = _queueBox.keys.toList();
    print('AUTODEMY: Attempting to sync ${keys.length} offline records...');

    for (var key in keys) {
      final data = _queueBox.get(key);
      try {
        await AttendanceService.syncOfflineRecord(
          studentName: data['studentName'],
          subject: data['subject'],
          section: data['section'],
          timestamp: DateTime.parse(data['timestamp']),
        );
        await _queueBox.delete(key);
        print('AUTODEMY: Synced offline record for ${data['studentName']}');
      } catch (e) {
        print('AUTODEMY: Offline Sync Error for $key: $e');
        // If it's a real error (not just connection), we might want to skip or retry later
        // For now, we stop syncing and wait for next connection change
        break; 
      }
    }
    _isSyncing = false;
  }

  static int get queueCount => _queueBox.length;
}
