import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'topic_confidence_history_page.dart';

class TopicConfidencePage extends StatefulWidget {
  final int subjectId;
  final String subjectName;

  const TopicConfidencePage({
    super.key,
    required this.subjectId,
    required this.subjectName,
  });

  @override
  State<TopicConfidencePage> createState() => _TopicConfidencePageState();
}

class _TopicConfidencePageState extends State<TopicConfidencePage> {
  final supabase = Supabase.instance.client;
  bool loading = true;
  List<Map<String, dynamic>> topicConfidence = [];
  bool isDescending = true;

  @override
  void initState() {
    super.initState();
    fetchTopicConfidenceData();
  }

  Future<void> fetchTopicConfidenceData() async {
    try {
      // Fetch all topics for the given subject
      final topics = await supabase
          .from('topics')
          .select('id, name')
          .eq('subject_id', widget.subjectId)
          .order('name', ascending: true);

      // Group topic IDs by topic name to handle duplicates
      final Map<String, List<int>> topicNameToIds = {};
      for (final topic in topics) {
        final name = topic['name'] as String;
        final id = topic['id'] as int;
        topicNameToIds.putIfAbsent(name, () => []).add(id);
      }

      final List<Map<String, dynamic>> results = [];

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
        final topicId = newestRevision['topic_id'] as int;
        results.add({
          'topicName': topicName,
          'confidence': conf,
          'revisedAt': newestTime,
          'topicId': topicId,
        });
      }

      // Sort results by confidence descending initially
      results.sort((a, b) => isDescending
          ? b['confidence'].compareTo(a['confidence'])
          : a['confidence'].compareTo(b['confidence']));

      setState(() {
        topicConfidence = results;
        loading = false;
      });
    } catch (e) {
      print('Error fetching topic confidence data: $e');
      setState(() => loading = false);
    }
  }

  void toggleSortOrder() {
    setState(() {
      isDescending = !isDescending;
      topicConfidence.sort((a, b) => isDescending
          ? b['confidence'].compareTo(a['confidence'])
          : a['confidence'].compareTo(b['confidence']));
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
              'Topics in ${widget.subjectName}',
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
                  isDescending ? Icons.arrow_downward : Icons.arrow_upward,
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
              : topicConfidence.isEmpty
                  ? const SliverFillRemaining(
                      child: Center(child: Text('No confidence data found.')),
                    )
                  : SliverPadding(
                      padding: const EdgeInsets.all(16),
                      sliver: SliverToBoxAdapter(
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: List.generate(topicConfidence.length, (index) {
                            final topic = topicConfidence[index];
                            return ConstrainedBox(
                              constraints: BoxConstraints(
                                minWidth: 120,
                                maxWidth: MediaQuery.of(context).size.width /
                                    (MediaQuery.of(context).size.width > 800 ? 4 : 2) -
                                    24,
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
                                          builder: (_) => TopicConfidenceHistoryPage(
                                            topicId: topic['topicId'],
                                            topicName: topic['topicName'],
                                          ),
                                        ),
                                      );
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            topic['topicName'],
                                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  color: isLight ? Colors.black : Colors.white,
                                                ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            "Confidence: ${topic['confidence'].toStringAsFixed(2)}",
                                            style: TextStyle(
                                              color: isLight ? Colors.black : Colors.white,
                                            ),
                                          ),
                                        ],
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