import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/student_model.dart';
import '../../../data/services/api_service.dart';
import '../../../data/app_data.dart' hide Student;
import '../../widgets/custom_widgets.dart';
import '../messaging/chat_screen.dart';

class StudentConcernsScreen extends StatefulWidget {
  final Student student;
  final Map<String, String>? teacherNames;

  const StudentConcernsScreen({
    super.key, 
    required this.student,
    this.teacherNames,
  });

  @override
  State<StudentConcernsScreen> createState() => _StudentConcernsScreenState();
}

class _StudentConcernsScreenState extends State<StudentConcernsScreen> {
  final _msgCtrl = TextEditingController();
  bool _isLoading = true;
  bool _isSubmitting = false;
  List<dynamic> _concerns = [];
  
  String _recipient = 'System Administrator';
  String _topic = 'Absent Today (Needs Excuse)';
  XFile? _attachedImage;
  Uint8List? _attachedImageBytes;
  bool _isDocumentAttached = false;

  late Map<String, String> _professors;

  @override
  void initState() {
    super.initState();
    _updateProfessors();
    _fetchConcerns();
  }

  @override
  void didUpdateWidget(StudentConcernsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.teacherNames != widget.teacherNames) {
      _updateProfessors();
    }
  }

  void _updateProfessors() {
    setState(() {
      _professors = {
        ...?widget.teacherNames,
      };
      // Ensure default recipient is valid
      if (!_professors.values.contains(_recipient)) {
        _recipient = _professors.values.first;
      }
    });
  }

  Future<void> _fetchConcerns() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.getConcerns();
      if (mounted) {
        setState(() {
          _concerns = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const CustomHeader(
          title: 'STUDENT CONCERNS',
          subtitle: 'Submit excuses or report issues',
        ),
        Expanded(
          child: _isLoading 
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
                children: [
                  const Text(
                    'SUBMIT A CONCERN',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textSecondary, letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 16),
                  _buildForm(),
                  const SizedBox(height: 32),
                  const Text(
                    'MY RECENT CONCERNS',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textSecondary, letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 16),
                  _buildRecentConcerns(),
                ],
              ),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDropdown('Send To Prof:', _recipient, _professors.values.toList(), Icons.person_rounded, (v) => setState(() => _recipient = v!)),
          const SizedBox(height: 16),
          _buildDropdown('Topic:', _topic, [
            'Absent Today (Needs Excuse)',
            'Running Late (Optional Excuse)',
            'Club Activity Excuse',
            'Technical Issue',
            'Others',
          ], Icons.topic_rounded, (v) => setState(() => _topic = v!)),
          const SizedBox(height: 16),
          TextField(
            controller: _msgCtrl,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: 'Message Details',
              labelStyle: const TextStyle(color: AppTheme.primary),
              alignLabelWithHint: true,
              filled: true,
              fillColor: Colors.grey.shade50,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppTheme.primary, width: 2),
              ),
              contentPadding: const EdgeInsets.all(20),
            ),
          ),
          const SizedBox(height: 20),
          _buildAttachmentArea(),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isSubmitting ? null : _submitConcern,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: _isSubmitting 
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('SUBMIT CONCERN', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items, IconData icon, ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppTheme.primary),
        prefixIcon: Icon(icon, color: AppTheme.primary),
        filled: true,
        fillColor: Colors.grey.shade50,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppTheme.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
      items: items.map((v) => DropdownMenuItem(value: v, child: Text(v, style: const TextStyle(fontSize: 14)))).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildAttachmentArea() {
    if (_attachedImage != null) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: _attachedImageBytes != null
                ? Image.memory(_attachedImageBytes!, width: double.infinity, height: 180, fit: BoxFit.cover)
                : Image.file(File(_attachedImage!.path), width: double.infinity, height: 180, fit: BoxFit.cover),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: () => setState(() { _attachedImage = null; _attachedImageBytes = null; _isDocumentAttached = false; }),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                child: const Icon(Icons.close, color: Colors.white, size: 18),
              ),
            ),
          ),
        ],
      );
    }
    return OutlinedButton.icon(
      onPressed: _showImageSourceSheet,
      icon: const Icon(Icons.add_a_photo_rounded),
      label: const Text('Attach Excuse Letter / Image'),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        side: BorderSide(color: Colors.grey.shade300, width: 2),
      ),
    );
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded), 
              title: const Text('Take a Photo'), 
              onTap: () { 
                AppData.preventLock = true;
                Navigator.pop(context); 
                _pickImage(ImageSource.camera); 
              }
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded), 
              title: const Text('Choose from Gallery'), 
              onTap: () { 
                AppData.preventLock = true;
                Navigator.pop(context); 
                _pickImage(ImageSource.gallery); 
              }
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    AppData.preventLock = true;
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source);
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() { _attachedImage = picked; _attachedImageBytes = bytes; _isDocumentAttached = true; });
      }
    } finally {
      // Delay reset to allow app to resume fully from the external activity
      Future.delayed(const Duration(seconds: 1), () {
        AppData.preventLock = false;
      });
    }
  }

  Future<void> _submitConcern() async {
    if (_msgCtrl.text.isEmpty && !_isDocumentAttached) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please provide details.')));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      String? attachmentUrl;
      if (_isDocumentAttached && _attachedImage != null) {
        attachmentUrl = await ApiService.uploadDocument(_attachedImage!.path);
      }

      final success = await ApiService.submitConcern({
        'subject': _topic,
        'category': _topic.contains('Excuse') ? 'Excuse Letter' : 'General Concern',
        'message': _msgCtrl.text.trim(),
        'target': _recipient,
        'attachmentPath': attachmentUrl ?? _attachedImage?.path,
        'attachments': attachmentUrl != null ? [attachmentUrl] : [],
      });

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Concern submitted successfully!'), backgroundColor: Colors.green));
          _msgCtrl.clear();
          setState(() { 
            _attachedImage = null; 
            _attachedImageBytes = null; 
            _isDocumentAttached = false;
            _isSubmitting = false;
          });
          _fetchConcerns();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to submit concern.')));
          setState(() => _isSubmitting = false);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Widget _buildRecentConcerns() {
    if (_concerns.isEmpty) return const Center(child: Text('No concerns submitted yet.', style: TextStyle(color: Colors.grey)));

    return Column(
      children: _concerns.map((c) => _buildConcernTile(c)).toList(),
    );
  }

  Widget _buildConcernTile(dynamic concern) {
    final status = concern['status'] ?? 'PENDING';
    final topic = concern['subject'] ?? 'No Topic';
    final body = concern['message'] ?? '';
    final id = concern['_id'] ?? '';
    final timestamp = concern['createdAt'] != null 
        ? DateTime.parse(concern['createdAt']).toString().split('.')[0]
        : 'Recently';

    Color statusColor = Colors.orange;
    if (status == 'APPROVED') statusColor = Colors.green;
    if (status == 'REJECTED' || status == 'DISAPPROVED') statusColor = Colors.red;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              threadId: id,
              recipientName: concern['target'] ?? 'Support',
              recipientRole: (concern['target'] ?? '').contains('Admin') ? 'System Staff' : 'Teacher',
              currentUserName: widget.student.name,
              initialMessage: body,
              initialTopic: topic,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.chat_bubble_outline_rounded, color: AppTheme.primary, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    body,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(timestamp, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(status, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, size: 18, color: Colors.grey.shade300),
          ],
        ),
      ),
    );
  }
}
