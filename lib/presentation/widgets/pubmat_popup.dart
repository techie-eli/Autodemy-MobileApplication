import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class PubmatPopup extends StatefulWidget {
  const PubmatPopup({super.key});

  @override
  State<PubmatPopup> createState() => _PubmatPopupState();
}

class _PubmatPopupState extends State<PubmatPopup> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> _pubmats = [
    {
      'title': 'Welcome to Autodemy',
      'description': 'Your all-in-one attendance and school management companion.',
      'color': '#0D47A1',
      'icon': 'school',
    },
    {
      'title': 'Dynamic QR Access',
      'description': 'Scan your secure, time-sensitive QR code to mark your presence.',
      'color': '#1A237E',
      'icon': 'qr_code_scanner',
    },
    {
      'title': 'Stay Updated',
      'description': 'View announcements, events, and your attendance records in real-time.',
      'color': '#001529',
      'icon': 'notifications_active',
    },
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 450,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: Stack(
                children: [
                  PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() => _currentPage = index);
                    },
                    itemCount: _pubmats.length,
                    itemBuilder: (context, index) {
                      final item = _pubmats[index];
                      return _buildPage(item);
                    },
                  ),
                  
                  // Indicators
                  Positioned(
                    bottom: 30,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _pubmats.length,
                        (index) => Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: _currentPage == index ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _currentPage == index 
                                ? AppTheme.primary 
                                : AppTheme.primary.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Close button
                  Positioned(
                    top: 15,
                    right: 15,
                    child: IconButton(
                      icon: Icon(Icons.close_rounded, color: AppTheme.textSecondary),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: 200,
            height: 50,
            child: ElevatedButton(
              onPressed: () {
                if (_currentPage < _pubmats.length - 1) {
                  _pageController.nextPage(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeInOut,
                  );
                } else {
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(
                _currentPage == _pubmats.length - 1 ? 'GET STARTED' : 'NEXT',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(Map<String, String> item) {
    final color = Color(int.parse(item['color']!.replaceFirst('#', '0xFF')));
    
    return Column(
      children: [
        Expanded(
          flex: 5,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color, color.withOpacity(0.8)],
              ),
            ),
            child: Center(
              child: Icon(
                _getIcon(item['icon']!),
                size: 100,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
          ),
        ),
        Expanded(
          flex: 4,
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              children: [
                  Text(
                    item['title']!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                const SizedBox(height: 16),
                Text(
                  item['description']!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  IconData _getIcon(String name) {
    switch (name) {
      case 'school': return Icons.school_rounded;
      case 'qr_code_scanner': return Icons.qr_code_scanner_rounded;
      case 'notifications_active': return Icons.notifications_active_rounded;
      default: return Icons.info_rounded;
    }
  }
}
