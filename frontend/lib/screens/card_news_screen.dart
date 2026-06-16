import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/api_service.dart';
import 'card_news_editor_screen.dart';
import '../widgets/footer.dart';

/**
 * 카드뉴스를 제작할 대상 경기를 선택하는 화면 위젯입니다.
 * 모바일(리스트 형태)과 PC(바둑판 그리드 형태) 판형에 모두 대응합니다.
 */
class CardNewsScreen extends StatefulWidget {
  const CardNewsScreen({super.key});

  @override
  State<CardNewsScreen> createState() => _CardNewsScreenState();
}

class _CardNewsScreenState extends State<CardNewsScreen> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _gamesList = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadGames();
  }

  Future<void> _loadGames() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final games = await _apiService.fetchCardNewsGames();
    if (!mounted) return;

    if (games != null) {
      setState(() {
        _gamesList = games;
        _isLoading = false;
      });
    } else {
      setState(() {
        _errorMessage = '경기 목록을 가져오지 못했습니다. 서버 상태를 확인해주세요.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 💡 [최종 최적화] LayoutBuilder와 shrinkWrap을 제거하고 CustomScrollView로 전환하여
    // 크롬 리사이징 시 발생하는 무한 크기 계산(Layout 병목)을 원천 차단합니다.
    final double width = MediaQuery.of(context).size.width;
    final bool isDesktop = width > 800; // LayoutBuilder 대신 MediaQuery로 가볍게 판별

    return CustomScrollView(
      slivers: [
        // A. 타이틀 및 헤더 영역을 고성능 Sliver로 배치
        SliverPadding(
          padding: const EdgeInsets.all(24.0),
          sliver: SliverList(
            // 💡 SliverChildListWith some 대신 아래와 같이 'SliverChildListDelegate'로 변경합니다.
            delegate: SliverChildListDelegate(
              [
                const Text(
                  '경기 요약 카드뉴스 제작', 
                  style: TextStyle(fontSize: 22.0, fontWeight: FontWeight.bold, color: AppColors.ink),
                ),
                const SizedBox(height: 8.0),
                const Text(
                  '제작하고 싶은 경기를 선택하여 AI 요약 기반 카드뉴스를 생성하고 편집 및 공유해 보세요.', 
                  style: TextStyle(fontSize: 13.0, color: AppColors.inkSubtle),
                ),
                const SizedBox(height: 24.0),
              ],
            ),
          ),
        ),
        
        // B. 본문 카드 리스트 영역 (SliverGrid 또는 SliverList로 독립 처리)
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          sliver: _isLoading
              ? const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator(color: AppColors.primary)))
              : (_errorMessage != null || _gamesList.isEmpty)
                  ? SliverToBoxAdapter(child: Center(child: Text(_errorMessage ?? '데이터가 없습니다.')))
                  : isDesktop
                      ? SliverGrid(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 16.0,
                            mainAxisSpacing: 16.0,
                            childAspectRatio: 1.3,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, idx) => _buildDesktopGameCard(_gamesList[idx]),
                            childCount: _gamesList.length,
                          ),
                        )
                      : SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, idx) => Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: _buildMobileGameCard(_gamesList[idx]),
                            ),
                            childCount: _gamesList.length,
                          ),
                        ),
        ),

        // C. 맨 밑바닥 푸터 영역
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 48.0),
            child: Footer(),
          ),
        ),
      ],
    );
  }

  /// 📱 공통 데이터 파싱 처리를 위한 헬퍼 메서드
  Map<String, dynamic> _parseGameData(Map<String, dynamic> game) {
    final int gameId = game['game_id'] ?? 0;
    final int homeScore = game['home_score'] ?? 0;
    final int awayScore = game['away_score'] ?? 0;

    String gameDate = 'MM/dd';
    if (game['game_date'] != null) {
      final rawDate = game['game_date'].toString();
      if (rawDate.length >= 10) {
        gameDate = "${rawDate.substring(5, 7)}/${rawDate.substring(8, 10)}";
      } else {
        gameDate = rawDate;
      }
    }

    final String homeTeam = game['home_team_id'] == 1 ? 'LAD' : (game['home_team_id'] == 2 ? 'NYY' : 'HOME');
    final String awayTeam = game['away_team_id'] == 1 ? 'LAD' : (game['away_team_id'] == 2 ? 'NYY' : 'AWAY');

    return {
      'gameId': gameId,
      'homeScore': homeScore,
      'awayScore': awayScore,
      'gameDate': gameDate,
      'homeTeam': homeTeam,
      'awayTeam': awayTeam,
    };
  }

  /// 📱 기존 모바일 화면용 가로형 리스트 카드 위젯
  Widget _buildMobileGameCard(Map<String, dynamic> rawGame) {
    final data = _parseGameData(rawGame);

    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                decoration: BoxDecoration(
                  color: AppColors.surface3,
                  borderRadius: BorderRadius.circular(6.0),
                ),
                child: Text(
                  data['gameDate'],
                  style: const TextStyle(
                    fontSize: 11.0,
                    fontWeight: FontWeight.bold,
                    color: AppColors.inkSubtle,
                  ),
                ),
              ),
              const SizedBox(height: 8.0),
              Text(
                'GAME ID: ${data['gameId']}',
                style: const TextStyle(fontSize: 10.0, color: AppColors.inkTertiary),
              ),
            ],
          ),
          const Spacer(),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(data['awayTeam'], style: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold, color: AppColors.ink)),
              const SizedBox(width: 12.0),
              Text(
                '${data['awayScore']} : ${data['homeScore']}',
                style: const TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold, color: AppColors.primaryHover, letterSpacing: 1.0),
              ),
              const SizedBox(width: 12.0),
              Text(data['homeTeam'], style: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold, color: AppColors.ink)),
            ],
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: () => _navigateToEditor(data['gameId']),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.ink,
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
            ),
            child: const Row(
              children: [
                Icon(Icons.dashboard_customize_outlined, size: 14),
                SizedBox(width: 6.0),
                Text('뉴스 제작', style: TextStyle(fontSize: 12.0, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 💻 PC/태블릿 대화면용 컴팩트 스퀘어 카드 위젯
  Widget _buildDesktopGameCard(Map<String, dynamic> rawGame) {
    final data = _parseGameData(rawGame);

    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween, // 상·중·하 고르게 배치
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. 상단 정보 영역 (날짜와 ID)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                decoration: BoxDecoration(
                  color: AppColors.surface3,
                  borderRadius: BorderRadius.circular(6.0),
                ),
                child: Text(
                  data['gameDate'],
                  style: const TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold, color: AppColors.inkSubtle),
                ),
              ),
              Text(
                'ID: ${data['gameId']}',
                style: const TextStyle(fontSize: 11.0, color: AppColors.inkTertiary),
              ),
            ],
          ),

          // 2. 중앙 정보 영역 (시원하게 키운 스코어 레이아웃)
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(data['awayTeam'], style: const TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold, color: AppColors.ink)),
                  const SizedBox(width: 16.0),
                  Text(
                    '${data['awayScore']} : ${data['homeScore']}',
                    style: const TextStyle(
                      fontSize: 26.0, 
                      fontWeight: FontWeight.w900, 
                      color: AppColors.primaryHover, 
                      letterSpacing: 1.5
                    ),
                  ),
                  const SizedBox(width: 16.0),
                  Text(data['homeTeam'], style: const TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold, color: AppColors.ink)),
                ],
              ),
            ],
          ),

          // 3. 하단 버튼 영역 (가로로 꽉 차는 안정적인 버튼)
          ElevatedButton(
            onPressed: () => _navigateToEditor(data['gameId']),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.ink,
              padding: const EdgeInsets.symmetric(vertical: 14.0),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.dashboard_customize_outlined, size: 16),
                SizedBox(width: 8.0),
                Text('카드뉴스 제작하기', style: TextStyle(fontSize: 13.0, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 화면 이동 공통 로직
  void _navigateToEditor(int gameId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CardNewsEditorScreen(gameId: gameId),
      ),
    );
  }
}