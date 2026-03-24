import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:intl/intl.dart';

void main() => runApp(const NoahScoreV2());

class NoahScoreV2 extends StatelessWidget {
  const NoahScoreV2({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF1F1F1F), elevation: 0),
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
  final String apiKey = '8b3c5b00b4a18b203a63f7f0aba0ddd2';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          AllMatchesPage(apiKey: apiKey),
          LiveMatchesPage(apiKey: apiKey), // 🔥 V2.0: 실시간 LIVE 탭 완성
          StandingsPage(apiKey: apiKey),
          LeagueExplorerScreen(apiKey: apiKey),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF1F1F1F),
        selectedItemColor: Colors.blueAccent,
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

// --- [V2.0 핵심: 통합 데이터 엔진] ---
class NoahDataEngine {
  static const String host = 'v3.football.api-sports.io';
  
  // 1. 오늘 경기 및 리그별 그룹화
  static Future<Map<String, List<dynamic>>> fetchTodayMatches(String key) async {
    String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final res = await http.get(Uri.parse('https://\System.Management.Automation.Internal.Host.InternalHost/fixtures?date=\'), headers: {'x-rapidapi-key': key, 'x-rapidapi-host': host});
    List matches = json.decode(res.body)['response'] ?? [];
    return groupBy(matches, (m) => "\ - \");
  }

  // 2. 실시간 경기 가져오기
  static Future<List<dynamic>> fetchLiveMatches(String key) async {
    final res = await http.get(Uri.parse('https://\System.Management.Automation.Internal.Host.InternalHost/fixtures?live=all'), headers: {'x-rapidapi-key': key, 'x-rapidapi-host': host});
    return json.decode(res.body)['response'] ?? [];
  }

  // 3. [지능형 브릿지] C++ 코어 서버에 AI 예측 결과 요청 (예약)
  static Future<Map<String, dynamic>> fetchAiPrediction(int fixtureId) async {
    try {
      // 도커로 띄운 C++ 코어 서버(포트 8080)에 연결 시도
      final res = await http.get(Uri.parse('http://localhost:8080/api/prediction/\')).timeout(const Duration(seconds: 2));
      return json.decode(res.body);
    } catch (e) {
      return {"status": "offline", "message": "AI 분석 엔진 연결 중..."};
    }
  }
}

// --- [V2.0: 실시간 LIVE 페이지] ---
class LiveMatchesPage extends StatelessWidget {
  final String apiKey;
  const LiveMatchesPage({super.key, required this.apiKey});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      app_appBar: AppBar(title: const Text('LIVE ⚽', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))),
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
                child: ListTile(
                  leading: Text("\'", style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                  title: Text("\ vs \"),
                  trailing: Text("\ : \", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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

// --- [V2.0: 상세 분석 페이지 (AI 예측 인터페이스)] ---
class MatchDetailPage extends StatelessWidget {
  final dynamic match;
  const MatchDetailPage({super.key, required this.match});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('상세 분석 & AI 예측')),
      body: Column(
        children: [
          _buildScoreBoard(),
          const Divider(),
          _buildAiPredictionSection(),
        ],
      ),
    );
  }

  Widget _buildScoreBoard() => Padding(
    padding: const EdgeInsets.all(20.0),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Column(children: [Image.network(match['teams']['home']['logo'], width: 60), Text(match['teams']['home']['name'])]),
        const Text('VS', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        Column(children: [Image.network(match['teams']['away']['logo'], width: 60), Text(match['teams']['away']['name'])]),
      ],
    ),
  );

  Widget _buildAiPredictionSection() => FutureBuilder(
    future: NoahDataEngine.fetchAiPrediction(match['fixture']['id']),
    builder: (context, snapshot) {
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.blueGrey.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            const Row(children: [Icon(Icons.psychology, color: Colors.amber), SizedBox(width: 10), Text('Noah AI 승률 분석', style: TextStyle(fontWeight: FontWeight.bold))]),
            const SizedBox(height: 20),
            Text(snapshot.hasData ? snapshot.data!['message'] ?? "분석 완료: 홈팀 승률 65%" : "엔진 가동 중..."),
            const SizedBox(height: 10),
            const LinearProgressIndicator(value: 0.65, color: Colors.amber),
          ],
        ),
      );
    }
  );
}

// (나머지 AllMatchesPage, StandingsPage, LeagueExplorerScreen 로직 유지)
class AllMatchesPage extends StatelessWidget {
  final String apiKey;
  const AllMatchesPage({super.key, required this.apiKey});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('NoahScore ⚽')),
      body: FutureBuilder<Map<String, List<dynamic>>>(
        future: NoahDataEngine.fetchTodayMatches(apiKey),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          return ListView.builder(
            itemCount: snapshot.data!.keys.length,
            itemBuilder: (context, index) {
              String league = snapshot.data!.keys.elementAt(index);
              return Column(
                children: [
                  ListTile(title: Text(league, style: const TextStyle(fontSize: 12, color: Colors.grey)), dense: true, tileColor: Colors.white10),
                  ...snapshot.data![league]!.map((m) => ListTile(
                    title: Text("\ vs \"),
                    trailing: Text("\ : \"),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MatchDetailPage(match: m))),
                  )),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

// (StandingsPage, LeagueExplorerScreen 생략... 기존 코드와 동일)
