import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme.dart';
import '../models/game_situation_model.dart';


/// 스트라이크 존 시각화 위젯 (StrikeZoneVisualizer)입니다.
/// 
/// 1. 타율 기반 9격자 핫앤콜드존(Hot & Cold Zone)과
/// 2. 구종별 투구 탄착군 분포를 확인할 수 있는 Pitch Zone 히트맵
/// 두 가지 시각화 모드를 실시간으로 스위칭하여 입체적으로 데이터를 조회할 수 있도록 돕습니다.
class StrikeZoneVisualizer extends StatefulWidget {
  /// 'HITTER'(타자) 또는 'PITCHER'(투수) 대상 역할 구분
  final String playerRole;
  
  /// 모드 전환 탭버튼(9격자 <-> 히트맵)을 상단 우측에 띄울지 여부
  final bool showToggle;
  
  /// 최초 렌더링 시 9격자 타율 모드로 시작할지 여부
  final bool initialGridMode;

  /// 백엔드로부터 주입받는 실제 투구 좌표 데이터 리스트
  final List<PitchCoordinate> pitches;

  /// 현재 투수의 누적 투구수
  final int pitcherPitchCount;

  /// 백엔드로부터 주입받는 9격자 타율 데이터 리스트
  final List<ZoneStat> zoneStats;

  /// 투구 탄착군 마커 호버 시 투구 순서(구째)를 노출할지 여부
  final bool showPitchOrder;

  final bool? isActive;

  final bool isFirstLoad;

  const StrikeZoneVisualizer({
    super.key, 
    required this.playerRole,
    this.showToggle = true,
    this.initialGridMode = true,
    this.pitches = const [],
    this.pitcherPitchCount = 0,
    this.zoneStats = const [],
    this.showPitchOrder = true,
    this.isActive = true,
    this.isFirstLoad = false,
  });

  @override
  State<StrikeZoneVisualizer> createState() => _StrikeZoneVisualizerState();
}

