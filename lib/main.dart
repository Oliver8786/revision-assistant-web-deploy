import 'dart:convert';
import 'auth_pages.dart';
import 'settings_page.dart';
import 'view_data_page.dart';
import 'confidence_rating_page.dart';
import 'add_from_json_page.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gotrue/gotrue.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'widgets/confidence_rating_widget.dart';


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

  final List<Widget> widgets = const [
    ConfidenceRatingWidget(),
    ];

  @override
  Widget build(BuildContext context) {
    final crossAxisCount = MediaQuery.of(context).size.width > 600 ? 3 : 1;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: widgets.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.4,
        ),
        itemBuilder: (context, index) {
          return widgets[index];
        },
      ),
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
  bool _hovering = false;

  void _onTap() {
    if (widget.index == 5) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ViewDataPage()),
      );
    } else {
      print('Tapped on ${widget.title}');
    }
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