import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/services/api_service.dart';
import '../../widgets/custom_widgets.dart';
import 'bulk_csv_upload_screen.dart';
import '../messaging/chat_screen.dart';


class GlobalConfigScreen extends StatefulWidget {
  const GlobalConfigScreen({super.key});

  @override
  State<GlobalConfigScreen> createState() => _GlobalConfigScreenState();
}

class _GlobalConfigScreenState extends State<GlobalConfigScreen> {
  final _lateCtrl = TextEditingController(text: '15');
  final _absentCtrl = TextEditingController(text: '30');
  bool _fingerprint = true;
  bool _gracePeriod = true;

  @override
  void dispose() {
    _lateCtrl.dispose();
    _absentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Global Configuration'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text('System Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primary)),
          const SizedBox(height: 24),
          
          _buildToggleTile('Enable Fingerprint Scanning', _fingerprint, (v) => setState(() => _fingerprint = v)),
          _buildToggleTile('Allow Late Attendance (Grace Period)', _gracePeriod, (v) => setState(() => _gracePeriod = v)),
          
          const SizedBox(height: 16),
          
          _buildEditableThreshold('Late Threshold (Minutes)', _lateCtrl, Icons.timer_outlined),
          const SizedBox(height: 16),
          _buildEditableThreshold('Absent Threshold (Minutes)', _absentCtrl, Icons.timer_off_outlined),
          
          const SizedBox(height: 40),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 4,
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Configuration saved successfully!'),
                behavior: SnackBarBehavior.floating,
                backgroundColor: AppTheme.success,
              ));
            },
            child: const Text('SAVE CHANGES', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleTile(String title, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
      value: value,
      onChanged: onChanged,
      activeColor: AppTheme.primary,
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildEditableThreshold(String label, TextEditingController ctrl, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primary, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          ),
          SizedBox(
            width: 60,
            child: TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary),
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.symmetric(vertical: 8),
                isDense: true,
                border: UnderlineInputBorder(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AccountEntryScreen extends StatelessWidget {
  final String userType;
  const AccountEntryScreen({super.key, required this.userType});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('$userType Management'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // ── Blue Header Cap
          Container(
            height: 32,
            width: double.infinity,
            decoration: const BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32)),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                _buildEntrySectionTitle('DIRECTORY'),
                ActionCard(
                  icon: Icons.people_alt_rounded,
                  title: 'Accounts',
                  subtitle: 'View and manage all $userType records',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ManageAccountsScreen(userType: userType)),
                  ),
                ),
                const SizedBox(height: 16),
                _buildEntrySectionTitle('REGISTRATION'),
                ActionCard(
                  icon: Icons.person_add_rounded,
                  title: 'Add Manually',
                  subtitle: 'Create a single $userType account',
                  onTap: () {
                    showAddAccountDialog(context, userType, onSave: ApiService.addUser);
                  },
                ),
                ActionCard(
                  icon: Icons.upload_file_rounded,
                  title: 'Upload Bulk Selection',
                  subtitle: 'Import multiple records from CSV/Excel',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => BulkCsvUploadScreen(userType: userType)),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntrySectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 12, top: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: AppTheme.textSecondary,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

class ManageAccountsScreen extends StatefulWidget {
  final String userType; // "Teacher" or "Student"
  
  const ManageAccountsScreen({super.key, required this.userType});

  @override
  State<ManageAccountsScreen> createState() => _ManageAccountsScreenState();
}

class _ManageAccountsScreenState extends State<ManageAccountsScreen> {
  String _searchQuery = "";
  List<dynamic> _allUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final users = await ApiService.getAllUsers();
    if (mounted) {
      setState(() {
        // Filter by role based on userType
        final roleMatch = widget.userType.toUpperCase();
        _allUsers = users.where((u) => u['role'] == roleMatch).toList();
        _isLoading = false;
      });
    }
  }

  void _deleteAccount(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text('Are you sure you want to delete this account? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await ApiService.deleteUser(id);
      if (success) {
        _fetchUsers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account deleted successfully')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredUsers = _allUsers.where((u) => 
      (u['name'] ?? '').toString().toLowerCase().contains(_searchQuery.toLowerCase()) || 
      (u['username'] ?? '').toString().toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('Manage ${widget.userType} Accounts'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchUsers,
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Blue Header Cap
          Container(
            height: 32,
            width: double.infinity,
            decoration: const BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32)),
            ),
          ),
          
          // ── Search Bar (Outside Blue)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
                border: Border.all(color: Colors.grey.shade100),
              ),
              child: TextField(
                onChanged: (val) => setState(() => _searchQuery = val),
                style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  hintText: 'Search by name or ID...',
                  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                  prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.primary, size: 22),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 18),
                ),
              ),
            ),
          ),
          
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : filteredUsers.isEmpty
                ? const Center(child: Text('No accounts found.'))
                : ListView.builder(
                    padding: const EdgeInsets.all(24),
                    itemCount: filteredUsers.length,
                    itemBuilder: (context, index) {
                      final u = filteredUsers[index];
                      // Prepare data for UI (mapping backend keys to UI keys if needed)
                      final Map<String, String> displayUser = {
                        'id_db': u['_id'] ?? '',
                        'name': u['name'] ?? 'No Name',
                        'id': u['username'] ?? 'No ID',
                        'email': u['email'] ?? u['username'] ?? 'No Email',
                        'dept': u['strand'] ?? u['assignedSubject'] ?? 'General',
                        'assignedSubject': u['assignedSubject'] ?? 'No Subject',
                        'professor': u['professor'] ?? 'TBA',
                        'section': u['section'] ?? 'TBD',
                        'status': 'Active',
                      };

                      
                      return GestureDetector(
                        onTap: () => _showManagementMenu(context, displayUser['name']!, false, displayUser),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.02),
                                blurRadius: 15,
                                offset: const Offset(0, 8),
                              ),
                            ],
                            border: Border.all(color: Colors.grey.shade50),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primary.withOpacity(0.08),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      widget.userType == 'Teacher' ? Icons.badge_rounded : Icons.person_rounded, 
                                      color: AppTheme.primary,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          displayUser['name']!, 
                                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppTheme.textPrimary, letterSpacing: 0.3)
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          displayUser['dept']!, 
                                          style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w500)
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(color: Colors.grey.shade50, shape: BoxShape.circle),
                                    child: const Icon(Icons.more_vert_rounded, color: Colors.grey, size: 20),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              Row(
                                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                 children: [
                                   Flexible(
                                     child: Container(
                                       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                       decoration: BoxDecoration(
                                         color: Colors.grey.shade50,
                                         borderRadius: BorderRadius.circular(10),
                                       ),
                                       child: Row(
                                         mainAxisSize: MainAxisSize.min,
                                         children: [
                                           Icon(Icons.tag_rounded, size: 14, color: Colors.grey.shade400),
                                           const SizedBox(width: 4),
                                           Flexible(
                                             child: Text(
                                               displayUser['id']!, 
                                               style: TextStyle(color: Colors.grey.shade600, fontSize: 11, fontWeight: FontWeight.w700),
                                               overflow: TextOverflow.ellipsis,
                                             ),
                                           ),
                                         ],
                                       ),
                                     ),
                                   ),
                                   const SizedBox(width: 8),
                                   Container(
                                     padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                     decoration: BoxDecoration(
                                       color: Colors.green.withOpacity(0.1),
                                       borderRadius: BorderRadius.circular(12),
                                     ),
                                     child: Text(
                                       'ACTIVE', 
                                       style: const TextStyle(
                                         color: Colors.green,
                                         fontSize: 10,
                                         fontWeight: FontWeight.w900,
                                         letterSpacing: 0.8
                                       )
                                     ),
                                   ),
                                   if (widget.userType == 'Student') ...[
                                     const SizedBox(width: 8),
                                     Container(
                                       padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                       decoration: BoxDecoration(
                                         color: AppTheme.primary.withOpacity(0.05),
                                         borderRadius: BorderRadius.circular(10),
                                       ),
                                       child: Row(
                                         mainAxisSize: MainAxisSize.min,
                                         children: [
                                           const Icon(Icons.person_pin_rounded, size: 12, color: AppTheme.primary),
                                           const SizedBox(width: 4),
                                           Text(
                                             displayUser['professor']!,
                                             style: const TextStyle(color: AppTheme.primary, fontSize: 10, fontWeight: FontWeight.bold),
                                           ),
                                         ],
                                       ),
                                     ),
                                   ],
                                 ],
                               ),

                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showManagementMenu(BuildContext context, String targetName, bool isNew, [Map<String, String>? userData]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
            ),
            const SizedBox(height: 32),
            Text(isNew ? 'ACCOUNT ACTIONS' : 'MANAGE ACCOUNT', 
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppTheme.textSecondary, letterSpacing: 1.5)),
            const SizedBox(height: 8),
            Text(isNew ? 'Registration Menu' : targetName, 
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
            const SizedBox(height: 32),
            
            if (isNew) ...[
              _buildModernActionCard(Icons.person_add_rounded, 'Add Manually', 'Create a new record from scratch', Colors.green, () async {
                Navigator.pop(ctx);
                final result = await showAddAccountDialog(context, widget.userType, onSave: ApiService.addUser);
                if (result == true) _fetchUsers();
              }),
              const SizedBox(height: 12),
              _buildModernActionCard(Icons.upload_file_rounded, 'Bulk Upload', 'Import records via CSV/Excel', AppTheme.primary, () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Bulk Upload is currently being finalized!'),
                  behavior: SnackBarBehavior.floating,
                ));
              }),
            ] else ...[
              _buildModernActionCard(Icons.visibility_rounded, 'View Profile', 'Check handled sections & logs', AppTheme.primary, () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => UserDetailScreen(userData: userData!, userType: widget.userType)),
                );
              }),
              const SizedBox(height: 12),
              if (widget.userType == 'Teacher') ...[
                _buildModernActionCard(Icons.add_business_rounded, 'Add Sections', 'Assign new sections to teacher', Colors.teal, () async {
                  Navigator.pop(ctx);
                  final result = await showAddSectionDialog(
                    context, 
                    userData!['name']!, 
                    userData['id_db']!, 
                    onSave: ApiService.createSection
                  );
                  if (result == true) {
                    _fetchUsers();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Section assigned successfully!')));
                    }
                  }
                }),
                const SizedBox(height: 12),
              ] else if (widget.userType == 'Student') ...[
                _buildModernActionCard(Icons.menu_book_rounded, 'Add Subject', 'Assign a subject & teacher to student', Colors.indigo, () async {
                  Navigator.pop(ctx);
                  final result = await showAddStudentSubjectDialog(
                    context, 
                    userData!['name']!, 
                    userData['id_db']!, 
                    onSave: ApiService.updateUser
                  );
                  if (result == true) {
                    _fetchUsers();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Subject assigned successfully!')));
                    }
                  }
                }),
                const SizedBox(height: 12),
              ],
              _buildModernActionCard(Icons.edit_rounded, 'Edit Details', 'Modify profile information', Colors.blue, () async {
                Navigator.pop(ctx);
                final result = await _showEditAccountDialog(context, widget.userType, userData!);
                if (result == true) _fetchUsers();
              }),
              const SizedBox(height: 12),
              _buildModernActionCard(Icons.vpn_key_rounded, 'Security', 'Reset password or credentials', Colors.orange, () async {
                Navigator.pop(ctx);
                final result = await _showSecurityDialog(context, userData!['id_db']!, userData['name']!);
                if (result == true) _fetchUsers();
              }),
              const SizedBox(height: 12),
              _buildModernActionCard(Icons.delete_forever_rounded, 'Delete Account', 'Remove this record permanently', Colors.red, () {
                Navigator.pop(ctx);
                _deleteAccount(userData!['id_db']!);
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildModernActionCard(IconData icon, String title, String subtitle, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textPrimary)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.grey.shade300),
          ],
        ),
      ),
    );
  }
}

