import 'dart:convert';
import 'auth_pages.dart';
import 'settings_page.dart';
import 'view_data_page.dart';
import 'confidence_rating_page.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gotrue/gotrue.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  print('🧪 SUPABASE URL: https://lstsvfifherpbzpwigse.supabase.co');
  await Supabase.initialize(
    url: 'https://lstsvfifherpbzpwigse.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxzdHN2ZmlmaGVycGJ6cHdpZ3NlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTM1NTUxNDMsImV4cCI6MjA2OTEzMTE0M30.CpxBNDmoJDFxl9rbGEn_DaG60Un7aTDmHllT9qi04_8',
  );

  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData.light(),
    darkTheme: ThemeData.dark(),
    themeMode: ThemeMode.system,
    routes: {
      '/': (context) => const AuthWrapper(),
      '/confidence': (context) => const ConfidenceRatingPage(),
    },
    initialRoute: '/',
  ));
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;
  Session? session;

  @override
  void initState() {
    super.initState();
    session = supabase.auth.currentSession;
    supabase.auth.onAuthStateChange.listen((data) {
      setState(() {
        session = data.session;
      });
    });
    isLoading = false;
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (session == null) {
      return LoginPage(onLoginSuccess: () {
        setState(() {
          session = supabase.auth.currentSession;
        });
      });
    }
    return const HomePage(title: 'Revision Assistant');
  }
}

class HomePage extends StatefulWidget {
  final String title;
  const HomePage({super.key, required this.title});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Scaffold(
      // Remove AppBar, use CustomScrollView with SliverAppBar for Apple-inspired design
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: isLight ? Colors.white : Colors.grey[900],
            floating: true,
            snap: true,
            elevation: 0,
            centerTitle: true,
            title: Text(
              widget.title,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isLight ? Colors.black : Colors.white,
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  CupertinoIcons.gear,
                  color: isLight ? Colors.black : Colors.white,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SettingsPage()),
                  );
                },
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 16,
            ),
          ),
          const SliverToBoxAdapter(
            child: WidgetList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: isLight ? Colors.black : Colors.white,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddFromJsonPage()),
          );
        },
        child: Icon(
          CupertinoIcons.add,
          color: isLight ? Colors.white : Colors.black,
        ),
      ),
      backgroundColor: isLight ? Colors.grey[100] : Colors.grey[900],
    );
  }
}

class WidgetList extends StatelessWidget {
  const WidgetList({super.key});

  @override
  Widget build(BuildContext context) {
    final List<String> widgetTitles = [
      'Confidence Rating',
      'Last Visited',
      'Time Spent',
      'TBD',
      'TBD',
      'Test View',
    ];
    // Use GridView.builder for modular widget-style layout
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 1,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 1.4,
      ),
      padding: const EdgeInsets.all(16),
      itemCount: widgetTitles.length,
      itemBuilder: (context, index) {
        return _WidgetCard(
          title: widgetTitles[index],
          index: index,
        );
      },
    );
  }
}

class _WidgetCard extends StatefulWidget {
  final String title;
  final int index;
  const _WidgetCard({required this.title, required this.index});

  @override
  State<_WidgetCard> createState() => _WidgetCardState();
}

class _WidgetCardState extends State<_WidgetCard> {
  late Future<List<double>> _weeklyAveragesFuture;
  bool _hovering = false;

  void _onTap() {
    if (widget.index == 0) {
      Navigator.pushNamed(context, '/confidence');
    } else if (widget.index == 5) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ViewDataPage()),
      );
    } else {
      // Placeholder for future navigation
      print('Tapped on ${widget.title}');
    }
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

        return GestureDetector(
          onTap: _onTap,
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
                width: 12,
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
                  Text('W${value.toInt() + 1}', style: const TextStyle(fontSize: 10)),
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 20,
              getTitlesWidget: (value, _) => Text(
                value.toInt().toString(),
                style: const TextStyle(fontSize: 10),
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
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isLight ? Colors.black : Colors.white,
                        ),
                  ),
                  const SizedBox(height: 16),
                  if (widget.index == 0)
                    Expanded(child: _buildConfidenceChart())
                  else
                    const Spacer(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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

      // Check or insert subject
      final subjectResponse = await supabase
          .from('subjects')
          .select()
          .eq('user_id', userId)
          .eq('name', subjectName)
          .limit(1)
          .execute();

      int subjectId;
      if (subjectResponse.data != null && subjectResponse.data.isNotEmpty) {
        subjectId = subjectResponse.data[0]['id'];
      } else {
        final insertSubject = await supabase.from('subjects').insert({
          'user_id': userId,
          'name': subjectName,
        }).select().single();
        subjectId = insertSubject['id'];
      }

      for (final topic in topics) {
        // Insert topic (allow duplicates)
        final topicInsert = await supabase.from('topics').insert({
          'subject_id': subjectId,
          'name': topic['name'],
        }).select().single();
        final topicId = topicInsert['id'];

        // Insert revision
        final revisionInsert = await supabase.from('revisions').insert({
          'topic_id': topicId,
          'confidence': topic['confidence'],
          'duration': topic['durationMinutes'],
          'revised_at': revisedAt,
        }).select().single();
        final revisionId = revisionInsert['id'];

        // Insert struggles
        final List<dynamic> struggles = topic['struggledWith'];
        for (final struggle in struggles) {
          await supabase.from('struggles').insert({
            'revision_id': revisionId,
            'description': struggle,
          }).execute();
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