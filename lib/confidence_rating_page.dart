import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'topic_confidence_page.dart';
import 'package:fl_chart/fl_chart.dart';

class ConfidenceRatingPage extends StatefulWidget {
  const ConfidenceRatingPage({super.key});

  @override
  State<ConfidenceRatingPage> createState() => _ConfidenceRatingPageState();
}

class _ConfidenceRatingPageState extends State<ConfidenceRatingPage> {
  final supabase = Supabase.instance.client;
  bool loading = true;
  List<Map<String, dynamic>> subjectConfidence = [];
  bool isDescending = true;

  @override
  void initState() {
    super.initState();
    fetchConfidenceData();
  }

  Future<void> fetchConfidenceData() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final subjects = await supabase
          .from('subjects')
          .select('id, name')
          .eq('user_id', userId);

      final List<Map<String, dynamic>> result = [];

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final currentWeekday = today.weekday;
      final startOfCurrentWeek = today.subtract(Duration(days: currentWeekday - 1));
      final fiveWeeksAgo = startOfCurrentWeek.subtract(const Duration(days: 7 * 4));

      for (final subject in subjects) {
        final subjectId = subject['id'];
        final subjectName = subject['name'];

        // Fetch all topic IDs for the subject
        final topics = await supabase
            .from('topics')
            .select('id')
            .eq('subject_id', subjectId);

        if (topics == null || topics.isEmpty) {
          // No topics for this subject, skip
          result.add({
            'subjectId': subjectId,
            'subject': subjectName,
            'weeklyConfidences': List<double>.filled(5, 0),
            'meanConfidence': 0.0,
          });
          continue;
        }

        final topicIds = topics.map<int>((t) => t['id'] as int).toList();

        // Prepare list for weekly confidences and counts
        List<double> weeklyConfidences = List.filled(5, 0);
        List<int> weeklyCounts = List.filled(5, 0);

        // Fetch all revisions for these topic IDs within last 5 weeks
        final revisions = await supabase
            .from('revisions')
            .select('confidence, revised_at')
            .in_('topic_id', topicIds)
            .gte('revised_at', fiveWeeksAgo.toIso8601String())
            .lte('revised_at', startOfCurrentWeek.add(const Duration(days: 6)).toIso8601String())
            .order('revised_at', ascending: true);

        if (revisions != null && revisions.isNotEmpty) {
          for (final rev in revisions) {
            final revisedAtStr = rev['revised_at'] as String?;
            if (revisedAtStr == null) continue;
            final revisedAt = DateTime.tryParse(revisedAtStr);
            if (revisedAt == null) continue;

            final diffInDays = revisedAt.difference(fiveWeeksAgo).inDays;
            final weekIndex = diffInDays ~/ 7;
            if (weekIndex < 0 || weekIndex >= 5) continue;

            final confValue = rev['confidence'];
            if (confValue == null) continue;
            final conf = (confValue as num).toDouble();

            weeklyConfidences[weekIndex] += conf;
            weeklyCounts[weekIndex] += 1;
          }
        }

        // Calculate average confidence per week
        for (int i = 0; i < 5; i++) {
          if (weeklyCounts[i] > 0) {
            weeklyConfidences[i] = weeklyConfidences[i] / weeklyCounts[i];
          } else {
            weeklyConfidences[i] = 0.0;
          }
        }

        // Calculate mean confidence across weeks with data
        double meanConfidence = 0;
        int nonZeroWeeks = 0;
        for (final conf in weeklyConfidences) {
          if (conf > 0) {
            meanConfidence += conf;
            nonZeroWeeks++;
          }
        }
        meanConfidence = nonZeroWeeks > 0 ? meanConfidence / nonZeroWeeks : 0;

        result.add({
          'subjectId': subjectId,
          'subject': subjectName,
          'weeklyConfidences': weeklyConfidences,
          'meanConfidence': meanConfidence,
        });
      }

      // Sort the subjects by mean confidence according to isDescending flag
      result.sort((a, b) => isDescending
          ? b['meanConfidence'].compareTo(a['meanConfidence'])
          : a['meanConfidence'].compareTo(b['meanConfidence']));

