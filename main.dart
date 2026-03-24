<<<<<<< HEAD
﻿import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

const String apiKey = '8b3c5b00b4a18b203a63f7f0aba0ddd2';

void main() => runApp(const NoahScoreV2());

class NoahScoreV2 extends StatelessWidget {
  const NoahScoreV2({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: const Color(0xFF0F172A)),
      home: const AllMatchesPage(),
=======
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:collection/collection.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        cardTheme: CardTheme(color: const Color(0xFF1E1E1E), elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      ),
      home: HomePage(),
>>>>>>> ea6487a5f548439b95fd59ed917c288a68fd1d59
    );
  }
}

<<<<<<< HEAD
// --- 통합 데이터 엔진 (H2H 기능 추가) ---
class ApiEngine {
  static const String host = 'v3.football.api-sports.io';
  
  static Future<List<dynamic>> getFixtures(String date) async {
    final res = await http.get(Uri.parse('https://\System.Management.Automation.Internal.Host.InternalHost/fixtures?date=\'), headers: {'x-rapidapi-key': apiKey, 'x-rapidapi-host': host});
    return json.decode(res.body)['response'];
  }

  static Future<List<dynamic>> getStats(int id) async {
    final res = await http.get(Uri.parse('https://\System.Management.Automation.Internal.Host.InternalHost/fixtures/statistics?fixture=\'), headers: {'x-rapidapi-key': apiKey, 'x-rapidapi-host': host});
    return json.decode(res.body)['response'];
  }

  // [보강] 상대 전적 호출 (최근 5경기)
  static Future<List<dynamic>> getH2H(int t1, int t2) async {
    final res = await http.get(Uri.parse('https://\System.Management.Automation.Internal.Host.InternalHost/fixtures/headtohead?h2h=\-\&last=5'), headers: {'x-rapidapi-key': apiKey, 'x-rapidapi-host': host});
    return json.decode(res.body)['response'];
  }
}

// --- 메인 리스트 페이지 ---
class AllMatchesPage extends StatefulWidget {
  const AllMatchesPage({super.key});
  @override
  State<AllMatchesPage> createState() => _AllMatchesPageState();
}

class _AllMatchesPageState extends State<AllMatchesPage> {
  String _today = DateFormat('yyyy-MM-dd').format(DateTime.now());
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('오늘의 경기')),
      body: FutureBuilder<List<dynamic>>(
        future: ApiEngine.getFixtures(_today),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          return ListView.builder(
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final f = snapshot.data![index];
              return ListTile(
                tileColor: const Color(0xFF1E293B),
                title: Text('\ vs \'),
                subtitle: Text(f['fixture']['status']['long']),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => MatchDetailPage(f: f))),
=======
class HomePage extends StatefulWidget {
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
          const Center(child: Text('LIVE (준비 중)', style: TextStyle(color: Colors.grey))),
          StandingsPage(apiKey: apiKey),
          LeagueExplorerScreen(apiKey: apiKey), // 🔥 V1.7 핵심: 글로벌 리그 탐색기 탑재!
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
          BottomNavigationBarItem(icon: Icon(Icons.public), label: '탐색'), // 아이콘/라벨 변경
        ],
      ),
    );
  }
}

// --- [V1.5.2 메인 경기 리스트 유지] ---
class AllMatchesPage extends StatelessWidget {
  final String apiKey;
  AllMatchesPage({required this.apiKey});

  Future<Map<String, List<dynamic>>> fetchAndGroupMatches() async {
    try {
      String today = DateTime.now().toIso8601String().substring(0, 10);
      final response = await http.get(
        Uri.parse('https://v3.football.api-sports.io/fixtures?date=$today'),
        headers: {'x-rapidapi-host': 'v3.football.api-sports.io', 'x-rapidapi-key': apiKey},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        List matches = json.decode(response.body)['response'] ?? [];
        return groupBy(matches, (dynamic m) => "${m['league']['country']} - ${m['league']['name']}");
      }
    } catch (e) {
      print("Error: $e");
    }
    return {};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('NoahScore ⚽', style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: const Color(0xFF1F1F1F)),
      body: FutureBuilder<Map<String, List<dynamic>>>(
        future: fetchAndGroupMatches(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
          if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text("오늘 예정된 경기가 없습니다."));
          
          var grouped = snapshot.data!;
          return ListView.builder(
            itemCount: grouped.keys.length,
            itemBuilder: (context, index) {
              String leagueName = grouped.keys.elementAt(index);
              List matches = grouped[leagueName]!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    color: const Color(0xFF2A2A2A),
                    child: Text(leagueName, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[300])),
                  ),
                  ...matches.map((m) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white10))),
                    child: Row(
                      children: [
                        SizedBox(width: 40, child: Text(m['fixture']['status']['short'] ?? "", style: const TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold))),
                        Expanded(
                          child: Column(
                            children: [
                              _buildTeamRow(m['teams']['home']['name'], m['teams']['home']['logo'], m['goals']['home']),
                              const SizedBox(height: 8),
                              _buildTeamRow(m['teams']['away']['name'], m['teams']['away']['logo'], m['goals']['away']),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )).toList(),
                ],
>>>>>>> ea6487a5f548439b95fd59ed917c288a68fd1d59
              );
            },
          );
        },
      ),
    );
  }
