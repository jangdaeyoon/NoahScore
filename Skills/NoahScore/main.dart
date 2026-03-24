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
          GamesWidgetPage(apiKey: footballApiKey),
          StandingsWidgetPage(apiKey: footballApiKey),
          LeaguesWidgetPage(apiKey: footballApiKey),
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

// --- [스크린샷 기반 100% 싱크로율 위젯 엔진] ---
class ApiWidgetDisplay extends StatefulWidget {
  final String htmlContent;
  const ApiWidgetDisplay({super.key, required this.htmlContent});

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
      ..loadHtmlString(widget.htmlContent, baseUrl: 'https://widgets.api-sports.io');
  }

  @override
  Widget build(BuildContext context) => WebViewWidget(controller: _controller);
}

// --- [상세 페이지: 스크린샷 속성값 7개 완벽 적용] ---
class MatchDetailPage extends StatelessWidget {
  final dynamic match;
  final String apiKey;
  const MatchDetailPage({super.key, required this.match, required this.apiKey});

  @override
  Widget build(BuildContext context) {
    int fixtureId = match['fixture']['id'];
    int homeId = match['teams']['home']['id'];
    int awayId = match['teams']['away']['id'];

    // 스크린샷 코드 그대로 가져온 HTML 템플릿 함수
    String getWidgetHtml(String dataTag) {
      return '''
        <!DOCTYPE html>
        <html>
          <head><meta name="viewport" content="width=device-width, initial-scale=1.0"></head>
          <body style="background-color: #121212; margin: 0; padding: 0;">
            <div $dataTag 
                 data-host="v3.football.api-sports.io" 
                 data-key="$apiKey" 
                 data-theme="dark" 
                 class="api_football_loader">
            </div>
            <script type="module" src="https://widgets.api-sports.io/2.0.0/widgets.js"></script>
          </body>
        </html>
      ''';
    }

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: Text("${match['teams']['home']['name']} vs ${match['teams']['away']['name']}"),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [Tab(text: "AI분석"), Tab(text: "매치"), Tab(text: "상대전적"), Tab(text: "팀"), Tab(text: "선수")],
          ),
        ),
        body: TabBarView(
          children: [
            const Center(child: Text("AI 분석 리포트 준비 중...")),
            // 스크린샷 224318.jpg 기반 [게임 위젯]
            ApiWidgetDisplay(htmlContent: getWidgetHtml('id="wg-api-football-game" data-game-id="$fixtureId"')),
            // 스크린샷 224329.jpg 기반 [맞대결 위젯]
            ApiWidgetDisplay(htmlContent: getWidgetHtml('id="wg-api-football-h2h" data-h2h="$homeId-$awayId"')),
            // 스크린샷 224358.jpg 기반 [팀 위젯]
            ApiWidgetDisplay(htmlContent: getWidgetHtml('id="wg-api-football-team" data-team-id="$homeId"')),
            // 스크린샷 224410.jpg 기반 [플레이어 위젯]
            ApiWidgetDisplay(htmlContent: getWidgetHtml('id="wg-api-football-player" data-player-id="154"')), 
          ],
        ),
      ),
    );
  }
}

// --- [하단 메인 페이지들: 스크린샷 기반 이식] ---
class AllMatchesPage extends StatelessWidget {
  final String apiKey;
  const AllMatchesPage({super.key, required this.apiKey});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Noah AI 픽 보드')),
      body: FutureBuilder<Map<String, List<dynamic>>>(
        future: fetchMatches(apiKey),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          return ListView(
            children: snapshot.data!.entries.map((e) => ExpansionTile(
              title: Text(e.key, style: const TextStyle(color: Colors.amberAccent)),
              children: e.value.map((m) => ListTile(
                title: Text("${m['teams']['home']['name']} vs ${m['teams']['away']['name']}"),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MatchDetailPage(match: m, apiKey: apiKey))),
              )).toList(),
            )).toList(),
          );
        },
      ),
    );
  }

  Future<Map<String, List<dynamic>>> fetchMatches(String key) async {
    final res = await http.get(Uri.parse('https://v3.football.api-sports.io/fixtures?date=2026-03-24'), headers: {'x-rapidapi-key': key});
    List matches = json.decode(res.body)['response'] ?? [];
    return groupBy(matches, (m) => m['league']['name']);
  }
}

// 스크린샷 224306.jpg 기반 [계약/일정 위젯]
class GamesWidgetPage extends StatelessWidget {
  final String apiKey;
  const GamesWidgetPage({super.key, required this.apiKey});
  @override
  Widget build(BuildContext context) => ApiWidgetDisplay(htmlContent: '''
    <html><body style="margin:0;background:#121212">
    <div id="wg-api-football-games" data-host="v3.football.api-sports.io" data-key="$apiKey" data-date="2026-03-24" data-theme="dark"></div>
    <script type="module" src="https://widgets.api-sports.io/2.0.0/widgets.js"></script></body></html>
  ''');
}

// 스크린샷 224345.jpg 기반 [순위 위젯]
class StandingsWidgetPage extends StatelessWidget {
  final String apiKey;
  const StandingsWidgetPage({super.key, required this.apiKey});
  @override
  Widget build(BuildContext context) => ApiWidgetDisplay(htmlContent: '''
    <html><body style="margin:0;background:#121212">
    <div id="wg-api-football-standings" data-host="v3.football.api-sports.io" data-key="$apiKey" data-league="39" data-season="2025" data-theme="dark"></div>
    <script type="module" src="https://widgets.api-sports.io/2.0.0/widgets.js"></script></body></html>
  ''');
}

// 스크린샷 224243.png 기반 [리그 위젯]
class LeaguesWidgetPage extends StatelessWidget {
  final String apiKey;
  const LeaguesWidgetPage({super.key, required this.apiKey});
  @override
  Widget build(BuildContext context) => ApiWidgetDisplay(htmlContent: '''
    <html><body style="margin:0;background:#121212">
    <div id="wg-api-football-leagues" data-host="v3.football.api-sports.io" data-key="$apiKey" data-theme="dark"></div>
    <script type="module" src="https://widgets.api-sports.io/2.0.0/widgets.js"></script></body></html>
  ''');
}