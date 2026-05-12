import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../widgets/custom_widgets.dart';
import '../../../data/services/api_service.dart';
import '../../../data/app_data.dart';
import '../messaging/chat_screen.dart';

class TeacherConcernsScreen extends StatefulWidget {
  const TeacherConcernsScreen({super.key});

  @override
  State<TeacherConcernsScreen> createState() => _TeacherConcernsScreenState();
}

class _TeacherConcernsScreenState extends State<TeacherConcernsScreen> {
  bool _isLoading = true;
  List<dynamic> _concerns = [];
  String _teacherName = 'Teacher';

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _fetchConcerns();
  }

  Future<void> _loadProfile() async {
    final data = await ApiService.getUserData();
    if (data != null && mounted) {
      setState(() {
        _teacherName = data['name'] ?? 'Teacher';
      });
    }
  }

  Future<void> _fetchConcerns() async {
    setState(() => _isLoading = true);
    try {
      // Use the teacher-specific endpoint that filters by teacher name
      final apiData = await ApiService.get('/teacher/concerns');

      // Merge with local data (if any exist)
      final List<dynamic> localData = AppData.teacherNotifs.map((m) => <String, dynamic>{
        '_id': m.id,
        'status': m.status,
        'student': <String, dynamic>{'name': m.sender},
        'message': m.body,
        'createdAt': m.time.toIso8601String(),
        'attachmentPath': m.attachmentPath,
      }).toList();

      if (mounted) {
        setState(() {
          _concerns = [...localData, ...?apiData];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          const CustomHeader(
            title: 'STUDENT CONCERNS',
            subtitle: 'Review excuse letters & requests',
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _concerns.isEmpty 
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
                        itemCount: _concerns.length,
                        itemBuilder: (context, index) {
                          final concern = _concerns[index];
                          return _buildConcernCard(context, concern);
                        },
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
          Icon(Icons.mark_email_read_rounded, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text('No pending concerns from students.', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildConcernCard(BuildContext context, dynamic concern) {
    final status = concern['status'] ?? 'PENDING';
    final student = concern['student'] != null ? concern['student']['name'] : 'Unknown Student';
    final body = concern['message'] ?? 'No content';
    
    Color statusColor = Colors.orange;
    if (status == 'APPROVED') statusColor = Colors.green;
    if (status == 'REJECTED' || status == 'DISAPPROVED') statusColor = Colors.red;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _viewConcernDetails(context, concern),
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.description_rounded, color: AppTheme.primary),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(student, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text(body, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: Text(status, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _viewConcernDetails(BuildContext context, dynamic concern) {
    final String id = concern['_id'] ?? '';
    final String status = concern['status'] ?? 'PENDING';
    final studentData = concern['student'] ?? {};
    final String studentName = studentData['name'] ?? 'Student';
    final String body = concern['message'] ?? '';
    final String timestamp = concern['createdAt'] != null 
        ? DateTime.parse(concern['createdAt']).toString().split('.')[0]
        : 'Recently';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(32),
            child: SingleChildScrollView(
              child: Builder(
                builder: (ctx) {
                  final dynamic rawPath = concern['attachmentPath'] ?? (concern['attachments'] is List && concern['attachments'].isNotEmpty ? concern['attachments'][0] : null);
                  
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(studentName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      Text(timestamp, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                  IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close_rounded)),
                ],
              ),
              const Divider(height: 40),
              
              const Text('MESSAGE CONTENT:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textSecondary, letterSpacing: 1)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(16)),
                child: Text(body, style: const TextStyle(fontSize: 14, height: 1.6)),
              ),
              const SizedBox(height: 24),

              // Check for attachments (handle both string attachmentPath and list attachments)
              if (rawPath != null && rawPath.toString().isNotEmpty) ...[
                const Text('ATTACHMENT:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textSecondary, letterSpacing: 1)),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () {
                    final String path = rawPath.toString();
                    final bool isNetwork = path.startsWith('http');
                    
                    showDialog(
                      context: context,
                      builder: (dialogCtx) => Dialog.fullscreen(
                        backgroundColor: Colors.black,
                        child: Stack(
                          children: [
                            Center(
                              child: isNetwork 
                                ? Image.network(
                                    path, 
                                    loadingBuilder: (ctx, child, progress) => progress == null ? child : const CircularProgressIndicator(color: Colors.white),
                                    errorBuilder: (ctx, err, stack) => const Icon(Icons.broken_image, color: Colors.white, size: 50),
                                  )
                                : (path.startsWith('/') 
                                    ? Image.network(
                                        '${ApiService.baseUrl.replaceAll('/api', '')}$path',
                                        loadingBuilder: (ctx, child, progress) => progress == null ? child : const CircularProgressIndicator(color: Colors.white),
                                        errorBuilder: (ctx, err, stack) => const Icon(Icons.broken_image, color: Colors.white, size: 50),
                                      )
                                    : Image.file(File(path), errorBuilder: (ctx, err, stack) => const Icon(Icons.broken_image, color: Colors.white, size: 50))),
                            ),
                            Positioned(
                              top: 40,
                              right: 20,
                              child: IconButton(
                                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                                onPressed: () => Navigator.pop(dialogCtx),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Builder(
                      builder: (context) {
                        final String path = rawPath.toString();
                        final bool isNetwork = path.startsWith('http');
                        
                        if (isNetwork) {
                          return Image.network(
                            path,
                            width: double.infinity,
                            height: 200,
                            fit: BoxFit.cover,
                            loadingBuilder: (ctx, child, progress) => progress == null ? child : Container(height: 200, color: Colors.grey.shade100, child: const Center(child: CircularProgressIndicator())),
                            errorBuilder: (ctx, err, stack) => _buildErrorAttachment(),
                          );
                        } else if (path.startsWith('/')) {
                          // Handle relative path from backend
                          return Image.network(
                            '${ApiService.baseUrl.replaceAll('/api', '')}$path',
                            width: double.infinity,
                            height: 200,
                            fit: BoxFit.cover,
                            loadingBuilder: (ctx, child, progress) => progress == null ? child : Container(height: 200, color: Colors.grey.shade100, child: const Center(child: CircularProgressIndicator())),
                            errorBuilder: (ctx, err, stack) => _buildErrorAttachment(),
                          );
                        } else {
                          return Image.file(
                            File(path),
                            width: double.infinity,
                            height: 200,
                            fit: BoxFit.cover,
                            errorBuilder: (ctx, err, stack) => _buildErrorAttachment(),
                          );
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Message button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          threadId: id,
                          recipientName: studentName,
                          recipientRole: 'Student',
                          currentUserName: _teacherName,
                          initialMessage: body,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.chat_rounded),
                  label: const Text('OPEN CHAT', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    side: const BorderSide(color: AppTheme.primary, width: 1.5),
                    minimumSize: const Size(0, 52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              
              const Text('UPDATE DECISION:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textSecondary, letterSpacing: 1)),
              const SizedBox(height: 12),
              Row(
                children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _updateStatus(id, 'REJECTED'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          minimumSize: const Size(0, 52),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text('REJECT', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _updateStatus(id, 'APPROVED'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(0, 52),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text('APPROVE', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    ),
  ),
);
}

  void _updateStatus(String id, String status) async {
    final success = await ApiService.updateConcernStatus(id, status);
    if (success) {
      _fetchConcerns();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Request $status'), backgroundColor: status == 'APPROVED' ? Colors.green : Colors.red));
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update status.')));
      }
    }
  }

  Widget _buildErrorAttachment() {
    return Container(
      height: 80,
      width: double.infinity,
      color: Colors.red.shade50,
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image_rounded, color: Colors.red),
          SizedBox(height: 4),
          Text('Attachment unavailable', style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
