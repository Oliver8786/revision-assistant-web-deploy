import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddFromJsonPage extends StatefulWidget {
  const AddFromJsonPage({super.key});

  @override
  State<AddFromJsonPage> createState() => _AddFromJsonPageState();
}

class _AddFromJsonPageState extends State<AddFromJsonPage> {
  final TextEditingController _jsonController = TextEditingController();
  final supabase = Supabase.instance.client;
  String? error;

  Future<void> handleJsonSubmit() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      setState(() => error = 'User not logged in.');
      return;
    }

    try {
      final Map<String, dynamic> data = jsonDecode(_jsonController.text.trim());

      final revisedAt = DateTime.now().toIso8601String();
      final subjectName = data['subject'];
      final List<dynamic> topics = data['topics'];

      final subjectResponse = await supabase
          .from('subjects')
          .select()
          .eq('user_id', userId)
          .eq('name', subjectName)
          .limit(1);

      int subjectId;
      if (subjectResponse.isNotEmpty) {
        subjectId = subjectResponse[0]['id'] as int;
      } else {
        final insertSubject = await supabase.from('subjects').insert({
          'user_id': userId,
          'name': subjectName,
        }).select().single();
        subjectId = insertSubject['id'] as int;
      }

      for (final topic in topics) {
        final topicInsert = await supabase.from('topics').insert({
          'subject_id': subjectId,
          'name': topic['name'],
        }).select().single();
        final topicId = topicInsert['id'] as int;

        final revisionInsert = await supabase.from('revisions').insert({
          'topic_id': topicId,
          'confidence': topic['confidence'],
          'duration': topic['durationMinutes'],
          'revised_at': revisedAt,
        }).select().single();
        final revisionId = revisionInsert['id'] as int;

        final List<dynamic> struggles = topic['struggledWith'];
        for (final struggle in struggles) {
          await supabase.from('struggles').insert({
            'revision_id': revisionId,
            'description': struggle,
          });
        }
      }

      setState(() {
        error = null;
        _jsonController.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data added successfully!')),
      );
    } catch (e) {
      setState(() => error = 'Invalid JSON or DB error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Data from JSON')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _jsonController,
              decoration: const InputDecoration(labelText: 'Paste JSON here'),
              maxLines: 10,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      final data = await Clipboard.getData('text/plain');
                      if (data != null && data.text != null) {
                        setState(() {
                          _jsonController.text = data.text!;
                          error = null;
                        });
                      }
                    },
                    child: const Text('Paste'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: handleJsonSubmit,
                    child: const Text('Submit'),
                  ),
                ),
              ],
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(error!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
    );
  }
}