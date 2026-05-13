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
            subtitle: _selectedSection == null ? 'Select a section' : 'Section $_selectedSection',
            showBackButton: true,
          ),
          Expanded(
            child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : _sections.isEmpty
                    ? const Center(child: Text('No sections available.', style: TextStyle(color: Colors.grey)))
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
                border: Border.all(color: AppTheme.primary.withOpacity(0.2), width: 1.5),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, color: AppTheme.primary),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('SEARCH BY DATE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textSecondary, letterSpacing: 1)),
                        const SizedBox(height: 4),
                        Text(
                          _selectedDate == null ? 'Select a date to view logs' : '${_selectedDate!.month}/${_selectedDate!.day}/${_selectedDate!.year}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
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
                        const SnackBar(content: Text('Please select a date first to download the report.')),
                      );
                      return;
                    }

                    // Find the session for the selected date
                    final sessionForDate = _historyRecords.firstWhere(
                      (s) {
                        final st = DateTime.parse(s['startTime'].toString()).toLocal();
                        return st.year == _selectedDate!.year && st.month == _selectedDate!.month && st.day == _selectedDate!.day;
                      },
                      orElse: () => null,
                    );

                    if (sessionForDate == null || sessionForDate['records'] == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('No records found for the selected date.')),
                      );
                      return;
                    }

                    final List<dynamic> rawRecords = sessionForDate['records'];
                    final List<Map<String, dynamic>> formattedRecords = rawRecords.map((r) {
                      final timeDt = r['timestamp'] != null ? DateTime.parse(r['timestamp'].toString()).toLocal() : null;
                      final timeStr = timeDt != null 
                          ? '${timeDt.hour % 12 == 0 ? 12 : timeDt.hour % 12}:${timeDt.minute.toString().padLeft(2, '0')} ${timeDt.hour >= 12 ? 'PM' : 'AM'}'
                          : 'N/A';
                      
                      return {
                        'studentName': r['name'] ?? 'Unknown',
                        'status': r['status'] ?? 'N/A',
                        'timein': timeStr,
                      };
                    }).toList();

                    ReportService.generateAttendanceReport(
                      teacherName: 'Teacher (${widget.teacherId})',
                      section: _selectedSection!,
                      records: formattedRecords,
                    );
                  },
              icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white),
              label: const Text('DOWNLOAD PDF REPORT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        Expanded(
          child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _historyRecords.isEmpty
                  ? _buildEmptyState('No attendance logs found for this section.')
                  : _selectedDate == null 
                      ? _buildHistoryList() // Show list of dates
                      : _buildLogsList(),   // Show specific students for selected date
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
        final start = DateTime.parse(session['startTime'].toString()).toLocal();
        final dateStr = '${start.month}/${start.day}/${start.year}';
        final timeStr = '${start.hour % 12 == 0 ? 12 : start.hour % 12}:${start.minute.toString().padLeft(2, '0')} ${start.hour >= 12 ? 'PM' : 'AM'}';
        final count = (session['records'] as List?)?.length ?? 0;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.calendar_today_rounded, color: AppTheme.primary, size: 20),
            ),
            title: Text(dateStr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            subtitle: Text('Started at $timeStr • $count Students', style: const TextStyle(color: Colors.grey, fontSize: 12)),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
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
          Icon(Icons.history_toggle_off_rounded, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildLogsList() {
    if (_selectedDate == null) return const SizedBox.shrink();

    // Find the session for the selected date
    final sessionForDate = _historyRecords.firstWhere(
      (s) {
        final st = DateTime.parse(s['startTime'].toString()).toLocal();
        return st.year == _selectedDate!.year && st.month == _selectedDate!.month && st.day == _selectedDate!.day;
      },
      orElse: () => null,
    );

    if (sessionForDate == null || sessionForDate['records'] == null || (sessionForDate['records'] as List).isEmpty) {
      return _buildEmptyState('No attendance logs found for this date.');
    }

    final records = sessionForDate['records'] as List<dynamic>;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: records.map((r) {
        final timeDt = r['timestamp'] != null ? DateTime.parse(r['timestamp'].toString()).toLocal() : null;
        final timeStr = timeDt != null 
            ? '${timeDt.hour % 12 == 0 ? 12 : timeDt.hour % 12}:${timeDt.minute.toString().padLeft(2, '0')} ${timeDt.hour >= 12 ? 'PM' : 'AM'}' 
            : '--:--';
        
        Color statusColor = Colors.grey;
        if (r['status'] == 'present') statusColor = Colors.green;
        else if (r['status'] == 'late') statusColor = Colors.orange;
        else if (r['status'] == 'absent') statusColor = Colors.red;

        return _buildHistoryTile(r['studentName'] ?? 'Unknown', timeStr, r['status']?.toString().toUpperCase() ?? 'UNKNOWN', statusColor);
      }).toList(),
    );
  }

  Widget _buildHistoryTile(String name, String time, String status, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(status, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: color)),
              Text(time, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
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
