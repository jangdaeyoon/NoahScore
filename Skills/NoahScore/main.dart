import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:intl/intl.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
  final String footballApiKey = '8b3c5b00b4a18b203a63f7f0aba0ddd2'; 

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          AllMatchesPage(apiKey: footballApiKey),
          LiveMatchesPage(apiKey: footballApiKey),
          StandingsPage(apiKey: footballApiKey),
          LeagueExplorerScreen(apiKey: footballApiKey),
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

  static Future<Map<String, dynamic>> fetchAiPrediction(int fixtureId, String key) async {
    try {
      final res = await http.get(Uri.parse('http://localhost:5000/analyze')).timeout(const Duration(milliseconds: 500));
      return json.decode(res.body);
    } catch (e) {
      final fallbackRes = await http.get(Uri.parse('https://$host/predictions?fixture=$fixtureId'), headers: {'x-rapidapi-key': key, 'x-rapidapi-host': host});
      int homeWin = 33, draw = 33, awayWin = 34, homeAtt = 50, awayDef = 50;
      try {
        var data = json.decode(fallbackRes.body)['response'][0];
        homeWin = int.tryParse(data['predictions']['percent']['home'].replaceAll('%', '')) ?? 33;
        draw = int.tryParse(data['predictions']['percent']['draw'].replaceAll('%', '')) ?? 33;
        awayWin = int.tryParse(data['predictions']['percent']['away'].replaceAll('%', '')) ?? 34;
        homeAtt = int.tryParse(data['comparison']['att']['home'].replaceAll('%', '')) ?? 50;
        awayDef = int.tryParse(data['comparison']['def']['away'].replaceAll('%', '')) ?? 50;
      } catch (e) { }
      return {
        "prediction": {"home": homeWin, "draw": draw, "away": awayWin},
        "visual_metrics": {"spear": homeAtt, "shield": awayDef},
        "value_analysis": {"roi": (homeWin * 0.15).toStringAsFixed(1)} 
      };
    }
  }
}

// --- [공통 위젯 생성기 (HTML 템플릿)] ---
Widget buildApiWidget(String widgetType, String attributes, String apiKey) {
  final controller = WebViewController()
    ..setJavaScriptMode(JavaScriptMode.unrestricted)
    ..setBackgroundColor(const Color(0xFF121212))
    ..loadHtmlString('''
      <html>
        <head><meta name="viewport" content="width=device-width, initial-scale=1.0"></head>
        <body style="background-color: #121212; margin: 0;">
          <div id="wg-api-football-$widgetType"
              data-host="v3.football.api-sports.io"
              data-key="$apiKey"
              data-theme="dark"
              data-show-errors="false"
              $attributes
              class="wg_loader">
          </div>
          <script type="module" src="https://widgets.api-sports.io/2.0.0/widgets.js"></script>
        </body>
      </html>
    ''');
  return WebViewWidget(controller: controller);
}

// --- [상세 분석 페이지: AI 분석 + 게임/H2H/팀 위젯 통합] ---
class MatchDetailPage extends StatelessWidget {
  final dynamic match;
  final String apiKey;
  const MatchDetailPage({super.key, required this.match, required this.apiKey});

  @override
  Widget build(BuildContext context) {
    String homeName = match['teams']['home']['name'];
    String awayName = match['teams']['away']['name'];
    int fixtureId = match['fixture']['id'];
    int homeId = match['teams']['home']['id'];
    int awayId = match['teams']['away']['id'];

    return DefaultTabController(
      length: 4, // 4개의 탭 생성
      child: Scaffold(
        appBar: AppBar(
          title: Text('$homeName vs $awayName', style: const TextStyle(fontSize: 16)),
          bottom: const TabBar(
            isScrollable: true,
            indicatorColor: Colors.blueAccent,
            tabs: [
              Tab(text: "AI 분석"),
              Tab(text: "매치 센터"), // 게임 위젯
              Tab(text: "상대 전적"), // H2H 위젯
              Tab(text: "팀 정보"), // 팀 위젯
            ],
          ),
        ),
        body: TabBarView(
          physics: const NeverScrollableScrollPhysics(), // 스와이프 간섭 방지
          children: [
            // 탭 1: AI 승률 분석 (기존)
            _buildAiAnalysisTab(homeName, awayName, fixtureId),
            // 탭 2: 게임 위젯 (라인업, 실시간 스탯)
            buildApiWidget("game", 'data-game-id="$fixtureId"', apiKey),
            // 탭 3: H2H 위젯 (맞대결)
            buildApiWidget("h2h", 'data-h2h="$homeId-$awayId"', apiKey),
            // 탭 4: 팀 위젯 (홈팀 기준 스쿼드/선수 정보)
            buildApiWidget("team", 'data-team-id="$homeId"', apiKey),
          ],
        ),
      ),
    );
  }

  Widget _buildAiAnalysisTab(String homeName, String awayName, int fixtureId) {
    return FutureBuilder<Map<String, dynamic>>(
      future: NoahDataEngine.fetchAiPrediction(fixtureId, apiKey),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        var ai = snapshot.data!;
        return SingleChildScrollView(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(vertical: 30),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Expanded(child: _metricColumn("$homeName\n(공격력)", ai['visual_metrics']['spear'], Colors.redAccent)),
                    const Icon(Icons.bolt, color: Colors.amber, size: 40),
                    Expanded(child: _metricColumn("$awayName\n(수비력)", ai['visual_metrics']['shield'], Colors.blueAccent)),
                  ],
                ),
              ),
              Card(
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
                    ],
                  ),
                ),
              )
            ],
          ),
        );
      }
    );
  }

  Widget _metricColumn(String label, int val, Color col) => Column(
    children: [
      Text(label, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 13)),
      const SizedBox(height: 15),
      Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(width: 80, height: 80, child: CircularProgressIndicator(value: val/100, color: col, strokeWidth: 8, backgroundColor: Colors.white10)),
          Text('$val', style: TextStyle(color: col, fontSize: 22, fontWeight: FontWeight.bold)),
        ],
      ),
    ],
  );

  Widget _probText(String label, int val, Color col) => Column(
    children: [
      Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      Text('$val%', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: col)),
    ],
  );
}

// --- [목록 페이지들] ---
class AllMatchesPage extends StatelessWidget {
  final String apiKey;
  const AllMatchesPage({super.key, required this.apiKey});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('NoahScore V2.2 (Widgets Pro)')),
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
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MatchDetailPage(match: m, apiKey: apiKey))),
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
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MatchDetailPage(match: m, apiKey: apiKey))),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// --- [순위 탭 (Standings 위젯)] ---
class StandingsPage extends StatelessWidget { 
  final String apiKey;
  const StandingsPage({super.key, required this.apiKey}); 
  @override Widget build(BuildContext context) {
    // 기본으로 영국 프리미어리그(39) 순위를 띄움
    return SafeArea(child: buildApiWidget("standings", 'data-league="39" data-season="2023"', apiKey));
  }
}

// --- [탐색 탭 (Leagues 위젯)] ---
class LeagueExplorerScreen extends StatelessWidget { 
  final String apiKey;
  const LeagueExplorerScreen({super.key, required this.apiKey}); 
  @override Widget build(BuildContext context) {
    return SafeArea(child: buildApiWidget("leagues", '', apiKey));
  }
}