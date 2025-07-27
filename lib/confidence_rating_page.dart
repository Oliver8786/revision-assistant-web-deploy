import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'topic_confidence_page.dart';

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

      for (final subject in subjects) {
        final subjectId = subject['id'];
        final subjectName = subject['name'];

        // Fetch all topics for the subject
        final topics = await supabase
            .from('topics')
            .select('id, name')
            .eq('subject_id', subjectId)
            .order('name', ascending: true);

        // Group topic IDs by topic name to handle duplicates
        final Map<String, List<int>> topicNameToIds = {};
        for (final topic in topics) {
          final name = topic['name'] as String;
          final id = topic['id'] as int;
          topicNameToIds.putIfAbsent(name, () => []).add(id);
        }

        double totalConfidence = 0;
        int count = 0;

        for (final entry in topicNameToIds.entries) {
          final topicName = entry.key;
          final topicIds = entry.value;

          // Fetch revisions for all topic IDs with this name
          final revisions = await supabase
              .from('revisions')
              .select('confidence, revised_at, topic_id')
              .in_('topic_id', topicIds)
              .order('revised_at', ascending: false);

          if (revisions == null || revisions.isEmpty) {
            debugPrint('Skipping topic "$topicName" - no revisions found.');
            continue;
          }

          // Find the revision with the latest revised_at timestamp
          Map<String, dynamic>? newestRevision;
          DateTime? newestTime;

          for (final rev in revisions) {
            final revisedAtStr = rev['revised_at'] as String?;
            if (revisedAtStr == null) continue;

            final revisedAt = DateTime.tryParse(revisedAtStr);
            if (revisedAt == null) continue;

            if (newestTime == null || revisedAt.isAfter(newestTime)) {
              newestTime = revisedAt;
              newestRevision = rev;
            }
          }

          if (newestRevision == null || newestRevision['confidence'] == null) {
            debugPrint('Skipping topic "$topicName" due to no valid confidence.');
            continue;
          }

          final conf = (newestRevision['confidence'] as num).toDouble();
          debugPrint(
            'Including topic "$topicName" with confidence $conf from $newestTime',
          );

          totalConfidence += conf;
          count += 1;
        }

        if (count > 0) {
          result.add({
            'subjectId': subjectId,
            'subject': subjectName,
            'meanConfidence': totalConfidence / count,
          });
        }
      }

      // Sort according to current isDescending value
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
                                            Container(
                                              height: 40,
                                              decoration: BoxDecoration(
                                                color: isLight ? Colors.grey[200] : Colors.grey[800],
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Center(
                                                child: Text(
                                                  "Confidence Rating: ${subject['meanConfidence'].toStringAsFixed(2)}",
                                                  style: TextStyle(
                                                    color: isLight ? Colors.black : Colors.white,
                                                  ),
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