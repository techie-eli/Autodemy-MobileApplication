import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/services/api_service.dart';
import '../../widgets/custom_widgets.dart';

class ReportModuleScreen extends StatefulWidget {
  final bool embedded;
  final String? userRole;
  const ReportModuleScreen({super.key, this.embedded = false, this.userRole});

  @override
  State<ReportModuleScreen> createState() => _ReportModuleScreenState();
}

class _ReportModuleScreenState extends State<ReportModuleScreen> {
  String? _selectedYear;
  String? _selectedStrand;
  String? _selectedGrade;
  
  List<String> _academicYears = [];
  List<dynamic> _allSections = [];
  List<dynamic> _filteredSections = [];
  List<String> _dynamicStrands = [];
  bool _isLoadingData = true;
  final List<String> _grades = ['Grade 11', 'Grade 12'];

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    try {
      final years = await ApiService.getAcademicYears();
      final sections = await ApiService.getSections();
      if (mounted) {
        setState(() {
          _academicYears = years.map((y) => y['year'].toString()).toList();
          _allSections = sections;
          _isLoadingData = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingData = false);
    }
  }

  void _updateDynamicStrands() {
    if (_selectedYear == null) {
      _dynamicStrands = [];
      return;
    }
    
    setState(() {
      _dynamicStrands = _allSections
          .where((s) => s['academicYear'] == _selectedYear)
          .map((s) => s['strand']?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toSet().toList();
    });
  }

  void _filterSections() {
    setState(() {
      _filteredSections = _allSections.where((s) {
        return s['academicYear'] == _selectedYear &&
               s['strand'] == _selectedStrand &&
               s['level'] == _selectedGrade;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final body = Column(
      children: [
        // ── Blue Header Cap for consistency
        Container(
          height: MediaQuery.of(context).padding.top + 32,
          width: double.infinity,
          decoration: const BoxDecoration(
            color: AppTheme.primary,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(32),
              bottomRight: Radius.circular(32),
            ),
          ),
        ),
        if (!widget.embedded) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('CAMPUS REPORTS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppTheme.textSecondary, letterSpacing: 1.5)),
                    Text('Report Module', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.analytics_rounded, color: AppTheme.primary),
                ),
              ],
            ),
          ),
        ],
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.embedded) const SizedBox(height: 16),
                _buildStepIndicator(),
                const SizedBox(height: 32),
                
                if (_selectedYear == null) ...[
                  _buildSectionTitle('1. Select Academic Year'),
                  if (_isLoadingData)
                    const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
                  else if (_academicYears.isEmpty)
                    const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('No academic years found. Add one in Admin Panel.', style: TextStyle(color: Colors.grey))))
                  else
                    ..._academicYears.map((year) => ActionCard(
                          icon: Icons.calendar_month_rounded,
                          title: year,
                          subtitle: 'View reports for SY $year',
                          onTap: () {
                            setState(() => _selectedYear = year);
                            _updateDynamicStrands();
                          },
                        )),
                ] else if (_selectedStrand == null) ...[
                  _buildSectionTitle('2. Select Strand'),
                  if (_dynamicStrands.isEmpty)
                    const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('No strands found in current sections.', style: TextStyle(color: Colors.grey))))
                  else
                    ..._dynamicStrands.map((strand) => ActionCard(
                          icon: Icons.school_rounded,
                          title: strand,
                          subtitle: 'Academic Track',
                          onTap: () => setState(() => _selectedStrand = strand),
                        )),
                ] else if (_selectedGrade == null) ...[
                  _buildSectionTitle('3. Select Grade Level'),
                  ..._grades.map((grade) => ActionCard(
                        icon: Icons.stairs_rounded,
                        title: grade,
                        subtitle: 'Senior High School',
                        onTap: () {
                          setState(() => _selectedGrade = grade);
                          _filterSections();
                        },
                      )),
                ] else ...[
                  _buildSectionTitle('4. Section List'),
                  if (_filteredSections.isEmpty)
                    const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('No sections found for this selection.', style: TextStyle(color: Colors.grey))))
                  else
                    ..._filteredSections.map((section) => ActionCard(
                          icon: Icons.class_rounded,
                          title: section['sectionName'] ?? 'Unknown Section',
                          subtitle: '${section['subject'] ?? ''}',
                          onTap: () => _generateReport(section['sectionName'] ?? ''),
                        )),
                ],
              ],
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

  Widget _buildStepIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          _buildStep('Year', _selectedYear != null),
          _buildDivider(),
          _buildStep('Strand', _selectedStrand != null),
          _buildDivider(),
          _buildStep('Grade', _selectedGrade != null),
          _buildDivider(),
          _buildStep('Section', false),
        ],
      ),
    );
  }

  Widget _buildStep(String label, bool isComplete) {
    return Column(
      children: [
        Icon(
          isComplete ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
          color: isComplete ? AppTheme.success : Colors.grey.shade400,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: isComplete ? AppTheme.textPrimary : Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        color: Colors.grey.shade200,
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.textSecondary,
                letterSpacing: 1.2,
              ),
            ),
          ),
          if (_selectedYear != null)
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _selectedYear = null;
                  _selectedStrand = null;
                  _selectedGrade = null;
                });
              },
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Reset'),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primary,
                textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }



  void _generateReport(String section) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SectionLogsDetailScreen(
          year: _selectedYear!,
          strand: _selectedStrand!,
          grade: _selectedGrade!,
          section: section,
          userRole: widget.userRole,
        ),
      ),
    );
  }
}

