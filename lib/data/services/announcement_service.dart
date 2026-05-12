import 'dart:async';
import './api_service.dart';
import './notification_service.dart';

class AnnouncementService {
  // Now using MongoDB Backend via ApiService
  
  static Future<void> publishAnnouncement({
    required String title,
    required String description,
    required String time,
    required String location,
    required DateTime dateTime,
    required List<String> invitedSections,
    required String targetType,
    required String authorName,
    required String authorRole,
  }) async {
    final Map<String, dynamic> data = {
      'title': title,
      'description': description,
      'time': time,
      'location': location,
      'dateTime': dateTime.toIso8601String(),
      'invitedSections': invitedSections,
      'targetType': targetType,
      'authorName': authorName,
      'authorRole': authorRole,
    };

    // Assuming we have a /announcements/publish endpoint in our backend
    await ApiService.post('/announcements/publish', data);

    // Also broadcast via Socket.io for real-time alerts
    String room = invitedSections.contains('ALL') ? 'ALL' : (invitedSections.isNotEmpty ? invitedSections.first : 'ALL');
    NotificationService.simulateNotification(
      'New Announcement: $title',
      description,
      type: 'announcement',
      room: room,
    );
  }

  static Future<List<Map<String, dynamic>>> getAnnouncements(String section) async {
    try {
      final response = await ApiService.get('/announcements?section=$section');
      if (response is List) {
        return response.map((e) => Map<String, dynamic>.from(e)).toList();
      }
      return [];
    } catch (e) {
      print('Error fetching announcements: $e');
      return [];
    }
  }

  static Future<void> deleteAnnouncement(String announcementId) async {
    try {
      await ApiService.delete('/announcements/$announcementId');
    } catch (e) {
      print('Error deleting announcement: $e');
      rethrow;
    }
  }

  static Stream<List<Map<String, dynamic>>> streamAnnouncements(String section) {
    // Create a periodic stream to simulate live updates since we moved from Firestore
    return Stream.periodic(const Duration(seconds: 15))
        .asyncMap((_) => getAnnouncements(section));
  }
}
