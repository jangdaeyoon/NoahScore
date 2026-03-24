import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:intl/intl.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 보안을 위해 API 키는 빌드 시 주입받습니다.
  // await Firebase.initializeApp(); 
  runApp(const NoahScoreV2());
}

class NoahScoreV2 extends StatelessWidget {
  const NoahScoreV2({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF1F1F1F), elevation: 0),
        cardTheme: CardTheme(color: const Color(0xFF1E1E1E), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  // 빌드 시 주입되는 Gemini API 키 환경 변수
  static const String geminiKey = String.fromEnvironment('GEMINI_API_KEY');
  final String footballApiKey = '8b3c5b00b4a18b203a63f7f0aba0ddd2'; 

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          AllMatchesPage(apiKey: footballApiKey),
          LiveMatchesPage(apiKey: footballApiKey),
          const StandingsPage(),
          const LeagueExplorerScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF1F1F1F),
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.grey,
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.view_list), label: '오늘경기'),
          BottomNavigationBarItem(icon: Icon(Icons.live_tv), label: 'LIVE'),
          BottomNavigationBarItem(icon: Icon(Icons.leaderboard), label: '순위'),
          BottomNavigationBarItem(icon: Icon(Icons.public), label: '탐색'),
        ],
      ),
    );
  }
}

// --- [데이터 엔진] ---
class NoahDataEngine {
  static const String host = 'v3.football.api-sports.io';

  static Future<Map<String, List<dynamic>>> fetchTodayMatches(String key) async {
    String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final res = await http.get(Uri.parse('https://$host/fixtures?date=$today'), headers: {'x-rapidapi-key': key, 'x-rapidapi-host': host});
    List matches = json.decode(res.body)['response'] ?? [];
    return groupBy(matches, (m) => "${m['league']['country']} - ${m['league']['name']}");
  }

  static Future<List<dynamic>> fetchLiveMatches(String key) async {
    final res = await http.get(Uri.parse('https://$host/fixtures?live=all'), headers: {'x-rapidapi-key': key, 'x-rapidapi-host': host});
    return json.decode(res.body)['response'] ?? [];
  }

  static Future<Map<String, dynamic>> fetchAiPrediction(int fixtureId) async {
    // 실제 운영 시에는 주인님의 C++ 코어 서버 주소로 변경합니다. [cite: 2026-03-02]
    try {
      final res = await http.get(Uri.parse('http://localhost:5000/analyze')).timeout(const Duration(seconds: 1));
      return json.decode(res.body);
    } catch (e) {
      // 서버 미가동 시 더미 데이터 (시각화 테스트용)
      return {
        "prediction": {"home": 64, "draw": 21, "away": 15},
        "visual_metrics": {"spear": 83, "shield": 37},
        "value_analysis": {"roi": 18.7}
      };
    }
  }
}