class UserDetailScreen extends StatefulWidget {
  final Map<String, String> userData;
  final String userType;

  const UserDetailScreen({super.key, required this.userData, required this.userType});

  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  List<dynamic> _teacherSections = [];
  bool _isLoadingSections = false;
  @override
  void initState() {
    super.initState();
    if (widget.userType == 'Teacher') {
      _fetchTeacherSections();
    }
  }

  Future<void> _fetchTeacherSections() async {
    setState(() => _isLoadingSections = true);
    try {
      final allSections = await ApiService.getSections();
      if (mounted) {
        setState(() {
          _teacherSections = allSections.where((s) => 
            (s['teacher']?['_id'] ?? s['teacher']) == widget.userData['id_db']
          ).toList();
          _isLoadingSections = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingSections = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('${widget.userData['name']}\'s Profile'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // ── Premium Profile Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    widget.userType == 'Teacher' ? Icons.badge_rounded : Icons.school_rounded,
                    size: 50,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  widget.userData['name']!.toUpperCase(),
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'ID: ${widget.userData['id']}',
                    style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          if (widget.userType == 'Teacher') ...[
            _buildSectionTitle('HANDLED SECTIONS & SUBJECTS'),
            if (_isLoadingSections)
              const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
            else if (_teacherSections.isNotEmpty)
              ..._teacherSections.map((section) => _buildInfoCard(
                section['subject'] ?? 'Unknown Subject', 
                '${section['sectionName']} • ${section['strand'] ?? ''} (${section['academicYear'] ?? ''})', 
                Icons.science_rounded, 
                Colors.blue,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SectionStudentsScreen(sectionName: section['sectionName'] ?? ''),
                    ),
                  );
                },
              ))
            else
              _buildInfoCard('No Subjects', 'Assign a subject via the manage menu', Icons.help_outline_rounded, Colors.grey),
          ] else ...[
            _buildSectionTitle('ENROLLED SUBJECTS'),
            if (widget.userData['assignedSubject'] != 'No Subject')
              _buildLogTile('ACTIVE', widget.userData['assignedSubject']!, 'Enrolled', '08:00 AM')
            else
              const Center(child: Text('Not enrolled in any subjects yet.')),
          ],
          
          const SizedBox(height: 32),
          _buildSectionTitle('ACCOUNT INFORMATION'),
          _buildDetailRow('Role', widget.userType),
          if (widget.userType == 'Student')
            _buildDetailRow('Professor', widget.userData['professor'] ?? 'TBA'),
          _buildDetailRow('Status', widget.userData['status'] ?? 'Active'),
          _buildDetailRow('Email', widget.userData['email'] ?? 'No Email'),
          _buildDetailRow('Contact', 'Not Provided'),
        ],
      ),
    );
  }
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 8),
      child: Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppTheme.textSecondary, letterSpacing: 1.5)),
    );
  }

  Widget _buildInfoCard(String title, String subtitle, IconData icon, Color color, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white, 
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
          border: Border.all(color: Colors.grey.shade50),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textPrimary)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey.shade300, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildStatMiniCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
        ],
      ),
    );
  }

  Widget _buildLogTile(String date, String subject, String status, String time) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade50),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 40,
            decoration: BoxDecoration(
              color: status == 'Present' ? Colors.green : (status == 'Late' ? Colors.orange : Colors.red),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(subject, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(date, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(status.toUpperCase(), style: TextStyle(color: status == 'Present' ? Colors.green : Colors.orange, fontWeight: FontWeight.w900, fontSize: 11)),
              Text(time, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary)),
        ],
      ),
    );
  }
}