      setState(() {
        subjectConfidence = result;
        loading = false;
      });
    } catch (e) {
      print('Error fetching confidence data: $e');
      setState(() => loading = false);
    }
  }

  void toggleSortOrder() {
    setState(() {
      isDescending = !isDescending;
      subjectConfidence.sort((a, b) => isDescending
          ? b['meanConfidence'].compareTo(a['meanConfidence'])
          : a['meanConfidence'].compareTo(b['meanConfidence']));
    });
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: isLight ? Colors.white : Colors.grey[900],
            floating: true,
            snap: true,
            elevation: 0,
            centerTitle: true,
            title: Text(
              'Confidence Rating',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isLight ? Colors.black : Colors.white,
              ),
            ),
            actions: [
              IconButton(
                tooltip: isDescending ? 'Sort Ascending' : 'Sort Descending',
                icon: Icon(
                  isDescending
                      ? Icons.arrow_downward
                      : Icons.arrow_upward,
                  color: isLight ? Colors.black : Colors.white,
                ),
                onPressed: toggleSortOrder,
              ),
            ],
          ),
          loading
              ? const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              : subjectConfidence.isEmpty
                  ? const SliverFillRemaining(
                      child: Center(child: Text('No confidence data found.')),
                    )
                  : SliverPadding(
                      padding: const EdgeInsets.all(16),
                      sliver: SliverToBoxAdapter(
                        child: Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: List.generate(subjectConfidence.length, (index) {
                            final subject = subjectConfidence[index];
                            return MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minWidth: 200,
                                  maxWidth: MediaQuery.of(context).size.width > 600
                                      ? (MediaQuery.of(context).size.width / 3) - 24
                                      : MediaQuery.of(context).size.width - 32,
                                ),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  curve: Curves.easeOut,
                                  decoration: BoxDecoration(
                                    color: isLight ? Colors.white : Colors.grey[850],
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(16),
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => TopicConfidencePage(
                                              subjectId: subject['subjectId'],
                                              subjectName: subject['subject'],
                                            ),
                                          ),
                                        );
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              subject['subject'],
                                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                    color: isLight ? Colors.black : Colors.white,
                                                  ),
                                            ),
                                            const SizedBox(height: 16),
                                            SizedBox(
                                              height: 200,
                                              child: BarChart(
                                                BarChartData(
                                                  alignment: BarChartAlignment.spaceAround,
                                                  maxY: 100,
                                                  minY: 0,
                                                  borderData: FlBorderData(show: false),
                                                  gridData: FlGridData(show: false),
                                                  titlesData: FlTitlesData(
                                                    bottomTitles: AxisTitles(
                                                      sideTitles: SideTitles(
                                                        showTitles: true,
                                                        getTitlesWidget: (value, _) {
                                                          return Text('W${(value + 1).toInt()}',
                                                              style: TextStyle(
                                                                color: isLight ? Colors.black : Colors.white,
                                                                fontWeight: FontWeight.bold,
                                                                fontSize: 15,
                                                              ));
                                                        },
                                                        interval: 1,
                                                        reservedSize: 24,
                                                      ),
                                                    ),
                                                    leftTitles: AxisTitles(
                                                      sideTitles: SideTitles(showTitles: false),
                                                    ),
                                                    rightTitles: AxisTitles(
                                                      sideTitles: SideTitles(showTitles: false),
                                                    ),
                                                    topTitles: AxisTitles(
                                                      sideTitles: SideTitles(showTitles: false),
                                                    ),
                                                  ),
                                                  barGroups: List.generate(5, (i) {
                                                    return BarChartGroupData(
                                                      x: i,
                                                      barRods: [
                                                        BarChartRodData(
                                                          toY: subject['weeklyConfidences'][i],
                                                          width: 50,
                                                          color: Colors.blue,
                                                          borderRadius: BorderRadius.circular(4),
                                                        ),
                                                      ],
                                                    );
                                                  }),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ),
        ],
      ),
      backgroundColor: isLight ? Colors.grey[100] : Colors.grey[900],
    );
  }
}