import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/pitch_simulator.dart';
import '../widgets/strike_zone.dart';
import '../widgets/spray_chart.dart';
import '../widgets/analysis_charts.dart';
import '../services/api_service.dart';
import '../models/game_situation_model.dart' show PitchCoordinate, WinProbabilityPoint;

/// 데이터 분석실 메인 화면 위젯 (StatefulWidget)입니다.
/// 
/// 시즌, 구단, 분석 대상 선수, 상황 필터를 조합하여
/// 3D 궤적 시뮬레이터, 스트라이크 존 히트맵, 타구 스프레이 분산도, 성능 추세 차트 등을
/// 유기적으로 연결 및 조회할 수 있도록 상태를 관리합니다.
class AnalysisScreen extends StatefulWidget {
  final bool? isActive;
  const AnalysisScreen({super.key, this.isActive = true});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  // 사용자가 상단 필터 바를 통해 선택한 세부 조건 상태값들
  String _selectedSeason = '';
  String _selectedTeam = '';
  bool _isPitcherMode = false;                 // false: 타자 모드, true: 투수 모드
  String _selectedPlayer = '';
  String _selectedSplit = '전체 데이터 (Total Splits)';

  // API 데이터 상태 관리
  final ApiService _apiService = ApiService();
  List<String> _seasonsList = [];
  List<Map<String, dynamic>> _teamsList = [];
  List<Map<String, dynamic>> _pitchersList = [];
  List<Map<String, dynamic>> _battersList = [];

