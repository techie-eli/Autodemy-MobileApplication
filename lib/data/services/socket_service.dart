import 'package:socket_io_client/socket_io_client.dart' as IO;
import './api_service.dart';

class SocketService {
  static IO.Socket? _socket;

  static IO.Socket get socket {
    if (_socket == null) {
      _init();
    }
    return _socket!;
  }

  static final Set<String> _rooms = {};

  static void _init() {
    final String socketUrl = ApiService.baseUrl.replaceAll('/api', '');
    print('SOCKET: Attempting connection to $socketUrl');

    _socket = IO.io(socketUrl, IO.OptionBuilder()
      .setTransports(['websocket'])
      .enableAutoConnect() // Enable auto-connect
      .setReconnectionAttempts(10)
      .setReconnectionDelay(2000)
      .build());
    
    _socket!.onConnect((_) {
      print('SOCKET: 🟢 Connected to Socket.io Server');
      // Re-join all rooms on reconnect
      for (var room in _rooms) {
        _socket!.emit('join_room', room);
        print('SOCKET: Re-joined room: $room');
      }
    });

    _socket!.onDisconnect((_) => print('SOCKET: 🔴 Disconnected from Server'));
    _socket!.onConnectError((err) => print('SOCKET: ⚠️ Connection Error: $err'));
    _socket!.onReconnect((_) => print('SOCKET: 🔄 Reconnecting...'));
    
    _socket!.connect();
  }

  static void joinRoom(String room) {
    if (room.isEmpty) return;
    _rooms.add(room);
    if (_socket != null && _socket!.connected) {
      _socket!.emit('join_room', room);
      print('SOCKET: Joined room $room');
    } else {
      print('SOCKET: Pending join room $room (waiting for connection)');
    }
  }

  static void leaveRoom(String room) {
    _rooms.remove(room);
    socket.emit('leave_room', room);
  }

  static void onMessage(Function(dynamic) callback) {
    socket.on('receive_message', callback);
  }

  static void offMessage() {
    socket.off('receive_message');
  }

  static void sendNotification(Map<String, dynamic> data) {
    socket.emit('send_notification', data);
  }

  static void onNotification(Function(dynamic) callback) {
    socket.on('receive_notification', callback);
  }
}
