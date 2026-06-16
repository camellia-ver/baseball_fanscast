import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/analysis_charts.dart'; 
import '../widgets/strike_zone.dart';      
import '../models/game_situation_model.dart'; 
import '../services/api_service.dart';    
import '../widgets/footer.dart';     

/// 야구 경기 실시간 중계 분석실 홈(Home) 메인 화면입니다.
/// 
/// 백엔드 API 서버로부터 실시간 경기 상황 스냅샷 데이터를 폴링/요청 조회하여
/// 경기 점수판(Scoreboard), 필드 주자 상태(Field), 투구 궤적 히트맵(StrikeZone),
/// 승률 변동 그래프(WPA), AI의 해설 코멘터리 및 팬 실시간 응원 투표 등을 구성합니다.
class HomeScreen extends StatefulWidget {
  final bool? isActive;
  const HomeScreen({super.key, this.isActive = true});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // api_service.dart의 인스턴스 연동
  final ApiService _apiService = ApiService();
  GameSituationModel? _gameData;
  GameSituationModel? _visualizedGameData;
  Timer? _visualizedUpdateTimer;
  GameSituationModel? _casterGameData;
  Timer? _casterUpdateTimer;
  bool _isLoading = true;
  String? _errorMessage;
  String _casterAnimationStage = 'start';

  // 실시간 투표 갱신 상태
  int _selectedPollIndex = -1; 
  final List<int> _pollVotes = [124, 98, 42]; 

  // AI 음성 중계 활성화 여부
  bool _isTtsPlaying = false;

  // WPA 승률 히스토리 누적 리스트
  final List<WinProbabilityPoint> _accumulatedTimeline = [];

  // 자동 시뮬레이션 제어용 타이머 및 단계 인덱스 변수
  Timer? _simulationTimer;
  int _currentStepIndex = 0;
  int _currentGameId = 776135;

  // ✅ [추가] 시뮬레이션 시작 여부 플래그 (false = 빈 껍데기 대시보드 표시)
  bool _isSimulationStarted = false;

