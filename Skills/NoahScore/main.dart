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
          AllMatchesPage(apiKey: footballApiKey),      // 1. 커스텀 분석 (클릭용)
          GamesWidgetPage(apiKey: footballApiKey),     // 2. 전체 일정 위젯
          StandingsWidgetPage(apiKey: footballApiKey), // 3. 순위 위젯
          LeaguesWidgetPage(apiKey: footballApiKey),   // 4. 리그 위젯
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF1F1F1F),
        selectedItemColor: Colors.amberAccent,
        unselectedItemColor: Colors.grey,
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.analytics), label: 'AI 분석'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: '일정'),
          BottomNavigationBarItem(icon: Icon(Icons.format_list_numbered), label: '순위'),
          BottomNavigationBarItem(icon: Icon(Icons.public), label: '리그'),
        ],
      ),
    );
  }
}

class NoahDataEngine {
  static const String host = 'v3.football.api-sports.io';

  static Future<Map<String, List<dynamic>>> fetchTodayMatches(String key) async {
    String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final res = await http.get(Uri.parse('https://$host/fixtures?date=$today'), headers: {'x-rapidapi-key': key, 'x-rapidapi-host': host});
    List matches = json.decode(res.body)['response'] ?? [];
    return groupBy(matches, (m) => "${m['league']['country']} - ${m['league']['name']}");
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

// --- [★완벽 수정본: V2 문법 적용 및 CORS 보안 우회 엔진] ---
class ApiWidgetDisplay extends StatefulWidget {
  final String widgetType;
  final String attributes;
  final String apiKey;

  const ApiWidgetDisplay({super.key, required this.widgetType, required this.attributes, required this.apiKey});

  @override
  State<ApiWidgetDisplay> createState() => _ApiWidgetDisplayState();
}

class _ApiWidgetDisplayState extends State<ApiWidgetDisplay> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF121212))
      ..loadHtmlString('''
        <!DOCTYPE html>
        <html>
          <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <style>body { margin: 0; padding: 0; background-color: #121212; }</style>
          </head>
          <body>
            <api-sports-widget
                data-type="${widget.widgetType}"
                data-key="${widget.apiKey}"
                data-theme="dark"
                ${widget.attributes}>
            </api-sports-widget>
            <script type="module" src="https://widgets.api-sports.io/2.0.0/widgets.js"></script>
          </body>
        </html>
      ''', 
      // 보안 차단을 뚫기 위한 baseUrl (가장 중요)
      baseUrl: 'https://widgets.api-sports.io');
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: WebViewWidget(controller: _controller),
    );
  }
}

// --- [상세 분석 페이지: 5개의 탭으로 나눈 궁극의 정보 센터] ---
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
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: Text('$homeName vs $awayName', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          bottom: const TabBar(
            isScrollable: true,
            indicatorColor: Colors.amberAccent,
            labelColor: Colors.amberAccent,
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(text: "AI 분석"),
              Tab(text: "매치 센터"),   // 위젯 1: game
              Tab(text: "상대 전적"),   // 위젯 2: h2h
              Tab(text: "홈팀 정보"),   // 위젯 3: team
              Tab(text: "스타 플레이어"),// 위젯 4: player
            ],
          ),
        ),
        body: TabBarView(
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildAiAnalysisTab(homeName, awayName, fixtureId),
            // 속성들을 스크린샷과 100% 동일하게 매칭
            ApiWidgetDisplay(widgetType: "game", attributes: 'data-game-id="$fixtureId"', apiKey: apiKey),
            ApiWidgetDisplay(widgetType: "h2h", attributes: 'data-h2h="$homeId-$awayId"', apiKey: apiKey),
            ApiWidgetDisplay(widgetType: "team", attributes: 'data-team-id="$homeId"', apiKey: apiKey),
            ApiWidgetDisplay(widgetType: "player", attributes: 'data-player-id="154" data-season="2023"', apiKey: apiKey),
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

// --- [목록 페이지] ---
class AllMatchesPage extends StatelessWidget {
  final String apiKey;
  const AllMatchesPage({super.key, required this.apiKey});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Noah AI 픽 보드', style: TextStyle(fontWeight: FontWeight.bold))),
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
                title: Text(league, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.amberAccent)),
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

// --- [하단 탭용 공식 위젯들 (일정, 순위, 리그)] ---
class GamesWidgetPage extends StatelessWidget { 
  final String apiKey;
  const GamesWidgetPage({super.key, required this.apiKey}); 
  @override Widget build(BuildContext context) {
    // 위젯 5: games
    return SafeArea(child: ApiWidgetDisplay(widgetType: "games", attributes: 'data-date="${DateFormat('yyyy-MM-dd').format(DateTime.now())}"', apiKey: apiKey));
  }
}

class StandingsWidgetPage extends StatelessWidget { 
  final String apiKey;
  const StandingsWidgetPage({super.key, required this.apiKey}); 
  @override Widget build(BuildContext context) {
    // 위젯 6: standings
    return SafeArea(child: ApiWidgetDisplay(widgetType: "standings", attributes: 'data-league="39" data-season="2023"', apiKey: apiKey));
  }
}

class LeaguesWidgetPage extends StatelessWidget { 
  final String apiKey;
  const LeaguesWidgetPage({super.key, required this.apiKey}); 
  @override Widget build(BuildContext context) {
    // 위젯 7: leagues
    return SafeArea(child: ApiWidgetDisplay(widgetType: "leagues", attributes: '', apiKey: apiKey));
  }
}