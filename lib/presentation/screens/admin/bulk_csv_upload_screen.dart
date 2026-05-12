import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/services/api_service.dart';
import '../../../data/app_data.dart';
import '../../widgets/custom_widgets.dart';

/// Bulk CSV Upload screen for importing student/teacher accounts.
class BulkCsvUploadScreen extends StatefulWidget {
  final String userType; // "Teacher" or "Student"

  const BulkCsvUploadScreen({super.key, required this.userType});

  @override
  State<BulkCsvUploadScreen> createState() => _BulkCsvUploadScreenState();
}

class _BulkCsvUploadScreenState extends State<BulkCsvUploadScreen> {
  PlatformFile? _selectedFile;
  List<Map<String, String>> _parsedRows = [];
  bool _isParsing = false;
  bool _isUploading = false;
  int _uploadedCount = 0;
  int _failedCount = 0;
  bool _uploadComplete = false;
  String? _errorMessage;

  Future<void> _pickFile() async {
    AppData.preventLock = true;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        setState(() {
          _selectedFile = file;
          _errorMessage = null;
          _uploadComplete = false;
        });
        _parseCSV(file);
      }
    } catch (e) {
      setState(() => _errorMessage = 'Error picking file: $e');
    } finally {
      Future.delayed(const Duration(seconds: 1), () {
        AppData.preventLock = false;
      });
    }
  }

  void _parseCSV(PlatformFile file) {
    setState(() => _isParsing = true);

    try {
      final bytes = file.bytes;
      if (bytes == null) {
        setState(() {
          _errorMessage = 'Could not read file data.';
          _isParsing = false;
        });
        return;
      }

      final content = utf8.decode(bytes);
      final lines = const LineSplitter().convert(content);

      if (lines.isEmpty) {
        setState(() {
          _errorMessage = 'File is empty.';
          _isParsing = false;
        });
        return;
      }

      // Parse header
      final headers = lines.first.split(',').map((h) => h.trim().toLowerCase()).toList();

      // Validate required columns
      final requiredCols = ['name', 'email', 'password'];
      final missing = requiredCols.where((c) => !headers.contains(c)).toList();
      if (missing.isNotEmpty) {
        setState(() {
          _errorMessage =
              'Missing required columns: ${missing.join(', ')}.\n\nExpected: name, email, password (and optionally: idnumber, section, subject)';
          _isParsing = false;
        });
        return;
      }

      // Parse data rows
      final rows = <Map<String, String>>[];
      for (int i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;

        final values = line.split(',').map((v) => v.trim()).toList();
        final row = <String, String>{};
        for (int j = 0; j < headers.length && j < values.length; j++) {
          row[headers[j]] = values[j];
        }

        if (row['name']?.isNotEmpty == true && row['email']?.isNotEmpty == true) {
          rows.add(row);
        }
      }

      setState(() {
        _parsedRows = rows;
        _isParsing = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error parsing CSV: $e';
        _isParsing = false;
      });
    }
  }

  Future<void> _uploadAll() async {
    setState(() {
      _isUploading = true;
      _uploadedCount = 0;
      _failedCount = 0;
    });

    final List<Map<String, dynamic>> payloads = _parsedRows.map((row) {
      return {
        'name': row['name'] ?? '',
        'username': row['email'] ?? '',
        'email': row['email'] ?? '',
        'idNumber': row['idnumber'] ?? row['id'] ?? '',
        'password': row['password'] ?? 'autodemy123',
        'role': widget.userType.toUpperCase(),
        if (row.containsKey('section')) 'section': row['section'],
        if (row.containsKey('strand')) 'strand': row['strand'],
        if (row.containsKey('subject')) 'assignedSubject': row['subject'],
        if (row.containsKey('schedule')) 'schedule': row['schedule'],
      };
    }).toList();

    try {
      final count = await ApiService.bulkAddUsers(payloads);
      if (mounted) {
        setState(() {
          _uploadedCount = count;
          _failedCount = payloads.length - count;
          _isUploading = false;
          _uploadComplete = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Upload Error: $e';
          _isUploading = false;
        });
      }
    }
  }

  void _resetForm() {
    setState(() {
      _selectedFile = null;
      _parsedRows = [];
      _uploadedCount = 0;
      _failedCount = 0;
      _uploadComplete = false;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('Bulk ${widget.userType} Upload'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _uploadComplete ? _buildResultView() : _buildFormView(),
    );
  }

  Widget _buildResultView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: _failedCount == 0
                    ? Colors.green.withValues(alpha: 0.1)
                    : Colors.orange.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _failedCount == 0
                    ? Icons.check_circle_rounded
                    : Icons.warning_rounded,
                color: _failedCount == 0 ? Colors.green : Colors.orange,
                size: 64,
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Upload Complete!',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 16),

            // Stats row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildStatChip('Success', '$_uploadedCount', Colors.green),
                const SizedBox(width: 16),
                _buildStatChip('Failed', '$_failedCount', Colors.red),
                const SizedBox(width: 16),
                _buildStatChip('Total', '${_parsedRows.length}', AppTheme.primary),
              ],
            ),
            const SizedBox(height: 40),

            ElevatedButton.icon(
              onPressed: _resetForm,
              icon: const Icon(Icons.upload_file_rounded),
              label: const Text('UPLOAD MORE'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w900, color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: color.withValues(alpha: 0.7))),
        ],
      ),
    );
  }

  Widget _buildFormView() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // Instructions card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1A237E), Color(0xFF3949AB)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.info_outline_rounded,
                        color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Text('CSV FORMAT',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1)),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'name,email,password,idnumber,section,strand,subject,schedule\nJohn Doe,john@email.com,pass123,2021-001,12STEM2501,STEM,Physics,7:30 AM - 9:00 AM',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.9),
                    height: 1.6,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Required: name, email, password\nOptional: idnumber, section, strand, subject, schedule',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6), fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Error message
        if (_errorMessage != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: Colors.red, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(_errorMessage!,
                      style:
                          const TextStyle(color: Colors.red, fontSize: 13)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // File picker card
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            children: [
              // File drop zone
              GestureDetector(
                onTap: _pickFile,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  decoration: BoxDecoration(
                    color: _selectedFile != null
                        ? AppTheme.primary.withValues(alpha: 0.05)
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _selectedFile != null
                          ? AppTheme.primary.withValues(alpha: 0.3)
                          : Colors.grey.shade300,
                      width: 2,
                      strokeAlign: BorderSide.strokeAlignInside,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        _selectedFile != null
                            ? Icons.description_rounded
                            : Icons.upload_file_rounded,
                        size: 48,
                        color: _selectedFile != null
                            ? AppTheme.primary
                            : Colors.grey.shade400,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _selectedFile != null
                            ? _selectedFile!.name
                            : 'Tap to select CSV file',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: _selectedFile != null
                              ? AppTheme.primary
                              : Colors.grey.shade500,
                        ),
                      ),
                      if (_selectedFile != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${_parsedRows.length} records found',
                          style: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Preview table
              if (_parsedRows.isNotEmpty) ...[
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('PREVIEW',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.textSecondary,
                          letterSpacing: 1.5)),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(
                            AppTheme.primary.withValues(alpha: 0.08)),
                        columns: [
                          const DataColumn(
                              label: Text('#',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold))),
                          const DataColumn(
                              label: Text('Name',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold))),
                          const DataColumn(
                              label: Text('Email',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold))),
                          const DataColumn(
                              label: Text('ID',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold))),
                        ],
                        rows: _parsedRows
                            .take(5)
                            .toList()
                            .asMap()
                            .entries
                            .map((e) => DataRow(cells: [
                                  DataCell(Text('${e.key + 1}')),
                                  DataCell(
                                      Text(e.value['name'] ?? '',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600))),
                                  DataCell(Text(e.value['email'] ?? '')),
                                  DataCell(Text(
                                      e.value['idnumber'] ?? e.value['id'] ?? '-')),
                                ]))
                            .toList(),
                      ),
                    ),
                  ),
                ),
                if (_parsedRows.length > 5)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '...and ${_parsedRows.length - 5} more rows',
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 12),
                    ),
                  ),
                const SizedBox(height: 24),

                // Upload button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _isUploading ? null : _uploadAll,
                    icon: _isUploading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.cloud_upload_rounded),
                    label: Text(
                      _isUploading
                          ? 'UPLOADING ($_uploadedCount/${_parsedRows.length})...'
                          : 'UPLOAD ${_parsedRows.length} ACCOUNTS',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, letterSpacing: 1),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      elevation: 4,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
