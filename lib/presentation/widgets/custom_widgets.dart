import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../data/services/api_service.dart';
import '../../data/app_data.dart';
import '../screens/shared/notifications_screen.dart';


/// A premium section title for the modern dashboard look.
Widget _buildSectionTitle(String title) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 16, top: 8),
    child: Text(
      title,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        color: AppTheme.primary.withValues(alpha: 0.6),
        letterSpacing: 1.5,
      ),
    ),
  );
}

/// A modern action card for the dashboard.
class ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? iconColor;

  const ActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (iconColor ?? AppTheme.primary).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    icon,
                    color: iconColor ?? AppTheme.primary,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: Colors.grey.shade300,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A premium header for the home screens.
class CustomHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback? onLogout;
  final bool showBackButton;

  final String? userRole;

  const CustomHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.onLogout,
    this.showBackButton = false,
    this.userRole,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 20,
        left: 24,
        right: 24,
        bottom: 32,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (showBackButton)
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                )
              else
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.school_rounded, color: Colors.white, size: 24),
                ),
              Row(
                children: [
                  if (userRole != null)
                    IconButton(
                      icon: const Icon(Icons.notifications_none_rounded, color: Colors.white),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => NotificationsScreen(userRole: userRole!),
                        ),
                      ),
                    ),
                  if (onLogout != null)
                    IconButton(
                      icon: const Icon(Icons.logout_rounded, color: Colors.white),
                      onPressed: onLogout,
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          ValueListenableBuilder<String>(
            valueListenable: AppData.currentUserName,
            builder: (context, name, _) {
              // If subtitle contains the old name or is a generic greeting, we can enhance it
              final displaySubtitle = (subtitle.contains('Hi,') || subtitle.contains('Welcome'))
                  ? 'Hi, $name!'
                  : subtitle;
                  
              return Text(
                displaySubtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Shows a truly premium, modern "Add Account" dialog.
Future<bool?> showAddAccountDialog(
  BuildContext context,
  String type, {
  required Future<bool> Function(Map<String, dynamic>) onSave,
}) {
  return showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Add Account',
    barrierColor: Colors.black.withOpacity(0.5),
    transitionDuration: const Duration(milliseconds: 400),
    pageBuilder: (ctx, anim1, anim2) => _AddAccountDialog(type: type, onSave: onSave),
    transitionBuilder: (ctx, anim1, anim2, child) {
      return FadeTransition(
        opacity: anim1,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.9, end: 1.0).animate(
            CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
          ),
          child: child,
        ),
      );
    },
  );
}

class _AddAccountDialog extends StatefulWidget {
  final String type;
  final Future<bool> Function(Map<String, dynamic>) onSave;

  const _AddAccountDialog({required this.type, required this.onSave});

  @override
  State<_AddAccountDialog> createState() => _AddAccountDialogState();
}

class _AddAccountDialogState extends State<_AddAccountDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _idCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _idCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    
    final payload = {
      'name': _nameCtrl.text.trim(),
      'username': _emailCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'idNumber': _idCtrl.text.trim(),
      'password': _passCtrl.text,
      'role': widget.type.toUpperCase(),
    };

    try {
      final ok = await widget.onSave(payload);
      if (ok) {
        if (mounted) Navigator.of(context).pop(true);
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = AppTheme.primary;
    
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: const BoxConstraints(maxWidth: 360),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F0F7),
            borderRadius: BorderRadius.circular(40),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10)),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Premium Header Icon
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8EAF6),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.person_add_rounded, color: primaryColor, size: 32),
                ),
                const SizedBox(height: 32),
                
                Text(
                  'Add New ${widget.type}',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter the details for the new account',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                ),
                const SizedBox(height: 40),

                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _buildPremiumField(
                        controller: _nameCtrl,
                        hint: 'Full Name',
                        icon: Icons.badge_outlined,
                        validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      _buildPremiumField(
                        controller: _idCtrl,
                        hint: widget.type == 'Student' ? 'Student Number' : 'Employee ID',
                        icon: Icons.tag_rounded,
                        validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      _buildPremiumField(
                        controller: _emailCtrl,
                        hint: 'Email Address',
                        icon: Icons.alternate_email_rounded,
                        validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      _buildPremiumField(
                        controller: _passCtrl,
                        hint: 'Password',
                        icon: Icons.lock_outline_rounded,
                        obscureText: _obscure,
                        suffix: IconButton(
                          icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                          onPressed: () => setState(() => _obscure = !_obscure),
                          color: Colors.grey.shade600,
                        ),
                        validator: (v) => (v?.length ?? 0) < 6 ? 'Min 6 chars' : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 48),

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('CANCEL', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    ),
                    const SizedBox(width: 24),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _handleSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 4,
                      ),
                      child: _isLoading 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('SAVE', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    Widget? suffix,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        validator: validator,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, color: AppTheme.primary, size: 22),
          suffixIcon: suffix,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        ),
      ),
    );
  }
}
/// Shows a premium dialog to assign a section to a teacher.
Future<bool?> showAddSectionDialog(BuildContext context, String teacherName, String teacherId, {required Future<bool> Function(Map<String, dynamic>) onSave}) {
  return showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Assign Section',
    barrierColor: Colors.black.withOpacity(0.5),
    transitionDuration: const Duration(milliseconds: 400),
    pageBuilder: (ctx, anim1, anim2) => _AddSectionDialog(name: teacherName, id: teacherId, onSave: onSave),
    transitionBuilder: (ctx, anim1, anim2, child) {
      return FadeTransition(
        opacity: anim1,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.9, end: 1.0).animate(CurvedAnimation(parent: anim1, curve: Curves.easeOutBack)),
          child: child,
        ),
      );
    },
  );
}