  Map<String, dynamic>? _playerAnalysisData;
  bool _isLoading = false;
  bool _isFilterLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInitialFilters();
  }

  /// 초기 필터 목록(시즌 및 팀 목록) 로드
  Future<void> _loadInitialFilters() async {
    setState(() {
      _isFilterLoading = true;
    });
    final filters = await _apiService.fetchAnalysisFilters();
    if (filters != null && filters['status'] != 'fail') {
      final List<dynamic> seasons = filters['seasons'] ?? [];
      final List<dynamic> teams = filters['teams'] ?? [];

      setState(() {
        _seasonsList = seasons.map((e) => e.toString()).toList();
        _teamsList = teams.map((e) => e as Map<String, dynamic>).toList();
        
        if (_seasonsList.isNotEmpty) {
          _selectedSeason = _seasonsList.first;
        }
        if (_teamsList.isNotEmpty) {
          _selectedTeam = _teamsList.first['teamName'];
        }
        _isFilterLoading = false;
      });

      if (_teamsList.isNotEmpty) {
        final int teamId = _teamsList.first['teamId'];
        await _loadTeamPlayers(teamId);
      }
    } else {
      setState(() {
        _isFilterLoading = false;
      });
    }
  }

  /// 특정 팀의 투수/타자 목록 로드
  Future<void> _loadTeamPlayers(int teamId, {bool resetPlayer = true}) async {
    final playersData = await _apiService.fetchTeamPlayers(teamId);
    if (playersData != null) {
      final List<dynamic> pitchers = playersData['pitchers'] ?? [];
      final List<dynamic> batters = playersData['batters'] ?? [];

      setState(() {
        _pitchersList = pitchers.map((e) => e as Map<String, dynamic>).toList();
        _battersList = batters.map((e) => e as Map<String, dynamic>).toList();

        final List<Map<String, dynamic>> currentList = _isPitcherMode ? _pitchersList : _battersList;
        if (resetPlayer && currentList.isNotEmpty) {
          _selectedPlayer = currentList.first['playerName'];
        } else if (currentList.isEmpty) {
          _selectedPlayer = '';
        }
      });

      await _loadPlayerData();
    }
  }

  /// 특정 선수의 상세 통계 데이터 로드
  Future<void> _loadPlayerData() async {
    final List<Map<String, dynamic>> currentList = _isPitcherMode ? _pitchersList : _battersList;
    if (currentList.isEmpty || _selectedPlayer.isEmpty) {
      setState(() {
        _playerAnalysisData = null;
      });
      return;
    }

    final player = currentList.firstWhere(
      (p) => p['playerName'] == _selectedPlayer,
      orElse: () => <String, dynamic>{},
    );

    if (player.isEmpty) {
      setState(() {
        _playerAnalysisData = null;
      });
      return;
    }

    final int playerId = player['playerId'];

    setState(() {
      _isLoading = true;
    });

    final data = await _apiService.fetchAnalysisPlayerData(playerId, _isPitcherMode, _selectedSplit, _selectedSeason);
    setState(() {
      _playerAnalysisData = data;
      _isLoading = false;
    });
  }

  // -------------------------------------------------------------
  // [데이터 파싱 헬퍼]
  // -------------------------------------------------------------
  List<PitchCoordinate> _parsePitches() {
    if (_playerAnalysisData == null || _playerAnalysisData!['pitches'] == null) {
      return [];
    }
    final List<dynamic> list = _playerAnalysisData!['pitches'];
    return list.map((item) {
      final p = item as Map<String, dynamic>;
      return PitchCoordinate(
        pitchType: p['pitchType'] ?? 'FF',
        plateX: (p['plateX'] as num? ?? 0.0).toDouble(),
        plateZ: (p['plateZ'] as num? ?? 0.0).toDouble(),
        zone: p['zone'] ?? 0,
        releaseSpeed: (p['releaseSpeed'] as num? ?? 0.0).toDouble(),
        releaseSpinRate: (p['releaseSpinRate'] as num? ?? 0.0).toDouble(),
        result: p['result'] ?? '',
        pitchNumber: p['pitchNumber'] ?? 0,
        pfxX: p['pfxX'] != null ? (p['pfxX'] as num).toDouble() : null,
        pfxZ: p['pfxZ'] != null ? (p['pfxZ'] as num).toDouble() : null,
      );
    }).toList();
  }

  List<ZoneStat> _parseZoneStats() {
    if (_playerAnalysisData == null || _playerAnalysisData!['zoneStats'] == null) {
      return [];
    }
    final List<dynamic> list = _playerAnalysisData!['zoneStats'];
    return list.map((item) {
      final z = item as Map<String, dynamic>;
      return ZoneStat(
        zone: z['zone'] ?? 0,
        avg: (z['avg'] as num? ?? 0.0).toDouble(),
        count: z['count'] ?? 0,
        total: z['total'] ?? 0,
      );
    }).toList();
  }

  List<SprayPoint> _parseSprayPoints() {
    if (_playerAnalysisData == null || _playerAnalysisData!['sprayPoints'] == null) {
      return [];
    }
    final List<dynamic> list = _playerAnalysisData!['sprayPoints'];
    return list.map((item) {
      final s = item as Map<String, dynamic>;
      return SprayPoint(
        angle: (s['angle'] as num? ?? 0.0).toDouble(),
        distance: (s['distance'] as num? ?? 0.0).toDouble(),
        type: s['type'] ?? 'OUT',
      );
    }).toList();
  }

  List<WinProbabilityPoint> _parseWinProbabilityTimeline() {
    if (_playerAnalysisData == null || _playerAnalysisData!['winProbabilityTimeline'] == null) {
      return [];
    }
    final List<dynamic> list = _playerAnalysisData!['winProbabilityTimeline'];
    return list.map((item) {
      final p = item as Map<String, dynamic>;
      return WinProbabilityPoint(
        inningLabel: p['inningLabel'] ?? '',
        homeWinPct: (p['homeWinPct'] as num? ?? 0.50).toDouble(),
      );
    }).toList();
  }

  List<Map<String, dynamic>> _parsePerformanceTrends() {
    if (_playerAnalysisData == null || _playerAnalysisData!['performanceTrends'] == null) {
      return [];
    }
    final List<dynamic> list = _playerAnalysisData!['performanceTrends'];
    return list.map((item) => item as Map<String, dynamic>).toList();
  }

  List<Map<String, dynamic>> _parseTrajectories() {
    if (_playerAnalysisData == null || _playerAnalysisData!['trajectories'] == null) {
      return [];
    }
    final List<dynamic> list = _playerAnalysisData!['trajectories'];
    return list.map((item) => item as Map<String, dynamic>).toList();
  }

  List<Map<String, dynamic>> _parseSprayPointsForVelocity() {
    if (_playerAnalysisData == null || _playerAnalysisData!['sprayPoints'] == null) {
      return [];
    }
    final List<dynamic> list = _playerAnalysisData!['sprayPoints'];
    return list.map((item) => item as Map<String, dynamic>).toList();
  }

  @override
  Widget build(BuildContext context) {
    // 디바이스 해상도를 기반으로 데스크톱(1024px 이상) 레이아웃 적용 판별
    final double width = MediaQuery.of(context).size.width;
    final bool isDesktop = width >= 1024;
    
    // 활성 대상 투수/타자 역할에 맞는 메타 문자열 주입 ('PITCHER' vs 'HITTER')
    final String activeRole = _isPitcherMode ? 'PITCHER' : 'HITTER';

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. 최상단 필터 구성 바
            _buildFiltersBar(),
            const SizedBox(height: 24.0),

            if (_isLoading)
              const SizedBox(
                height: 300,
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              )
            else if (_playerAnalysisData == null)
              const SizedBox(
                height: 300,
                child: Center(
                  child: Text(
                    '조회할 데이터가 존재하지 않습니다. 필터를 선택해 주세요.',
                    style: TextStyle(color: AppColors.inkSubtle, fontSize: 14.0),
                  ),
                ),
              )
            else ...[
              // 2. 선택 선수 요약 프로필 카드
              _buildPlayerProfileCard(activeRole),
              const SizedBox(height: 24.0),

              // 3. 주요 스탯 수치 그리드 영역 (4칸 반응형 구성)
              _buildStatsGrid(),
              const SizedBox(height: 24.0),

              // 4. 3D 투구 궤적 시뮬레이터 (고정 높이 480)
              SizedBox(
                height: 480,
                child: PitchTrajectorySimulator(
                  playerRole: activeRole,
                  trajectories: _parseTrajectories(),
                  isActive: widget.isActive,
                ),
              ),
              const SizedBox(height: 24.0),

              // 5. 스트라이크 존 & 타구 스프레이 분산 맵 구성
              if (isDesktop)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 480,
                        child: StrikeZoneVisualizer(
                          playerRole: activeRole,
                          pitches: _parsePitches(),
                          pitcherPitchCount: _parsePitches().length,
                          zoneStats: _parseZoneStats(),
                          showPitchOrder: false,
                        ),
                      ),
                    ),
                    const SizedBox(width: 24.0),
                    Expanded(
                      child: SizedBox(
                        height: 480,
                        child: SprayChartVisualizer(
                          playerRole: activeRole,
                          points: _parseSprayPoints(),
                        ),
                      ),
                    ),
                  ],
                )
              else
                Column(
                  children: [
                    SizedBox(
                      height: 440,
                      child: StrikeZoneVisualizer(
                        playerRole: activeRole,
                        pitches: _parsePitches(),
                        pitcherPitchCount: _parsePitches().length,
                        zoneStats: _parseZoneStats(),
                        showPitchOrder: false,
                      ),
                    ),
                    const SizedBox(height: 24.0),
                    SizedBox(
                      height: 440,
                      child: SprayChartVisualizer(
                        playerRole: activeRole,
                        points: _parseSprayPoints(),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 24.0),

              // 6. 구종 무브먼트 맵 & 타구 속도 발사각 배럴 존 차트
              if (isDesktop)
                Row(
                  children: [
                    Expanded(
                      child: MovementMapChart(
                        playerRole: activeRole,
                        pitches: _parsePitches(),
                      ),
                    ),
                    const SizedBox(width: 24.0),
                    Expanded(
                      child: LaunchAngleVelocityChart(
                        playerRole: activeRole,
                        sprayPoints: _parseSprayPointsForVelocity(),
                      ),
                    ),
                  ],
                )
              else
                Column(
                  children: [
                    MovementMapChart(
                      playerRole: activeRole,
                      pitches: _parsePitches(),
                    ),
                    const SizedBox(height: 24.0),
                    LaunchAngleVelocityChart(
                      playerRole: activeRole,
                      sprayPoints: _parseSprayPointsForVelocity(),
                    ),
                  ],
                ),
              const SizedBox(height: 24.0),

              // 7. WPA 기대 승률 추이 & 경기력 추세 차트
              if (isDesktop)
                Row(
                  children: [
                    Expanded(
                      child: WinProbabilityChart(
                        playerRole: activeRole,
                        timeline: _parseWinProbabilityTimeline(),
                        gameDate: _playerAnalysisData != null ? _playerAnalysisData!['gameDate'] ?? '05/30' : '05/30',
                        homeTeamName: _playerAnalysisData != null ? _playerAnalysisData!['profile']['teamName'] ?? '홈팀' : '홈팀',
                      ),
                    ),
                    const SizedBox(width: 24.0),
                    Expanded(
                      child: PerformanceTrendChart(
                        playerRole: activeRole,
                        trends: _parsePerformanceTrends(),
                      ),
                    ),
                  ],
                )
              else
                Column(
                  children: [
                    WinProbabilityChart(
                      playerRole: activeRole,
                      timeline: _parseWinProbabilityTimeline(),
                      gameDate: _playerAnalysisData != null ? _playerAnalysisData!['gameDate'] ?? '05/30' : '05/30',
                      homeTeamName: _playerAnalysisData != null ? _playerAnalysisData!['profile']['teamName'] ?? '홈팀' : '홈팀',
                    ),
                    const SizedBox(height: 24.0),
                    PerformanceTrendChart(
                      playerRole: activeRole,
                      trends: _parsePerformanceTrends(),
                    ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // [3] 하위 빌더 메소드 섹션
  // -------------------------------------------------------------

  /// 회색 필터 카드 배경 박스 구성 메소드
  Widget _buildFiltersBar() {
    if (_isFilterLoading) {
      return Container(
        height: 60,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(color: AppColors.primary),
      );
    }

    final List<String> currentPlayers = (_isPitcherMode ? _pitchersList : _battersList)
        .map((p) => p['playerName'] as String)
        .toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Wrap(
        spacing: 12.0,
        runSpacing: 12.0,
        alignment: WrapAlignment.start,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _buildFilterDropdown(
            label: '시즌',
            value: _selectedSeason,
            items: _seasonsList,
            onChanged: (val) {
              setState(() => _selectedSeason = val!);
              _loadPlayerData();
            },
          ),
          _buildFilterDropdown(
            label: '소속 팀',
            value: _selectedTeam,
            items: _teamsList.map((t) => t['teamName'] as String).toList(),
            onChanged: (val) {
              setState(() {
                _selectedTeam = val!;
              });
              final selectedTeamMap = _teamsList.firstWhere((t) => t['teamName'] == val);
              _loadTeamPlayers(selectedTeamMap['teamId']);
            },
          ),

          // 투수/타자 세그먼트 버튼 토글
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '분석 대상 구분',
                style: TextStyle(fontSize: 10.0, color: AppColors.inkSubtle, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6.0),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.canvas,
                  borderRadius: BorderRadius.circular(6.0),
                  border: Border.all(color: AppColors.hairline),
                ),
                padding: const EdgeInsets.all(2.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildSegmentButton('투수 분석', _isPitcherMode),
                    _buildSegmentButton('타자 분석', !_isPitcherMode),
                  ],
                ),
              ),
            ],
          ),

          _buildFilterDropdown(
            label: '분석 대상 선수',
            value: _selectedPlayer,
            items: currentPlayers,
            onChanged: (val) {
              setState(() => _selectedPlayer = val!);
              _loadPlayerData();
            },
          ),
          _buildFilterDropdown(
            label: '경기 상황 필터',
            value: _selectedSplit,
            items: const ['전체 데이터 (Total Splits)', '주자 있는 상황', '득점권 상황'],
            onChanged: (val) {
              setState(() => _selectedSplit = val!);
              _loadPlayerData();
            },
          ),
        ],
      ),
    );
  }

  /// 공통 재사용 드롭다운 박스 렌더 메소드
  Widget _buildFilterDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    final List<String> dropdownItems = (items.isNotEmpty ? items : const ['데이터 없음']).toSet().toList();
    final String activeValue = dropdownItems.contains(value) ? value : dropdownItems.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10.0, color: AppColors.inkSubtle, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6.0),
        Container(
          height: 36.0,
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          decoration: BoxDecoration(
            color: AppColors.canvas,
            borderRadius: BorderRadius.circular(6.0),
            border: Border.all(color: AppColors.hairline),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: activeValue,
              dropdownColor: AppColors.surface2,
              icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.inkSubtle, size: 16),
              style: const TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontSize: 12.0,
                color: AppColors.ink,
                fontWeight: FontWeight.w500,
              ),
              items: dropdownItems.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
              onChanged: (newVal) {
                if (newVal != '데이터 없음') {
                  onChanged(newVal);
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  /// 투수/타자 세그먼트 전환용 스타일 버튼
  Widget _buildSegmentButton(String text, bool isActive) {
    return InkWell(
      onTap: () {
        if ((text == '투수 분석') != _isPitcherMode) {
          setState(() {
            _isPitcherMode = (text == '투수 분석');
            final List<Map<String, dynamic>> currentList = _isPitcherMode ? _pitchersList : _battersList;
            _selectedPlayer = currentList.isNotEmpty ? currentList.first['playerName'] : '';
          });
          _loadPlayerData();
        }
      },
      borderRadius: BorderRadius.circular(4.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(4.0),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontSize: 11.5,
            fontWeight: isActive ? FontWeight.w500 : FontWeight.w300,
            color: isActive ? AppColors.ink : AppColors.inkSubtle,
          ),
        ),
      ),
    );
  }

  /// 활성 대상 선수의 상세 프로필 카드 구성 메소드
  Widget _buildPlayerProfileCard(String role) {
    if (_playerAnalysisData == null) {
      return const SizedBox.shrink();
    }

    final profile = _playerAnalysisData!['profile'];
    final String name = profile['playerName'] ?? '';
    final String number = profile['playerNumber'] ?? '';
    final String details = profile['details'] ?? '';
    final bool isPitcher = role == 'PITCHER';

    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        children: [
          // 동그라미 엠블럼 아바타 (성 이니셜 노출)
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary, width: 2.0),
            ),
            child: Center(
              child: Text(
                name.isNotEmpty ? name.substring(0, 1) : '',
                style: const TextStyle(
                  fontSize: 20.0,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryHover,
                ),
              ),
            ),
          ),
          const SizedBox(width: 20.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 20.0,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    Text(
                      number,
                      style: const TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 13.0,
                        color: AppColors.inkTertiary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6.0),
                Text(
                  details,
                  style: const TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 13.0,
                    color: AppColors.inkSubtle,
                  ),
                ),
              ],
            ),
          ),
          
          // 우측: 투수(보라) vs 타자(오렌지) 구분용 라벨 태그 박스
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
            decoration: BoxDecoration(
              color: isPitcher ? AppColors.primary.withOpacity(0.15) : Colors.orangeAccent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(4.0),
              border: Border.all(
                color: isPitcher ? AppColors.primary : Colors.orangeAccent,
              ),
            ),
            child: Text(
              role,
              style: TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontSize: 11.0,
                fontWeight: FontWeight.bold,
                color: isPitcher ? AppColors.primaryHover : Colors.orangeAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 4칸 스탯 패널 그리드 구성 메소드
  Widget _buildStatsGrid() {
    if (_playerAnalysisData == null || _playerAnalysisData!['stats'] == null) {
      return const SizedBox.shrink();
    }

    final Map<String, dynamic> rawStats = _playerAnalysisData!['stats'];
    final List<Map<String, String>> activeStats = [];

    if (_isPitcherMode) {
      activeStats.addAll([
        {'label': '평균 자책점 (ERA)', 'value': rawStats['ERA'] ?? '0.00', 'rank': '시즌', 'color': 'success'},
        {'label': '시즌 WHIP', 'value': rawStats['WHIP'] ?? '0.00', 'rank': '시즌', 'color': 'primary'},
        {'label': '삼진율 (K%)', 'value': rawStats['kRate'] ?? '0.0%', 'rank': '시즌', 'color': 'orange'},
        {'label': '평균 구속', 'value': rawStats['avgSpeed'] ?? '0.0 km/h', 'rank': '시즌', 'color': 'cyan'},
      ]);
    } else {
      activeStats.addAll([
        {'label': '시즌 타율 (AVG)', 'value': rawStats['AVG'] ?? '.000', 'rank': '시즌', 'color': 'success'},
        {'label': '시즌 OPS', 'value': rawStats['OPS'] ?? '.000', 'rank': '시즌', 'color': 'primary'},
        {'label': '홈런 개수 (HR)', 'value': rawStats['HR'] ?? '0개', 'rank': '시즌', 'color': 'orange'},
        {'label': '시즌 출루율 (OBP)', 'value': rawStats['OBP'] ?? '.000', 'rank': '시즌', 'color': 'cyan'},
      ]);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        // 768px 미만 좁은 레이아웃에서는 2x2 형태 그리드 분기
        final bool isWide = width >= 768;

        if (isWide) {
          return Row(
            children: activeStats.map((s) => Expanded(
              child: Container(
                margin: const EdgeInsets.only(right: 12.0),
                child: _buildStatCard(s),
              ),
            )).toList(),
          );
        } else {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: _buildStatCard(activeStats[0])),
                  const SizedBox(width: 12.0),
                  Expanded(child: _buildStatCard(activeStats[1])),
                ],
              ),
              const SizedBox(height: 12.0),
              Row(
                children: [
                  Expanded(child: _buildStatCard(activeStats[2])),
                  const SizedBox(width: 12.0),
                  Expanded(child: _buildStatCard(activeStats[3])),
                ],
              ),
            ],
          );
        }
      },
    );
  }

  /// 개별 단일 메트릭 스탯 수치 카드 위젯
  Widget _buildStatCard(Map<String, String> stat) {
    Color valColor = AppColors.primaryHover;
    if (stat['color'] == 'success') valColor = AppColors.success;
    if (stat['color'] == 'orange') valColor = Colors.orangeAccent;
    if (stat['color'] == 'cyan') valColor = Colors.cyanAccent;

    return Container(
      padding: const EdgeInsets.all(18.0),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            stat['label']!,
            style: const TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: 11.5,
              color: AppColors.inkSubtle,
            ),
          ),
          const SizedBox(height: 12.0),
          // 수치와 리그 랭킹 텍스트 정렬 시 밑선 기준점(TextBaseline)을 통일해 삐뚤어짐 정돈
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                stat['value']!,
                style: TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: 26.0,
                  fontWeight: FontWeight.w700,
                  color: valColor,
                ),
              ),
              Text(
                stat['rank']!,
                style: const TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: 11.0,
                  color: AppColors.inkTertiary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

