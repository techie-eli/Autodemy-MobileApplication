import 'dart:async';
import './socket_service.dart';

class NotificationService {
  static final StreamController<Map<String, dynamic>> _notificationStream = StreamController<Map<String, dynamic>>.broadcast();
  static final List<Map<String, dynamic>> _history = [];

  static Stream<Map<String, dynamic>> get notifications => _notificationStream.stream;
  static List<Map<String, dynamic>> get history => List.unmodifiable(_history);

  static void simulateNotification(String title, String body, {String? type, String room = 'ALL'}) {
    // Also emit to the real-time socket so other devices receive it!
    SocketService.sendNotification({
      'title': title,
      'body': body,
      'type': type,
      'room': room,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  static void showLocalNotification(String title, String body, {String? type}) {
    _handleIncoming({
      'title': title,
      'body': body,
      'type': type,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  // Called to start listening to the socket for notifications
  static Future<void> initialize() async {
    print('Notification Service Initialized with Socket.io');
    
    // Listen for the standard event
    SocketService.onNotification(_handleIncoming);
    
    // Fallback/Secondary event listener
    SocketService.socket.on('notification', _handleIncoming);
    
    print('Notification listeners registered.');
  }

  static void _handleIncoming(dynamic data) {
    print('RECEIVED NOTIFICATION: $data');
    if (data is Map) {
      final notif = {
        'title': data['title'] ?? 'New Alert',
        'body': data['body'] ?? data['message'] ?? '',
        'type': data['type'],
        'timestamp': data['timestamp'] ?? DateTime.now().toIso8601String(),
      };
      _history.insert(0, notif);
      _notificationStream.add(notif);
    }
  }
}
