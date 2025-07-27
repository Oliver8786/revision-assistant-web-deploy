import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // for date formatting
import 'package:supabase_flutter/supabase_flutter.dart';

class TopicConfidenceHistoryPage extends StatefulWidget {
  final int topicId;
  final String topicName;

  const TopicConfidenceHistoryPage({
    super.key,
    required this.topicId,
    required this.topicName,
  });

  @override
  State<TopicConfidenceHistoryPage> createState() => _TopicConfidenceHistoryPageState();
}

class _TopicConfidenceHistoryPageState extends State<TopicConfidenceHistoryPage> {
  final supabase = Supabase.instance.client;
  bool loading = true;
  List<Map<String, dynamic>> revisions = [];

  @override
  void initState() {
    super.initState();
    fetchRevisions();
  }

  Future<void> fetchRevisions() async {
    try {
      // Join revisions with topics table on topic_id and filter by topic name
      final data = await supabase
          .from('revisions')
          .select('confidence, revised_at, duration, topics!inner(name)')
          .eq('topics.name', widget.topicName)
          .order('revised_at', ascending: false)
          .execute(); // Added execute() to run the query
      
      // Note: Supabase Flutter client requires .execute() when using filters on related tables
      // The above query fetches revisions where the joined topic's name matches widget.topicName

      // The returned data is wrapped in a PostgrestResponse, so extract data accordingly
      final List<dynamic>? dataList = data.data;

      print('Fetched revisions: $dataList');

      setState(() {
        revisions = List<Map<String, dynamic>>.from(dataList ?? []);
        loading = false;
      });
    } catch (e) {
      print('Error fetching revisions: $e');
      setState(() => loading = false);
    }
  }

  String formatDate(String? dateStr) {
    if (dateStr == null) return 'Unknown date';
    try {
      final dateTime = DateTime.parse(dateStr);
      // Format date and time
      final formattedDate = DateFormat('yyyy-MM-dd HH:mm').format(dateTime);
      // Get timezone offset as string like +01:00
      final offset = dateTime.timeZoneOffset;
      final hours = offset.inHours.abs().toString().padLeft(2, '0');
      final minutes = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
      final sign = offset.isNegative ? '-' : '+';
      final offsetString = '$sign$hours:$minutes';
      return '$formattedDate (UTC$offsetString)';
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Scaffold(
      appBar: AppBar(
        title: Text('Confidence History: ${widget.topicName}'),
        backgroundColor: isLight ? Colors.blue : Colors.grey[900],
      ),
      backgroundColor: isLight ? Colors.grey[100] : Colors.grey[900],
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : revisions.isEmpty
              ? const Center(child: Text('No confidence data found.'))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: revisions.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, index) {
                    final revision = revisions[index];
                    final confidence = (revision['confidence'] as num).toDouble();
                    final revisedAt = formatDate(revision['revised_at'] as String?);
                    final duration = revision['duration'] as int?;

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isLight ? Colors.blue : Colors.grey[700],
                        child: Text(
                          confidence.toStringAsFixed(0),
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text('Confidence: ${confidence.toStringAsFixed(2)}'),
                      subtitle: Text('Date: $revisedAt\nDuration: ${duration ?? 'N/A'} min'),
                    );
                  },
                ),
    );
  }
}