<<<<<<< HEAD
}

// --- [보강] 상세 분석 페이지 (H2H 섹션 추가) ---
class MatchDetailPage extends StatefulWidget {
  final dynamic f;
  const MatchDetailPage({super.key, required this.f});
  @override
  State<MatchDetailPage> createState() => _MatchDetailPageState();
}

class _MatchDetailPageState extends State<MatchDetailPage> {
  @override
  Widget build(BuildContext context) {
    final int hId = widget.f['teams']['home']['id'];
    final int aId = widget.f['teams']['away']['id'];

    return Scaffold(
      appBar: AppBar(title: const Text('경기 상세 분석')),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(),
            const Divider(),
            _buildStatSection(), // 점유율 바
            const Divider(),
            // 🚨 [보강 핵심] 상대 전적 리스트 섹션
            _buildH2HSection(hId, aId),
            _buildVipBanner(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Image.network(widget.f['teams']['home']['logo'], width: 60),
          Text('\ : \', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
          Image.network(widget.f['teams']['away']['logo'], width: 60),
        ],
      ),
    );
  }

  Widget _buildStatSection() {
    return FutureBuilder<List<dynamic>>(
      future: ApiEngine.getStats(widget.f['fixture']['id']),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox.shrink();
        final hPos = snapshot.data![0]['statistics'].firstWhere((s) => s['type'] == 'Ball Possession')['value'];
        return ListTile(title: const Text('공점유율', textAlign: TextAlign.center), subtitle: Text('\ vs \', textAlign: TextAlign.center));
      },
    );
  }

  // [새로 추가된 H2H 섹션]
  Widget _buildH2HSection(int hId, int aId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(padding: EdgeInsets.all(16), child: Text('최근 상대 전적 (H2H)', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold))),
        FutureBuilder<List<dynamic>>(
          future: ApiEngine.getH2H(hId, aId),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const LinearProgressIndicator();
            if (snapshot.data!.isEmpty) return const Center(child: Text('기록 없음'));
            return Column(
              children: snapshot.data!.map((m) => ListTile(
                dense: true,
                leading: Text(m['fixture']['date'].toString().substring(0, 10)),
                title: Text('\ \ : \ \'),
                trailing: const Icon(Icons.history, size: 16),
              )).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildVipBanner() {
    return Container(margin: const EdgeInsets.all(20), padding: const EdgeInsets.all(20), color: Colors.amber.withOpacity(0.1), child: const Center(child: Text('🔒 VIP: 노아 AI 정밀 분석 리포트 보기', style: TextStyle(color: Colors.amber))));
=======

  Widget _buildTeamRow(String name, String? logo, int? score) {
    return Row(
      children: [
        if (logo != null) Image.network(logo, width: 20, height: 20, errorBuilder: (c, e, s) => const Icon(Icons.sports_soccer, size: 20)),
        const SizedBox(width: 10),
        Expanded(child: Text(name, style: const TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis)),
        Text(score?.toString() ?? "-", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.amber)),
      ],
    );
  }
}

// --- [V1.6 순위표 유지 (년도 로직 추후 보강 예정)] ---
class StandingsPage extends StatefulWidget {
  final String apiKey;
  StandingsPage({required this.apiKey});
  @override
  _StandingsPageState createState() => _StandingsPageState();
}
class _StandingsPageState extends State<StandingsPage> {
  int _selectedLeagueId = 39;
  late Future<List<dynamic>> _standingsFuture;
  final Map<int, String> _leagues = {39: 'Premier League', 140: 'La Liga', 135: 'Serie A', 78: 'Bundesliga', 283: 'K League 1'};

  @override
  void initState() { super.initState(); _standingsFuture = _fetchStandings(); }

  Future<List<dynamic>> _fetchStandings() async {
    // 임시로 유럽/아시아 시즌 분기 처리
    String season = (_selectedLeagueId == 283) ? '2026' : '2025';
    final response = await http.get(Uri.parse('https://v3.football.api-sports.io/standings?league=$_selectedLeagueId&season=$season'), headers: {'x-rapidapi-key': widget.apiKey, 'x-rapidapi-host': 'v3.football.api-sports.io'});
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['response'] != null && data['response'].isNotEmpty) return data['response'][0]['league']['standings'][0];
    }
    throw Exception('데이터 로드 실패');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F1F1F), elevation: 0,
        title: DropdownButtonHideUnderline(
          child: DropdownButton<int>(
            value: _selectedLeagueId, dropdownColor: const Color(0xFF2A2A2A),
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            onChanged: (val) { if(val != null) setState(() { _selectedLeagueId = val; _standingsFuture = _fetchStandings(); }); },
            items: _leagues.entries.map((e) => DropdownMenuItem<int>(value: e.key, child: Text(e.value))).toList(),
          ),
        ),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _standingsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
          if (!snapshot.hasData) return const Center(child: Text('데이터가 없습니다.'));
          return SingleChildScrollView(
            scrollDirection: Axis.vertical, child: SingleChildScrollView(
              scrollDirection: Axis.horizontal, child: DataTable(
                columnSpacing: 22, headingRowColor: MaterialStateProperty.all(const Color(0xFF2A2A2A)),
                columns: const [DataColumn(label: Text('#')), DataColumn(label: Text('팀')), DataColumn(label: Text('경기')), DataColumn(label: Text('GD')), DataColumn(label: Text('승점', style: TextStyle(color: Colors.blueAccent)))],
                rows: snapshot.data!.map((t) => DataRow(cells: [
                  DataCell(Text('${t['rank']}')),
                  DataCell(Row(children: [Image.network(t['team']['logo'], width: 20), const SizedBox(width: 8), SizedBox(width: 110, child: Text(t['team']['name'], overflow: TextOverflow.ellipsis))])),
                  DataCell(Text('${t['all']['played']}')), DataCell(Text('${t['goalsDiff']}')), DataCell(Text('${t['points']}', style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold))),
                ])).toList(),
              ),
            ),
          );
        },
      ),
    );
  }
}