class AdminConcernsScreen extends StatefulWidget {
  const AdminConcernsScreen({super.key});

  @override
  State<AdminConcernsScreen> createState() => _AdminConcernsScreenState();
}

class _AdminConcernsScreenState extends State<AdminConcernsScreen> {
  bool _isLoading = true;
  List<dynamic> _concerns = [];

  @override
  void initState() {
    super.initState();
    _fetchConcerns();
  }

  Future<void> _fetchConcerns() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.getConcerns();
      if (mounted) {
        setState(() {
          // Filter concerns targeted only to Admin
          _concerns = data.where((c) => c['target'] == 'System Administrator').toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _updateStatus(String id, String status, String name) async {
    final success = await ApiService.updateConcernStatus(id, status);
    if (success) {
      _fetchConcerns();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Concern from $name marked as $status.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: status == 'APPROVED' ? Colors.green : Colors.red,
        ));
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Failed to update concern status.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.redAccent,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          Container(
            height: MediaQuery.of(context).padding.top + 32,
            width: double.infinity,
            decoration: const BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32)),
            ),
          ),
          
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('USER CONCERNS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppTheme.textSecondary, letterSpacing: 1.5)),
                        Text('Support Requests', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
                      child: const Icon(Icons.support_agent_rounded, color: AppTheme.primary),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                
                if (_isLoading)
                  const Center(child: CircularProgressIndicator())
                else if (_concerns.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Text('No active support requests.', style: TextStyle(color: Colors.grey)),
                    ),
                  )
                else
                  ..._concerns.map((c) => _buildConcernCard(
                    context, 
                    c['student']?['name'] ?? 'Unknown Student',
                    c['student']?['section'] ?? 'No Section',
                    c['_id'].toString().substring(0, 8),
                    c['message'] ?? '',
                    c['createdAt'] != null ? DateTime.parse(c['createdAt']).toString().split(' ')[0] : 'Today',
                    AppTheme.primary,
                    c
                  )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConcernCard(BuildContext context, String name, String role, String id, String message, String time, Color accent, dynamic raw) {
    final String status = raw['status'] ?? 'PENDING';
    
    Color statusColor = Colors.orange;
    if (status == 'ON-GOING') statusColor = Colors.blue;
    if (status == 'RESOLVED' || status == 'APPROVED') statusColor = Colors.green;
    if (status == 'REJECTED') statusColor = Colors.red;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(width: 6, color: statusColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textPrimary)),
                              Row(
                                children: [
                                  Text('$role • $id', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.bold)),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: statusColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      status, 
                                      style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Text(time, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        message,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.4),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _buildActionChip(Icons.chat_bubble_outline_rounded, 'Open Chat', Colors.indigo, onTap: () async {
                            // Automatically update status to ON-GOING if it's PENDING
                            if (status == 'PENDING') {
                              await ApiService.updateConcernStatus(raw['_id'], 'ON-GOING');
                              _fetchConcerns(); // Refresh list
                            }

                            if (context.mounted) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChatScreen(
                                    threadId: raw['_id'],
                                    recipientName: name,
                                    recipientRole: 'Student',
                                    currentUserName: 'System Administrator',
                                    initialMessage: message,
                                    initialTopic: raw['subject'] ?? 'Support Request',
                                  ),
                                ),
                              );
                            }
                          }),
                          const SizedBox(width: 8),
                          if (status != 'RESOLVED' && status != 'APPROVED')
                            _buildActionChip(Icons.check_circle_outline_rounded, 'Resolve', Colors.teal, onTap: () => _updateStatus(raw['_id'], 'RESOLVED', name)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildActionChip(IconData icon, String label, Color color, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }
}

class SectionStudentsScreen extends StatefulWidget {
  final String sectionName;
  const SectionStudentsScreen({super.key, required this.sectionName});