class SectionLogsDetailScreen extends StatefulWidget {
  final String year;
  final String strand;
  final String grade;
  final String section;
  final String? userRole;

  const SectionLogsDetailScreen({
    super.key,
    required this.year,
    required this.strand,
    required this.grade,
    required this.section,
    this.userRole,
  });

  @override
  State<SectionLogsDetailScreen> createState() => _SectionLogsDetailScreenState();
}

class _SectionLogsDetailScreenState extends State<SectionLogsDetailScreen> {
  List<dynamic> _sessions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchLogs();
  }

  Future<void> _fetchLogs() async {
    setState(() => _isLoading = true);
    try {
      final logs = await ApiService.getGranularAttendance(
        year: widget.year,
        strand: widget.strand,
        grade: widget.grade,
        section: widget.section,
      );
      if (mounted) {
        setState(() {
          _sessions = logs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          Container(
            height: MediaQuery.of(context).padding.top,
            width: double.infinity,
            color: AppTheme.primary,
          ),
          Stack(
            children: [
              CustomHeader(
                title: 'SECTION LOGS',
                subtitle: '${widget.grade} ${widget.strand} - ${widget.section} (${widget.year})',
                showBackButton: true,
              ),
              if (widget.userRole == 'ADMIN' && _sessions.isNotEmpty)
                Positioned(
                  right: 24,
                  top: 40,
                  child: IconButton(
                    onPressed: () => _downloadPDF(context),
                    icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white, size: 28),
                    tooltip: 'Download PDF',
                  ),
                ),
            ],
          ),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _sessions.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Text('No logs available yet.', style: TextStyle(color: Colors.grey)),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(24),
                    itemCount: _sessions.length,
                    itemBuilder: (context, index) {
                      final session = _sessions[index];
                      final date = DateTime.parse(session['startTime']).toString().split(' ')[0];
                      final presentCount = (session['records'] as List).where((r) => r['status'] == 'present').length;
                      final totalCount = (session['records'] as List).length;

                      return _buildLogItem(
                        'Session: $date',
                        'Subject: ${session['subject']}\nAttendance: $presentCount / $totalCount present',
                        '${DateTime.parse(session['startTime']).hour}:${DateTime.parse(session['startTime']).minute.toString().padLeft(2, '0')}',
                        Icons.event_note_rounded,
                        AppTheme.primary,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AttendanceDetailScreen(
                                section: widget.section,
                                date: date,
                                userRole: widget.userRole,
                                records: session['records'],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _downloadPDF(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Preparing report for download...'),
        backgroundColor: AppTheme.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildLogItem(String title, String description, String time, IconData icon, Color color, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textPrimary),
                        ),
                      ),
                      Text(
                        time,
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary, height: 1.4),
                  ),
                  if (onTap != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Tap to view details →',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AttendanceDetailScreen extends StatelessWidget {
  final String section;
  final String date;
  final String? userRole;
  final List<dynamic> records;

  const AttendanceDetailScreen({
    super.key, 
    required this.section, 
    required this.date, 
    this.userRole,
    required this.records,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          Container(
            height: MediaQuery.of(context).padding.top,
            width: double.infinity,
            color: AppTheme.primary,
          ),
          Stack(
            children: [
              CustomHeader(
                title: 'ATTENDANCE LOGS',
                subtitle: 'Section $section - $date',
                showBackButton: true,
              ),
              if (userRole == 'ADMIN')
                Positioned(
                  right: 24,
                  top: 40,
                  child: IconButton(
                    onPressed: () => _downloadAttendancePDF(context),
                    icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white, size: 28),
                  ),
                ),
            ],
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                _buildAttendanceHeader(),
                const SizedBox(height: 12),
                if (records.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Text('No attendance records found.', style: TextStyle(color: Colors.grey)),
                    ),
                  )
                else
                  ...records.map((r) {
                    final status = r['status'] ?? 'pending';
                    final time = r['timestamp'] != null 
                        ? '${DateTime.parse(r['timestamp']).hour}:${DateTime.parse(r['timestamp']).minute.toString().padLeft(2, '0')}'
                        : 'N/A';
                    return _buildAttendanceTile(
                      r['studentName'] ?? 'Unknown',
                      'Student ID: ${r['studentId'] ?? 'N/A'}',
                      time,
                      status.toUpperCase(),
                      status == 'present',
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('STUDENT NAME', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textSecondary, letterSpacing: 1)),
          Text('STATUS / TIME', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textSecondary, letterSpacing: 1)),
        ],
      ),
    );
  }

  Widget _buildAttendanceTile(String name, String id, String time, String status, bool isOnTime) {
    Color statusColor = status == 'ABSENT' ? Colors.red.shade700 : (isOnTime ? Colors.green.shade600 : Colors.orange.shade700);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimary)),
                const SizedBox(height: 2),
                Text(id, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                status, 
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: statusColor),
              ),
              const SizedBox(height: 2),
              Text(time, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }

  void _downloadAttendancePDF(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Downloading detailed attendance PDF...'),
        backgroundColor: AppTheme.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
