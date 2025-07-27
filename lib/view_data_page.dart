import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ViewDataPage extends StatefulWidget {
  const ViewDataPage({super.key});

  @override
  State<ViewDataPage> createState() => _ViewDataPageState();
}

class _ViewDataPageState extends State<ViewDataPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> data = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  Future<void> fetchData() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      // Get all subjects for user
      final subjectsRes = await supabase
          .from('subjects')
          .select('id, name')
          .eq('user_id', userId);

      final List<Map<String, dynamic>> displayData = [];

      for (final subject in subjectsRes) {
        final subjectId = subject['id'];
        final subjectName = subject['name'];

        final topicsRes = await supabase
            .from('topics')
            .select('id, name')
            .eq('subject_id', subjectId);

        for (final topic in topicsRes) {
          final topicId = topic['id'];
          final topicName = topic['name'];

          // Get all revisions for the topic
          final revisionsRes = await supabase
              .from('revisions')
              .select('id, confidence, duration, revised_at')
              .eq('topic_id', topicId)
              .order('revised_at', ascending: false);

          if (revisionsRes.isNotEmpty) {
            // Calculate total duration and mean confidence from all revisions
            int totalDuration = 0;
            double totalConfidence = 0;
            for (final revision in revisionsRes) {
              totalDuration += ((revision['duration'] ?? 0) as num).toInt();
              totalConfidence += (revision['confidence'] ?? 0).toDouble();
            }
            double meanConfidence = totalConfidence / revisionsRes.length;

            final latestRevision = revisionsRes.first;
            final latestRevisionId = latestRevision['id'];

            final strugglesRes = await supabase
                .from('struggles')
                .select('description')
                .eq('revision_id', latestRevisionId);

            displayData.add({
              'subject': subjectName,
              'topic': topicName,
              'confidence': meanConfidence,
              'duration': totalDuration,
              'revised_at': latestRevision['revised_at'].toString(),
              'struggles': strugglesRes.map((s) => s['description']).toList(),
            });
          }
        }
      }

      // Merge duplicates by subject + topic
      final Map<String, Map<String, dynamic>> merged = {};

      for (final entry in displayData) {
        final key = '${entry['subject']}|${entry['topic']}';
        if (!merged.containsKey(key)) {
          merged[key] = {
            'subject': entry['subject'],
            'topic': entry['topic'],
            'confidenceTotal': entry['confidence'],
            'confidenceCount': 1,
            'duration': entry['duration'],
            'revised_at': entry['revised_at'],
            'struggles': List<String>.from(entry['struggles']),
          };
        } else {
          merged[key]!['confidenceTotal'] += (entry['confidence'] as num).toDouble();
          merged[key]!['confidenceCount'] += 1;
          merged[key]!['duration'] += (entry['duration'] as num).toInt();
          final DateTime entryDate = DateTime.parse(entry['revised_at'].toString());
          final DateTime existingDate = DateTime.parse(merged[key]!['revised_at'].toString());
          if (entryDate.isAfter(existingDate)) {
            merged[key]!['revised_at'] = entryDate.toIso8601String();
          }
          merged[key]!['struggles'].addAll(List<String>.from(entry['struggles']));
        }
      }

      final List<Map<String, dynamic>> finalData = merged.values.map((entry) {
        return {
          'subject': entry['subject'],
          'topic': entry['topic'],
          'confidence': entry['confidenceTotal'] / entry['confidenceCount'],
          'duration': entry['duration'],
          'revised_at': entry['revised_at'],
          'struggles': entry['struggles'],
        };
      }).toList();

      setState(() {
        data = finalData;
        loading = false;
      });
    } catch (e) {
      print('Error loading data: $e');
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('View Saved Data')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : data.isEmpty
              ? const Center(child: Text('No data found.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: data.length,
                  itemBuilder: (context, index) {
                    final entry = data[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Subject: ${entry['subject']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text('Topic: ${entry['topic']}'),
                            Text('Confidence: ${entry['confidence']}'),
                            Text('Duration: ${entry['duration']} mins'),
                            Text('Revised At: ${entry['revised_at']}'),
                            const SizedBox(height: 8),
                            const Text('Struggled With:', style: TextStyle(decoration: TextDecoration.underline)),
                            ...List.generate(entry['struggles'].length, (i) => Text('• ${entry['struggles'][i]}')),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}