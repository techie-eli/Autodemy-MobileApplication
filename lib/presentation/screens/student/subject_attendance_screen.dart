import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class SubjectAttendanceScreen extends StatelessWidget {
  final String subjectName;
  final String section;
  final String professor;
  final List<Map<String, String>> logs;

  const SubjectAttendanceScreen({
    super.key,
    required this.subjectName,
    required this.section,
    required this.professor,
    this.logs = const [],
  });

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: AppTheme.primary,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              titlePadding: const EdgeInsets.only(bottom: 16),
              title: Text(
                subjectName.toUpperCase(),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  letterSpacing: 1.2,
                  color: Colors.white,
                ),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.primary, Color(0xFF3949AB)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -20,
                      top: -20,
                      child: Icon(Icons.book_rounded, color: Colors.white.withOpacity(0.05), size: 180),
                    ),
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 20),
                          Text(
                            section,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1,
                            ),
                          ),
                          Text(
                            'with $professor',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 40), // Spacing for the floating title
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ATTENDANCE LOGS',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textSecondary, letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 16),
                  ...logs.map((log) => Container(
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
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: log['status']?.toLowerCase() == 'present' 
                                ? Colors.green.withOpacity(0.1) 
                                : log['status']?.toLowerCase() == 'late' ? Colors.orange.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            log['status']?.toLowerCase() == 'present' 
                                ? Icons.check_rounded 
                                : log['status']?.toLowerCase() == 'late' ? Icons.access_time_rounded : Icons.close_rounded,
                            color: log['status']?.toLowerCase() == 'present' 
                                ? Colors.green 
                                : log['status']?.toLowerCase() == 'late' ? Colors.orange : Colors.red,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(log['date']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              Text(log['status']!, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                            ],
                          ),
                        ),
                        Text(
                          log['time']!,
                          style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.primary),
                        ),
                      ],
                    ),
                  )).toList(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