  @override
  State<SectionStudentsScreen> createState() => _SectionStudentsScreenState();
}

class _SectionStudentsScreenState extends State<SectionStudentsScreen> {
  bool _isLoading = true;
  List<dynamic> _students = [];

  @override
  void initState() {
    super.initState();
    _fetchStudents();
  }

  Future<void> _fetchStudents() async {
    final users = await ApiService.getAllUsers();
    if (mounted) {
      setState(() {
        _students = users.where((u) => u['role'] == 'STUDENT' && u['section'] == widget.sectionName).toList();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('Students in ${widget.sectionName}'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _students.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.group_off_rounded, size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text(
                        'No students found in this section.',
                        style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: _students.length,
                  itemBuilder: (context, index) {
                    final student = _students[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), shape: BoxShape.circle),
                            child: const Icon(Icons.person_rounded, color: AppTheme.primary, size: 24),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  student['name'] ?? 'Unknown',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textPrimary),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  student['username'] ?? 'No ID',
                                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
class AcademicYearsScreen extends StatefulWidget {
  const AcademicYearsScreen({super.key});

  @override
  State<AcademicYearsScreen> createState() => _AcademicYearsScreenState();
}

class _AcademicYearsScreenState extends State<AcademicYearsScreen> {
  List<dynamic> _years = [];
  bool _isLoading = true;
  final _yearCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchYears();
  }

  Future<void> _fetchYears() async {
    final years = await ApiService.getAcademicYears();
    if (mounted) {
      setState(() {
        _years = years;
        _isLoading = false;
      });
    }
  }

  Future<void> _addYear() async {
    if (_yearCtrl.text.isEmpty) return;
    final ok = await ApiService.createAcademicYear(_yearCtrl.text);
    if (ok) {
      _yearCtrl.clear();
      _fetchYears();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Academic Years'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Add New School Year', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _yearCtrl,
                            decoration: InputDecoration(
                              hintText: 'e.g. 2025-2026',
                              filled: true,
                              fillColor: Colors.grey.shade100,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: _addYear,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Icon(Icons.add),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              const Text('EXISTING YEARS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
              const SizedBox(height: 16),
              ..._years.map((y) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, color: Colors.deepOrange),
                        const SizedBox(width: 16),
                        Text(y['year'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(Icons.check_circle_outline_rounded, color: Colors.green),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                          onPressed: () async {
                            final ok = await ApiService.deleteAcademicYear(y['_id']);
                            if (ok) _fetchYears();
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              )),
            ],
          ),
    );
  }
}

Future<bool?> _showEditAccountDialog(BuildContext context, String type, Map<String, String> data) async {
  final nameCtrl = TextEditingController(text: data['name']);
  final emailCtrl = TextEditingController(text: data['email']);
  final deptCtrl = TextEditingController(text: data['dept']);

  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Edit $type Details'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Full Name')),
          TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email/Username')),
          TextField(controller: deptCtrl, decoration: InputDecoration(labelText: type == 'Teacher' ? 'Assigned Subject' : 'Strand')),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () async {
            final ok = await ApiService.updateUser(data['id_db']!, {
              'name': nameCtrl.text,
              'email': emailCtrl.text,
              if (type == 'Teacher') 'assignedSubject': deptCtrl.text else 'strand': deptCtrl.text,
            });
            Navigator.pop(ctx, ok);
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

Future<bool?> _showSecurityDialog(BuildContext context, String userId, String name) async {
  final passCtrl = TextEditingController();

  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Reset Password'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Setting a new password for $name'),
          const SizedBox(height: 16),
          TextField(
            controller: passCtrl, 
            obscureText: true,
            decoration: const InputDecoration(labelText: 'New Password', border: OutlineInputBorder()),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () async {
            if (passCtrl.text.isEmpty) return;
            final ok = await ApiService.changePassword(userId, passCtrl.text);
            Navigator.pop(ctx, ok);
          },
          child: const Text('Update Password'),
        ),
      ],
    ),
  );
}