  // Lazy Loading 상태 변수
  List<OtherGame> _otherGames = [];
  List<SeasonStanding> _seasonStandings = [];
  bool _isOtherGamesLoading = true;
  bool _isStandingsLoading = true;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final bool currentActive = widget.isActive ?? true;
    final bool oldActive = oldWidget.isActive ?? true;
    if (currentActive != oldActive) {
      if (currentActive) {
        _resumeSimulation();
      } else {
        _pauseSimulation();
      }
    }
  }

  void _pauseSimulation() {
    _simulationTimer?.cancel();
    _visualizedUpdateTimer?.cancel();
    _casterUpdateTimer?.cancel();

    // 💡 [추가] 다른 페이지로 이동을 시작할 때, 무거운 타임라인 배열을 
    // 우선적으로 비워 가비지 컬렉터(GC)가 애니메이션 종료 후 천천히 일하도록 분산합니다.
    _accumulatedTimeline.clear();

    print('[HomeScreen] 다른 페이지로 이동하여 시뮬레이션 및 무거운 자원을 일시 정지합니다.');
  }

  void _resumeSimulation() {
    _pauseSimulation();
    _loadLiveGameData(isFirstLoad: false);
    _simulationTimer = Timer.periodic(const Duration(seconds: 7), (timer) {
      _loadNextStep();
    });
  }

  @override
  void dispose() {
    // 위젯 파괴 시 비동기 타이머 해제 수행 (메모리 누수 방지)
    _pauseSimulation();
    super.dispose();
  }

  /// ✅ [추가] 사용자가 Play Ball! 버튼을 눌렀을 때 호출되는 핸들러입니다.
  void _onStartButtonPressed() {
    setState(() {
      _isSimulationStarted = true;
    });
    _startSimulation();
  }

  /// 시뮬레이션을 개시하고 5초 주기로 인덱스를 자동 갱신시키는 주기적 타이머를 동작시킵니다.
  void _startSimulation() async {
    _currentStepIndex = 0;
    final success = await _loadLiveGameData(isFirstLoad: true);

    if (success && mounted) {
      _simulationTimer = Timer.periodic(const Duration(seconds: 7), (timer) {
        _loadNextStep();
      });
    }
  }

  /// 7초 타이머 주기 호출 시마다 다음 단계 투구 인덱스 증가 및 API 호출을 트리거합니다.
  Future<void> _loadNextStep() async {
    _currentStepIndex++;
    final success = await _loadLiveGameData(isFirstLoad: false);
    
    // 데이터 쿼리 실패 시(마지막 투구 도달로 404/Null 발생 등) 타이머를 중단합니다.
    if (!success) {
      _simulationTimer?.cancel();
      print('[HomeScreen] 마지막 경기 데이터 상황에 도달하여 타이머를 정지합니다.');
    }
  }

  /// 백엔드 Spring Boot API 서버로부터 시뮬레이션 경기 스냅샷을 비동기 조회합니다.
  /// 
  /// [isFirstLoad]가 true일 때만 화면에 풀 서클 로딩창을 띄우고,
  /// 타이머에 의한 주기적인 업데이트 상황에서는 백그라운드로 데이터만 갱신하는 Silent Update를 수행합니다.
  Future<bool> _loadLiveGameData({
    required bool isFirstLoad,
    int? sourceGameId,
    int? sourceStepIndex,
  }) async {
    if (isFirstLoad) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try{
        // 💡 [개선] 초기 진입 시 의존성이 없는 API 3개를 동시에 병렬 요청 (RTT 단축)
        final results = await Future.wait([
          _apiService.fetchLiveFeedDashboard(
            _currentGameId,
            _currentStepIndex,
            sourceGameId: sourceGameId,
            sourceStepIndex: sourceStepIndex,
          ),
          _apiService.fetchOtherGames(_currentGameId, _currentStepIndex),
          _apiService.fetchSeasonStandings(_currentGameId),
        ]);

        final data = results[0] as GameSituationModel?;
        final otherGames = results[1] as List<OtherGame>?;
        final standings = results[2] as List<SeasonStanding>?;

        if (!mounted) return false;

        if (data != null) {
          setState(() {
            _gameData = data;
            _otherGames = otherGames ?? [];
            _seasonStandings = standings ?? [];
            _isOtherGamesLoading = false;
            _isStandingsLoading = false;
            _isLoading = false;
            _currentStepIndex = data.currentStepIndex;

            // 💡 [개선] 첫 로딩 시에는 1초/3.5초 딜레이 타이머를 거치지 않고 최종 데이터를 즉시 바인딩
            _visualizedGameData = GameSituationModel(
              status: data.status,
              gameDate: data.gameDate,
              scoreBoard: data.postScoreBoard ?? data.scoreBoard,
              fieldAndPitch: data.postFieldAndPitch ?? data.fieldAndPitch,
              winProbabilityTimeline: data.winProbabilityTimeline,
              aiCommentary: data.aiCommentary,
              otherGames: otherGames ?? [],
              seasonStandings: standings ?? [],
              currentStepIndex: data.currentStepIndex,
            );

            _casterGameData = GameSituationModel(
              status: data.status,
              gameDate: data.gameDate,
              scoreBoard: data.postScoreBoard ?? data.scoreBoard,
              fieldAndPitch: data.postFieldAndPitch ?? data.fieldAndPitch,
              winProbabilityTimeline: data.winProbabilityTimeline,
              aiCommentary: data.postAiCommentary ?? data.aiCommentary,
              otherGames: otherGames ?? [],
              seasonStandings: standings ?? [],
              currentStepIndex: data.currentStepIndex,
            );
            _casterAnimationStage = 'end';

            // 승률 타임라인 누적
            _accumulatedTimeline.clear();
            for (var point in data.winProbabilityTimeline) {
              _accumulatedTimeline.add(point);
            }
          });
          return true;
          }
      }catch(e){
        print('[HomeScreen] 초기 병렬 로딩 중 오류 발생: $e');
      }

      setState(() {
        _errorMessage = "백엔드 분석 파이프라인 연결에 실패했습니다.";
        _isLoading = false;
      });
      return false;
    }

    final data = await _apiService.fetchLiveFeedDashboard(
      _currentGameId,
      _currentStepIndex,
      sourceGameId: sourceGameId,
      sourceStepIndex: sourceStepIndex,
    );

    if (!mounted) return false;

    if (data != null) {
      // 💡 [개선] 이전 스텝의 시차 타이머가 아직 완료되지 않은 상태로 다음 스텝이 수신된 경우,
      // 이전 타이머가 반영하려던 최종 데이터(post 상태)를 강제로 즉시 화면에 반영(Flush)하여 유실을 차단합니다.
      if (_visualizedUpdateTimer?.isActive == true) {
        _visualizedUpdateTimer?.cancel();
        if (_gameData != null) {
          _visualizedGameData = GameSituationModel(
            status: _gameData!.status,
            gameDate: _gameData!.gameDate,
            scoreBoard: _gameData!.postScoreBoard ?? _gameData!.scoreBoard,
            fieldAndPitch: _gameData!.postFieldAndPitch ?? _gameData!.fieldAndPitch,
            winProbabilityTimeline: _gameData!.winProbabilityTimeline,
            aiCommentary: _gameData!.aiCommentary,
            otherGames: _gameData!.otherGames,
            seasonStandings: _gameData!.seasonStandings,
            currentStepIndex: _gameData!.currentStepIndex,
          );
        }
      } else {
        _visualizedUpdateTimer?.cancel();
      }

      if (_casterUpdateTimer?.isActive == true) {
        _casterUpdateTimer?.cancel();
        if (_gameData != null) {
          _casterGameData = GameSituationModel(
            status: _gameData!.status,
            gameDate: _gameData!.gameDate,
            scoreBoard: _gameData!.postScoreBoard ?? _gameData!.scoreBoard,
            fieldAndPitch: _gameData!.postFieldAndPitch ?? _gameData!.fieldAndPitch,
            winProbabilityTimeline: _gameData!.winProbabilityTimeline,
            aiCommentary: _gameData!.postAiCommentary ?? _gameData!.aiCommentary,
            otherGames: _gameData!.otherGames,
            seasonStandings: _gameData!.seasonStandings,
            currentStepIndex: _gameData!.currentStepIndex,
          );
          _casterAnimationStage = 'end';
        }
      } else {
        _casterUpdateTimer?.cancel();
      }
      setState(() {
        _gameData = data;
        _isLoading = false;
        _currentStepIndex = data.currentStepIndex; // 백엔드 보정 스텝과 동기화

        // 1단계 (0.0초): 스트라이크존 점은 실시간으로 그리되, 
        // 💡 우측 상단 PITCH COUNT 수치만큼은 post 데이터에서 미리 가져와 동기화합니다.
        _visualizedGameData = GameSituationModel(
          status: data.status,
          gameDate: data.gameDate,
          // 투구 개수(pitcherPitchCount)가 포함된 fieldAndPitch만 최신 상태(post)를 미리 빌려옵니다.
          fieldAndPitch: data.postFieldAndPitch ?? data.fieldAndPitch, 
          scoreBoard: data.scoreBoard, // 전광판의 다른 요소(점수, 아웃카운트 등)는 기존의 1초 딜레이 유지
          winProbabilityTimeline: data.winProbabilityTimeline,
          aiCommentary: data.aiCommentary,
          otherGames: data.otherGames,
          seasonStandings: data.seasonStandings,
          currentStepIndex: data.currentStepIndex,
        );
        
        _casterGameData = data;
        _casterAnimationStage = 'start';

        // Lazy Loading 상태 초기화를 메인 setState에 통합 (별도 setState 방지)
        _isOtherGamesLoading = true;
        _isStandingsLoading = true;

        // 실시간 이닝 승률 누적 처리
        if (isFirstLoad) {
          _accumulatedTimeline.clear();
          for (var point in data.winProbabilityTimeline) {
            _accumulatedTimeline.add(point);
          }
        }
      });

      // 2단계 (1.0초 뒤): 투구 착탄 및 전광판(볼카운트/점수/안타/실책) & 베이스 주자 상태 동시 갱신
      _visualizedUpdateTimer = Timer(const Duration(seconds: 1), () {
        if (!mounted) return;
        setState(() {
          _visualizedGameData = GameSituationModel(
            status: data.status,
            gameDate: data.gameDate,
            scoreBoard: data.postScoreBoard ?? data.scoreBoard,
            fieldAndPitch: data.postFieldAndPitch ?? data.fieldAndPitch,
            winProbabilityTimeline: data.winProbabilityTimeline,
            aiCommentary: data.aiCommentary,
            otherGames: data.otherGames,
            seasonStandings: data.seasonStandings,
            currentStepIndex: data.currentStepIndex,
          );

          for (var point in data.winProbabilityTimeline) {
            final existingIndex = _accumulatedTimeline.indexWhere(
              (p) => p.inningLabel == point.inningLabel
            );
            if (existingIndex != -1) {
              _accumulatedTimeline[existingIndex] = point;
            } else {
              _accumulatedTimeline.add(point);
            }
          }
        });
      });

      // 3단계 (3.5초 뒤): AI 캐스터 패널에 다음 투구 예측 정보(postAiCommentary)를 즉시 표시 (Instant Render)
      _casterUpdateTimer = Timer(const Duration(milliseconds: 3500), () {
        if (!mounted) return;
        setState(() {
          _casterGameData = GameSituationModel(
            status: data.status,
            gameDate: data.gameDate,
            scoreBoard: data.postScoreBoard ?? data.scoreBoard,
            fieldAndPitch: data.postFieldAndPitch ?? data.fieldAndPitch,
            winProbabilityTimeline: data.winProbabilityTimeline,
            aiCommentary: data.postAiCommentary ?? data.aiCommentary,
            otherGames: data.otherGames,
            seasonStandings: data.seasonStandings,
            currentStepIndex: data.currentStepIndex,
          );
          _casterAnimationStage = 'end';
        });
      });

      _loadOtherGames();
      _loadSeasonStandings();

      return true;
    } else {
      if (isFirstLoad) {
        setState(() {
          _errorMessage = "백엔드 분석 파이프라인 연결에 실패했습니다.";
          _isLoading = false;
        });
      }
      return false;
    }
  }

  /// 타 경기 목록을 백엔드로부터 지연 로딩합니다.
  /// (진입 시 setState 제거: 메인 _loadLiveGameData setState에 통합됨)
  Future<void> _loadOtherGames() async {
    try {
      final otherGames = await _apiService.fetchOtherGames(_currentGameId, _currentStepIndex);
      if (mounted) {
        setState(() {
          _otherGames = otherGames ?? [];
          _isOtherGamesLoading = false;
        });
      }
    } catch (e) {
      print('[HomeScreen] 타 경기 로딩 오류: $e');
      if (mounted) {
        setState(() {
          _isOtherGamesLoading = false;
        });
      }
    }
  }

  /// 시즌 순위표 정보를 백엔드로부터 지연 로딩합니다.
  /// (진입 시 setState 제거: 메인 _loadLiveGameData setState에 통합됨)
  Future<void> _loadSeasonStandings() async {
    try {
      final standings = await _apiService.fetchSeasonStandings(_currentGameId);
      if (mounted) {
        setState(() {
          _seasonStandings = standings ?? [];
          _isStandingsLoading = false;
        });
      }
    } catch (e) {
      print('[HomeScreen] 시즌 순위표 로딩 오류: $e');
      if (mounted) {
        setState(() {
          _isStandingsLoading = false;
        });
      }
    }
  }

  /// 클릭한 타겟 경기정보로 메인화면을 전환하고 동기화 진행률에 맞춘 시각화를 렌더링합니다.
  void _switchMainGame(int newGameId) {
    if (_currentGameId == newGameId) return;

    // 1. 기존 타이머 모두 취소
    _simulationTimer?.cancel();
    _visualizedUpdateTimer?.cancel();
    _casterUpdateTimer?.cancel();

    final int oldGameId = _currentGameId;
    final int oldStepIndex = _currentStepIndex;

    setState(() {
      _currentGameId = newGameId;
      _isLoading = true; // 전환 동안 로딩창 표시
      _errorMessage = null;
    });

    // 2. 백엔드에 현재 게임 ID와 현재 스텝 인덱스를 알려주어 진행률 비율에 맞추어 로드 요청
    _loadLiveGameData(
      isFirstLoad: true,
      sourceGameId: oldGameId,
      sourceStepIndex: oldStepIndex,
    ).then((success) {
      if (success && mounted) {
        // 3. 로드가 정상 완료되면 새 경기의 시점부터 7초 타이머 가동
        _simulationTimer = Timer.periodic(const Duration(seconds: 7), (timer) {
          _loadNextStep();
        });
      }
    });
  }

  /// 사용자의 MVP 실시간 투표 반영 로직
  void _submitVote(int index) {
    if (_selectedPollIndex == -1) { 
      setState(() {
        _selectedPollIndex = index;
        _pollVotes[index]++;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    // 1024px 기점 데스크톱 레이아웃 활성화 체크
    final bool isDesktop = width >= 1024;

    // ✅ [추가] 시뮬 시작 전: 빈 껍데기 대시보드 + Play Ball! 버튼 표시
    if (!_isSimulationStarted) {
      return _buildEmptyDashboard(isDesktop: isDesktop);
    }

    if (_isLoading) {
      return const SizedBox(
        height: 500,
        child: Center(child: CircularProgressIndicator(color: AppColors.primaryHover)),
      );
    }

    if (_errorMessage != null || _gameData == null) {
      return SizedBox(
        height: 500,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_errorMessage ?? "에러 발생", style: const TextStyle(color: Colors.redAccent, fontSize: 14.0)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _loadLiveGameData(isFirstLoad: true),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.surface3),
                child: const Text("다시 시도", style: TextStyle(color: AppColors.ink)),
              ),
            ],
          ),
        ),
      );
    }

    // 바인딩 완료된 데이터 상황 객체들
    final visualizedData = _visualizedGameData ?? _gameData!;
    final casterData = _casterGameData ?? _gameData!;
    final ScoreBoardInfo sb = visualizedData.scoreBoard;
    final FieldAndPitchInfo fp = visualizedData.fieldAndPitch;
    final AiCommentary ai = casterData.aiCommentary;

    // 💡 [최종 최적화] build 메서드가 동작할 때 무거운 커스텀 시각화 위젯들이 
    // 힙 메모리에 중복 상주하지 않도록 변수로 선언하여 인스턴스를 딱 1번만 만듭니다.
    final Widget layoutFieldVisualizer = FieldVisualizerWidget(fp: fp);

    // 💡 현재 대시보드가 로딩 창을 막 끝내고 처음 그려지는 시점인지 판별하는 플래그
    final bool isFirstLoadDraw = (_visualizedGameData?.currentStepIndex == _gameData?.currentStepIndex) && (_casterAnimationStage == 'end');

    final Widget layoutStrikeZoneVisualizer = SizedBox(
      height: 360,
      child: StrikeZoneVisualizer(
        playerRole: 'HITTER',
        showToggle: false,
        initialGridMode: false,
        pitches: fp.pitchCoordinates,
        pitcherPitchCount: fp.pitcherPitchCount,
        isActive: widget.isActive,
        isFirstLoad: isFirstLoadDraw,
      ),
    );

    final Widget layoutWinProbabilityChart = WinProbabilityChart(
      playerRole: 'HITTER',
      timeline: _accumulatedTimeline,
      gameDate: visualizedData.gameDate,
      homeTeamName: sb.homeTeamAbbr,
    );

    final Widget layoutAICasterPanel = AICasterPanelWidget(
      ai: ai,
      sb: sb,
      isTtsPlaying: _isTtsPlaying,
      onTtsToggle: () {
        setState(() { _isTtsPlaying = !_isTtsPlaying; });
      },
    );

    final Widget layoutUserPollPanel = _buildUserPollPanel();

    final Widget layoutStandingsPanel = StandingsPanelWidget(
      standings: _seasonStandings,
      isLoading: _isStandingsLoading,
    );

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. 타 경기 종료/진행 상황 정보 바
            _buildOtherGamesBar(_otherGames),
            const SizedBox(height: 24.0),

            // 💡 레이아웃 분기 시 위 위젯 인스턴스를 재사용함으로써 
            // 가비지 컬렉터(GC) 부하 및 레이아웃 패스 디코딩 Latency를 차단합니다.
            if (isDesktop)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildScoreboardAndCount(sb, fp), 
                      const SizedBox(height: 24.0),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: layoutFieldVisualizer), 
                          const SizedBox(width: 24.0),
                          Expanded(child: layoutStrikeZoneVisualizer), 
                        ],
                      ),
                      const SizedBox(height: 24.0),
                      layoutWinProbabilityChart,
                    ],
                  ),
                ),
                const SizedBox(width: 24.0),
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      layoutAICasterPanel, 
                      const SizedBox(height: 24.0),
                      layoutUserPollPanel,
                      const SizedBox(height: 24.0),
                      layoutStandingsPanel,
                    ],
                  ),
                ),
              ],
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildScoreboardAndCount(sb, fp), 
                const SizedBox(height: 24.0),
                layoutFieldVisualizer, 
                const SizedBox(height: 24.0),
                layoutStrikeZoneVisualizer, 
                const SizedBox(height: 24.0),
                layoutWinProbabilityChart,
                const SizedBox(height: 24.0),
                layoutAICasterPanel, 
                const SizedBox(height: 24.0),
                layoutUserPollPanel,
                const SizedBox(height: 24.0),
                layoutStandingsPanel,
              ],
            ),

            // 💡 [추가] 대시보드 콘텐츠가 다 끝난 맨 밑바닥에 여백과 함께 푸터를 배치합니다.
            const SizedBox(height: 48.0),
            const Footer(),
          ],
        ),
      ),
    );
  }

  /// ✅ [최종 수정] 사용자가 처음 진입했을 때 보여주는 랜딩 대시보드 화면입니다.
  /// 중앙 집중형 카드 구조로 설계되었으며,
  /// 타 경기 스코어 바(Nav)와 푸터(Footer) 사이 공간을 완전히 활용합니다.
  Widget _buildEmptyDashboard({required bool isDesktop}) {
    // ── 1. 상단 타 경기 스코어 바 (상단 네비게이션 역할) ──────────────────────
    // 데이터가 로딩 중이거나 없을 때도 핏이 깨지지 않도록 기존 메서드를 재활용합니다.
    // final Widget topNavBar = _buildOtherGamesBar(_otherGames);

    // ── 중앙 메인 랜딩 카드 내부 구성 ─────────────────────────────────────
    final Widget mainLandingCard = Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 40.0),
        decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: BorderRadius.circular(16.0),
          border: Border.all(color: AppColors.hairlineStrong, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min, // 콘텐츠 크기에 맞게 세로 압축
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ● LIVE SIMULATION 뱃지
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20.0),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  _LiveBlinkingDot(), // 기존 코드에 있던 깜빡이는 점 재활용
                  SizedBox(width: 6.0),
                  Text(
                    'LIVE SIMULATION',
                    style: TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontSize: 11.0,
                      fontWeight: FontWeight.bold,
                      color: Colors.redAccent,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28.0),

            // ⚾ 로고 및 타이틀 영역
            const Text('⚾', style: TextStyle(fontSize: 44.0)),
            const SizedBox(height: 12.0),
            const Text(
              'baseball fancast',
              style: TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontWeight: FontWeight.w800,
                fontSize: 24.0,
                color: AppColors.primaryHover,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6.0),
            const Text(
              '실시간 경기 분석 시뮬레이터',
              style: TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontWeight: FontWeight.w500,
                fontSize: 14.0,
                color: AppColors.inkSubtle,
              ),
            ),
            const SizedBox(height: 24.0),
            
            // 구분선
            const Divider(color: AppColors.hairline, thickness: 1.0),
            const SizedBox(height: 24.0),

            // 안내 설명 문구
            const Text(
              '버튼을 눌러 경기 시뮬레이션을 시작하세요.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontWeight: FontWeight.w600,
                fontSize: 14.0,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 8.0),
            const Text(
              '투구 분석, 승률 변동, AI 해설이 실시간으로 동기화됩니다.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontSize: 12.0,
                color: AppColors.inkTertiary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 36.0),

            // ╔═══════════════════╗
            // ║  ⚾  Play Ball!   ║ -> InkWell을 사용하여 Hover 시 밝아지는 인터랙션 구현
            // ╚═══════════════════╝
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _onStartButtonPressed,
                borderRadius: BorderRadius.circular(12.0),
                // 메인 앱테마 잉크 액션 연동 (Hover 시 백그라운드가 부드럽게 밝아지거나 물듭니다)
                hoverColor: AppColors.primaryHover.withOpacity(0.85), 
                splashColor: AppColors.primary.withOpacity(0.2),
                child: Ink(
                  padding: const EdgeInsets.symmetric(horizontal: 48.0, vertical: 18.0),
                  decoration: BoxDecoration(
                    color: AppColors.primaryHover, // 기본 대기 색상
                    borderRadius: BorderRadius.circular(12.0),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryHover.withOpacity(0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text('⚾', style: TextStyle(fontSize: 18.0)),
                      SizedBox(width: 10.0),
                      Text(
                        'Play Ball!',
                        style: TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontWeight: FontWeight.bold,
                          fontSize: 16.0,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    // ── 3. 전체 레이아웃 조립 (화면 스크롤 및 컴포넌트 간 반응형 배치) ─────────────────
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: Container(
            // 최소 높이를 기기 전체 높이로 강제하여 푸터가 항상 바닥에 머물거나 아래로 밀리게 처리
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            padding: const EdgeInsets.all(24.0),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // topNavBar,          // 1. 상단 네비게이션
                  const Spacer(),     // 유연한 공백: 상단 바와 카드 사이 공간 채우기
                  mainLandingCard,    // 1. 아시아트 기반 메인 랜딩 카드 (정중앙 위치)
                  const Spacer(),     // 유연한 공백: 카드와 푸터 사이 공간 채우기
                  const SizedBox(height: 24.0),
                  const Footer(),     // 2. 최하단 푸터 바
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// 타 경기 종료/진행 통계 정보를 가로 스크롤 방식으로 뿌려주는 헤더 바 위젯
  Widget _buildOtherGamesBar(List<OtherGame> games) {
    if (games.isEmpty) {
      if (_isOtherGamesLoading) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '타 경기 스코어',
              style: TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontWeight: FontWeight.w700,
                fontSize: 14.0,
                color: AppColors.inkSubtle,
              ),
            ),
            const SizedBox(height: 10.0),
            SizedBox(
              height: 52,
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryHover),
                    ),
                    SizedBox(width: 8),
                    Text('타 경기 정보를 가져오는 중...', style: TextStyle(color: AppColors.inkSubtle, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ],
        );
      }
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '타 경기 스코어',
          style: TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontWeight: FontWeight.w700,
            fontSize: 14.0,
            color: AppColors.inkSubtle,
          ),
        ),
        const SizedBox(height: 10.0),
        SizedBox(
          height: 52,
          child: ListView.separated(
            scrollDirection: Axis.horizontal, 
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            itemCount: games.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12.0), 
            itemBuilder: (context, idx) {
              final g = games[idx];
              final bool isLive = g.status != '종료'; 
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _switchMainGame(g.gameId),
                  borderRadius: BorderRadius.circular(8.0),
                  hoverColor: AppColors.primary.withOpacity(0.08),
                  splashColor: AppColors.primary.withOpacity(0.15),
                  child: Ink(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    decoration: BoxDecoration(
                      color: AppColors.surface1,
                      borderRadius: BorderRadius.circular(8.0),
                      border: Border.all(
                        color: _currentGameId == g.gameId 
                            ? AppColors.primaryHover 
                            : AppColors.hairline,
                        width: _currentGameId == g.gameId ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        if (isLive) ...[
                          // 라이브 경기 시 빨간색 애니메이션 서클 표기
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Colors.redAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6.0),
                        ],
                        Text(
                          '${g.awayTeamName} ${g.awayScore} : ${g.homeScore} ${g.homeTeamName}',
                          style: TextStyle(
                            fontFamily: AppTypography.fontFamily,
                            fontSize: 12.0,
                            fontWeight: _currentGameId == g.gameId 
                                ? FontWeight.bold 
                                : FontWeight.w500,
                            color: _currentGameId == g.gameId 
                                ? AppColors.primaryHover 
                                : AppColors.ink,
                          ),
                        ),
                        const SizedBox(width: 8.0),
                        Text(
                          g.status,
                          style: TextStyle(
                            fontFamily: AppTypography.fontFamily,
                            fontSize: 11.0,
                            color: isLive ? Colors.redAccent : AppColors.inkTertiary,
                            fontWeight: _currentGameId == g.gameId 
                                ? FontWeight.bold 
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// 스코어보드 라인 카드 및 매치업 상황 볼카운트 정보 묶음
  Widget _buildScoreboardAndCount(ScoreBoardInfo sb, FieldAndPitchInfo fp) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildLineScoreCard(sb),       
        const SizedBox(height: 20.0), 
        _buildMatchupAndCountCard(sb),  
      ],
    );
  }

  /// 이닝별 득점표 테이블을 렌더링하는 라인 스코어 위젯 (스크롤 가능 지원)
  Widget _buildLineScoreCard(ScoreBoardInfo sb) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface1,                    
        borderRadius: BorderRadius.circular(12.0),    
        border: Border.all(color: AppColors.hairline), 
      ),
      padding: const EdgeInsets.all(20.0), 
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'LINE SCORE',
            style: TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontWeight: FontWeight.w500,
              fontSize: 12.0,
              color: AppColors.inkSubtle,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 16.0),
          LayoutBuilder(
            builder: (context, constraints) {
              // 정규 9이닝 또는 실제 득점 기록 중 최대 이닝 수 계산
              final int maxInning = math.max(9, math.max(sb.awayInningScores.length, sb.homeInningScores.length));
              
              // 이닝 크기에 비례한 가로 최소 너비 계산 (TEAM(110px) + R/H/E(각 40px*3=120px) + 이닝당 35px)
              final double minTableWidth = 230.0 + (maxInning * 35.0); 
              
              // 가로폭이 확보되지 않으면 좌우 스크롤링 지원 처리
              final bool useFlex = constraints.maxWidth >= minTableWidth; 

              final TableColumnWidth teamWidth = useFlex ? const FlexColumnWidth(3.0) : const FixedColumnWidth(110.0);
              final TableColumnWidth inningWidth = useFlex ? const FlexColumnWidth(1.0) : const FixedColumnWidth(35.0);
              final TableColumnWidth metricWidth = useFlex ? const FlexColumnWidth(1.2) : const FixedColumnWidth(40.0);

              // 컬럼 인덱스에 따라 컬럼 폭 맵 동적 생성
              final Map<int, TableColumnWidth> columnWidths = {
                0: teamWidth,
              };
              for (int i = 1; i <= maxInning; i++) {
                columnWidths[i] = inningWidth;
              }
              columnWidths[maxInning + 1] = metricWidth; // R
              columnWidths[maxInning + 2] = metricWidth; // H
              columnWidths[maxInning + 3] = metricWidth; // E

              Widget table = Table(
                columnWidths: columnWidths, 
                defaultVerticalAlignment: TableCellVerticalAlignment.middle, 
                children: [
                  TableRow(
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: AppColors.hairline)), 
                    ),
                    children: [
                      const TableCell(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                          child: Text('TEAM', style: TextStyle(fontFamily: AppTypography.fontFamily, fontWeight: FontWeight.w500, fontSize: 11, color: AppColors.inkSubtle)),
                        ),
                      ),
                      ...List.generate(maxInning, (i) => TableCell(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Text('${i+1}', style: const TextStyle(fontFamily: AppTypography.fontFamily, fontSize: 11, color: AppColors.inkSubtle)),
                          ),
                        ),
                      )),
                      TableCell(
                        child: Container(
                          color: AppColors.surface2,
                          child: const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 8.0),
                              child: Text('R', style: TextStyle(fontFamily: AppTypography.fontFamily, fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.primaryHover)),
                            ),
                          ),
                        ),
                      ),
                      const TableCell(child: Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 8.0), child: Text('H', style: TextStyle(fontFamily: AppTypography.fontFamily, fontSize: 11, color: AppColors.inkSubtle))))),
                      const TableCell(child: Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 8.0), child: Text('E', style: TextStyle(fontFamily: AppTypography.fontFamily, fontSize: 11, color: AppColors.inkSubtle))))),
                    ],
                  ),
                  TableRow(
                    children: [
                      TableCell(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 4.0),
                          child: Text(sb.awayTeamAbbr, style: const TextStyle(fontFamily: AppTypography.fontFamily, fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryHover)),
                        ),
                      ),
                      ...List.generate(maxInning, (i) {
                        String score = "";
                        if (i < sb.awayInningScores.length) {
                          score = sb.awayInningScores[i].toString();
                        }
                        return TableCell(child: Center(child: Text(score, style: const TextStyle(fontFamily: AppTypography.fontFamily, fontSize: 12, color: AppColors.inkMuted))));
                      }),
                      TableCell(
                        child: Container(
                          color: AppColors.surface2,
                          child: Center(child: Text('${sb.awayScore}', style: const TextStyle(fontFamily: AppTypography.fontFamily, fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryHover))),
                        ),
                      ),
                      TableCell(child: Center(child: Text('${sb.awayHits}', style: const TextStyle(fontFamily: AppTypography.fontFamily, fontSize: 12, color: AppColors.ink)))),
                      TableCell(child: Center(child: Text('${sb.awayErrors}', style: const TextStyle(fontFamily: AppTypography.fontFamily, fontSize: 12, color: AppColors.ink)))),
                    ],
                  ),
                  TableRow(
                    children: [
                      TableCell(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 4.0),
                          child: Text(sb.homeTeamAbbr, style: const TextStyle(fontFamily: AppTypography.fontFamily, fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.ink)),
                        ),
                      ),
                      ...List.generate(maxInning, (i) {
                        String score = "";
                        if (i < sb.homeInningScores.length) {
                          score = sb.homeInningScores[i].toString();
                        }
                        return TableCell(child: Center(child: Text(score, style: const TextStyle(fontFamily: AppTypography.fontFamily, fontSize: 12, color: AppColors.inkMuted))));
                      }),
                      TableCell(
                        child: Container(
                          color: AppColors.surface2,
                          child: Center(child: Text('${sb.homeScore}', style: const TextStyle(fontFamily: AppTypography.fontFamily, fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryHover))),
                        ),
                      ),
                      TableCell(child: Center(child: Text('${sb.homeHits}', style: const TextStyle(fontFamily: AppTypography.fontFamily, fontSize: 12, color: AppColors.ink)))),
                      TableCell(child: Center(child: Text('${sb.homeErrors}', style: const TextStyle(fontFamily: AppTypography.fontFamily, fontSize: 12, color: AppColors.ink)))),
                    ],
                  ),
                ],
              );

              if (useFlex) {
                return table;
              } else {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(width: minTableWidth, child: table),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  /// 팀 대진 상황 및 볼/스트라이크/아웃(B-S-O) 전용 전광판 카드 렌더 위젯
  Widget _buildMatchupAndCountCard(ScoreBoardInfo sb) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: AppColors.hairline),
      ),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              // ================= 원정 팀 (Away Team) 영역 =================
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // 💡 가로 공간 부족 시 텍스트 생략 처리를 위해 Expanded 추가
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end, // 우측 정렬
                        children: [
                          _buildTeamEmblem(sb.awayTeamAbbr), 
                          const SizedBox(height: 8.0),
                          Text(
                            sb.awayTeamAbbr, 
                            overflow: TextOverflow.ellipsis, // 💡 말줄임표 처리
                            maxLines: 1,
                            style: const TextStyle(
                              fontFamily: AppTypography.fontFamily, 
                              fontWeight: FontWeight.w700, 
                              fontSize: 12, 
                              color: AppColors.ink
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12.0),
                    Text('${sb.awayScore}', style: const TextStyle(fontFamily: AppTypography.fontFamily, fontWeight: FontWeight.w700, fontSize: 44, color: AppColors.ink, letterSpacing: -1.0)),
                  ],
                ),
              ),
              
              // ================= 이닝 정보 (Center 경기 상황) 영역 =================
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                      decoration: BoxDecoration(
                        color: AppColors.surface3,                 
                        borderRadius: BorderRadius.circular(12.0), 
                        border: Border.all(color: AppColors.hairline),
                      ),
                      child: Text(
                        '${sb.currentInning}TH INNING',
                        style: const TextStyle(fontFamily: AppTypography.fontFamily, fontWeight: FontWeight.w500, fontSize: 10, color: AppColors.inkSubtle),
                      ),
                    ),
                    const SizedBox(height: 6.0),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 이닝의 초(상단)/말(하단) 구분을 나타내는 램프 뱃지
                        Container(
                          width: 6, height: 6,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: !sb.isBottom ? AppColors.primaryHover : AppColors.surface4),
                        ),
                        const SizedBox(width: 6.0),
                        Container(
                          width: 6, height: 6,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: sb.isBottom ? AppColors.primaryHover : AppColors.surface4),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // ================= 홈 팀 (Home Team) 영역 =================
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Text('${sb.homeScore}', style: const TextStyle(fontFamily: AppTypography.fontFamily, fontWeight: FontWeight.w700, fontSize: 44, color: AppColors.ink, letterSpacing: -1.0)),
                    const SizedBox(width: 12.0),
                    // 💡 가로 공간 부족 시 텍스트 생략 처리를 위해 Expanded 추가
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start, // 좌측 정렬
                        children: [
                          _buildTeamEmblem(sb.homeTeamAbbr), 
                          const SizedBox(height: 8.0),
                          Text(
                            sb.homeTeamAbbr, 
                            overflow: TextOverflow.ellipsis, // 💡 말줄임표 처리
                            maxLines: 1,
                            style: const TextStyle(
                              fontFamily: AppTypography.fontFamily, 
                              fontWeight: FontWeight.w700, 
                              fontSize: 12, 
                              color: AppColors.inkSubtle
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Padding(padding: EdgeInsets.symmetric(vertical: 16.0), child: Divider(color: AppColors.hairline, height: 1)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly, 
            children: [
              _buildRectCountLight('BALL', sb.balls, 3, AppColors.primary),       
              _buildRectCountLight('STRIKE', sb.strikes, 2, Colors.redAccent),   
              _buildRectCountLight('OUT', sb.outs, 2, Colors.orangeAccent),       
            ],
          ),
        ],
      ),
    );
  }

  /// 그라데이션이 들어간 원형 팀 로고 이니셜 엠블럼을 생성합니다.
  Widget _buildTeamEmblem(String teamName) {
    final String initial = teamName.isNotEmpty ? teamName[0].toUpperCase() : 'T';
    final bool isAway = teamName.contains('HOU') || teamName.contains('휴스턴') || teamName.contains('다이노스'); 
    final List<Color> gradientColors = isAway
        ? [const Color(0xFF0F3A5F), const Color(0xFF2E7B9D)]
        : [const Color(0xFF6E0D25), const Color(0xFF9B113B)];

    return Container(
      width: 48.0, height: 48.0,
      decoration: BoxDecoration(
        shape: BoxShape.circle, 
        gradient: LinearGradient(colors: gradientColors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        border: Border.all(color: AppColors.hairlineStrong, width: 2.0), 
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Center(child: Text(initial, style: const TextStyle(fontFamily: AppTypography.fontFamily, fontWeight: FontWeight.w700, fontSize: 18.0, color: AppColors.ink))),
    );
  }

  /// 사각형 형태의 세련된 볼카운트 인디케이터 점등 램프를 드로잉합니다.
  Widget _buildRectCountLight(String label, int activeCount, int totalCount, Color activeColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(fontFamily: AppTypography.fontFamily, fontWeight: FontWeight.w500, fontSize: 10, color: AppColors.inkSubtle, letterSpacing: 0.5)),
        const SizedBox(height: 8.0),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(totalCount, (i) {
            final bool isActive = i < activeCount; 
            return Container(
              margin: EdgeInsets.only(left: i == 0 ? 0.0 : 4.0, right: i == totalCount - 1 ? 0.0 : 4.0),
              width: 24, height: 10, 
              decoration: BoxDecoration(color: isActive ? activeColor : AppColors.surface3, borderRadius: BorderRadius.circular(2.0), border: Border.all(color: AppColors.hairline)),
            );
          }),
        ),
      ],
    );
  }

  /// 오늘의 수훈 MVP 투표 패널
  Widget _buildUserPollPanel() {
    final options = const ['김대한 (서울 다이노스)', '류현진 (한화 이글스)', '기타 선수'];
    final int total = _pollVotes.reduce((a, b) => a + b);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: AppColors.hairline),
      ),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('오늘의 경기 실시간 투표', style: TextStyle(fontFamily: AppTypography.fontFamily, fontWeight: FontWeight.w700, fontSize: 14.0, color: AppColors.ink)),
          const SizedBox(height: 2.0),
          const Text('가장 뛰어난 활약을 펼친 오늘의 MVP는?', style: TextStyle(fontFamily: AppTypography.fontFamily, fontSize: 11.0, color: AppColors.inkTertiary)),
          const SizedBox(height: 16.0),
          ...List.generate(options.length, (idx) {
            final double pct = total > 0 ? _pollVotes[idx] / total : 0;
            final bool isSelected = _selectedPollIndex == idx;
            return Container(
              margin: const EdgeInsets.only(bottom: 10.0),
              child: InkWell(
                onTap: () => _submitVote(idx),
                borderRadius: BorderRadius.circular(8.0),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: pct,
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primary.withOpacity(0.3) : AppColors.surface2,
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                      decoration: BoxDecoration(
                        border: Border.all(color: isSelected ? AppColors.primary : AppColors.hairline),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              options[idx],
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: AppTypography.fontFamily,
                                fontSize: 12.0,
                                fontWeight: isSelected ? FontWeight.w500 : FontWeight.w300,
                                color: isSelected ? AppColors.ink : AppColors.inkMuted,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8.0),
                          Text(
                            '${(pct * 100).toStringAsFixed(0)}% (${_pollVotes[idx]}표)',
                            style: TextStyle(
                              fontFamily: AppTypography.fontFamily,
                              fontSize: 11.0,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? AppColors.primaryHover : AppColors.inkSubtle,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// =============================================================
// [FieldVisualizerWidget] 필드 주자 배치 시각화 위젯
//
// 호버 상태를 내부 상태로 관리하여 마우스 이동 시 이 위젯만 재빌드됩니다.
// RepaintBoundary로 CustomPaint를 감싸 불필요한 캔버스 재페인트를 방지합니다.
// =============================================================
class FieldVisualizerWidget extends StatefulWidget {
  final FieldAndPitchInfo fp;
  const FieldVisualizerWidget({super.key, required this.fp});
  @override
  State<FieldVisualizerWidget> createState() => _FieldVisualizerWidgetState();
}

class _FieldVisualizerWidgetState extends State<FieldVisualizerWidget> {
  int? _hoveredSprayPointIndex;
  int? _hoveredBaseIndex;

  String _getRunnerStatusText(FieldAndPitchInfo fp) {
    final bool r1 = fp.runner1b == 1;
    final bool r2 = fp.runner2b == 1;
    final bool r3 = fp.runner3b == 1;
    if (r1 && r2 && r3) return '만루 상황 (1, 2, 3루 점유)';
    if (r1 && r2) return '1, 2루 주자 점유';
    if (r2 && r3) return '득점권 (2, 3루 점유)';
    if (r1 && r3) return '1, 3루 주자 점유';
    if (r1) return '1루 주자 출루';
    if (r2) return '득점권 (2루 주자 출루)';
    if (r3) return '득점권 (3루 주자 출루)';
    return '주자 없음';
  }

  Widget _buildBaseRunnerTooltip(int baseIndex, FieldAndPitchInfo fp, Size constraintsSize) {
    String runnerName = "";
    String baseLabel = "";
    if (baseIndex == 1) { runnerName = fp.runner1bName.isNotEmpty ? fp.runner1bName : "1루 주자"; baseLabel = "1루 주자"; }
    else if (baseIndex == 2) { runnerName = fp.runner2bName.isNotEmpty ? fp.runner2bName : "2루 주자"; baseLabel = "2루 주자"; }
    else if (baseIndex == 3) { runnerName = fp.runner3bName.isNotEmpty ? fp.runner3bName : "3루 주자"; baseLabel = "3루 주자"; }
    final double w = constraintsSize.width;
    final double h = constraintsSize.height;
    final Offset home = Offset(w / 2, h - 20);
    final double fieldRadius = (h - 40);
    Offset polarToCartesian(double angleDeg, double distanceFeet) {
      final double angleRad = (angleDeg - 90) * math.pi / 180.0;
      final double r = (distanceFeet / 420.0) * fieldRadius;
      return Offset(home.dx + r * math.cos(angleRad), home.dy + r * math.sin(angleRad));
    }
    Offset baseOffset;
    if (baseIndex == 1) { baseOffset = polarToCartesian(45, 90); }
    else if (baseIndex == 2) { baseOffset = polarToCartesian(0, 127.28); }
    else { baseOffset = polarToCartesian(-45, 90); }
    final double px = baseOffset.dx;
    final double py = baseOffset.dy;
    const double tooltipHeight = 55.0;
    const double tooltipWidth = 160.0;
    double leftPos = px - (tooltipWidth / 2);
    double topPos = py - tooltipHeight - 12.0;
    if (leftPos < -20.0) leftPos = -20.0;
    if (leftPos + tooltipWidth > w + 20.0) leftPos = w + 20.0 - tooltipWidth;
    if (topPos < 0) topPos = py + 12.0;
    return Positioned(
      left: leftPos, top: topPos,
      child: IgnorePointer(
        child: Container(
          width: tooltipWidth, height: tooltipHeight,
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E24).withOpacity(0.90),
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(color: Colors.orangeAccent.withOpacity(0.5), width: 1.0),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 6, offset: const Offset(0, 3))],
          ),
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(baseLabel, style: const TextStyle(fontFamily: AppTypography.fontFamily, fontSize: 10.0, fontWeight: FontWeight.w500, color: Colors.orangeAccent)),
              const SizedBox(height: 3.0),
              Text(runnerName, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: AppTypography.fontFamily, fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSprayHoverTooltip(SprayPoint p, Size constraintsSize) {
    Color color;
    String outcomeText = p.eventDescription.isNotEmpty ? p.eventDescription : '타석 결과';
    String headerText = '${p.batterName} ($outcomeText)';
    if (p.type == 'HIT') { color = const Color(0xFF27A644); }
    else if (p.type == 'HR') { color = Colors.orangeAccent; }
    else { color = AppColors.inkSubtle; }
    final double w = constraintsSize.width;
    final double h = constraintsSize.height;
    final Offset home = Offset(w / 2, h - 20);
    final double fieldRadius = (h - 40);
    Offset polarToCartesian(double angleDeg, double distanceFeet) {
      final double angleRad = (angleDeg - 90) * math.pi / 180.0;
      final double r = (distanceFeet / 420.0) * fieldRadius;
      return Offset(home.dx + r * math.cos(angleRad), home.dy + r * math.sin(angleRad));
    }
    final Offset projectedOffset = polarToCartesian(p.angle, p.distance);
    final double px = projectedOffset.dx;
    final double py = projectedOffset.dy;
    String speedText = p.launchSpeed > 0 ? '${(p.launchSpeed * 1.60934).toStringAsFixed(1)} km/h (${p.launchSpeed.toStringAsFixed(1)} mph)' : '구속 정보 없음';
    String angleText = '${p.launchAngle.toStringAsFixed(1)}°';
    String distanceText = p.distance > 0 ? '${p.distance.toInt()} ft (${(p.distance * 0.3048).toStringAsFixed(1)} m)' : '비거리 정보 없음';
    final bool isDetailed = p.launchSpeed > 0 || p.distance > 0;
    final double tooltipHeight = isDetailed ? 160.0 : (p.pitchNumber > 0 ? 80.0 : 55.0);
    const double tooltipWidth = 280.0;
    double leftPos = px - (tooltipWidth / 2);
    double topPos = py - tooltipHeight - 12.0;
    if (leftPos < -20.0) { leftPos = -20.0; } else if (leftPos + tooltipWidth > w + 20.0) { leftPos = w + 20.0 - tooltipWidth; }
    if (topPos < 0) { topPos = py + 12.0; }
    if (topPos + tooltipHeight > h + 20.0) { topPos = h + 20.0 - tooltipHeight; }
    return Positioned(
      left: leftPos, top: topPos,
      child: IgnorePointer(
        child: Container(
          width: tooltipWidth, height: tooltipHeight,
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E24).withOpacity(0.90),
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(color: Colors.white24, width: 1.0),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 8, offset: const Offset(0, 4))],
          ),
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                        const SizedBox(width: 6.0),
                        Expanded(child: Text(headerText, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: AppTypography.fontFamily, fontSize: 13.0, fontWeight: FontWeight.w800, color: Colors.white))),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4.0),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20.0)),
                    child: Text(p.type, style: const TextStyle(fontFamily: AppTypography.fontFamily, fontSize: 9.0, fontWeight: FontWeight.w900, color: Colors.white)),
                  ),
                ],
              ),
              if (p.pitchNumber > 0) ...[
                const SizedBox(height: 10.0),
                Row(children: [
                  const Icon(Icons.sports_baseball, size: 11.0, color: Colors.white54),
                  const SizedBox(width: 6.0),
                  const Text('타격 시점: ', style: TextStyle(fontFamily: AppTypography.fontFamily, fontSize: 10.5, fontWeight: FontWeight.w500, color: Colors.white70)),
                  Text('타석 ${p.pitchNumber}구째', style: const TextStyle(fontFamily: AppTypography.fontFamily, fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white)),
                ]),
              ],
              if (isDetailed) ...[
                const SizedBox(height: 6.0),
                Row(children: [const Icon(Icons.straighten, size: 11.0, color: Colors.white54), const SizedBox(width: 6.0), const Text('비거리: ', style: TextStyle(fontFamily: AppTypography.fontFamily, fontSize: 10.5, fontWeight: FontWeight.w500, color: Colors.white70)), Text(distanceText, style: const TextStyle(fontFamily: AppTypography.fontFamily, fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white))]),
                const SizedBox(height: 6.0),
                Row(children: [const Icon(Icons.speed, size: 11.0, color: Colors.white54), const SizedBox(width: 6.0), const Text('타구 속도: ', style: TextStyle(fontFamily: AppTypography.fontFamily, fontSize: 10.5, fontWeight: FontWeight.w500, color: Colors.white70)), Text(speedText, style: const TextStyle(fontFamily: AppTypography.fontFamily, fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white))]),
                const SizedBox(height: 6.0),
                Row(children: [const Icon(Icons.navigation, size: 11.0, color: Colors.white54), const SizedBox(width: 6.0), const Text('발사각: ', style: TextStyle(fontFamily: AppTypography.fontFamily, fontSize: 10.5, fontWeight: FontWeight.w500, color: Colors.white70)), Text(angleText, style: const TextStyle(fontFamily: AppTypography.fontFamily, fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white))]),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fp = widget.fp;
    return Container(
      height: 360,
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: AppColors.hairline),
      ),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('실시간 필드 정보 시각화', style: TextStyle(fontFamily: AppTypography.fontFamily, fontWeight: FontWeight.w700, fontSize: 14.0, color: AppColors.ink)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
                decoration: BoxDecoration(
                  color: (fp.runner1b == 1 || fp.runner2b == 1 || fp.runner3b == 1) ? Colors.orangeAccent.withOpacity(0.15) : AppColors.surface3,
                  borderRadius: BorderRadius.circular(4.0),
                  border: Border.all(color: (fp.runner1b == 1 || fp.runner2b == 1 || fp.runner3b == 1) ? Colors.orangeAccent.withOpacity(0.5) : AppColors.hairline),
                ),
                child: Text(
                  _getRunnerStatusText(fp),
                  style: TextStyle(fontFamily: AppTypography.fontFamily, fontSize: 10.0, fontWeight: FontWeight.bold, color: (fp.runner1b == 1 || fp.runner2b == 1 || fp.runner3b == 1) ? Colors.orangeAccent : AppColors.inkSubtle),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2.0),
          Text('누적 탄착군 구종 수: ${fp.pitchCoordinates.length}개 렌더링 중', style: const TextStyle(fontFamily: AppTypography.fontFamily, fontWeight: FontWeight.w300, fontSize: 11.0, color: AppColors.primaryHover)),
          const SizedBox(height: 20.0),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double w = constraints.maxWidth;
                final double h = constraints.maxHeight;
                final Size sizeLimit = Size(w, h);
                final Offset home = Offset(w / 2, h - 20);
                final double fieldRadius = h - 40;
                Offset polarToCartesian(double angleDeg, double distanceFeet) {
                  final double angleRad = (angleDeg - 90) * math.pi / 180.0;
                  final double r = (distanceFeet / 420.0) * fieldRadius;
                  return Offset(home.dx + r * math.cos(angleRad), home.dy + r * math.sin(angleRad));
                }
                return MouseRegion(
                  onHover: (event) {
                    final Offset fb = polarToCartesian(45, 90);
                    final Offset sb = polarToCartesian(0, 127.28);
                    final Offset tb = polarToCartesian(-45, 90);
                    int? hoveredBase;
                    if ((fb - event.localPosition).distance <= 15.0 && fp.runner1b == 1) { hoveredBase = 1; }
                    else if ((sb - event.localPosition).distance <= 15.0 && fp.runner2b == 1) { hoveredBase = 2; }
                    else if ((tb - event.localPosition).distance <= 15.0 && fp.runner3b == 1) { hoveredBase = 3; }
                    if (hoveredBase != null) {
                      if (_hoveredBaseIndex != hoveredBase || _hoveredSprayPointIndex != null) {
                        setState(() { _hoveredBaseIndex = hoveredBase; _hoveredSprayPointIndex = null; });
                      }
                      return;
                    }
                    int? hoveredIndex;
                    for (int i = 0; i < fp.sprayPoints.length; i++) {
                      final sp = fp.sprayPoints[i];
                      final pt = polarToCartesian(sp.angle, sp.distance);
                      if ((pt - event.localPosition).distance <= 12.0) { hoveredIndex = i; break; }
                    }
                    if (_hoveredSprayPointIndex != hoveredIndex || _hoveredBaseIndex != null) {
                      setState(() { _hoveredSprayPointIndex = hoveredIndex; _hoveredBaseIndex = null; });
                    }
                  },
                  onExit: (event) {
                    setState(() { _hoveredSprayPointIndex = null; _hoveredBaseIndex = null; });
                  },
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: RepaintBoundary(
                          child: CustomPaint(
                            painter: FieldStatePainter(
                              runner1b: fp.runner1b == 1,
                              runner2b: fp.runner2b == 1,
                              runner3b: fp.runner3b == 1,
                              sprayPoints: fp.sprayPoints,
                            ),
                          ),
                        ),
                      ),
                      if (_hoveredSprayPointIndex != null && _hoveredSprayPointIndex! < fp.sprayPoints.length)
                        _buildSprayHoverTooltip(fp.sprayPoints[_hoveredSprayPointIndex!], sizeLimit),
                      if (_hoveredBaseIndex != null)
                        _buildBaseRunnerTooltip(_hoveredBaseIndex!, fp, sizeLimit),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================
// [AICasterPanelWidget] AI 캐스터 해설 패널 위젯
// =============================================================
class AICasterPanelWidget extends StatelessWidget {
  final AiCommentary ai;
  final ScoreBoardInfo sb;
  final bool isTtsPlaying;
  final VoidCallback onTtsToggle;

  const AICasterPanelWidget({
    super.key,
    required this.ai,
    required this.sb,
    required this.isTtsPlaying,
    required this.onTtsToggle,
  });

  Widget _buildLiveDot() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _LiveBlinkingDot(),
        const SizedBox(width: 5.0),
        const Text('LIVE', style: TextStyle(fontFamily: AppTypography.fontFamily, fontSize: 9.0, fontWeight: FontWeight.bold, color: Colors.redAccent, letterSpacing: 0.5)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final commentaries = [
      {'category': '경기 흐름 분석', 'icon': Icons.trending_up, 'text': ai.analysis, 'color': AppColors.primaryHover},
      {'category': '다음 투구 예상', 'icon': Icons.sports_baseball, 'text': ai.pitching, 'color': Colors.orangeAccent},
      {'category': '타석 결과 예상', 'icon': Icons.sports_cricket, 'text': ai.record, 'color': Colors.cyanAccent},
    ];
    return Container(
      decoration: BoxDecoration(color: AppColors.surface1, borderRadius: BorderRadius.circular(12.0), border: Border.all(color: AppColors.hairline)),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── 1. 헤더 영역 (AI 캐스터 중계 타이틀 + LIVE Dot + TTS 토글 버튼) ──
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: AppColors.primaryHover, size: 18),
              const SizedBox(width: 8.0),
              const Text('AI 캐스터 중계', style: TextStyle(fontFamily: AppTypography.fontFamily, fontWeight: FontWeight.w700, fontSize: 14.0, color: AppColors.ink)),
              const SizedBox(width: 8.0),
              _buildLiveDot(),
              const Spacer(),
              InkWell(
                onTap: () {
                  onTtsToggle();
                  ScaffoldMessenger.of(context).clearSnackBars();
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    backgroundColor: AppColors.surface3,
                    duration: const Duration(seconds: 2),
                    content: Text(!isTtsPlaying ? '🎙️ AI 캐스터의 실시간 음성 중계를 켭니다.' : '🔇 AI 캐스터 음성 중계를 끕니다.', style: const TextStyle(fontFamily: AppTypography.fontFamily, color: AppColors.ink, fontSize: 12.0)),
                  ));
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
                  decoration: BoxDecoration(
                    color: isTtsPlaying ? AppColors.primary.withOpacity(0.15) : AppColors.surface3,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isTtsPlaying ? AppColors.primaryHover : AppColors.hairline),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(isTtsPlaying ? Icons.volume_up : Icons.volume_off, color: isTtsPlaying ? AppColors.primaryHover : AppColors.inkSubtle, size: 14),
                      const SizedBox(width: 6.0),
                      SoundWaveVisualizer(isPlaying: isTtsPlaying),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20.0),

          // ── 2. 본문 영역 분기 처리 ──
          if (ai.hasError)...[
            // ⚠️ [에러 시 렌더링할 배너 카드]
            Container(
              padding: const EdgeInsets.symmetric(vertical: 32.0, horizontal: 16.0),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10.0),
                border: Border.all(color: Colors.redAccent.withOpacity(0.2)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.error_outline, color: Colors.redAccent, size: 28.0),
                  const SizedBox(height: 12.0),
                  const Text(
                    'AI 예측 분석 시스템 오프라인',
                    style: TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontWeight: FontWeight.bold,
                      fontSize: 13.0,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 6.0),
                  Text(
                    '현재 FastAPI 예측 분석 서버와의 연결이 원활하지 않습니다.\n복구 작업을 진행 중이오니 잠시 후 이용해 주세요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontSize: 11.0,
                      color: AppColors.inkSubtle,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
                      Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [AppColors.primary.withOpacity(0.3), Colors.cyanAccent.withOpacity(0.15)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  border: Border.all(color: AppColors.primary, width: 1.5),
                  boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.2), blurRadius: 8, spreadRadius: 1)],
                ),
                child: const Center(child: Icon(Icons.mic, color: AppColors.ink, size: 20)),
              ),
              const SizedBox(width: 12.0),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Text('AI 캐스터', style: TextStyle(fontFamily: AppTypography.fontFamily, fontWeight: FontWeight.bold, fontSize: 13.0, color: AppColors.ink)),
                    const SizedBox(width: 6.0),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(4.0)),
                      child: const Text('🤖 AI', style: TextStyle(fontFamily: AppTypography.fontFamily, fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ]),
                  const SizedBox(height: 3.0),
                  const Text('실시간 야구 분석 엔진 가동 중', style: TextStyle(fontFamily: AppTypography.fontFamily, fontSize: 10.5, color: AppColors.inkSubtle)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16.0),
          ...commentaries.map((c) {
            return Container(
              margin: const EdgeInsets.only(bottom: 16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 8.0),
                    padding: const EdgeInsets.all(6.0),
                    decoration: BoxDecoration(color: (c['color'] as Color).withOpacity(0.1), shape: BoxShape.circle),
                    child: Icon(c['icon'] as IconData, color: c['color'] as Color, size: 14),
                  ),
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                          decoration: BoxDecoration(
                            color: AppColors.surface2,
                            borderRadius: const BorderRadius.only(topLeft: Radius.zero, topRight: Radius.circular(12.0), bottomLeft: Radius.circular(12.0), bottomRight: Radius.circular(12.0)),
                            border: Border.all(color: AppColors.hairline),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(c['category'] as String, style: TextStyle(fontFamily: AppTypography.fontFamily, fontSize: 10.0, fontWeight: FontWeight.bold, color: c['color'] as Color)),
                              const SizedBox(height: 6.0),
                              TypewriterText(
                                text: c['text'] as String,
                                style: const TextStyle(fontFamily: AppTypography.fontFamily, fontSize: 12.0, color: AppColors.inkMuted, height: 1.4),
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          left: -6, top: 8,
                          child: CustomPaint(painter: BubbleTailPainter(color: AppColors.surface2, borderColor: AppColors.hairline), size: const Size(6, 8)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
            }),
          ] 
        ],
      ),
    );
  }
}

