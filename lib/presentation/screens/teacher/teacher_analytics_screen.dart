import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/services/api_service.dart';
import '../../widgets/custom_widgets.dart';

class TeacherAnalyticsScreen extends StatefulWidget {
  const TeacherAnalyticsScreen({super.key});

  @override
  State<TeacherAnalyticsScreen> createState() => _TeacherAnalyticsScreenState();
}

class _TeacherAnalyticsScreenState extends State<TeacherAnalyticsScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _data = {};

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    final result = await ApiService.getAnalytics();
    if (mounted) {
      setState(() {
        _data = result;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          const CustomHeader(
            title: 'ATTENDANCE ANALYTICS',
            subtitle: 'Visualize student performance trends',
            userRole: 'TEACHER',
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      _buildWeeklyBarChart(),
                      const SizedBox(height: 32),
                      _buildDistributionPieChart(),
                      const SizedBox(height: 100),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyBarChart() {
    final weekly = _data['weeklyAttendance'] as List<dynamic>? ?? [];
    if (weekly.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('WEEKLY ATTENDANCE', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textSecondary, fontSize: 13, letterSpacing: 1.2)),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 60,
                barTouchData: BarTouchData(enabled: true),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() < weekly.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(weekly[value.toInt()]['day'], style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: weekly.asMap().entries.map((e) {
                  return BarChartGroupData(
                    x: e.key,
                    barRods: [
                      BarChartRodData(toY: (e.value['present'] as num).toDouble(), color: Colors.green, width: 12, borderRadius: BorderRadius.circular(4)),
                      BarChartRodData(toY: (e.value['late'] as num).toDouble(), color: Colors.orange, width: 12, borderRadius: BorderRadius.circular(4)),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildLegend(),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _legendItem('Present', Colors.green),
        const SizedBox(width: 20),
        _legendItem('Late', Colors.orange),
      ],
    );
  }

  Widget _legendItem(String label, Color color) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
      ],
    );
  }

  Widget _buildDistributionPieChart() {
    final dist = _data['categoryDistribution'] as List<dynamic>? ?? [];
    if (dist.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('STATUS DISTRIBUTION', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textSecondary, fontSize: 13, letterSpacing: 1.2)),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 180,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 4,
                      centerSpaceRadius: 40,
                      sections: dist.map((d) {
                        return PieChartSectionData(
                          color: _hexToColor(d['color']),
                          value: (d['value'] as num).toDouble(),
                          title: '${d['value']}%',
                          radius: 50,
                          titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: dist.map((d) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: _legendItem(d['name'], _hexToColor(d['color'])),
                  )).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _hexToColor(String hex) {
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }
}
