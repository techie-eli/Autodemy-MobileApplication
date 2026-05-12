import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../data/services/api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../widgets/custom_widgets.dart';

class RequestSupportScreen extends StatefulWidget {
  final String senderName;
  final String senderRole; // 'Admin', 'Teacher', 'Student'
  final bool embedded;

  const RequestSupportScreen({
    super.key,
    required this.senderName,
    required this.senderRole,
    this.embedded = false,
  });

  @override
  State<RequestSupportScreen> createState() => _RequestSupportScreenState();
}

class _RequestSupportScreenState extends State<RequestSupportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subjectCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  bool _isSending = false;

  String _selectedCategory = 'Technical Issue';
  final List<String> _categories = [
    'Technical Issue',
    'Login / Access Problem',
    'Attendance Error',
    'Data Request',
    'Feature Request',
    'Other',
  ];

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitConcern() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSending = true);

    try {
      final success = await ApiService.submitConcern({
        'subject': _subjectCtrl.text.trim(),
        'category': _selectedCategory,
        'message': _messageCtrl.text.trim(),
      });

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Your concern has been submitted successfully!'),
              backgroundColor: AppTheme.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
          // Go back or reset form
          if (!widget.embedded) {
            Navigator.pop(context);
          } else {
            _subjectCtrl.clear();
            _messageCtrl.clear();
            _formKey.currentState!.reset();
          }
        } else {
          _showError('Failed to submit concern. Please try again.');
        }
      }
    } catch (e) {
      _showError('Error: $e');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = Column(
      children: [
        if (!widget.embedded)
          CustomHeader(
            title: 'REQUEST SUPPORT',
            subtitle: 'Autodemy Support Team',
            showBackButton: true,
          ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info Banner
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primary.withOpacity(0.08),
                          AppTheme.accent.withOpacity(0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.primary.withOpacity(0.15)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.support_agent_rounded,
                              color: AppTheme.primary, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Autodemy Support',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primary,
                                ),
                              ),
                              Text(
                                'Sending as ${widget.senderName} (${widget.senderRole})',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Category Dropdown
                  const Text(
                    'CATEGORY',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textSecondary,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _selectedCategory,
                        items: _categories
                            .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                            .toList(),
                        onChanged: (v) => setState(() => _selectedCategory = v!),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Subject
                  const Text(
                    'SUBJECT',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textSecondary,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _subjectCtrl,
                    decoration: InputDecoration(
                      hintText: 'Brief description of the issue...',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppTheme.primary, width: 2),
                      ),
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Subject is required.' : null,
                  ),

                  const SizedBox(height: 20),

                  // Message
                  const Text(
                    'MESSAGE',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textSecondary,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _messageCtrl,
                    maxLines: 5,
                    decoration: InputDecoration(
                      hintText: 'Describe your concern in detail...',
                      filled: true,
                      fillColor: Colors.white,
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppTheme.primary, width: 2),
                      ),
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Message is required.' : null,
                  ),

                  const SizedBox(height: 32),

                  // Send Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _isSending ? null : _submitConcern,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        disabledBackgroundColor: Colors.grey.shade300,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      icon: _isSending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded, color: Colors.white),
                      label: Text(
                        _isSending ? 'Submitting...' : 'SUBMIT CONCERN',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Direct email info
                  Center(
                    child: Text(
                      'Or email us directly at:\nautodemy.support@gmail.com',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );

    if (widget.embedded) return body;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: body,
    );
  }
}