class _StrikeZoneVisualizerState extends State<StrikeZoneVisualizer> 
    with SingleTickerProviderStateMixin {
  /// 현재 시각화 모드 상태값 (true: 9격자 타율 모드, false: 히트맵 탄착군 모드)
  late bool _isGridMode;
  
  /// 마우스가 실시간으로 호버링 중인 격자 인덱스 번호 (1 ~ 9, 없으면 null)
  int? _hoveredZone;

  /// 마우스가 실시간으로 호버링 중인 투구 마커 인덱스 번호 (없으면 null)
  int? _hoveredPitchIndex;

  // 딜레이 렌더링용 피치 리스트 상태
  List<PitchCoordinate> _currentPitches = [];

  // 마지막 투구 착탄 애니메이션 제어
  late AnimationController _pitchAppearController;
  late Animation<double> _pitchScaleAnimation;
  late Animation<double> _pitchOpacityAnimation;

  // 비동기 타이머 관리 (메모리 누수 방지)
  Timer? _delayTimer;

  @override
  void initState() {
    super.initState();
    _isGridMode = widget.initialGridMode;
    
    // 초기 렌더링 시에는 현재 있는 투구 목록 전체를 즉시 복사하여 세팅
    _currentPitches = List.from(_displayPitches);

    _pitchAppearController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _pitchScaleAnimation = Tween<double>(begin: 3.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _pitchAppearController,
        curve: Curves.elasticOut, // 공이 꽂히며 생기는 탄성(바운스) 효과
      ),
    );

    _pitchOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _pitchAppearController,
        curve: Curves.easeIn,
      ),
    );

    // 초기 상태에는 애니메이션 완료 상태로 세팅
    _pitchAppearController.value = 1.0;
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _pitchAppearController.dispose();
    super.dispose();
  }

  /// 부모 위젯이 재구조화되며 상태 파라미터(initialGridMode)를 넘겨주었을 때
  /// 내부 상태값(_isGridMode)을 동기화하기 위한 라이프사이클 구현
  @override
  void didUpdateWidget(StrikeZoneVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    final bool currentActive = widget.isActive ?? true;
    final bool oldActive = oldWidget.isActive ?? true;
    if (currentActive != oldActive) {
      if (!currentActive) {
        _delayTimer?.cancel();
        // 💡 [수정] 단순히 stop()만 하는 게 아니라 value를 원래대로 고정하고 멈춰 
        // 화면 이동 애니메이션 스레드에 영향을 주지 않도록 프리징(Freezing)합니다.
        _pitchAppearController.stop();
        _pitchAppearController.value = 1.0;
      } else {
        if (widget.pitches.isNotEmpty && _currentPitches.length != widget.pitches.length) {
          setState(() {
            _currentPitches = List.from(widget.pitches);
            _pitchAppearController.value = 1.0;
          });
        }
      }
    }

    if (oldWidget.initialGridMode != widget.initialGridMode) {
      _isGridMode = widget.initialGridMode;
    }

    // 신규 투구가 들어왔는지 체크 (길이가 다르거나, 마지막 투구의 순서 번호가 다른 경우)
    final bool hasNewPitch = widget.pitches.length != oldWidget.pitches.length ||
        (widget.pitches.isNotEmpty && oldWidget.pitches.isNotEmpty &&
         widget.pitches.last.pitchNumber != oldWidget.pitches.last.pitchNumber);

    if (hasNewPitch) {
      _delayTimer?.cancel();

      // 💡 [개선] 첫 화면 접속(First Load) 상태라면 쪼개기 렌더링 및 애니메이션을 통째로 생략
      if (widget.isFirstLoad){
        setState(() {
          _currentPitches = List.from(widget.pitches);
          _hoveredPitchIndex = null;
          _pitchAppearController.value = 1.0; // 애니메이션 최종 상태(착탄 완료)로 고정
        });
        return;
      }

      if (widget.pitches.isNotEmpty) {
        // 1단계: 마지막 투구 1개를 제외한 나머지 투구들만 즉시 업데이트하여 화면 일치화
        setState(() {
          _currentPitches = widget.pitches.sublist(0, widget.pitches.length - 1);
          _hoveredPitchIndex = null;
        });

        // 2단계: 0ms 후에 마지막 투구를 추가하며 착탄 애니메이션 실행 (1초 동안 비행/착탄)
        _delayTimer = Timer(Duration.zero, () {
          if (!mounted) return;

          setState(() {
            _currentPitches = List.from(widget.pitches);
          });

          _pitchAppearController.reset();
          _pitchAppearController.forward();
        });
      } else {
        setState(() {
          _currentPitches = [];
        });
      }
    } else {
      // 투구 개수 변동이 없을 때는 상태 리스트와 동기화만 유지
      if (widget.pitches.isNotEmpty && _currentPitches.length != widget.pitches.length) {
        setState(() {
          _currentPitches = List.from(widget.pitches);
        });
      }
    }
  }

  // 데모용 타자 데이터셋 (격자별 안타 수 / 타수 / 타율)
  final List<ZoneStat> _batterStats = [
    ZoneStat(zone: 1, avg: 0.182, count: 4, total: 22),
    ZoneStat(zone: 2, avg: 0.143, count: 3, total: 21),
    ZoneStat(zone: 3, avg: 0.190, count: 4, total: 21),
    ZoneStat(zone: 4, avg: 0.125, count: 2, total: 16),
    ZoneStat(zone: 5, avg: 0.250, count: 7, total: 28),
    ZoneStat(zone: 6, avg: 0.208, count: 5, total: 24),
    ZoneStat(zone: 7, avg: 0.318, count: 7, total: 22),
    ZoneStat(zone: 8, avg: 0.375, count: 9, total: 24),
    ZoneStat(zone: 9, avg: 0.285, count: 6, total: 61),
  ];

  // 데모용 투수 피안타 데이터셋
  final List<ZoneStat> _pitcherStats = [
    ZoneStat(zone: 1, avg: 0.150, count: 3, total: 20),
    ZoneStat(zone: 2, avg: 0.120, count: 2, total: 18),
    ZoneStat(zone: 3, avg: 0.160, count: 3, total: 19),
    ZoneStat(zone: 4, avg: 0.180, count: 4, total: 22),
    ZoneStat(zone: 5, avg: 0.220, count: 5, total: 23),
    ZoneStat(zone: 6, avg: 0.140, count: 3, total: 21),
    ZoneStat(zone: 7, avg: 0.290, count: 7, total: 24),
    ZoneStat(zone: 8, avg: 0.310, count: 8, total: 26),
    ZoneStat(zone: 9, avg: 0.240, count: 5, total: 21),
  ];

  // 2D 캔버스 스트라이크 존 중심점 대비 야구공 탄착 마킹 가상 좌표 리스트 (-1.0 ~ 1.0)
  final List<Offset> _pitchLocations = const [
    Offset(-0.4, -0.6), Offset(-0.2, -0.3), Offset(0.1, -0.5), Offset(0.3, -0.2),
    Offset(-0.8, 0.1), Offset(-0.1, 0.2), Offset(0.5, 0.4), Offset(0.2, 0.1),
    Offset(-0.3, 0.7), Offset(0.0, 0.8), Offset(0.6, 0.6), Offset(0.4, 0.9),
    Offset(-0.6, -0.1), Offset(-0.7, -0.5), Offset(0.7, -0.2), Offset(0.8, -0.8),
    Offset(0.0, 0.0), Offset(0.1, 0.3), Offset(-0.2, 0.4), Offset(-0.5, 0.5),
  ];

  /// 백엔드 데이터와 더미 데이터를 통합하여 렌더링에 적합한 PitchCoordinate 리스트로 반환합니다.
  List<PitchCoordinate> get _displayPitches {
    if (widget.pitches.isNotEmpty) {
      return widget.pitches;
    }
    // 데이터가 비어 있을 경우, 기존 더미 Offset 리스트를 기반으로 PitchCoordinate 생성
    return List.generate(_pitchLocations.length, (i) {
      final offset = _pitchLocations[i];
      // offset.dx = plateX / 1.5 => plateX = offset.dx * 1.5
      // offset.dy = -(plateZ - 2.5) / 2.0 => plateZ = 2.5 - offset.dy * 2.0
      return PitchCoordinate(
        pitchType: i % 4 == 0 ? 'FF' : (i % 4 == 1 ? 'SL' : (i % 4 == 2 ? 'CH' : 'CU')),
        plateX: offset.dx * 1.5,
        plateZ: 2.5 - offset.dy * 2.0,
        zone: 0,
        releaseSpeed: 0.0,
        releaseSpinRate: 0.0,
        result: '',
        pitchNumber: i + 1,
      );
    });
  }

  /// 선택된 활성 역할('PITCHER' vs 'HITTER')에 따라 알맞은 데이터셋 획득
  List<ZoneStat> get _currentStats {
    if (widget.zoneStats.isNotEmpty) {
      return widget.zoneStats;
    }
    return widget.playerRole == 'PITCHER' ? _pitcherStats : _batterStats;
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 768;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: AppColors.hairline),
      ),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. 헤더 타이틀 및 세그먼트 스위칭 바
          isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.showToggle ? '하이브리드 스트라이크 존' : 'Pitch Zone 히트맵',
                          style: const TextStyle(
                            fontFamily: AppTypography.fontFamily,
                            fontWeight: FontWeight.w700,
                            fontSize: 16.0,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 2.0),
                        Text(
                          widget.showToggle 
                            ? '결과 타율과 투구 탄착군 분포의 하이브리드 제어' 
                            : '투구 탄착군 분포 시각화',
                          style: const TextStyle(
                            fontFamily: AppTypography.fontFamily,
                            fontWeight: FontWeight.w300,
                            fontSize: 11.0,
                            color: AppColors.inkTertiary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12.0),
                    Wrap(
                      spacing: 12.0,
                      runSpacing: 8.0,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.surface3,
                            borderRadius: BorderRadius.circular(6.0),
                            border: Border.all(color: AppColors.hairline),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.sports_baseball,
                                color: AppColors.primary,
                                size: 14.0,
                              ),
                              const SizedBox(width: 6.0),
                              Text(
                                'PITCH COUNT: ${widget.pitcherPitchCount}',
                                style: const TextStyle(
                                  fontFamily: AppTypography.fontFamily,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11.0,
                                  color: AppColors.ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (widget.showToggle)
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.canvas,
                              borderRadius: BorderRadius.circular(9999),
                              border: Border.all(color: AppColors.hairline),
                            ),
                            padding: const EdgeInsets.all(2.0),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildToggleButton('9격자 핫앤콜드존', _isGridMode),
                                _buildToggleButton('Pitch Zone 히트맵', !_isGridMode),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.showToggle ? '하이브리드 스트라이크 존' : 'Pitch Zone 히트맵',
                          style: const TextStyle(
                            fontFamily: AppTypography.fontFamily,
                            fontWeight: FontWeight.w700,
                            fontSize: 16.0,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 2.0),
                        Text(
                          widget.showToggle 
                            ? '결과 타율과 투구 탄착군 분포의 하이브리드 제어' 
                            : '투구 탄착군 분포 시각화',
                          style: const TextStyle(
                            fontFamily: AppTypography.fontFamily,
                            fontWeight: FontWeight.w300,
                            fontSize: 11.0,
                            color: AppColors.inkTertiary,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        // 투구수 뱃지 (PITCH COUNT: XX)
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.surface3,
                            borderRadius: BorderRadius.circular(6.0),
                            border: Border.all(color: AppColors.hairline),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.sports_baseball,
                                color: AppColors.primary,
                                size: 14.0,
                              ),
                              const SizedBox(width: 6.0),
                              Text(
                                'PITCH COUNT: ${widget.pitcherPitchCount}',
                                style: const TextStyle(
                                  fontFamily: AppTypography.fontFamily,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11.0,
                                  color: AppColors.ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (widget.showToggle) ...[
                          const SizedBox(width: 12.0),
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.canvas,
                              borderRadius: BorderRadius.circular(9999),
                              border: Border.all(color: AppColors.hairline),
                            ),
                            padding: const EdgeInsets.all(2.0),
                            child: Row(
                              children: [
                                _buildToggleButton('9격자 핫앤콜드존', _isGridMode),
                                _buildToggleButton('Pitch Zone 히트맵', !_isGridMode),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),

          const SizedBox(height: 32.0),

          // 2. 메인 커스텀 페인트 드로잉 구역 (마우스 휠/포인터 좌표 감지)
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // 부채꼴 및 격자 찌그러짐을 방지하기 위해 가로세로 폭 중 최솟값으로 정사각 영역 규격 산출
                final double sizeLimit = math.min(constraints.maxWidth, constraints.maxHeight);
                return Center(
                  child: SizedBox(
                    width: sizeLimit,
                    height: sizeLimit,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fill(
                          child: MouseRegion(
                            onHover: (event) {
                              final localPos = event.localPosition;
                              if (_isGridMode) {
                                final zone = _calculateZoneIndex(localPos, sizeLimit);
                                if (zone != _hoveredZone || _hoveredPitchIndex != null) {
                                  setState(() {
                                    _hoveredZone = zone;
                                    _hoveredPitchIndex = null;
                                  });
                                }
                              } else {
                                 final pitchIdx = PitchCoordinateMapper.findHoveredPitchIndex(localPos, _currentPitches, sizeLimit);
                                 if (pitchIdx != _hoveredPitchIndex || _hoveredZone != null) {
                                   setState(() {
                                     _hoveredPitchIndex = pitchIdx;
                                     _hoveredZone = null;
                                   });
                                 }
                              }
                            },
                            onExit: (_) {
                              setState(() {
                                _hoveredZone = null;
                                _hoveredPitchIndex = null;
                              });
                            },
                            child: AnimatedBuilder(
                              animation: _pitchAppearController,
                              builder: (context, child) {
                                return CustomPaint(
                                  painter: StrikeZonePainter(
                                    isGridMode: _isGridMode,
                                    stats: _currentStats,
                                    hoverZone: _hoveredZone,
                                    pitches: _currentPitches,
                                    lastPitchScale: _pitchScaleAnimation.value,
                                    lastPitchOpacity: _pitchOpacityAnimation.value,
                                  ),
                                );
                              }
                            ),
                          ),
                        ),
                        if (!_isGridMode && _hoveredPitchIndex != null && _hoveredPitchIndex! < _currentPitches.length)
                          _buildHoverTooltip(_currentPitches[_hoveredPitchIndex!], sizeLimit),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 24.0),

          // 3. 하단 범례 컬러 가이드바 (9격자 핫앤콜드존 상태에만 노출)
          if (_isGridMode)
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'COLD (.150)',
                    style: TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontSize: 11.0,
                      color: Colors.blueAccent,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 12.0),
                  Container(
                    width: 120,
                    height: 8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4.0),
                      gradient: const LinearGradient(
                        colors: [
                          Colors.blue,
                          Colors.lightBlueAccent,
                          Colors.yellow,
                          Colors.orange,
                          Colors.red,
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12.0),
                  const Text(
                    'HOT (.380+)',
                    style: TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontSize: 11.0,
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          else
            Center(
              child: Wrap(
                spacing: 16.0,
                runSpacing: 8.0,
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _buildPitchLegendItem('속구류 (FF/SI/FC)', const Color(0xFFFF5252)),
                  _buildPitchLegendItem('횡 변화구 (SL/ST)', const Color(0xFF40C4FF)),
                  _buildPitchLegendItem('오프스피드 (CH/FS)', const Color(0xFFE040FB)),
                  _buildPitchLegendItem('종 변화구 (CU/KC)', const Color(0xFFFFD740)),
                ],
              ),
            ),

          const SizedBox(height: 8.0),
          // const Center(
          //   child: Text(
          //     '선수의 스트라이크 존 내부의 가상의 구획별 투구 안타 빈도와 피안타율을 밀도별 컬러 코딩으로 시각화한 지표입니다.',
          //     textAlign: TextAlign.center,
          //     style: TextStyle(
          //       fontFamily: AppTypography.fontFamily,
          //       fontSize: 11.0,
          //       color: AppColors.inkTertiary,
          //     ),
          //   ),
          // ),
        ],
      ),
    );
  }

  /// 탭 모드 활성화 변경 버튼
  Widget _buildToggleButton(String label, bool isSelected) {
    return InkWell(
      onTap: () {
        setState(() {
          _isGridMode = (label == '9격자 핫앤콜드존');
        });
      },
      borderRadius: BorderRadius.circular(9999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 6.0),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.surface2 : Colors.transparent,
          borderRadius: BorderRadius.circular(9999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontWeight: isSelected ? FontWeight.w500 : FontWeight.w300,
            fontSize: 12.0,
            color: isSelected ? AppColors.ink : AppColors.inkSubtle,
          ),
        ),
      ),
    );
  }

  /// 구종별 개별 범례 마커와 라벨을 가로 한 행으로 그리는 헬퍼 위젯입니다.
  Widget _buildPitchLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10.0,
          height: 10.0,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 1,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6.0),
        Text(
          label,
          style: const TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontSize: 11.0,
            fontWeight: FontWeight.w500,
            color: AppColors.inkMuted,
          ),
        ),
      ],
    );
  }


  /// 캔버스 내 마우스 포인터의 로컬 픽셀 XY 위치를 3x3 격자 번호(1 ~ 9)로 판정하는 기하학 계산식입니다.
  int? _calculateZoneIndex(Offset localPos, double totalSize) {
    // 캔버스 안쪽 상하좌우 마진 패딩 값 적용 (15% 공간)
    final double padding = totalSize * 0.15;
    final double gridArea = totalSize - 2 * padding; // 격자 실체 폭 크기
    final double x = localPos.dx - padding;
    final double y = localPos.dy - padding;

    // 만약 마우스 포인터가 격자 공간 외벽으로 벗어나 있으면 스킵
    if (x < 0 || x > gridArea || y < 0 || y > gridArea) return null;

    // 가로 및 세로 셀 간격으로 나누어 col(0,1,2), row(0,1,2) 산출
    final int col = (x / (gridArea / 3)).floor().clamp(0, 2);
    final int row = (y / (gridArea / 3)).floor().clamp(0, 2);

    // 0행: 1, 2, 3 / 1행: 4, 5, 6 / 2행: 7, 8, 9 격자로 1-based 매핑하여 반환
    return row * 3 + col + 1;
  }

  /// 캔버스 내 마우스 포인터의 로컬 픽셀 XY 위치와 각 투구 마커 간의 거리를 계산해


  /// 마우스 호버링 중인 투구에 대한 상세 설명을 렌더링하는 Glassmorphism 툴팁 카드 위젯입니다.
  Widget _buildHoverTooltip(PitchCoordinate pitch, double totalSize) {
    // [SRP] PitchCoordinateMapper를 활용해 픽셀 투영 좌표 획득
    final Offset projectedOffset = PitchCoordinateMapper.project(
      plateX: pitch.plateX,
      plateZ: pitch.plateZ,
      totalSize: totalSize,
    );
    final double px = projectedOffset.dx;
    final double py = projectedOffset.dy;

    // [OCP] PitchTranslationService를 활용해 한글 변역 및 판정 결과 획득
    final String pitchName = PitchTranslationService.getPitchKoreanName(pitch.pitchType);
    final String outcome = PitchTranslationService.getPitchResult(pitch);
    
    // 구속 포맷 (mph -> km/h 변환 병기)
    String speedText = '';
    if (pitch.releaseSpeed > 0) {
      final double kmh = pitch.releaseSpeed * 1.60934;
      speedText = '${kmh.toStringAsFixed(1)} km/h (${pitch.releaseSpeed.toStringAsFixed(1)} mph)';
    } else {
      speedText = '구속 정보 없음';
    }

    // 회전수 포맷
    String spinText = '';
    if (pitch.releaseSpinRate > 0) {
      spinText = '${pitch.releaseSpinRate.toInt()} RPM';
    } else {
      spinText = '회전수 정보 없음';
    }

    const double tooltipWidth = 240.0;
    final double tooltipHeight = widget.showPitchOrder && pitch.pitchNumber > 0 ? 115.0 : 95.0;

    double leftPos = px - (tooltipWidth / 2);
    double topPos = py - tooltipHeight - 12.0; // 마커 상단 12px 간격

    // 경계 초과 방지 가드 (부모 컨테이너 패딩 영역을 고려하여 좌우/하단으로 약간의 오버플로우 허용)
    if (leftPos < -20.0) {
      leftPos = -20.0;
    } else if (leftPos + tooltipWidth > totalSize + 20.0) {
      leftPos = totalSize + 20.0 - tooltipWidth;
    }

    if (topPos < 0) {
      topPos = py + 12.0; // 위쪽 경계를 넘어서면 아래쪽에 툴팁 표시
    }

    if (topPos + tooltipHeight > totalSize + 20.0) {
      topPos = totalSize + 20.0 - tooltipHeight;
    }

    // [OCP] PitchTranslationService를 활용해 구종별 컬러 매핑 획득
    final Color pitchCol = PitchTranslationService.getPitchColor(pitch.pitchType);

    final isStrikeOutcome = outcome.contains('스트라이크') || outcome.contains('파울') || outcome.contains('인플레이');
    final Color outcomeBadgeColor = isStrikeOutcome 
        ? const Color(0xFFFF5252) // 불투명 솔리드 레드 (스트라이크 계열)
        : const Color(0xFF29B6F6); // 불투명 솔리드 하늘색/라이트블루 (볼 계열)
    final Color outcomeTextColor = Colors.white; // 고대비 흰색 텍스트

    return Positioned(
      left: leftPos,
      top: topPos,
      child: IgnorePointer(
        child: Container(
          width: tooltipWidth,
          height: tooltipHeight,
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E24).withOpacity(0.85),
            borderRadius: BorderRadius.circular(10.0),
            border: Border.all(color: Colors.white24, width: 1.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
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
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: pitchCol,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6.0),
                        Expanded(
                          child: Text(
                            pitchName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: AppTypography.fontFamily,
                              fontSize: 12.0,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4.0),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
                    decoration: BoxDecoration(
                      color: outcomeBadgeColor,
                      borderRadius: BorderRadius.circular(4.0),
                    ),
                    child: Text(
                      outcome,
                      style: TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 10.0,
                        fontWeight: FontWeight.w800,
                        color: outcomeTextColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10.0),
              if (widget.showPitchOrder && pitch.pitchNumber > 0) ...[
                Row(
                  children: [
                    const Text(
                      '투구 순서: ',
                      style: TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 10.0,
                        fontWeight: FontWeight.w500,
                        color: Colors.white70,
                      ),
                    ),
                    Text(
                      '타석 ${pitch.pitchNumber}구째',
                      style: const TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 10.0,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6.0),
              ],
              Row(
                children: [
                  const Text(
                    '구속: ',
                    style: TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontSize: 10.0,
                      fontWeight: FontWeight.w500,
                      color: Colors.white70,
                    ),
                  ),
                  Text(
                    speedText,
                    style: const TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontSize: 10.0,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6.0),
              Row(
                children: [
                  const Text(
                    '회전수: ',
                    style: TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontSize: 10.0,
                      fontWeight: FontWeight.w500,
                      color: Colors.white70,
                    ),
                  ),
                  Text(
                    spinText,
                    style: const TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontSize: 10.0,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 개별 격자 데이터 정의 클래스
class ZoneStat {
  final int zone;     // 격자 구역 번호 (1~9)
  final double avg;   // 타율/피타율
  final int count;    // 안타 개수
  final int total;    // 총 타수

  ZoneStat({
    required this.zone,
    required this.avg,
    required this.count,
    required this.total,
  });
}

/// 스트라이크 존 캔버스 핫앤콜드 격자 또는 야구공 탄착군 점을 직접 색칠하는 CustomPainter입니다.
class StrikeZonePainter extends CustomPainter {
  final bool isGridMode;
  final List<ZoneStat> stats;
  final int? hoverZone;
  final List<PitchCoordinate> pitches;
  final double lastPitchScale;
  final double lastPitchOpacity;

  StrikeZonePainter({
    required this.isGridMode,
    required this.stats,
    required this.hoverZone,
    required this.pitches,
    this.lastPitchScale = 1.0,
    this.lastPitchOpacity = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    
    // 스트라이크존 마진 테두리 12% 마크
    final double padding = w * 0.12;
    final double zoneWidth = w - 2 * padding;
    final double zoneHeight = h - 2 * padding;
    final double cellW = zoneWidth / 3;
    final double cellH = zoneHeight / 3;

    // 백그라운드 프레임 외곽선 드로잉
    final framePaint = Paint()
      ..color = AppColors.hairline.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRect(Offset.zero & size, framePaint);

    if (isGridMode) {
      // 9격자 핫앤콜드존 드로잉 분기
      for (final s in stats) {
        final int index = s.zone - 1;
        final int row = index ~/ 3;
        final int col = index % 3;

        final double x = padding + col * cellW;
        final double y = padding + row * cellH;
        final rect = Rect.fromLTWH(x, y, cellW, cellH);

        // 타율 메트릭 범위에 맞춰진 핫앤콜드 색상 반환
        final Color cellColor = _getColorForAvg(s.avg);

        // 셀 채우기 페인트 
        final cellPaint = Paint()
          ..color = cellColor.withOpacity(0.8)
          ..style = PaintingStyle.fill;
        canvas.drawRect(rect, cellPaint);

        // 테두리선 페인트
        final borderPaint = Paint()
          ..color = AppColors.hairline.withOpacity(0.5)
          ..strokeWidth = 1.0;
        canvas.drawRect(rect, borderPaint);

        // CustomPainter 내부 글씨 작성을 위한 TextPainter 개체 레이아웃 수행
        // 1. 격자 이름 라벨 (예: Zone 1)
        final textPainter1 = TextPainter(
          text: TextSpan(
            text: 'Zone ${s.zone}',
            style: const TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontWeight: FontWeight.w700,
              fontSize: 10.0,
              color: Colors.white70,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        // 2. 안타 개수 분수 라벨 (예: 4/22)
        final textPainter2 = TextPainter(
          text: TextSpan(
            text: '${s.count}/${s.total}',
            style: const TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontWeight: FontWeight.w500,
              fontSize: 10.0,
              color: Colors.white70,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        // 3. 소수점 타율 지표 라벨 (예: .182)
        final textPainter3 = TextPainter(
          text: TextSpan(
            text: '.${(s.avg * 1000).toInt().toString().padLeft(3, '0')}',
            style: TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontWeight: FontWeight.w700,
              fontSize: 13.0,
              color: AppColors.ink,
              shadows: [
                Shadow(
                  color: Colors.black.withOpacity(0.7),
                  offset: const Offset(1, 1),
                  blurRadius: 2,
                )
              ]
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        // 셀 내부 영역에 맞춰 중앙 및 오프셋 정렬 드로잉
        textPainter1.paint(canvas, Offset(x + 6, y + 6));
        textPainter3.paint(canvas, Offset(x + cellW / 2 - textPainter3.width / 2, y + cellH / 2 - textPainter3.height / 2));
        textPainter2.paint(canvas, Offset(x + cellW / 2 - textPainter2.width / 2, y + cellH - 18));
      }
    } else {
      // 투구 탄착군 분포 히트맵 드로잉 분기
      
      // 스트라이크존 내부 영역 검은색 사각 도화지
      final szBgPaint = Paint()
        ..color = AppColors.canvas
        ..style = PaintingStyle.fill;
      canvas.drawRect(Rect.fromLTWH(padding, padding, zoneWidth, zoneHeight), szBgPaint);

      // 격자 내부 식별 십자 구분 점선 그리기
      final gridPaint = Paint()
        ..color = AppColors.hairline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      
      canvas.drawLine(Offset(padding + cellW, padding), Offset(padding + cellW, padding + zoneHeight), gridPaint);
      canvas.drawLine(Offset(padding + cellW * 2, padding), Offset(padding + cellW * 2, padding + zoneHeight), gridPaint);
      canvas.drawLine(Offset(padding, padding + cellH), Offset(padding + zoneWidth, padding + cellH), gridPaint);
      canvas.drawLine(Offset(padding, padding + cellH * 2), Offset(padding + zoneWidth, padding + cellH * 2), gridPaint);

      // 스트라이크존 굵은 외곽 경계 보라색 보더 라인
      final szBorderPaint = Paint()
        ..color = AppColors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;
      canvas.drawRect(Rect.fromLTWH(padding, padding, zoneWidth, zoneHeight), szBorderPaint);

      // 구종별 입체 마커 뿌리기 (비율 좌표 환산 후 단색 서클 및 고대비 흰색 테두리 드로잉)
      for (int i = 0; i < pitches.length; i++) {
        final p = pitches[i];
        
        // [SRP] PitchCoordinateMapper를 활용해 픽셀 오프셋 획득
        final Offset projectedPos = PitchCoordinateMapper.project(
          plateX: p.plateX,
          plateZ: p.plateZ,
          totalSize: w,
        );
        final double x = projectedPos.dx;
        final double y = projectedPos.dy;

        // [OCP] PitchTranslationService를 활용해 구종별 컬러 매핑 획득
        final Color pitchCol = PitchTranslationService.getPitchColor(p.pitchType);

        final bool isLast = i == pitches.length - 1;
        final double scale = isLast ? lastPitchScale : 1.0;
        final double opacity = isLast ? lastPitchOpacity : 1.0;

        // 1. 입체감을 주기 위한 은은한 블랙 섀도우 베이스 깔기
        canvas.drawCircle(
          Offset(x, y),
          7.5 * scale,
          Paint()
            ..color = Colors.black.withOpacity(0.4 * opacity)
            ..style = PaintingStyle.fill,
        );

        // 2. 구종 색상 기준 속이 찬 단색 서클(Solid Circle) 그리기
        canvas.drawCircle(
          Offset(x, y),
          6.5 * scale,
          Paint()
            ..color = pitchCol.withOpacity(opacity)
            ..style = PaintingStyle.fill,
        );

        // 3. 어두운 배경 대비 가시성 증대를 위한 흰색 테두리(White Border) 그리기
        canvas.drawCircle(
          Offset(x, y),
          6.5 * scale,
          Paint()
            ..color = Colors.white.withOpacity(opacity)
            ..strokeWidth = 1.5
            ..style = PaintingStyle.stroke,
        );
      }

    }
  }

  /// 타율 범위에 입각하여 핫앤콜드 구역 격자 배경색을 리턴하는 분기 게터 함수
  Color _getColorForAvg(double avg) {
    if (avg < 0.170) {
      return Colors.blue.shade900; // 극단적 저타율 (딥블루 COLD)
    } else if (avg < 0.200) {
      return Colors.blue.shade700; // 저타율 (블루 COLD)
    } else if (avg < 0.230) {
      return Colors.blue.shade400; // 약한 저타율 (라이트블루 COLD)
    } else if (avg < 0.270) {
      return Colors.orangeAccent.withOpacity(0.5); // 리그 평균 (반투명 오렌지)
    } else if (avg < 0.320) {
      return Colors.orange.shade700; // 고타율 (오렌지 HOT)
    } else {
      return Colors.red.shade700;    // 최고 타율 (진한 레드 HOT)
    }
  }

  @override
  bool shouldRepaint(covariant StrikeZonePainter oldDelegate) {
    return oldDelegate.isGridMode != isGridMode ||
        oldDelegate.stats != stats ||
        oldDelegate.hoverZone != hoverZone ||
        oldDelegate.pitches != pitches ||
        oldDelegate.lastPitchScale != lastPitchScale ||
        oldDelegate.lastPitchOpacity != lastPitchOpacity;
  }
}

/// [SRP] 물리 공간 상의 투구 좌표를 화면 2D 픽셀 좌표계로 투영하고,
/// 마우스 포인터 충돌을 감지하는 단일 책임을 가집니다.
class PitchCoordinateMapper {
  /// plateX, plateZ 실제 물리 구역을 바탕으로 2D 화면 픽셀 Offset 좌표를 연산합니다.
  static Offset project({
    required double plateX,
    required double plateZ,
    required double totalSize,
  }) {
    final double padding = totalSize * 0.12;
    final double zoneWidth = totalSize - 2 * padding;
    final double zoneHeight = totalSize - 2 * padding;

    // 실제 물리 좌표 (plateX: [-1.5, 1.5], plateZ: [0.5, 4.5]) 범위를 비율 좌표 [-1.3, 1.3]로 정밀 매핑 (볼 투구 렌더링 영역 확장)
    final double rx = (plateX / 1.5).clamp(-1.3, 1.3);
    final double rz = (-(plateZ - 2.5) / 2.0).clamp(-1.3, 1.3);

    // 상대 비율 좌표값(-1.0 ~ 1.0)을 화면 픽셀 스케일에 맞추어 변환
    final double x = padding + zoneWidth / 2 + rx * (zoneWidth / 2);
    final double y = padding + zoneHeight / 2 + rz * (zoneHeight / 2);

    return Offset(x, y);
  }

  /// 캔버스 내 마우스 포인터의 로컬 픽셀 XY 위치와 각 투구 마커 간의 거리를 계산해
  /// 12px 이내에 호버링된 투구의 인덱스를 판정합니다. (유클리드 거리 공식 사용)
  static int? findHoveredPitchIndex(Offset localPos, List<PitchCoordinate> pitches, double totalSize) {
    double minDistance = double.infinity;
    int? closestIndex;

    for (int i = 0; i < pitches.length; i++) {
      final p = pitches[i];
      final Offset projectedPos = project(plateX: p.plateX, plateZ: p.plateZ, totalSize: totalSize);

      final double dist = math.sqrt(
        (localPos.dx - projectedPos.dx) * (localPos.dx - projectedPos.dx) + 
        (localPos.dy - projectedPos.dy) * (localPos.dy - projectedPos.dy)
      );

      if (dist < minDistance) {
        minDistance = dist;
        closestIndex = i;
      }
    }

    // 마우스가 마커 중심 반경 12px 이내에 있을 때만 호버링된 것으로 처리
    if (minDistance <= 12.0) {
      return closestIndex;
    }
    return null;
  }
}

/// [OCP] 구종 번역, 판정 결과 변환 및 구종별 테마 컬러 매핑을 총괄하며
/// 구종 확장 시 UI를 고치지 않고 매핑 테이블만 확장 가능하도록 설계되었습니다.
class PitchTranslationService {
  /// 구종 코드별 메타데이터 매핑 테이블
  static const Map<String, _PitchMetadata> _pitchMetadataRegistry = {
    'FF': _PitchMetadata(koreanName: '포심 패스트볼', color: Color(0xFFFF5252)),
    'FT': _PitchMetadata(koreanName: '투심 패스트볼', color: Color(0xFFFF5252)),
    'FC': _PitchMetadata(koreanName: '컷 패스트볼', color: Color(0xFFFF5252)),
    'SI': _PitchMetadata(koreanName: '싱커', color: Color(0xFFFF5252)),
    'SL': _PitchMetadata(koreanName: '슬라이더', color: Color(0xFF40C4FF)),
    'ST': _PitchMetadata(koreanName: '스위퍼', color: Color(0xFF40C4FF)),
    'CH': _PitchMetadata(koreanName: '체인지업', color: Color(0xFFE040FB)),
    'FS': _PitchMetadata(koreanName: '스플리터', color: Color(0xFFE040FB)),
    'CU': _PitchMetadata(koreanName: '커브볼', color: Color(0xFFFFD740)),
    'KC': _PitchMetadata(koreanName: '너클커브', color: Color(0xFFFFD740)),
    'FO': _PitchMetadata(koreanName: '포크볼', color: Color(0xFFE040FB)),
    'EP': _PitchMetadata(koreanName: '이퍼스', color: Color(0xFF9E9E9E)),
    'KN': _PitchMetadata(koreanName: '너클볼', color: Color(0xFF9E9E9E)),
    'FA': _PitchMetadata(koreanName: '속구', color: Color(0xFFFF5252)),
    'SC': _PitchMetadata(koreanName: '스크류볼', color: Color(0xFF9E9E9E)),
    'SV': _PitchMetadata(koreanName: '슬러브', color: Color(0xFF40C4FF)),
  };

  /// 기본 폴백 메타데이터
  static const _PitchMetadata _fallbackMetadata = _PitchMetadata(
    koreanName: '기타 구종',
    color: Color(0xFF9E9E9E),
  );

  /// 구종 약어 코드를 식별하여 한국어 구종명으로 반환합니다.
  static String getPitchKoreanName(String type) {
    final metadata = _pitchMetadataRegistry[type.toUpperCase()];
    return metadata?.koreanName ?? type;
  }

  /// 구종 약어 코드를 식별하여 알맞은 테마 컬러를 반환합니다.
  static Color getPitchColor(String type) {
    final metadata = _pitchMetadataRegistry[type.toUpperCase()];
    return metadata?.color ?? _fallbackMetadata.color;
  }

  /// 투구 좌표 및 백엔드 판정 결과에 맞춰 최종 한국어 결과를 판정합니다.
  static String getPitchResult(PitchCoordinate pitch) {
    if (pitch.result.isNotEmpty) {
      return pitch.result;
    }
    
    // 폴백: 물리 스트라이크 존 박스의 영역 경계(rx.abs() <= 1.0, rz.abs() <= 1.0)에 의한 판정
    // rx = plateX / 1.5, rz = -(plateZ - 2.5) / 2.0
    final double rx = (pitch.plateX / 1.5).clamp(-1.3, 1.3);
    final double rz = (-(pitch.plateZ - 2.5) / 2.0).clamp(-1.3, 1.3);
    final bool isStrike = rx.abs() <= 1.0 && rz.abs() <= 1.0;
    
    return isStrike ? '스트라이크' : '볼';
  }
}

/// 내부에 캡슐화된 구종별 메타데이터 캡슐 클래스
class _PitchMetadata {
  final String koreanName;
  final Color color;

  const _PitchMetadata({
    required this.koreanName,
    required this.color,
  });
}
