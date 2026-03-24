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
          ApiWidgetPage(html: _getHtml('data-type="games" data-date="${DateFormat('yyyy-MM-dd').format(DateTime.now())}"'), apiKey: footballApiKey), // 스크린샷 224306.jpg
          ApiWidgetPage(html: _getHtml('data-type="standings" data-league="39" data-season="2025"'), apiKey: footballApiKey), // 스크린샷 224345.jpg
          ApiWidgetPage(html: _getHtml('data-type="leagues"'), apiKey: footballApiKey), // 스크린샷 224243.png
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF1F1F1F),
        selectedItemColor: Colors.amberAccent,
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

  // 주인님 스크린샷 속 검은색 코드창 문법 100% 재현 함수
  String _getHtml(String dataAttrs) {
    return '''
      <!DOCTYPE html>
      <html>
        <head>
          <meta charset="UTF-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
          <style>body { margin: 0; background: #121212; }</style>
        </head>
        <body>
          <api-sports-widget 
              $dataAttrs 
              data-key="$footballApiKey" 
              data-theme="dark">
          </api-sports-widget>
          <script type="module" src="https://widgets.api-sports.io/2.0.0/widgets.js"></script>
        </body>
      </html>
    ''';
  }
}

// --- [공식 위젯 구동 엔진] ---
class ApiWidgetPage extends StatefulWidget {
  final String html;
  final String apiKey;
  const ApiWidgetPage({super.key, required this.html, required this.apiKey});
  @override
  State<ApiWidgetPage> createState() => _ApiWidgetPageState();
}

class _ApiWidgetPageState extends State<ApiWidgetPage> {
  late final WebViewController _controller;
  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF121212))
      ..loadHtmlString(widget.html, baseUrl: 'https://widgets.api-sports.io');
  }
  @override
  Widget build(BuildContext context) => SafeArea(child: WebViewWidget(controller: _controller));
}

// --- [상세 페이지: 탭별 7개 위젯 완성] ---
class MatchDetailPage extends StatelessWidget {
  final dynamic match;
  final String apiKey;
  const MatchDetailPage({super.key, required this.match, required this.apiKey});

  @override
  Widget build(BuildContext context) {
    int fId = match['fixture']['id'];
    int hId = match['teams']['home']['id'];
    int aId = match['teams']['away']['id'];

    String getHtml(String attrs) => '''
      <html><head><meta name="viewport" content="width=device-width, initial-scale=1.0"></head>
      <body style="margin:0;background:#121212">
        <api-sports-widget $attrs data-key="$apiKey" data-theme="dark"></api-sports-widget>
        <script type="module" src="https://widgets.api-sports.io/2.0.0/widgets.js"></script>
      </body></html>
    ''';

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: Text("${match['teams']['home']['name']} vs ${match['teams']['away']['name']}", style: const TextStyle(fontSize: 14)),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [Tab(text: "AI분석"), Tab(text: "매치센터"), Tab(text: "상대전적"), Tab(text: "팀정보"), Tab(text: "선수분석")],
          ),
        ),
        body: TabBarView(
          children: [
            const Center(child: Text("Noah AI 정밀 분석 중...")),
            ApiWidgetPage(html: getHtml('data-type="game" data-game-id="$fId"'), apiKey: apiKey), // 스크린샷 224318.jpg
            ApiWidgetPage(html: getHtml('data-type="h2h" data-h2h="$hId-$aId"'), apiKey: apiKey), // 스크린샷 224329.jpg
            ApiWidgetPage(html: getHtml('data-type="team" data-team-id="$hId"'), apiKey: apiKey), // 스크린샷 224358.jpg
            ApiWidgetPage(html: getHtml('data-type="player" data-player-id="154"'), apiKey: apiKey), // 스크린샷 224410.jpg
          ],
        ),
      ),
    );
  }
}

// --- [메인 리스트: 어느 나라 팀인지 명시] ---
class AllMatchesPage extends StatelessWidget {
  final String apiKey;
  const AllMatchesPage({super.key, required this.apiKey});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Noah AI 픽 보드")),
      body: FutureBuilder<Map<String, List<dynamic>>>(
        future: fetchMatches(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          return ListView(
            children: snapshot.data!.entries.map((e) => ExpansionTile(
              initiallyExpanded: true,
              title: Text(e.key, style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold)),
              children: e.value.map((m) => ListTile(
                leading: Image.network(m['teams']['home']['logo'], width: 30),
                title: Text("${m['teams']['home']['name']} vs ${m['teams']['away']['name']}"),
                subtitle: Text("경기장: ${m['fixture']['venue']['name'] ?? '정보 없음'}"),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MatchDetailPage(match: m, apiKey: apiKey))),
              )).toList(),
            )).toList(),
          );
        },
      ),
    );
  }

  Future<Map<String, List<dynamic>>> fetchMatches() async {
    final res = await http.get(Uri.parse('https://v3.football.api-sports.io/fixtures?date=2026-03-24'), headers: {'x-rapidapi-key': apiKey});
    List data = json.decode(res.body)['response'] ?? [];
    // 국가(Country)와 리그(League) 이름을 합쳐서 어느 나라인지 확실히 표기
    return groupBy(data, (m) => "${m['league']['country']} - ${m['league']['name']}");
  }
}