// --- [🔥 V1.7 신규 탑재: 글로벌 리그 탐색기] ---
class LeagueExplorerScreen extends StatefulWidget {
  final String apiKey;
  const LeagueExplorerScreen({Key? key, required this.apiKey}) : super(key: key);
  @override
  _LeagueExplorerScreenState createState() => _LeagueExplorerScreenState();
}

class _LeagueExplorerScreenState extends State<LeagueExplorerScreen> {
  List<dynamic> _leagues = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchLeagues();
  }

  Future<void> _fetchLeagues() async {
    try {
      final response = await http.get(
        Uri.parse('https://v3.football.api-sports.io/leagues'),
        headers: {'x-rapidapi-key': widget.apiKey, 'x-rapidapi-host': 'v3.football.api-sports.io'},
      );
      if (response.statusCode == 200) {
        setState(() {
          _leagues = json.decode(response.body)['response'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('전 세계 대회 탐색', style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: const Color(0xFF1F1F1F)),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
        : ListView.builder(
            itemCount: _leagues.length,
            itemBuilder: (context, index) {
              final leagueInfo = _leagues[index];
              final league = leagueInfo['league'];
              final country = leagueInfo['country'];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
                child: ListTile(
                  leading: league['logo'] != null 
                    ? Image.network(league['logo'], width: 40, height: 40, errorBuilder: (c,e,s) => const Icon(Icons.sports_soccer))
                    : const Icon(Icons.sports_soccer, size: 40),
                  title: Text(league['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${country['name']} (${league['type']})', style: const TextStyle(color: Colors.grey)),
                  trailing: country['flag'] != null 
                    ? Image.network(country['flag'], width: 30, errorBuilder: (c,e,s) => const SizedBox(width: 30))
                    : const SizedBox(width: 30),
                  onTap: () {
                    // 향후 이 리그를 터치하면 해당 리그 상세페이지로 넘어가는 로직 연결
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${league['name']} 선택됨 (ID: ${league['id']})')));
                  },
                ),
              );
            },
          ),
    );
>>>>>>> ea6487a5f548439b95fd59ed917c288a68fd1d59
  }
}
