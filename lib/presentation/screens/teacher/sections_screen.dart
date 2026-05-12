import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/services/api_service.dart';
import '../../widgets/custom_widgets.dart';
import '../attendance/live_attendance.dart';

class SectionsScreen extends StatefulWidget {
  final String teacherId;
  const SectionsScreen({super.key, required this.teacherId});

  @override
  State<SectionsScreen> createState() => _SectionsScreenState();
}

class _SectionsScreenState extends State<SectionsScreen> {
  bool _isLoading = true;
  List<dynamic> _sections = [];

  @override
  void initState() {
    super.initState();
    _fetchSections();
  }

  Future<void> _fetchSections() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.getSections().timeout(const Duration(seconds: 10));
      if (mounted) {
        setState(() {
          _sections = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Fetch Sections Error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection Error: $e'),
            backgroundColor: Colors.red.shade800,
            action: SnackBarAction(
              label: 'RETRY',
              textColor: Colors.white,
              onPressed: _fetchSections,
            ),
            duration: const Duration(seconds: 10),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          CustomHeader(
            title: 'HANDLED SECTIONS',
            subtitle: 'Select a section to manage',
            showBackButton: true,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchSections,
              color: AppTheme.primary,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _sections.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(24),
                          itemCount: _sections.length,
                          itemBuilder: (context, index) {
                            final section = _sections[index];
                            final name = section['sectionName'] ?? 'Unknown Section';
                            final subject = section['subject'] ?? 'No Subject';
                            
                            return ActionCard(
                              icon: Icons.groups_rounded,
                              title: name,
                              subtitle: subject,
                              onTap: () => _showAttendanceAction(context, name, subject),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.layers_clear_rounded, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text(
              'No sections found or connection error.',
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _fetchSections,
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
              child: const Text('RETRY CONNECTION'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAttendanceAction(BuildContext context, String sectionName, String subject) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 24),
            Text(
              sectionName,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(subject, style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600)),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () async {
                // Extract students from the selected section (Match both name and subject)
                final selectedSection = _sections.firstWhere(
                  (s) => s['sectionName'] == sectionName && s['subject'] == subject,
                  orElse: () => _sections.firstWhere((s) => s['sectionName'] == sectionName)
                );
                final List studentsData = selectedSection['students'] ?? [];
                
                // DEBUG
                debugPrint('=== SECTION DEBUG ===');
                debugPrint('Section: $sectionName | Subject: $subject');
                debugPrint('Students from Section doc: ${studentsData.length}');

                List<String> studentNames = studentsData.map((s) {
                  if (s is Map) return s['name']?.toString() ?? '';
                  return s.toString();
                }).where((n) => n.isNotEmpty && n != 'null').toList().cast<String>();

                // FALLBACK: If section doc has no students, query by User.section field
                if (studentNames.isEmpty) {
                  debugPrint('Section doc empty — fetching via fallback API...');
                  studentNames = await ApiService.getStudentsBySection(sectionName);
                  debugPrint('Fallback returned: $studentNames');
                }

                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LiveAttendanceScreen(
                      targetName: subject,
                      section: sectionName,
                      isEvent: false,
                      teacherId: widget.teacherId,
                      initialStudents: studentNames,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.fact_check_rounded),
              label: const Text('TAKE ATTENDANCE'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: AppTheme.primary,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CANCEL', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
