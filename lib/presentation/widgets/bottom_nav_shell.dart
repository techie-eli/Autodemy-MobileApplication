import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/theme/app_theme.dart';

/// A truly premium, ultra-modern bottom navigation bar with a glassmorphism floating center QR scan button.
class BottomNavShell extends StatefulWidget {
  final List<Widget> pages;
  final List<String> labels;
  final List<IconData> icons;
  final Widget? header;
  final VoidCallback? onLogout;

  const BottomNavShell({
    super.key,
    required this.pages,
    required this.labels,
    required this.icons,
    this.header,
    this.onLogout,
  });

  @override
  State<BottomNavShell> createState() => _BottomNavShellState();
}

class _BottomNavShellState extends State<BottomNavShell>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          if (widget.header != null && _currentIndex == 0) widget.header!,
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: IndexedStack(
                key: ValueKey<int>(_currentIndex),
                index: _currentIndex,
                children: widget.pages,
              ),
            ),
          ),
        ],
      ),
      extendBody: true,
      bottomNavigationBar: _buildPremiumNavBar(),
    );
  }

  Widget _buildPremiumNavBar() {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Container(
      height: 80 + bottomPadding,
      color: Colors.transparent,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Glass Background
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: EdgeInsets.only(left: 16, right: 16, bottom: 12 + bottomPadding),
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: [
                  ...List.generate(widget.labels.length, (index) => _buildTab(index)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildTab(int index) {
    final isActive = _currentIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentIndex = index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: isActive ? 1.2 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                widget.icons[index],
                color: isActive ? AppTheme.primary : Colors.grey.shade500,
                size: 24,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.labels[index],
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                color: isActive ? AppTheme.primary : Colors.grey.shade500,
              ),
            ),
            if (isActive)
              Container(
                margin: const EdgeInsets.only(top: 4),
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  color: AppTheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class QRScannerScreen extends StatefulWidget {
  final void Function(String qrData)? onScanned;
  const QRScannerScreen({super.key, this.onScanned});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  bool _scanned = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.9),
      body: Stack(
        children: [
          MobileScanner(
            onDetect: (capture) {
              if (_scanned) return;
              final barcodes = capture.barcodes;
              if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
                _scanned = true;
                final data = barcodes.first.rawValue!;
                widget.onScanned?.call(data);
                Navigator.pop(context, data);
              }
            },
          ),
          
          // Overlay UI
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.accent, width: 4),
                borderRadius: BorderRadius.circular(32),
              ),
            ),
          ),
          
          Positioned(
            top: 60,
            left: 20,
            child: IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white, size: 32),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          
          const Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                'Scan Student QR Code',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
