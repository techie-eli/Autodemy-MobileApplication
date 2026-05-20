import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../widgets/custom_widgets.dart';
import '../../../data/services/report_service.dart';
import '../../../data/services/api_service.dart';

class AttendanceHistoryScreen extends StatefulWidget {
  final String teacherId;
  const AttendanceHistoryScreen({super.key, required this.teacherId});

  @override
  State<AttendanceHistoryScreen> createState() => _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  String? _selectedSection;
  DateTime? _selectedDate;

  List<String> _sections = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSections();
  }

  Future<void> _fetchSections() async {
    try {
      final data = await ApiService.getSections();
      if (mounted) {
        setState(() {
          _sections = data.map((s) => s['sectionName'].toString()).toList();
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
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          CustomHeader(
            title: 'ATTENDANCE HISTORY',
            subtitle: _selectedSection == null
                ? 'Select a section'
                : 'Section $_selectedSection',
            showBackButton: true,
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _sections.isEmpty
                    ? const Center(
                        child: Text('No sections available.',
                            style: TextStyle(color: Colors.grey)))
                    : _selectedSection == null
                        ? _buildSectionList()
                        : _buildHistoryView(),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionList() {
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _sections.length,
      itemBuilder: (context, index) {
        return ActionCard(
          icon: Icons.groups_rounded,
          title: _sections[index],
          subtitle: 'View history for this group',
          onTap: () => _fetchHistory(_sections[index]),
        );
      },
    );
  }

  List<dynamic> _historyRecords = [];

  Future<void> _fetchHistory(String section) async {
    setState(() {
      _selectedSection = section;
      _isLoading = true;
    });

    try {
      final records = await ApiService.getTeacherAttendanceHistory(section);
      if (mounted) {
        setState(() {
          _historyRecords = records;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ─────────────────────────────────────────────────────────────
  // FIX: Helper to resolve the student name regardless of key
  // ─────────────────────────────────────────────────────────────
  String _resolveStudentName(Map<dynamic, dynamic> r) {
    // Debug: print all keys so you can confirm which one carries the name
    debugPrint('=== RECORD KEYS: ${r.keys.toList()} ===');
    debugPrint('=== RECORD DATA: $r ===');

    // Try every common key variant; add more here if needed
    for (final key in ['studentName', 'name', 'student_name', 'fullName', 'full_name']) {
      final value = r[key];
      if (value != null && value.toString().isNotEmpty && value.toString() != 'null') {
        return value.toString();
      }
    }

    // Nested student object: { student: { name: '...' } }
    final nested = r['student'];
    if (nested is Map) {
      for (final key in ['name', 'fullName', 'studentName']) {
        final value = nested[key];
        if (value != null && value.toString().isNotEmpty) {
          return value.toString();
        }
      }
    }

    return 'Unknown';
  }

  // ─────────────────────────────────────────────────────────────
  // FIX: Helper to resolve the timestamp without double-shifting
  // ─────────────────────────────────────────────────────────────
  DateTime? _resolveTimestamp(Map<dynamic, dynamic> r) {
    // Try common timestamp key variants
    for (final key in ['timestamp', 'timeIn', 'time_in', 'timein', 'createdAt', 'created_at']) {
      final raw = r[key];
      if (raw == null) continue;

      try {
        final parsed = DateTime.parse(raw.toString());

        // If the stored string already contains a timezone offset (e.g. +08:00)
        // or ends with 'Z', DateTime.parse handles it correctly. Calling
        // .toLocal() on top is safe because Dart will only shift when needed.
        //
        // If the value was saved WITHOUT a timezone marker (plain local time),
        // .toLocal() would double-shift it. In that case we treat it as-is.
        if (raw.toString().endsWith('Z') || raw.toString().contains('+')) {
          return parsed.toLocal(); // Has UTC marker → safe to localise
        } else {
          return parsed; // Already local / no marker → use as-is
        }
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '--:--';
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  Widget _buildHistoryView() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: InkWell(
            onTap: _selectDate,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: AppTheme.primary.withOpacity(0.2), width: 1.5),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_rounded,
                      color: AppTheme.primary),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('SEARCH BY DATE',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textSecondary,
                                letterSpacing: 1)),
                        const SizedBox(height: 4),
                        Text(
                          _selectedDate == null
                              ? 'Select a date to view logs'
                              : '${_selectedDate!.month}/${_selectedDate!.day}/${_selectedDate!.year}',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.search_rounded, color: AppTheme.primary),
                ],
              ),
            ),
          ),
        ),
        if (_selectedDate != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
            child: ElevatedButton.icon(
              onPressed: () {
                if (_selectedDate == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text(
                            'Please select a date first to download the report.')),
                  );
                  return;
                }

                final sessionForDate = _historyRecords.firstWhere(
                  (s) {
                    final st =
                        DateTime.parse(s['startTime'].toString()).toLocal();
                    return st.year == _selectedDate!.year &&
                        st.month == _selectedDate!.month &&
                        st.day == _selectedDate!.day;
                  },
                  orElse: () => null,
                );

                if (sessionForDate == null ||
                    sessionForDate['records'] == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content:
                            Text('No records found for the selected date.')),
                  );
                  return;
                }

                final List<dynamic> rawRecords = sessionForDate['records'];

                // ── FIX applied to PDF report generation ──────────────────
                final List<Map<String, dynamic>> formattedRecords =
                    rawRecords.map((r) {
                  final timeDt = _resolveTimestamp(r as Map<dynamic, dynamic>);
                  return {
                    'studentName': _resolveStudentName(r),
                    'status': r['status'] ?? 'N/A',
                    'timein': _formatTime(timeDt),
                  };
                }).toList();

                ReportService.generateAttendanceReport(
                  teacherName: 'Teacher (${widget.teacherId})',
                  section: _selectedSection!,
                  records: formattedRecords,
                );
              },
              icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white),
              label: const Text('DOWNLOAD PDF REPORT',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _historyRecords.isEmpty
                  ? _buildEmptyState(
                      'No attendance logs found for this section.')
                  : _selectedDate == null
                      ? _buildHistoryList()
                      : _buildLogsList(),
        ),
      ],
    );
  }

  Widget _buildHistoryList() {
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _historyRecords.length,
      itemBuilder: (context, index) {
        final session = _historyRecords[index];
        final start =
            DateTime.parse(session['startTime'].toString()).toLocal();
        final dateStr = '${start.month}/${start.day}/${start.year}';
        final timeStr = _formatTime(start);
        final count = (session['records'] as List?)?.length ?? 0;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.02), blurRadius: 10)
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  shape: BoxShape.circle),
              child: const Icon(Icons.calendar_today_rounded,
                  color: AppTheme.primary, size: 20),
            ),
            title: Text(dateStr,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16)),
            subtitle: Text('Started at $timeStr • $count Students',
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
            trailing: const Icon(Icons.arrow_forward_ios_rounded,
                size: 16, color: Colors.grey),
            onTap: () {
              setState(() => _selectedDate = start);
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_toggle_off_rounded,
              size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildLogsList() {
    if (_selectedDate == null) return const SizedBox.shrink();

    final sessionForDate = _historyRecords.firstWhere(
      (s) {
        final st = DateTime.parse(s['startTime'].toString()).toLocal();
        return st.year == _selectedDate!.year &&
            st.month == _selectedDate!.month &&
            st.day == _selectedDate!.day;
      },
      orElse: () => null,
    );

    if (sessionForDate == null ||
        sessionForDate['records'] == null ||
        (sessionForDate['records'] as List).isEmpty) {
      return _buildEmptyState('No attendance logs found for this date.');
    }

    final records = sessionForDate['records'] as List<dynamic>;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: records.map((r) {
        final record = r as Map<dynamic, dynamic>;

        // ── FIX: use helpers instead of raw key access ─────────────
        final studentName = _resolveStudentName(record);
        final timeDt = _resolveTimestamp(record);
        final timeStr = _formatTime(timeDt);

        Color statusColor = Colors.grey;
        final status = record['status']?.toString() ?? '';
        if (status == 'present') statusColor = Colors.green;
        else if (status == 'late') statusColor = Colors.orange;
        else if (status == 'absent') statusColor = Colors.red;

        return _buildHistoryTile(
          studentName,
          timeStr,
          status.toUpperCase().isEmpty ? 'UNKNOWN' : status.toUpperCase(),
          statusColor,
        );
      }).toList(),
    );
  }

  Widget _buildHistoryTile(
      String name, String time, String status, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 4,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(name,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 14)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(status,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: color)),
              Text(time,
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2025),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }
}