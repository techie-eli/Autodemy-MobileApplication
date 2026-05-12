import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/services/api_service.dart';
import '../../../data/services/notification_service.dart';
import '../../../data/services/socket_service.dart';

/// A single chat message in a thread.
class ChatMessage {
  final String sender;
  final String body;
  final DateTime time;
  final bool isMe;
  final String? attachmentPath;

  ChatMessage({
    required this.sender,
    required this.body,
    required this.time,
    required this.isMe,
    this.attachmentPath,
  });

  String get formattedTime {
    int h = time.hour % 12;
    if (h == 0) h = 12;
    return "$h:${time.minute.toString().padLeft(2, '0')} ${time.hour >= 12 ? 'PM' : 'AM'}";
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map, String currentUserId) {
    return ChatMessage(
      sender: map['senderName'] ?? 'Unknown',
      body: map['body'] ?? '',
      time: DateTime.parse(map['timestamp']),
      isMe: map['sender'] == currentUserId,
      attachmentPath: map['attachmentPath'],
    );
  }
}

/// Premium chat screen for concern threads.
class ChatScreen extends StatefulWidget {
  final String threadId;
  final String recipientName;
  final String recipientRole;
  final String currentUserName;
  final String? initialMessage;
  final String? initialTopic;

  const ChatScreen({
    super.key,
    required this.threadId,
    required this.recipientName,
    required this.recipientRole,
    required this.currentUserName,
    this.initialMessage,
    this.initialTopic,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  List<ChatMessage> _messages = [];
  Timer? _pollTimer;
  bool _isLoading = true;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (image == null) return;

    setState(() => _isLoading = true);
    
    try {
      // 1. Upload to server first
      final String? uploadedUrl = await ApiService.uploadDocument(image.path);
      
      if (uploadedUrl != null) {
        // 2. Send message with the official URL
        final success = await ApiService.sendMessage({
          'threadId': widget.threadId,
          'body': '[Image Attached]',
          'attachmentPath': uploadedUrl, // Official network path
        });

        if (success) {
          _fetchHistory(silent: true);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to upload image.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchHistory();
    SocketService.joinRoom(widget.threadId);
    SocketService.onMessage((data) {
      if (mounted) {
        _fetchHistory(silent: true);
      }
    });
  }

  Future<void> _fetchHistory({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    try {
      final currentUserId = (await ApiService.getUserData())?['id'];
      if (currentUserId == null) return;

      final history = await ApiService.getChatHistory(widget.threadId);
      final newMessages = history.map((m) => ChatMessage.fromMap(m, currentUserId)).toList();
      
      if (mounted && newMessages.length != _messages.length) {
        setState(() {
          _messages = newMessages;
          _isLoading = false;
        });
        _scrollToBottom();
      } else if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Chat History Error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    SocketService.offMessage();
    SocketService.leaveRoom(widget.threadId);
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    _pollTimer?.cancel();
    super.dispose();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;

    _msgCtrl.clear();
    
    final success = await ApiService.sendMessage({
      'threadId': widget.threadId,
      'body': text,
    });

    if (success) {
      NotificationService.simulateNotification(
        'Message Sent',
        'Your reply to ${widget.recipientName} was delivered.',
        type: 'chat'
      );
      _fetchHistory(silent: true);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send message.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // Topic banner
          if (widget.initialTopic != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              color: AppTheme.primary.withValues(alpha: 0.05),
              child: Row(
                children: [
                  Icon(Icons.topic_rounded, size: 16, color: AppTheme.primary.withValues(alpha: 0.6)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.initialTopic!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primary.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Messages list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        controller: _scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final showAvatar = index == 0 ||
                          _messages[index - 1].isMe != msg.isMe;
                      return _buildMessageBubble(msg, showAvatar);
                    },
                  ),
          ),

          // Input area
          _buildInputArea(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppTheme.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      leadingWidth: 40,
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                widget.recipientName[0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.recipientName,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  widget.recipientRole,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.chat_bubble_outline_rounded, size: 48, color: AppTheme.primary.withValues(alpha: 0.4)),
          ),
          const SizedBox(height: 20),
          Text(
            'Start a conversation',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Send a message to ${widget.recipientName}',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg, bool showAvatar) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: 8,
        left: msg.isMe ? 48 : 0,
        right: msg.isMe ? 0 : 48,
      ),
      child: Row(
        mainAxisAlignment: msg.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!msg.isMe && showAvatar)
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  msg.sender[0].toUpperCase(),
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            )
          else if (!msg.isMe)
            const SizedBox(width: 40),

          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: msg.isMe ? AppTheme.primary : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(msg.isMe ? 20 : 4),
                  bottomRight: Radius.circular(msg.isMe ? 4 : 20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (msg.attachmentPath != null) ...[
                    GestureDetector(
                      onTap: () {
                        final String path = msg.attachmentPath!;
                        final bool isNetwork = path.startsWith('http');
                        final String imageUrl = isNetwork 
                            ? path 
                            : (path.startsWith('/') 
                                ? '${ApiService.baseUrl.replaceAll('/api', '')}$path'
                                : '${ApiService.baseUrl.replaceAll('/api', '')}/$path');

                        showDialog(
                          context: context,
                          builder: (ctx) => Dialog.fullscreen(
                            backgroundColor: Colors.black,
                            child: Stack(
                              children: [
                                Center(
                                  child: isNetwork || path.startsWith('/') || path.contains('uploads')
                                    ? Image.network(imageUrl, fit: BoxFit.contain)
                                    : Image.file(File(path), fit: BoxFit.contain),
                                ),
                                Positioned(
                                  top: 40,
                                  right: 20,
                                  child: IconButton(
                                    icon: const Icon(Icons.close, color: Colors.white, size: 30),
                                    onPressed: () => Navigator.pop(ctx),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Builder(
                          builder: (context) {
                            final String path = msg.attachmentPath!;
                            final bool isNetwork = path.startsWith('http');
                            
                            if (isNetwork) {
                              return Image.network(
                                path,
                                width: 200,
                                fit: BoxFit.cover,
                                errorBuilder: (ctx, err, stack) => const Icon(Icons.broken_image_rounded, color: Colors.grey),
                              );
                            } else if (path.startsWith('/') || path.startsWith('uploads')) {
                              final String fullPath = path.startsWith('/') ? path : '/$path';
                              return Image.network(
                                '${ApiService.baseUrl.replaceAll('/api', '')}$fullPath',
                                width: 200,
                                fit: BoxFit.cover,
                                errorBuilder: (ctx, err, stack) => const Icon(Icons.broken_image_rounded, color: Colors.grey),
                              );
                            } else {
                              return Image.file(
                                File(path),
                                width: 200,
                                fit: BoxFit.cover,
                                errorBuilder: (ctx, err, stack) => const Icon(Icons.broken_image_rounded, color: Colors.grey),
                              );
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (msg.body.isNotEmpty && msg.body != '[Image Attached]')
                    Text(
                      msg.body,
                      style: TextStyle(
                        fontSize: 14,
                        color: msg.isMe ? Colors.white : AppTheme.textPrimary,
                        height: 1.4,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        msg.formattedTime,
                        style: TextStyle(
                          fontSize: 10,
                          color: msg.isMe
                              ? Colors.white.withValues(alpha: 0.6)
                              : Colors.grey.shade400,
                        ),
                      ),
                      if (msg.isMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.done_all_rounded,
                          size: 14,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(12, 8, 12, 8 + bottomPadding),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Attachment button
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(14),
            ),
            child: IconButton(
              icon: Icon(Icons.attach_file_rounded, color: Colors.grey.shade500, size: 22),
              onPressed: _pickImage,
            ),
          ),
          const SizedBox(width: 8),

          // Text field
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _msgCtrl,
                textCapitalization: TextCapitalization.sentences,
                maxLines: null,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Send button
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1A237E), Color(0xFF3949AB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
    );
  }
}