// =============================================================
// [StandingsPanelWidget] 시즌 순위표 패널 위젯
// =============================================================
class StandingsPanelWidget extends StatelessWidget {
  final List<SeasonStanding> standings;
  final bool isLoading;
  const StandingsPanelWidget({super.key, required this.standings, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: AppColors.surface1, borderRadius: BorderRadius.circular(12.0), border: Border.all(color: AppColors.hairline)),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('시즌 순위표', style: TextStyle(fontFamily: AppTypography.fontFamily, fontWeight: FontWeight.w700, fontSize: 14.0, color: AppColors.ink)),
          const SizedBox(height: 16.0),
          if (standings.isEmpty)
            SizedBox(
              height: 200,
              child: Center(
                child: isLoading
                    ? const CircularProgressIndicator(color: AppColors.primaryHover)
                    : const Text('시즌 순위 데이터가 없습니다.', style: TextStyle(color: AppColors.inkSubtle, fontSize: 12)),
              ),
            )
          else
            SizedBox(
              height: 380,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Table(
                  columnWidths: const { 0: FixedColumnWidth(28.0), 1: FlexColumnWidth(), 2: FixedColumnWidth(40.0), 3: FixedColumnWidth(44.0) },
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  children: [
                    const TableRow(
                      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.hairline))),
                      children: [
                        TableCell(child: Padding(padding: EdgeInsets.symmetric(vertical: 8.0), child: Text('순위', style: TextStyle(color: AppColors.inkSubtle, fontSize: 11)))),
                        TableCell(child: Padding(padding: EdgeInsets.symmetric(vertical: 8.0), child: Text('팀명', style: TextStyle(color: AppColors.inkSubtle, fontSize: 11)))),
                        TableCell(child: Padding(padding: EdgeInsets.symmetric(vertical: 8.0), child: Text('승률', style: TextStyle(color: AppColors.inkSubtle, fontSize: 11)))),
                        TableCell(child: Padding(padding: EdgeInsets.symmetric(vertical: 8.0), child: Text('최근', style: TextStyle(color: AppColors.inkSubtle, fontSize: 11)))),
                      ],
                    ),
                    ...standings.map((s) {
                      final bool isTop = s.rank == 1;
                      return TableRow(
                        children: [
                          TableCell(child: Padding(padding: const EdgeInsets.symmetric(vertical: 10.0), child: Text('${s.rank}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.0, color: isTop ? AppColors.primaryHover : AppColors.inkMuted)))),
                          TableCell(child: Padding(padding: const EdgeInsets.symmetric(vertical: 10.0), child: Text(s.teamName, style: const TextStyle(fontSize: 12.0, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis))),
                          TableCell(child: Padding(padding: const EdgeInsets.symmetric(vertical: 10.0), child: Text(s.winRate, style: const TextStyle(fontSize: 12.0, color: AppColors.inkMuted)))),
                          TableCell(child: Padding(padding: const EdgeInsets.symmetric(vertical: 10.0), child: Text(s.streak, style: TextStyle(fontSize: 11.0, color: s.streak.contains('승') ? AppColors.success : Colors.redAccent)))),
                        ],
                      );
                    }).toList(),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}


/// 내야 다이아몬드 지면 및 1, 2, 3루 주자 점유 상황을 2D 그래픽 캔버스로 매핑하는 CustomPainter 클래스입니다.
class FieldStatePainter extends CustomPainter {
  final bool runner1b;
  final bool runner2b;
  final bool runner3b;
  final List<SprayPoint> sprayPoints;

  FieldStatePainter({
    required this.runner1b,
    required this.runner2b,
    required this.runner3b,
    required this.sprayPoints,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // 홈 플레이트의 기준 2D 픽셀 좌표 (캔버스 가로 중앙 및 하단)
    final Offset home = Offset(w / 2, h - 20);

    // 야구장 펜스 최대 비거리인 420ft를 화면 캔버스 상 반지름 크기로 변환하는 스케일링 상숫값
    final double fieldRadius = (h - 40);

    /// 극좌표계(각도, 피트 거리)를 화면 픽셀 좌표 Offset(dx, dy)로 정밀 변환하는 삼각함수 매핑 메소드입니다.
    Offset polarToCartesian(double angleDeg, double distanceFeet) {
      // 0도 선이 하늘 방향(정중앙 외야)이므로 플러터 캔버스 삼각법(오른쪽 동쪽이 0도 시작)과 맞추기 위해 90도를 감산합니다.
      final double angleRad = (angleDeg - 90) * math.pi / 180.0;
      
      // 비거리에 상응하는 화면 비율 반경 계산
      final double r = (distanceFeet / 420.0) * fieldRadius;

      // X = R * cos(theta), Y = R * sin(theta) 극좌표 변환식 적용
      final double x = home.dx + r * math.cos(angleRad);
      final double y = home.dy + r * math.sin(angleRad);

      return Offset(x, y);
    }

    // 1. 외야 잔디 부채꼴 채우기 (다크 그린 잔디 칼라)
    final grassPaint = Paint()
      ..color = const Color(0xFF0D251C).withOpacity(0.4)
      ..style = PaintingStyle.fill;

    final fieldOutlinePath = Path()..moveTo(home.dx, home.dy);

    // 좌익수 파울라인 담장 끝점 (325ft 위치)
    final leftLineEnd = polarToCartesian(-45, 325);
    fieldOutlinePath.lineTo(leftLineEnd.dx, leftLineEnd.dy);

    // 외야 담장 펜스 라인 그리기 (부채꼴 아치형 담장 생성)
    for (double a = -45; a <= 45; a += 5) {
      final double factor = math.cos(a * math.pi / 180.0);
      final double wallDist = 325 + 75 * factor; // 중앙(0도) 기준 최대 400ft 연장
      final pt = polarToCartesian(a, wallDist);
      fieldOutlinePath.lineTo(pt.dx, pt.dy);
    }

    // 우익수 파울라인 담장 끝점 (325ft 위치)
    final rightLineEnd = polarToCartesian(45, 325);
    fieldOutlinePath.lineTo(rightLineEnd.dx, rightLineEnd.dy);
    fieldOutlinePath.close(); // 홈플레이트 시작점으로 클로즈하여 그라운드 영역 패스 조립 완료

    canvas.drawPath(fieldOutlinePath, grassPaint);

    // 야구장 외곽 경계선 드로잉
    final borderPaint = Paint()
      ..color = AppColors.hairline
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawPath(fieldOutlinePath, borderPaint);

    // 2. 내야 흙 다이아몬드 (Infield Dirt) 드로잉
    final Offset firstBase = polarToCartesian(45, 90);
    final Offset secondBase = polarToCartesian(0, 127.28);
    final Offset thirdBase = polarToCartesian(-45, 90);

    final dirtPaint = Paint()
      ..color = const Color(0xFF2C251F).withOpacity(0.7) // 적토 흙빛 컬러
      ..style = PaintingStyle.fill;

    final infieldPath = Path()
      ..moveTo(home.dx, home.dy)
      ..lineTo(firstBase.dx, firstBase.dy)
      ..lineTo(secondBase.dx, secondBase.dy)
      ..lineTo(thirdBase.dx, thirdBase.dy)
      ..close();

    canvas.drawPath(infieldPath, dirtPaint);
    canvas.drawPath(infieldPath, borderPaint);

    // 투수 마운드 원형 마킹 드로잉 (홈에서 60.5ft 거리)
    final moundPos = polarToCartesian(0, 60.5);
    canvas.drawCircle(
      moundPos,
      6.0,
      Paint()
        ..color = const Color(0xFF2C251F)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(moundPos, 6.0, borderPaint);

    // 외야 경계 워닝 트랙(Warning Track) 보조 드로잉
    final warningTrackPaint = Paint()
      ..color = AppColors.hairline.withOpacity(0.3)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    
    final warningPath = Path();
    for (double a = -45; a <= 45; a += 5) {
      final double factor = math.cos(a * math.pi / 180.0);
      final double trackDist = 310 + 70 * factor; // 외벽 펜스보다 15ft 안쪽에 위치
      final pt = polarToCartesian(a, trackDist);
      if (a == -45) {
        warningPath.moveTo(pt.dx, pt.dy);
      } else {
        warningPath.lineTo(pt.dx, pt.dy);
      }
    }
    canvas.drawPath(warningPath, warningTrackPaint);

    /// 각 베이스 사각형을 45도 회전 꼬아 정해진 지점에 렌더링하는 함수
    void drawBaseBox(Offset center, bool runnerOn) {
      canvas.save(); 
      canvas.translate(center.dx, center.dy); 
      canvas.rotate(math.pi / 4); // 45도 회전변화

      final Rect rect = Rect.fromCenter(center: Offset.zero, width: 12, height: 12);
      
      canvas.drawRect(
        rect,
        Paint()
          ..color = runnerOn ? Colors.orangeAccent : AppColors.surface2
          ..style = PaintingStyle.fill,
      );
      canvas.drawRect(
        rect,
        Paint()
          ..color = runnerOn ? Colors.orangeAccent : AppColors.hairline
          ..strokeWidth = 1.0
          ..style = PaintingStyle.stroke,
      );

      // 주자가 점유 중일 시 아우라 발광 오렌지 외벽 오버그리기 추가
      if (runnerOn) {
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: 18, height: 18),
          Paint()
            ..color = Colors.orangeAccent.withOpacity(0.3)
            ..strokeWidth = 1.0
            ..style = PaintingStyle.stroke,
        );
      }

      canvas.restore(); 
    }

    drawBaseBox(home, false);      
    drawBaseBox(firstBase, runner1b);  
    drawBaseBox(secondBase, runner2b); 
    drawBaseBox(thirdBase, runner3b);  

    // 3. 개별 타구 결과 마커 흩뿌리기
    for (final p in sprayPoints) {
      final Offset pt = polarToCartesian(p.angle, p.distance);

      Color color;
      if (p.type == 'HIT') {
        color = const Color(0xFF27A644); // 안타: 그린
      } else if (p.type == 'HR') {
        color = Colors.orangeAccent;      // 홈런: 오렌지
      } else {
        color = AppColors.inkSubtle;     // 범타/아웃: 그레이
      }

      final dotPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(pt, 5.0, dotPaint);

      // 아웃이 아닌 정상 안타/홈런인 경우 점 복판에 입체성을 주기 위한 흰색 링 코어 추가
      if (p.type != 'OUT') {
        canvas.drawCircle(
          pt,
          5.0,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant FieldStatePainter oldDelegate) {
    if (oldDelegate.runner1b != runner1b ||
        oldDelegate.runner2b != runner2b ||
        oldDelegate.runner3b != runner3b) return true;
    if (oldDelegate.sprayPoints.length != sprayPoints.length) return true;
    // 마지막 타구의 pitchNumber까지 비교하여 내용 변경 여부 정밀 감지 (O(1))
    if (sprayPoints.isNotEmpty &&
        oldDelegate.sprayPoints.isNotEmpty &&
        oldDelegate.sprayPoints.last.pitchNumber != sprayPoints.last.pitchNumber) {
      return true;
    }
    return false;
  }
}

// -------------------------------------------------------------
// [AI Caster UI Helper Widgets]
// -------------------------------------------------------------

/// 타이핑 효과 텍스트 위젯 (AnimationController 기반)
///
/// 기존 Timer.periodic + setState 방식에서 AnimationController + AnimatedBuilder 방식으로 교체.
/// setState를 전혀 사용하지 않고 Flutter 렌더 파이프라인 내부 애니메이션 루프만 활용합니다.
class TypewriterText extends StatefulWidget {
  final String text;
  final TextStyle style;
  /// 글자당 표시 시간 (기본 30ms)
  final Duration duration;

  const TypewriterText({
    super.key,
    required this.text,
    required this.style,
    this.duration = const Duration(milliseconds: 30),
  });

  @override
  State<TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<TypewriterText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _calcDuration(widget.text),
    )..forward();
  }

  @override
  void didUpdateWidget(TypewriterText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      // 텍스트 변경 시 애니메이션 재시작
      _controller.duration = _calcDuration(widget.text);
      _controller.reset();
      _controller.forward();
    }
  }

  Duration _calcDuration(String text) {
    final int ms = text.isEmpty ? 1 : text.length * widget.duration.inMilliseconds;
    return Duration(milliseconds: ms);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        // AnimationController 진행도(0.0~1.0)로 현재까지 표시할 글자 수 계산
        final int charCount = (_controller.value * widget.text.length).floor();
        return Text(
          widget.text.substring(0, charCount.clamp(0, widget.text.length)),
          style: widget.style,
        );
      },
    );
  }

}

class SoundWaveVisualizer extends StatefulWidget {
  final bool isPlaying;
  const SoundWaveVisualizer({super.key, required this.isPlaying});

  @override
  State<SoundWaveVisualizer> createState() => _SoundWaveVisualizerState();
}

class _SoundWaveVisualizerState extends State<SoundWaveVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<double> _heightMultiplier = [0.3, 0.9, 0.5, 0.7];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    
    if (widget.isPlaying) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(SoundWaveVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying) {
      if (!_controller.isAnimating) {
        _controller.repeat(reverse: true);
      }
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: List.generate(4, (index) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            double currentHeight = 3.0;
            if (widget.isPlaying) {
              final double value = math.sin(_controller.value * math.pi + (index * 0.5));
              currentHeight = 3.0 + (value.abs() * 10.0 * _heightMultiplier[index]);
            }
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 1.0),
              width: 2.0,
              height: currentHeight,
              decoration: BoxDecoration(
                color: widget.isPlaying ? AppColors.primaryHover : AppColors.inkSubtle,
                borderRadius: BorderRadius.circular(1.0),
              ),
            );
          },
        );
      }),
    );
  }
}

class _LiveBlinkingDot extends StatefulWidget {
  const _LiveBlinkingDot();

  @override
  State<_LiveBlinkingDot> createState() => _LiveBlinkingDotState();
}

class _LiveBlinkingDotState extends State<_LiveBlinkingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _animation = Tween<double>(begin: 0.2, end: 1.0).animate(_controller);
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Container(
        width: 6,
        height: 6,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.redAccent,
        ),
      ),
    );
  }
}

class BubbleTailPainter extends CustomPainter {
  final Color color;
  final Color borderColor;

  BubbleTailPainter({required this.color, required this.borderColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final path = Path()
      ..moveTo(size.width, 0)
      ..lineTo(0, 0)
      ..lineTo(size.width, size.height)
      ..close();

    canvas.drawPath(path, paint);

    final borderPath = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..moveTo(0, 0)
      ..lineTo(size.width, size.height);
    canvas.drawPath(borderPath, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
