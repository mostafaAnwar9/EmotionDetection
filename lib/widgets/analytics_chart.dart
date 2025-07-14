import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:emotion_detection_app/providers/emotion_provider.dart';
import 'package:provider/provider.dart';

class AnalyticsChart extends StatefulWidget {
  const AnalyticsChart({super.key});

  @override
  State<AnalyticsChart> createState() => _AnalyticsChartState();
}

class _AnalyticsChartState extends State<AnalyticsChart> {
  List<Map<String, dynamic>> _analytics = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final analytics =
          await context.read<EmotionProvider>().getAnalytics(context);
      setState(() {
        _analytics = analytics;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadAnalytics,
      child: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Error: $_error',
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadAnalytics,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _analytics.isEmpty
                  ? const Center(
                      child: Text(
                        'No analytics data available',
                        style: TextStyle(fontSize: 16),
                      ),
                    )
                  : SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            SizedBox(
                              height: 300,
                              child: PieChart(
                                PieChartData(
                                  sections: _analytics.map((item) {
                                    final percentage = (item['count'] as int) /
                                        _analytics.fold<int>(
                                            0,
                                            (sum, item) =>
                                                sum + (item['count'] as int));
                                    return PieChartSectionData(
                                      value: percentage * 100,
                                      title:
                                          '${(percentage * 100).toStringAsFixed(1)}%',
                                      radius: 100,
                                      titleStyle: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    );
                                  }).toList(),
                                  sectionsSpace: 2,
                                  centerSpaceRadius: 40,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 16,
                              runSpacing: 8,
                              children: _analytics.map((item) {
                                return Chip(
                                  label: Text(
                                    '${item['_id']}: ${item['count']}',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  backgroundColor:
                                      Theme.of(context).colorScheme.primary,
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ),
    );
  }
}
