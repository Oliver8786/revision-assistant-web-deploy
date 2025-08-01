import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';

class ConfidenceRatingWidget extends StatefulWidget {
  const ConfidenceRatingWidget({super.key});

  @override
  State<ConfidenceRatingWidget> createState() => _ConfidenceRatingWidgetState();
}

class _ConfidenceRatingWidgetState extends State<ConfidenceRatingWidget> {
  final GlobalKey _chartKey = GlobalKey();
  late Future<List<double>> _weeklyAveragesFuture;
  bool _hovering = false;

  void _onTap() {
    // Navigate or other logic can be added here
    print('Tapped Confidence Rating Widget');
  }

  @override
  void initState() {
    super.initState();
    _weeklyAveragesFuture = fetchWeeklyConfidenceAverages();
  }

  Future<List<double>> fetchWeeklyConfidenceAverages() async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      // Calculate start of today and start of current week (Monday)
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final currentWeekday = today.weekday;
      final startOfCurrentWeek = today.subtract(Duration(days: currentWeekday - 1));
      final fiveWeeksAgo = startOfCurrentWeek.subtract(const Duration(days: 7 * 4));

      // Query only confidence and revised_at, rely on RLS for user filtering
      final response = await supabase
          .from('revisions')
          .select('confidence, revised_at')
          .gte('revised_at', fiveWeeksAgo.toIso8601String());

      if (response == null || response.isEmpty) return List.filled(5, 0);

      final Map<int, List<double>> weekBuckets = {
        0: [],
        1: [],
        2: [],
        3: [],
        4: [],
      };

      for (final rev in response) {
        final confidence = (rev['confidence'] as num?)?.toDouble();
        final revisedAt = DateTime.tryParse(rev['revised_at']);
        if (confidence == null || revisedAt == null) continue;

        // Calculate week index (0 = oldest, 4 = current week)
        final diffInDays = revisedAt.difference(fiveWeeksAgo).inDays;
        final weekIndex = diffInDays ~/ 7;
        // Only assign if revision falls within the 5 displayed weeks
        if (weekIndex >= 0 && weekIndex < 5) {
          weekBuckets[weekIndex]?.add(confidence);
        }
      }

      final List<double> weeklyAverages = [];
      for (int i = 0; i < 5; i++) {
        final bucket = weekBuckets[i]!;
        if (bucket.isEmpty) {
          weeklyAverages.add(0);
        } else {
          final avg = bucket.reduce((a, b) => a + b) / bucket.length;
          weeklyAverages.add(avg);
        }
      }

      return weeklyAverages;
    } catch (e) {
      print('Error fetching grouped weekly averages: $e');
      return List.filled(5, 0);
    }
  }

  Widget _buildConfidenceChart() {
    return FutureBuilder<List<double>>(
      future: _weeklyAveragesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        final averages = snapshot.data ?? [];

        return Container(
          key: _chartKey,
          child: _buildBarChart(averages),
        );
      },
    );
  }

  Widget _buildBarChart(List<double> averages) {
    return BarChart(
      BarChartData(
        barGroups: averages.asMap().entries.map((entry) {
          final index = entry.key;
          final value = entry.value;
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: value,
                color: Colors.blue,
                borderRadius: BorderRadius.circular(4),
                width: 50,
              ),
            ],
          );
        }).toList(),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, _) =>
                  Text('W${value.toInt() + 1}', style: const TextStyle(fontSize: 15)),
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 20,
              getTitlesWidget: (value, _) => Text(
                value.toInt().toString(),
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(show: false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return MouseRegion(
      onEnter: (_) {
        if (!_hovering) {
          setState(() => _hovering = true);
        }
      },
      onExit: (_) {
        if (_hovering) {
          setState(() => _hovering = false);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: isLight ? Colors.white : Colors.grey[850],
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(_hovering ? 0.10 : 0.05),
              blurRadius: _hovering ? 16 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTapDown: (details) {
              final RenderBox? chartBox = _chartKey.currentContext?.findRenderObject() as RenderBox?;
              if (chartBox != null) {
                final chartPosition = chartBox.localToGlobal(Offset.zero);
                final chartSize = chartBox.size;
                final tapPos = details.globalPosition;

                final inChart = (tapPos.dx >= chartPosition.dx &&
                                 tapPos.dx <= chartPosition.dx + chartSize.width &&
                                 tapPos.dy >= chartPosition.dy &&
                                 tapPos.dy <= chartPosition.dy + chartSize.height);

                if (!inChart) {
                  _onTap();
                }
              } else {
                _onTap(); // fallback
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Confidence Rating',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isLight ? Colors.black : Colors.white,
                        ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(child: _buildConfidenceChart()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}