class _AddSectionDialog extends StatefulWidget {
  final String name;
  final String id;
  final Future<bool> Function(Map<String, dynamic>) onSave;

  const _AddSectionDialog({required this.name, required this.id, required this.onSave});

  @override
  State<_AddSectionDialog> createState() => _AddSectionDialogState();
}

class _AddSectionDialogState extends State<_AddSectionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _sectionNameCtrl = TextEditingController();
  final _subjectCtrl = TextEditingController();
  final _strandCtrl = TextEditingController();
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  String? _selectedYear;
  String? _selectedLevel;
  bool _isLoading = false;
  List<String> _academicYears = [];

  final List<String> _levels = ['Grade 11', 'Grade 12'];

  @override
  void initState() {
    super.initState();
    _fetchYears();
  }

  Future<void> _fetchYears() async {
    final years = await ApiService.getAcademicYears();
    if (mounted) {
      setState(() {
        _academicYears = years.map((y) => y['year'].toString()).toList();
        if (_academicYears.isNotEmpty) _selectedYear = _academicYears.first;
      });
    }
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? (_startTime ?? const TimeOfDay(hour: 7, minute: 30)) : (_endTime ?? const TimeOfDay(hour: 9, minute: 0)),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  String _formatTime(TimeOfDay? time) {
    if (time == null) return '--:--';
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }

  @override
  void dispose() {
    _sectionNameCtrl.dispose();
    _subjectCtrl.dispose();
    _strandCtrl.dispose();
    super.dispose();
  }

  void _handleSave() async {
    if (!_formKey.currentState!.validate() || 
        _subjectCtrl.text.trim().isEmpty || 
        _strandCtrl.text.trim().isEmpty ||
        _startTime == null || 
        _endTime == null ||
        _selectedYear == null || 
        _selectedLevel == null) {
      return;
    }
    
    setState(() => _isLoading = true);
    
    final scheduleStr = '${_formatTime(_startTime)} - ${_formatTime(_endTime)}';
    
    final ok = await widget.onSave({
      'teacher': widget.id,
      'subject': _subjectCtrl.text.trim(),
      'sectionName': _sectionNameCtrl.text.trim(),
      'academicYear': _selectedYear,
      'strand': _strandCtrl.text.trim(),
      'level': _selectedLevel,
      'schedule': scheduleStr,
    });
    
    if (mounted) {
      setState(() => _isLoading = false);
      if (ok) Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: const BoxConstraints(maxWidth: 360),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F0F7),
            borderRadius: BorderRadius.circular(40),
          ),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(color: Color(0xFFE0F2F1), shape: BoxShape.circle),
                    child: const Icon(Icons.add_business_rounded, color: Colors.teal, size: 32),
                  ),
                  const SizedBox(height: 24),
                  const Text('Assign Section', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                  Text('To ${widget.name}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 32),
                  
                  _buildDropdownField(
                    hint: 'Select Academic Year',
                    value: _selectedYear,
                    items: _academicYears,
                    icon: Icons.calendar_today_rounded,
                    onChanged: (val) => setState(() => _selectedYear = val),
                  ),
                  const SizedBox(height: 16),
                  
                  _buildDropdownField(
                    hint: 'Select Grade Level',
                    value: _selectedLevel,
                    items: _levels,
                    icon: Icons.layers_rounded,
                    onChanged: (val) => setState(() => _selectedLevel = val),
                  ),
                  const SizedBox(height: 16),
                  
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: TextFormField(
                      controller: _strandCtrl,
                      validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                      decoration: const InputDecoration(
                        hintText: 'Strand (e.g. STEM, ICT)',
                        prefixIcon: Icon(Icons.school_rounded, color: Colors.teal),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: TextFormField(
                      controller: _subjectCtrl,
                      validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                      decoration: const InputDecoration(
                        hintText: 'Subject Name (e.g. Physical Science)',
                        prefixIcon: Icon(Icons.subject_rounded, color: Colors.teal),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: TextFormField(
                      controller: _sectionNameCtrl,
                      validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                      decoration: const InputDecoration(
                        hintText: 'Section Name (e.g. STEM-A)',
                        prefixIcon: Icon(Icons.groups_rounded, color: Colors.teal),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => _pickTime(true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                            child: Row(
                              children: [
                                const Icon(Icons.access_time_rounded, color: Colors.teal, size: 20),
                                const SizedBox(width: 8),
                                Text(_startTime == null ? 'Start' : _formatTime(_startTime), style: TextStyle(fontSize: 13, color: _startTime == null ? Colors.grey : Colors.black)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('-', style: TextStyle(fontWeight: FontWeight.bold))),
                      Expanded(
                        child: InkWell(
                          onTap: () => _pickTime(false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                            child: Row(
                              children: [
                                const Icon(Icons.access_time_rounded, color: Colors.teal, size: 20),
                                const SizedBox(width: 8),
                                Text(_endTime == null ? 'End' : _formatTime(_endTime), style: TextStyle(fontSize: 13, color: _endTime == null ? Colors.grey : Colors.black)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 40),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _handleSave,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal, 
                          foregroundColor: Colors.white, 
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white)) : const Text('ASSIGN'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Widget _buildDropdownField({
  required String hint,
  required String? value,
  required List<String> items,
  required IconData icon,
  required Function(String?) onChanged,
}) {
  return DropdownButtonFormField<String>(
    value: value,
    hint: Text(hint),
    decoration: InputDecoration(
      prefixIcon: Icon(icon, color: Colors.teal),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
    ),
    items: items.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
    onChanged: onChanged,
  );
}

/// Shows a premium dialog to assign a subject to a student.
Future<bool?> showAddStudentSubjectDialog(BuildContext context, String studentName, String studentId, {required Future<bool> Function(String, Map<String, dynamic>) onSave}) {
  return showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Assign Subject',
    barrierColor: Colors.black.withOpacity(0.5),
    transitionDuration: const Duration(milliseconds: 400),
    pageBuilder: (ctx, anim1, anim2) => _AddStudentSubjectDialog(name: studentName, id: studentId, onSave: onSave),
    transitionBuilder: (ctx, anim1, anim2, child) {
      return FadeTransition(
        opacity: anim1,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.9, end: 1.0).animate(CurvedAnimation(parent: anim1, curve: Curves.easeOutBack)),
          child: child,
        ),
      );
    },
  );
}

class _AddStudentSubjectDialog extends StatefulWidget {
  final String name;
  final String id;
  final Future<bool> Function(String, Map<String, dynamic>) onSave;

  const _AddStudentSubjectDialog({required this.name, required this.id, required this.onSave});

  @override
  State<_AddStudentSubjectDialog> createState() => _AddStudentSubjectDialogState();
}

class _AddStudentSubjectDialogState extends State<_AddStudentSubjectDialog> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedSubject;
  String? _selectedStrand;
  String? _selectedTeacher;
  String? _selectedYear;
  String? _selectedLevel;
  String? _selectedSection;
  List<String> _academicYears = [];
  
  List<String> _allTeachers = [];
  List<dynamic> _allSections = [];
  List<String> _availableSubjects = [];
  List<String> _availableStrands = [];
  List<String> _filteredTeachers = [];
  List<String> _filteredSections = [];
  bool _isLoading = false;
  bool _isFetchingData = true;


  final List<String> _levels = ['Grade 11', 'Grade 12'];

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
    _fetchYears();
  }

  Future<void> _fetchInitialData() async {
    try {
      final users = await ApiService.getAllUsers();
      final sections = await ApiService.getSections();
      if (mounted) {
        setState(() {
          _allTeachers = users
              .where((u) => u['role'] == 'TEACHER')
              .map((u) => (u['name'] ?? 'Unknown').toString())
              .toSet().toList();
          _allSections = sections;
          
          // Populate dynamic subjects and strands from existing sections
          _availableSubjects = _allSections
              .map((s) => s['subject']?.toString() ?? '')
              .where((s) => s.isNotEmpty)
              .toSet().toList();
          _availableStrands = _allSections
              .map((s) => s['strand']?.toString() ?? '')
              .where((s) => s.isNotEmpty)
              .toSet().toList();

          _isFetchingData = false;
          _updateFilteredTeachers();
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isFetchingData = false);
    }
  }

  void _updateFilteredTeachers() {
    if (_selectedSubject == null) {
      _filteredTeachers = [];
      return;
    }

    // Get teacher names who have a section with the selected subject
    final eligibleTeacherNames = _allSections
        .where((s) => s['subject']?.toString() == _selectedSubject)
        .map((s) => s['teacher']?['name']?.toString() ?? '')
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList();

    setState(() {
      _filteredTeachers = eligibleTeacherNames;
      // Reset selected teacher if they are no longer eligible
      if (_selectedTeacher != null && !_filteredTeachers.contains(_selectedTeacher)) {
        _selectedTeacher = null;
      }
      _updateFilteredSections();
    });
  }

  void _updateFilteredSections() {
    if (_selectedSubject == null || _selectedTeacher == null) {
      _filteredSections = [];
      return;
    }

    final sectionsForSubjectAndTeacher = _allSections
        .where((s) => s['subject']?.toString() == _selectedSubject && 
                      (s['teacher']?['name']?.toString() == _selectedTeacher))
        .map((s) => s['sectionName']?.toString() ?? '')
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList();

    setState(() {
      _filteredSections = sectionsForSubjectAndTeacher;
      if (_selectedSection != null && !_filteredSections.contains(_selectedSection)) {
        _selectedSection = null;
      }
    });
  }

  Future<void> _fetchYears() async {
    final years = await ApiService.getAcademicYears();
    if (mounted) {
      setState(() {
        _academicYears = years.map((y) => y['year'].toString()).toList();
        if (_academicYears.isNotEmpty && _selectedYear == null) {
          _selectedYear = _academicYears.first;
        }
      });
    }
  }

  void _handleSave() async {
    if (!_formKey.currentState!.validate() || 
        _selectedSubject == null || 
        _selectedStrand == null ||
        _selectedTeacher == null ||
        _selectedYear == null ||
        _selectedLevel == null ||
        _selectedSection == null) {
      return;
    }
    
    setState(() => _isLoading = true);

    // Find the selected section to get its schedule
    String? schedule;
    try {
      final sectionObj = _allSections.firstWhere(
        (s) => s['subject']?.toString() == _selectedSubject && 
               s['teacher']?['name'] == _selectedTeacher &&
               s['sectionName'] == _selectedSection
      );
      schedule = sectionObj['schedule'];
    } catch (e) {
      schedule = 'TBA';
    }

    final ok = await widget.onSave(widget.id, {
      'assignedSubject': _selectedSubject,
      'professor': _selectedTeacher,
      'academicYear': _selectedYear,
      'level': _selectedLevel,
      'strand': _selectedStrand,
      'section': _selectedSection,
      'assignedTime': schedule, // Inherited from section schedule
    });
    if (mounted) {
      setState(() => _isLoading = false);
      if (ok) Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: const BoxConstraints(maxWidth: 360),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(color: const Color(0xFFF0F0F7), borderRadius: BorderRadius.circular(40)),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(color: Color(0xFFE8EAF6), shape: BoxShape.circle),
                    child: const Icon(Icons.menu_book_rounded, color: AppTheme.primary, size: 32),
                  ),
                  const SizedBox(height: 24),
                  const Text('Assign Subject', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                  Text('To ${widget.name}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 32),
                  
                  _buildDropdownField(
                    hint: 'Academic Year',
                    value: _selectedYear,
                    items: _academicYears,
                    icon: Icons.calendar_today_rounded,
                    onChanged: (val) => setState(() => _selectedYear = val),
                  ),
                  const SizedBox(height: 16),
                  
                  _buildDropdownField(
                    hint: 'Grade Level',
                    value: _selectedLevel,
                    items: _levels,
                    icon: Icons.layers_rounded,
                    onChanged: (val) => setState(() => _selectedLevel = val),
                  ),
                  const SizedBox(height: 16),
                  
                  _buildDropdownField(
                    hint: 'Strand',
                    value: _selectedStrand,
                    items: _availableStrands,
                    icon: Icons.school_rounded,
                    onChanged: (val) => setState(() => _selectedStrand = val),
                  ),
                  const SizedBox(height: 16),
                  
                  _buildDropdownField(
                    hint: 'Subject',
                    value: _selectedSubject,
                    items: _availableSubjects,
                    icon: Icons.subject_rounded,
                    onChanged: (val) {
                      setState(() {
                        _selectedSubject = val;
                        _updateFilteredTeachers();
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  _isFetchingData 
                    ? const CircularProgressIndicator()
                    : _buildDropdownField(
                        hint: _selectedSubject == null ? 'Select Subject First' : 'Teacher',
                        value: _selectedTeacher,
                        items: _filteredTeachers,
                        icon: Icons.person_pin_rounded,
                        onChanged: (val) {
                          setState(() => _selectedTeacher = val);
                          _updateFilteredSections();
                        },
                      ),
                  const SizedBox(height: 16),

                  _buildDropdownField(
                    hint: _selectedTeacher == null ? 'Select Teacher First' : 'Section',
                    value: _selectedSection,
                    items: _filteredSections,
                    icon: Icons.meeting_room_rounded,
                    onChanged: (val) => setState(() => _selectedSection = val),
                  ),
                  
                  const SizedBox(height: 40),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: _isLoading || _isFetchingData || _selectedTeacher == null || _selectedSection == null ? null : _handleSave,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary, 
                          foregroundColor: Colors.white, 
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white)) : const Text('ASSIGN'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