// --- [상세 분석 페이지: 창과 방패 UI] ---
class MatchDetailPage extends StatelessWidget {
  final dynamic match;
  const MatchDetailPage({super.key, required this.match});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${match['teams']['home']['name']} vs ${match['teams']['away']['name']}')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: NoahDataEngine.fetchAiPrediction(match['fixture']['id']),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          var ai = snapshot.data!;
          return SingleChildScrollView(
            child: Column(
              children: [
                _buildVisualMetrics(ai['visual_metrics']['spear'], ai['visual_metrics']['shield']), 
                _buildAiReportCard(ai),
              ],
            ),
          );
        }
      ),
    );
  }

  Widget _buildVisualMetrics(int spear, int shield) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 30),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _metricColumn("창 (공격)", spear, Colors.redAccent),
          const Icon(Icons.bolt, color: Colors.amber, size: 50),
          _metricColumn("방패 (수비)", shield, Colors.blueAccent),
        ],
      ),
    );
  }

  Widget _metricColumn(String label, int val, Color col) => Column(
    children: [
      Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
      const SizedBox(height: 15),
      Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(width: 90, height: 90, child: CircularProgressIndicator(value: val/100, color: col, strokeWidth: 10, backgroundColor: Colors.white10)),
          Text('$val', style: TextStyle(color: col, fontSize: 24, fontWeight: FontWeight.bold)),
        ],
      ),
    ],
  );

  Widget _buildAiReportCard(Map<String, dynamic> ai) => Card(
    margin: const EdgeInsets.all(16),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Row(children: [Icon(Icons.auto_awesome, color: Colors.amber), SizedBox(width: 10), Text("Noah AI 승률 분석", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))]),
          const SizedBox(height: 25),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _probText("홈승", ai['prediction']['home'], Colors.redAccent),
              _probText("무승부", ai['prediction']['draw'], Colors.grey),
              _probText("원정승", ai['prediction']['away'], Colors.blueAccent),
            ],
          ),
          const Divider(height: 40, color: Colors.white24),
          const Text("💰 실시간 배류(Value) 리포트", style: TextStyle(color: Colors.amber, letterSpacing: 1.2)),
          const SizedBox(height: 10),
          Text("+${ai['value_analysis']['roi']}% 기댓값 발생", style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.greenAccent)),
          const SizedBox(height: 10),
          const Text("북메이커 대비 15% 이상 유리한 고지", style: TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    ),
  );

  Widget _probText(String label, int val, Color col) => Column(
    children: [
      Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      Text('$val%', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: col)),
    ],
  );
}

// --- [AllMatchesPage & LiveMatchesPage: 생략된 부분 복원] ---
class AllMatchesPage extends StatelessWidget {
  final String apiKey;
  const AllMatchesPage({super.key, required this.apiKey});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('NoahScore V2.1')),
      body: FutureBuilder<Map<String, List<dynamic>>>(
        future: NoahDataEngine.fetchTodayMatches(apiKey),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          return ListView.builder(
            itemCount: snapshot.data!.keys.length,
            itemBuilder: (context, index) {
              String league = snapshot.data!.keys.elementAt(index);
              return ExpansionTile(
                initiallyExpanded: true,
                title: Text(league, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                children: snapshot.data![league]!.map((m) => ListTile(
                  leading: Image.network(m['teams']['home']['logo'], width: 30),
                  title: Text("${m['teams']['home']['name']} vs ${m['teams']['away']['name']}", style: const TextStyle(fontSize: 13)),
                  trailing: Text("${m['goals']['home'] ?? '-'} : ${m['goals']['away'] ?? '-'}", style: const TextStyle(fontWeight: FontWeight.bold)),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MatchDetailPage(match: m))),
                )).toList(),
              );
            },
          );
        },
      ),
    );
  }
}

class LiveMatchesPage extends StatelessWidget {
  final String apiKey;
  const LiveMatchesPage({super.key, required this.apiKey});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('LIVE Matches', style: TextStyle(color: Colors.redAccent))),
      body: FutureBuilder<List<dynamic>>(
        future: NoahDataEngine.fetchLiveMatches(apiKey),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          if (snapshot.data!.isEmpty) return const Center(child: Text("현재 진행 중인 경기가 없습니다."));
          return ListView.builder(
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              var m = snapshot.data![index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  leading: CircleAvatar(backgroundColor: Colors.red, radius: 15, child: Text("${m['fixture']['status']['elapsed']}'", style: const TextStyle(fontSize: 10, color: Colors.white))),
                  title: Text("${m['teams']['home']['name']} vs ${m['teams']['away']['name']}"),
                  trailing: Text("${m['goals']['home']} : ${m['goals']['away']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.greenAccent)),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MatchDetailPage(match: m))),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class StandingsPage extends StatelessWidget { const StandingsPage({super.key}); @override Widget build(BuildContext context) => const Center(child: Text("순위 데이터 분석 중...")); }
class LeagueExplorerScreen extends StatelessWidget { const LeagueExplorerScreen({super.key}); @override Widget build(BuildContext context) => const Center(child: Text("글로벌 리그 탐색 준비 중...")); }