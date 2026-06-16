import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';

class Cached3DPoint {
  final double x;
  final double y;
  final double z;
  const Cached3DPoint(this.x, this.y, this.z);
}

class CachedTrajectory {
  final String pitchName;
  final List<Cached3DPoint> points3D;
  final Cached3DPoint plateIntersection3D;
  final Color color;

  const CachedTrajectory({
    required this.pitchName,
    required this.points3D,
    required this.plateIntersection3D,
    required this.color,
  });
}

class ProjectedTrajectory {
  final String pitchName;
  final List<Offset> projectedPoints;
  final Offset plateIntersection2D;
  final Color color;

  const ProjectedTrajectory({
    required this.pitchName,
    required this.projectedPoints,
    required this.plateIntersection2D,
    required this.color,
  });
}

// -------------------------------------------------------------
// [1] 3D 투구 궤적 시뮬레이터 (PitchTrajectorySimulator)
// -------------------------------------------------------------
class PitchTrajectorySimulator extends StatefulWidget {
  final String playerRole;
  final List<Map<String, dynamic>> trajectories;
  final bool? isActive;
  
  const PitchTrajectorySimulator({
    super.key, 
    required this.playerRole,
    required this.trajectories,
    this.isActive = true,
  });

  @override
  State<PitchTrajectorySimulator> createState() => _PitchTrajectorySimulatorState();
}

class _PitchTrajectorySimulatorState extends State<PitchTrajectorySimulator> with SingleTickerProviderStateMixin {
  double _yaw = -0.35;     
  double _pitch = 0.45;    
  double _zoom = 1.0;      
  double _translateX = 0.0; 
  double _translateY = 0.0; 
  String _activePreset = '중계'; 
  bool _isDragging = false;

  late AnimationController _animController;
  bool _isPlaying = true; 

  final Map<String, bool> _visiblePitches = {};

  String _selectedPitchName = '직구 (Fastball)';
  double _speed = 148;
  double _rpm = 2210;
  double _pfxX = 8.2;
  double _pfxZ = 14.5;

  List<CachedTrajectory> _cachedTrajectories = [];

  double? _lastYaw;
  double? _lastPitch;
  double? _lastZoom;
  double? _lastTranslateX;
  double? _lastTranslateY;
  Size? _lastSize;
  List<CachedTrajectory>? _lastCachedTrajectories;
  bool? _lastIsDragging;

  List<ProjectedTrajectory> _projectedTrajectories = [];
  List<List<Offset>> _projectedGroundGridLines = [];
  List<Offset> _projectedHomePlate = [];
  List<Offset> _projectedStrikeZoneFront = [];
  Offset _projectedStrikeZoneCenterBottom = Offset.zero;
  Offset _projectedStrikeZoneCenterTop = Offset.zero;
  List<Offset> _projectedReleasePointPlane = [];

  Offset _projectStatePoint(double x, double y, double z, Size size, double yaw, double pitch, double zoom, double translateX, double translateY) {
    final double cx = size.width / 2;
    final double cy = size.height / 2 + 10;

    final double dx = x;
    final double dy = y - 15.0;
    final double dz = z - 3.0;

    final double rx1 = dx * math.cos(yaw) - dy * math.sin(yaw);
    final double ry1 = dx * math.sin(yaw) + dy * math.cos(yaw);
    final double rz1 = dz;

    final double rx2 = rx1;
    final double ry2 = ry1 * math.cos(pitch) - rz1 * math.sin(pitch);
    final double rz2 = ry1 * math.sin(pitch) + rz1 * math.cos(pitch);

    final double depth = ry2 + 45.0;
    if (depth <= 1.0) return Offset(cx + translateX, cy + translateY);

    final double scale = (450.0 * zoom) / depth;

    final double screenX = cx + rx2 * scale + translateX;
    final double screenY = cy - rz2 * scale + translateY;

    return Offset(screenX, screenY);
  }

  void _updateProjectedPoints(Size size) {
    if (_lastYaw == _yaw &&
        _lastPitch == _pitch &&
        _lastZoom == _zoom &&
        _lastTranslateX == _translateX &&
        _lastTranslateY == _translateY &&
        _lastSize == size &&
        _lastCachedTrajectories == _cachedTrajectories &&
        _lastIsDragging == _isDragging) {
      return;
    }

    _lastYaw = _yaw;
    _lastPitch = _pitch;
    _lastZoom = _zoom;
    _lastTranslateX = _translateX;
    _lastTranslateY = _translateY;
    _lastSize = size;
    _lastCachedTrajectories = _cachedTrajectories;
    _lastIsDragging = _isDragging;

    final double curYaw = _yaw;
    final double curPitch = _pitch;
    final double curZoom = _zoom;
    final double curTranslateX = _translateX;
    final double curTranslateY = _translateY;

    Offset localProject(double x, double y, double z) {
      return _projectStatePoint(x, y, z, size, curYaw, curPitch, curZoom, curTranslateX, curTranslateY);
    }

    _projectedGroundGridLines = [];
    for (double x = -6.0; x <= 6.0; x += 2.0) {
      final List<Offset> points = [];
      for (double y = 0.0; y <= 60.0; y += 5.0) {
        points.add(localProject(x, y, 0.0));
      }
      _projectedGroundGridLines.add(points);
    }
    for (double y = 0.0; y <= 60.0; y += 10.0) {
      final List<Offset> points = [];
      for (double x = -6.0; x <= 6.0; x += 1.0) {
        points.add(localProject(x, y, 0.0));
      }
      _projectedGroundGridLines.add(points);
    }

    final double hpW = 1.417 / 2;
    final List<Offset> hp3D = [
      const Offset(0, 0),
      Offset(-hpW, 0.7),
      Offset(-hpW, 1.417),
      Offset(hpW, 1.417),
      Offset(hpW, 0.7),
    ];
    _projectedHomePlate = hp3D.map((pt) => localProject(pt.dx, pt.dy, 0)).toList();

    final double szLeft = -1.417 / 2;
    final double szRight = 1.417 / 2;
    const double szBottom = 1.5;
    const double szTop = 3.5;
    const double szY = 1.417;

    _projectedStrikeZoneFront = [
      localProject(szLeft, szY, szBottom),
      localProject(szLeft, szY, szTop),
      localProject(szRight, szY, szTop),
      localProject(szRight, szY, szBottom),
    ];

    _projectedStrikeZoneCenterBottom = localProject(0, szY, szBottom);
    _projectedStrikeZoneCenterTop = localProject(0, szY, szTop);

    _projectedReleasePointPlane = [
      localProject(-1.5, 55.0, 5.0),
      localProject(1.5, 55.0, 5.0),
      localProject(1.5, 55.0, 7.0),
      localProject(-1.5, 55.0, 7.0),
    ];

    _projectedTrajectories = _cachedTrajectories.map((traj) {
      final List<Offset> projectedPoints = [];
      final int step = _isDragging ? 4 : 2; // LOD 기법 적용: 드래그 시 연산량을 1/2로 감소
      for (int i = 0; i < traj.points3D.length; i += step) {
        final pt = traj.points3D[i];
        projectedPoints.add(localProject(pt.x, pt.y, pt.z));
      }
      if ((traj.points3D.length - 1) % step != 0 && traj.points3D.isNotEmpty) {
        final pt = traj.points3D.last;
        projectedPoints.add(localProject(pt.x, pt.y, pt.z));
      }
      final plateIntersection2D = localProject(traj.plateIntersection3D.x, traj.plateIntersection3D.y, traj.plateIntersection3D.z);
      return ProjectedTrajectory(
        pitchName: traj.pitchName,
        projectedPoints: projectedPoints,
        plateIntersection2D: plateIntersection2D,
        color: traj.color,
      );
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );
    if (widget.isActive ?? true) {
      _animController.repeat();
    }
    
    _initializePitches();
    _precomputeTrajectories();
  }

  @override
  void didUpdateWidget(covariant PitchTrajectorySimulator oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    final bool currentActive = widget.isActive ?? true;
    final bool oldActive = oldWidget.isActive ?? true;
    if (currentActive != oldActive) {
      if (currentActive) {
        if (_isPlaying) {
          _animController.repeat();
        }
      } else {
        _animController.stop();
      }
    }

    if (widget.trajectories != oldWidget.trajectories || widget.playerRole != oldWidget.playerRole) {
      _initializePitches();
      _precomputeTrajectories();
    }
  }

  void _precomputeTrajectories() {
    final List<String> pitchNames = widget.trajectories.isNotEmpty
        ? widget.trajectories.map((t) => t['pitchName'] as String? ?? '').where((n) => n.isNotEmpty).toSet().toList()
        : const [
            '직구 (Fastball)',
            '슬라이더 (Slider)',
            '커브 (Curveball)',
            '체인지업 (Changeup)'
          ];

    final List<CachedTrajectory> cachedList = [];

    for (final name in pitchNames) {
      final Color col = _getPitchColor(name);

      final traj = widget.trajectories.firstWhere(
        (t) => (t['pitchName'] as String) == name,
        orElse: () => <String, dynamic>{},
      );

      final double pfxX = traj.isNotEmpty ? (traj['pfxX'] as num? ?? 0.0).toDouble() : _getDefaultPfxX(name);
      final double plateX = traj.isNotEmpty ? (traj['plateX'] as num? ?? 0.0).toDouble() : _getDefaultPlateX(name);

      const double releaseX = -1.6;
      final double deviationX = pfxX / 12.0;

      final double speedKmh = traj.isNotEmpty ? (traj['speed'] as num? ?? 140.0).toDouble() : _getDefaultSpeed(name);
      final double pfxZ = traj.isNotEmpty ? (traj['pfxZ'] as num? ?? 0.0).toDouble() : _getDefaultPfxZ(name);
      final double plateZ = traj.isNotEmpty ? (traj['plateZ'] as num? ?? 3.0).toDouble() : _getDefaultPlateZ(name);

      const double releaseZ = 6.0;
      const double g = 32.174;

      final double speedFps = speedKmh * 0.911344;
      final double flightTime = speedFps > 0 ? (55.0 - 1.417) / speedFps : 0.4;

      final double gravityDrop = 0.5 * g * flightTime * flightTime;
      final double liftZ = pfxZ / 12.0;
      final double deviationZ = liftZ - gravityDrop;

      double getZAtY(double y) {
        final double t = (55.0 - y) / (55.0 - 1.417);
        double z = releaseZ + (plateZ - releaseZ - deviationZ) * t + deviationZ * math.pow(t, 2);
        if (name.contains('커브')) {
          final double hump = math.sin(t * math.pi) * 0.5;
          z += hump;
        }
        return z;
      }

      final List<Cached3DPoint> points3D = [];
      for (double y = 55.0; y >= 1.417; y -= 1.0) {
        final double t = (55.0 - y) / (55.0 - 1.417);
        final double x = releaseX + (plateX - releaseX - deviationX) * t + deviationX * math.pow(t, 2.5);
        points3D.add(Cached3DPoint(x, y, getZAtY(y)));
      }

      final double endX = points3D.isNotEmpty ? points3D.last.x : plateX;
      final double endZ = getZAtY(1.417);
      final Cached3DPoint plateIntersection3D = Cached3DPoint(endX, 1.417, endZ);

      cachedList.add(CachedTrajectory(
        pitchName: name,
        points3D: points3D,
        plateIntersection3D: plateIntersection3D,
        color: col,
      ));
    }

    setState(() {
      _cachedTrajectories = cachedList;
    });
  }

  double _getDefaultSpeed(String name) {
    final bool isPitcher = widget.playerRole == 'PITCHER';
    if (name.contains('직구') || name.contains('포심') || name.contains('속구') || name.contains('Fastball')) return isPitcher ? 156 : 148;
    if (name.contains('슬라이더') || name.contains('Slider')) return isPitcher ? 142 : 135;
    if (name.contains('커브') || name.contains('Curveball')) return isPitcher ? 124 : 118;
    return isPitcher ? 136 : 128;
  }

  double _getDefaultPfxX(String name) {
    final bool isPitcher = widget.playerRole == 'PITCHER';
    if (name.contains('직구') || name.contains('포심') || name.contains('속구') || name.contains('Fastball')) return isPitcher ? 8.5 : 8.2;
    if (name.contains('슬라이더') || name.contains('Slider')) return isPitcher ? -6.2 : -5.4;
    if (name.contains('커브') || name.contains('Curveball')) return isPitcher ? -9.1 : -8.0;
    return isPitcher ? 9.8 : 9.1;
  }

  double _getDefaultPfxZ(String name) {
    final bool isPitcher = widget.playerRole == 'PITCHER';
    if (name.contains('직구') || name.contains('포심') || name.contains('속구') || name.contains('Fastball')) return isPitcher ? 18.2 : 14.5;
    if (name.contains('슬라이더') || name.contains('Slider')) return isPitcher ? 2.1 : 1.2;
    if (name.contains('커브') || name.contains('Curveball')) return isPitcher ? -12.4 : -10.8;
    return isPitcher ? 6.2 : 5.1;
  }

  double _getDefaultPlateX(String name) {
    if (name.contains('직구') || name.contains('포심') || name.contains('속구') || name.contains('Fastball')) return -0.3;
    if (name.contains('슬라이더') || name.contains('Slider')) return 0.8;
    if (name.contains('커브') || name.contains('Curveball')) return 0.2;
    return -0.6;
  }

  double _getDefaultPlateZ(String name) {
    if (name.contains('직구') || name.contains('포심') || name.contains('속구') || name.contains('Fastball')) return 2.8;
    if (name.contains('슬라이더') || name.contains('Slider')) return 2.0;
    if (name.contains('커브') || name.contains('Curveball')) return 1.6;
    return 2.2;
  }

  void _initializePitches() {
    setState(() {
      _visiblePitches.clear();
      if (widget.trajectories.isNotEmpty) {
        for (final t in widget.trajectories) {
          final name = t['pitchName'] as String? ?? '알 수 없음';
          _visiblePitches[name] = true;
        }
        _selectedPitchName = widget.trajectories.first['pitchName'] ?? '직구 (Fastball)';
      } else {
        _visiblePitches['직구 (Fastball)'] = true;
        _visiblePitches['슬라이더 (Slider)'] = true;
        _visiblePitches['커브 (Curveball)'] = true;
        _visiblePitches['체인지업 (Changeup)'] = true;
        _selectedPitchName = '직구 (Fastball)';
      }
      _setMetricsForPitch(_selectedPitchName);
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _setMetricsForPitch(String name) {
    setState(() {
      _selectedPitchName = name;
      
      final traj = widget.trajectories.firstWhere(
        (t) => (t['pitchName'] as String) == name,
        orElse: () => <String, dynamic>{},
      );
      
      if (traj.isNotEmpty) {
        _speed = (traj['speed'] as num? ?? 0.0).toDouble();
        _rpm = (traj['rpm'] as num? ?? 0.0).toDouble();
        _pfxX = (traj['pfxX'] as num? ?? 0.0).toDouble();
        _pfxZ = (traj['pfxZ'] as num? ?? 0.0).toDouble();
      } else {
        final bool isPitcher = widget.playerRole == 'PITCHER';
        if (name.contains('직구') || name.contains('포심') || name.contains('속구') || name.contains('Fastball')) {
          _speed = isPitcher ? 156 : 148;
          _rpm = isPitcher ? 2580 : 2210;
          _pfxX = isPitcher ? 8.5 : 8.2;
          _pfxZ = isPitcher ? 18.2 : 14.5;
        } else if (name.contains('슬라이더') || name.contains('Slider')) {
          _speed = isPitcher ? 142 : 135;
          _rpm = isPitcher ? 2450 : 2180;
          _pfxX = isPitcher ? -6.2 : -5.4;
          _pfxZ = isPitcher ? 2.1 : 1.2;
        } else if (name.contains('커터') || name.contains('Cutter')) {
          _speed = isPitcher ? 146 : 139;
          _rpm = isPitcher ? 2380 : 2100;
          _pfxX = isPitcher ? 2.5 : 2.0;
          _pfxZ = isPitcher ? 8.2 : 7.0;
        } else if (name.contains('스위퍼') || name.contains('Sweeper')) {
          _speed = isPitcher ? 134 : 128;
          _rpm = isPitcher ? 2600 : 2300;
          _pfxX = isPitcher ? -12.5 : -11.0;
          _pfxZ = isPitcher ? 1.5 : 1.0;
        } else if (name.contains('커브') || name.contains('Curveball') || name.contains('너클 커브') || name.contains('Knuckle Curve') || name.contains('슬러브') || name.contains('Slurve')) {
          _speed = isPitcher ? 124 : 118;
          _rpm = isPitcher ? 2720 : 2410;
          _pfxX = isPitcher ? -9.1 : -8.0;
          _pfxZ = isPitcher ? -12.4 : -10.8;
        } else if (name.contains('싱커') || name.contains('Sinker') || name.contains('투심')) {
          _speed = isPitcher ? 152 : 144;
          _rpm = isPitcher ? 2180 : 2010;
          _pfxX = isPitcher ? 14.2 : 12.8;
          _pfxZ = isPitcher ? 7.5 : 6.2;
        } else if (name.contains('스플리터') || name.contains('Splitter') || name.contains('포크볼') || name.contains('Forkball')) {
          _speed = isPitcher ? 138 : 132;
          _rpm = isPitcher ? 1600 : 1420;
          _pfxX = isPitcher ? 4.5 : 4.0;
          _pfxZ = isPitcher ? 2.2 : 1.8;
        } else { 
          _speed = isPitcher ? 136 : 128;
          _rpm = isPitcher ? 1980 : 1720;
          _pfxX = isPitcher ? 9.8 : 9.1;
          _pfxZ = isPitcher ? 6.2 : 5.1;
        }
      }
    });
  }

  void _setCameraPreset(String preset) {
    setState(() {
      _activePreset = preset;
      _zoom = 1.0;
      _translateX = 0.0;
      _translateY = 0.0;
      if (preset == '포수') {
        _yaw = 0.0;
        _pitch = 0.12;
      } else if (preset == '투수') {
        _yaw = math.pi;
        _pitch = 0.15;
      } else if (preset == '중계') {
        _yaw = -0.35;
        _pitch = 0.45;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 768;

    final double speedPct = ((_speed - 130) / (165 - 130)).clamp(0.0, 1.0);
    final double rpmPct = ((_rpm - 1500) / (2800 - 1500)).clamp(0.0, 1.0);
    final double pfxXPct = ((_pfxX - (-15)) / (15 - (-15))).clamp(0.0, 1.0);
    final double pfxZPct = ((_pfxZ - (-15)) / (20 - (-15))).clamp(0.0, 1.0);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        children: [
          // 1. 헤더 조작부 영역
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: isMobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.blur_on, color: AppColors.primary),
                          const SizedBox(width: 8.0),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '3D 투구 궤적 시뮬레이터',
                                  style: TextStyle(
                                    fontFamily: AppTypography.fontFamily,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16.0,
                                    color: AppColors.ink,
                                  ),
                                ),
                                const SizedBox(height: 2.0),
                                const Text(
                                  '3차원 공간 시뮬레이션 및 수평/수직 물리 변화량 분석',
                                  style: TextStyle(
                                    fontFamily: AppTypography.fontFamily,
                                    fontWeight: FontWeight.w300,
                                    fontSize: 11.0,
                                    color: AppColors.inkTertiary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12.0),
                      Wrap(
                        spacing: 8.0,
                        runSpacing: 8.0,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _buildSegmentedViews(),
                          const SizedBox(width: 4.0),
                          _buildCircleButton(
                            icon: _isPlaying ? Icons.pause : Icons.play_arrow,
                            tooltip: _isPlaying ? '시뮬레이션 일시정지' : '시뮬레이션 재생',
                            onTap: () {
                              setState(() {
                                _isPlaying = !_isPlaying;
                                if (_isPlaying) {
                                  if (widget.isActive ?? true) _animController.repeat();
                                } else {
                                  _animController.stop();
                                }
                              });
                            },
                          ),
                          _buildCircleButton(
                            icon: Icons.replay,
                            tooltip: '시뮬레이션 처음부터 재생',
                            onTap: () {
                              _animController.forward(from: 0.0);
                              if (_isPlaying && (widget.isActive ?? true)) _animController.repeat();
                            },
                          ),
                        ],
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.blur_on, color: AppColors.primary),
                          const SizedBox(width: 8.0),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '3D 투구 궤적 시뮬레이터 (Trajectory Space)',
                                style: TextStyle(
                                  fontFamily: AppTypography.fontFamily,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16.0,
                                  color: AppColors.ink,
                                ),
                              ),
                              const SizedBox(height: 2.0),
                              const Text(
                                '마운드로부터 홈플레이트까지의 3차원 투구 공간 및 릴리즈 포인트 분석',
                                style: TextStyle(
                                  fontFamily: AppTypography.fontFamily,
                                  fontWeight: FontWeight.w300,
                                  fontSize: 11.0,
                                  color: AppColors.inkTertiary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          _buildSegmentedViews(),
                          const SizedBox(width: 12.0),
                          _buildCircleButton(
                            icon: _isPlaying ? Icons.pause : Icons.play_arrow,
                            tooltip: _isPlaying ? '시뮬레이션 일시정지' : '시뮬레이션 재생',
                            onTap: () {
                              setState(() {
                                _isPlaying = !_isPlaying;
                                if (_isPlaying) {
                                  if (widget.isActive ?? true) _animController.repeat();
                                } else {
                                  _animController.stop();
                                }
                              });
                            },
                          ),
                          const SizedBox(width: 8.0),
                          _buildCircleButton(
                            icon: Icons.replay,
                            tooltip: '시뮬레이션 처음부터 재생',
                            onTap: () {
                              _animController.forward(from: 0.0);
                              if (_isPlaying && (widget.isActive ?? true)) _animController.repeat();
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
          ),

          // 2. 메인 3차원 투영 드로잉 영역
          Expanded(
            child: Stack(
              children: [
                // 드래그를 통한 회전 및 이동 전용 리스너
                Listener(
                  onPointerDown: (event) {
                    setState(() {
                      _isDragging = true;
                      _activePreset = '사용자';
                    });
                  },
                  onPointerMove: (event) {
                    setState(() {
                      _isDragging = true;
                      if (event.buttons == kSecondaryMouseButton) {
                        // 우클릭 드래그 시 카메라 평면 이동
                        _translateX += event.delta.dx;
                        _translateY += event.delta.dy;
                      } else {
                        // 좌클릭 드래그 또는 모바일 터치 시 카메라 앵글 회전
                        _yaw += event.delta.dx * 0.007;
                        _pitch = (_pitch + event.delta.dy * 0.007)
                            .clamp(-math.pi / 3, math.pi / 3);
                      }
                      _activePreset = '사용자';
                    });
                  },
                  onPointerUp: (event) {
                    setState(() {
                      _isDragging = false;
                    });
                  },
                  onPointerCancel: (event) {
                    setState(() {
                      _isDragging = false;
                    });
                  },
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final Size size = Size(constraints.maxWidth, constraints.maxHeight);
                      _updateProjectedPoints(size);

                      return AnimatedBuilder(
                        animation: _animController,
                        builder: (context, child) {
                          return CustomPaint(
                            size: Size.infinite,
                            painter: Pitch3DPainter(
                              projectedTrajectories: _projectedTrajectories,
                              projectedGroundGridLines: _projectedGroundGridLines,
                              projectedHomePlate: _projectedHomePlate,
                              projectedStrikeZoneFront: _projectedStrikeZoneFront,
                              projectedStrikeZoneCenterBottom: _projectedStrikeZoneCenterBottom,
                              projectedStrikeZoneCenterTop: _projectedStrikeZoneCenterTop,
                              projectedReleasePointPlane: _projectedReleasePointPlane,
                              progress: _animController.value,
                              visiblePitches: _visiblePitches,
                              playerRole: widget.playerRole,
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),

                // 좌측 상단: 데스크톱 전용 구종 제어 패널
                if (!isMobile)
                  Positioned(
                    top: 16.0,
                    bottom: 16.0,
                    left: 16.0,
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12.0),
                        child: Container(
                          padding: const EdgeInsets.all(12.0),
                          decoration: BoxDecoration(
                            color: AppColors.canvas.withOpacity(0.65), 
                            borderRadius: BorderRadius.circular(12.0),
                            border: Border.all(color: AppColors.hairline.withOpacity(0.6)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 10.0,
                                spreadRadius: 2.0,
                              ),
                            ],
                          ),
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: _visiblePitches.keys.map((name) {
                                final Color pitchColor = _getPitchColor(name);
                                final bool isSelected = _selectedPitchName == name;
                                final bool isVisible = _visiblePitches[name] ?? true;

                                return InkWell(
                                  onTap: () => _setMetricsForPitch(name),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              _visiblePitches[name] = !isVisible;
                                            });
                                          },
                                          child: AnimatedContainer(
                                            duration: const Duration(milliseconds: 200),
                                            width: 16,
                                            height: 16,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: isVisible ? pitchColor : Colors.transparent,
                                              border: Border.all(color: pitchColor, width: 1.5),
                                            ),
                                            child: isVisible
                                                ? const Icon(Icons.check, size: 10, color: Colors.white)
                                                : null,
                                          ),
                                        ),
                                        const SizedBox(width: 8.0),
                                        Text(
                                          name,
                                          style: TextStyle(
                                            fontFamily: AppTypography.fontFamily,
                                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                            fontSize: 12.0,
                                            color: isSelected ? AppColors.ink : AppColors.inkMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                // 우측 상단 조작 버튼 묶음 (안내 아이콘 및 줌인/아웃 컨트롤러 추가)
                Positioned(
                  top: 16.0,
                  right: 16.0,
                  child: Column(
                    children: [
                      Tooltip(
                        message: '마우스 드래그: 3D 뷰포트 회전\n우클릭 드래그: 카메라 평면 이동',
                        textStyle: const TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontSize: 11.0,
                          color: Colors.white,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(6.0),
                        ),
                        triggerMode: TooltipTriggerMode.tap,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.canvas.withOpacity(0.8),
                            border: Border.all(color: AppColors.hairline),
                          ),
                          child: const Icon(
                            Icons.info_outline,
                            size: 16,
                            color: AppColors.inkSubtle,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12.0),
                      // 확실한 작동을 보장하는 줌인(+) 버튼
                      _buildCircleButton(
                        icon: Icons.add,
                        tooltip: '확대 (Zoom In)',
                        onTap: () {
                          setState(() {
                            _zoom = (_zoom + 0.1).clamp(0.5, 3.0);
                            _activePreset = '사용자';
                          });
                        },
                      ),
                      const SizedBox(height: 6.0),
                      // 확실한 작동을 보장하는 줌아웃(-) 버튼
                      _buildCircleButton(
                        icon: Icons.remove,
                        tooltip: '축소 (Zoom Out)',
                        onTap: () {
                          setState(() {
                            _zoom = (_zoom - 0.1).clamp(0.5, 3.0);
                            _activePreset = '사용자';
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (isMobile)
            _buildMobileLegend(),

          const Divider(color: AppColors.hairline, height: 1.0),

          // 3. 하단 실시간 세부 수치 전광판
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: isMobile
                ? Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: _buildTelemetryCard('투구 구속', '${_speed.toStringAsFixed(0)} km/h', AppColors.primaryHover, speedPct, 'SPEED')),
                          const SizedBox(width: 8.0),
                          Expanded(child: _buildTelemetryCard('분당 회전 수 (RPM)', '${_rpm.toStringAsFixed(0)} rpm', AppColors.primary, rpmPct, 'RPM')),
                        ],
                      ),
                      const SizedBox(height: 8.0),
                      Row(
                        children: [
                          Expanded(child: _buildTelemetryCard('수평 변화량 (PFX_X)', '${_pfxX > 0 ? "+" : ""}${_pfxX.toStringAsFixed(1)} in', Colors.cyanAccent, pfxXPct, 'PFX_X')),
                          const SizedBox(width: 8.0),
                          Expanded(child: _buildTelemetryCard('수직 변화량 (PFX_Z)', '${_pfxZ > 0 ? "+" : ""}${_pfxZ.toStringAsFixed(1)} in', Colors.orangeAccent, pfxZPct, 'PFX_Z')),
                        ],
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Expanded(child: _buildTelemetryCard('투구 구속', '${_speed.toStringAsFixed(0)} km/h', AppColors.primaryHover, speedPct, 'SPEED')),
                      const SizedBox(width: 12.0),
                      Expanded(child: _buildTelemetryCard('분당 회전 수 (RPM)', '${_rpm.toStringAsFixed(0)} rpm', AppColors.primary, rpmPct, 'RPM')),
                      const SizedBox(width: 12.0),
                      Expanded(child: _buildTelemetryCard('수평 변화량 (PFX_X)', '${_pfxX > 0 ? "+" : ""}${_pfxX.toStringAsFixed(1)} in', Colors.cyanAccent, pfxXPct, 'PFX_X')),
                      const SizedBox(width: 12.0),
                      Expanded(child: _buildTelemetryCard('수직 변화량 (PFX_Z)', '${_pfxZ > 0 ? "+" : ""}${_pfxZ.toStringAsFixed(1)} in', Colors.orangeAccent, pfxZPct, 'PFX_Z')),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentedViews() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(color: AppColors.hairline),
      ),
      padding: const EdgeInsets.all(3.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSegmentViewItem('포수 뷰', '포수'),
          _buildSegmentViewItem('투수 뷰', '투수'),
          _buildSegmentViewItem('중계 뷰', '중계'),
        ],
      ),
    );
  }

  Widget _buildSegmentViewItem(String text, String preset) {
    final bool isActive = _activePreset == preset;
    return GestureDetector(
      onTap: () {
        _setCameraPreset(preset);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(18.0),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontWeight: FontWeight.w600,
            fontSize: 11.0,
            color: isActive ? AppColors.ink : AppColors.inkMuted,
          ),
        ),
      ),
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      textStyle: const TextStyle(
        fontFamily: AppTypography.fontFamily,
        fontSize: 11.0,
        color: Colors.white,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.85),
        borderRadius: BorderRadius.circular(4.0),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20.0),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.surface2,
            border: Border.all(color: AppColors.hairline),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.08),
                blurRadius: 4.0,
                spreadRadius: 1.0,
              ),
            ],
          ),
          child: Icon(icon, color: AppColors.ink, size: 16),
        ),
      ),
    );
  }

  Widget _buildMobileLegend() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      color: AppColors.surface1,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _visiblePitches.keys.map((name) {
            final Color pitchColor = _getPitchColor(name);
            final bool isSelected = _selectedPitchName == name;
            final bool isVisible = _visiblePitches[name] ?? true;

            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: GestureDetector(
                onTap: () {
                  _setMetricsForPitch(name);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? pitchColor.withOpacity(0.12) 
                        : AppColors.surface2,
                    borderRadius: BorderRadius.circular(20.0),
                    border: Border.all(
                      color: isSelected 
                          ? pitchColor 
                          : AppColors.hairline,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _visiblePitches[name] = !isVisible;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isVisible ? pitchColor : Colors.transparent,
                            border: Border.all(color: pitchColor, width: 1.5),
                          ),
                          child: isVisible
                              ? const Icon(Icons.check, size: 9, color: Colors.white)
                              : null,
                        ),
                      ),
                      const SizedBox(width: 8.0),
                      Text(
                        name,
                        style: TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                          fontSize: 11.5,
                          color: isSelected ? AppColors.ink : AppColors.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildTelemetryCard(String label, String value, Color color, double percent, String type) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
      decoration: BoxDecoration(
        color: AppColors.surface2.withOpacity(0.4),
        borderRadius: BorderRadius.circular(10.0),
        border: Border.all(color: AppColors.hairline.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: 9.5,
              color: AppColors.inkSubtle,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4.0),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'monospace',
              fontWeight: FontWeight.w700,
              fontSize: 14.5,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6.0),
          _buildGaugeBar(percent, color, type),
        ],
      ),
    );
  }

  Widget _buildGaugeBar(double percent, Color color, String type) {
    final bool isCenterBased = type == 'PFX_X' || type == 'PFX_Z';
    
    if (isCenterBased) {
      return Container(
        height: 4.0,
        decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: BorderRadius.circular(2.0),
        ),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.center,
              child: Container(
                width: 1.5,
                height: 4.0,
                color: AppColors.inkTertiary.withOpacity(0.5),
              ),
            ),
            Positioned.fill(
              child: FractionallySizedBox(
                alignment: percent < 0.5 ? Alignment.centerRight : Alignment.centerLeft,
                widthFactor: 0.5,
                child: FractionallySizedBox(
                  alignment: percent < 0.5 ? Alignment.centerRight : Alignment.centerLeft,
                  widthFactor: (percent - 0.5).abs() * 2.0,
                  child: Container(
                    height: 4.0,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2.0),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        height: 4.0,
        decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: BorderRadius.circular(2.0),
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: percent,
            child: Container(
              height: 4.0,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2.0),
              ),
            ),
          ),
        ),
      );
    }
  }

  static Color _getPitchColor(String name) {
    if (name.contains('직구') || name.contains('포심') || name.contains('속구') || name.contains('Fastball')) {
      return const Color(0xFFFF5252); 
    }
    if (name.contains('싱커') || name.contains('Sinker') || name.contains('투심')) {
      return const Color(0xFFFF7A00); 
    }
    if (name.contains('슬라이더') || name.contains('Slider')) {
      return const Color(0xFF40C4FF); 
    }
    if (name.contains('스위퍼') || name.contains('Sweeper')) {
      return const Color(0xFF00E5FF); 
    }
    if (name.contains('커터') || name.contains('Cutter')) {
      return const Color(0xFF2979FF); 
    }
    if (name.contains('체인지업') || name.contains('Changeup')) {
      return const Color(0xFFE040FB); 
    }
    if (name.contains('스플리터') || name.contains('Splitter') || name.contains('포크볼') || name.contains('Forkball')) {
      return const Color(0xFF00E676); 
    }
    if (name.contains('커브') || name.contains('Curveball') || name.contains('너클 커브') || name.contains('Knuckle Curve') || name.contains('슬러브') || name.contains('Slurve')) {
      return const Color(0xFFFFD740); 
    }
    return const Color(0xFFB0BEC5); 
  }
}

// -------------------------------------------------------------
// [6] 3D 드로잉 화가 클래스 (Pitch3DPainter)
// -------------------------------------------------------------
class Pitch3DPainter extends CustomPainter {
  final List<ProjectedTrajectory> projectedTrajectories;
  final List<List<Offset>> projectedGroundGridLines;
  final List<Offset> projectedHomePlate;
  final List<Offset> projectedStrikeZoneFront;
  final Offset projectedStrikeZoneCenterBottom;
  final Offset projectedStrikeZoneCenterTop;
  final List<Offset> projectedReleasePointPlane;
  final double progress;
  final Map<String, bool> visiblePitches;
  final String playerRole;

  Pitch3DPainter({
    required this.projectedTrajectories,
    required this.projectedGroundGridLines,
    required this.projectedHomePlate,
    required this.projectedStrikeZoneFront,
    required this.projectedStrikeZoneCenterBottom,
    required this.projectedStrikeZoneCenterTop,
    required this.projectedReleasePointPlane,
    required this.progress,
    required this.visiblePitches,
    required this.playerRole,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);

    _drawStarsAndGrid(canvas, size);
    _drawGroundGrid(canvas, size);
    _drawHomePlate(canvas, size);
    _drawStrikeZoneFront(canvas, size);
    _drawReleasePointPlane(canvas, size);
    _drawTrajectories(canvas, size);
  }

  void _drawStarsAndGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.canvas
      ..style = PaintingStyle.fill;
    canvas.drawRect(Offset.zero & size, paint);
  }

  void _drawGroundGrid(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = AppColors.hairline.withOpacity(0.5)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    for (final points in projectedGroundGridLines) {
      _drawSmoothLine(canvas, points, linePaint);
    }
  }

  void _drawHomePlate(Canvas canvas, Size size) {
    final platePaint = Paint()
      ..color = AppColors.ink.withOpacity(0.8)
      ..style = PaintingStyle.fill;

    final path = Path();
    for (int i = 0; i < projectedHomePlate.length; i++) {
      final pt = projectedHomePlate[i];
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    path.close();
    canvas.drawPath(path, platePaint);
  }

  void _drawStrikeZoneFront(Canvas canvas, Size size) {
    if (projectedStrikeZoneFront.length < 4) return;

    final szPaint = Paint()
      ..color = AppColors.primary.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    final szBorder = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final path = Path();
    final p1 = projectedStrikeZoneFront[0];
    final p2 = projectedStrikeZoneFront[1];
    final p3 = projectedStrikeZoneFront[2];
    final p4 = projectedStrikeZoneFront[3];

    path.moveTo(p1.dx, p1.dy);
    path.lineTo(p2.dx, p2.dy);
    path.lineTo(p3.dx, p3.dy);
    path.lineTo(p4.dx, p4.dy);
    path.close();

    canvas.drawPath(path, szPaint);
    canvas.drawPath(path, szBorder);

    final centerBorder = Paint()
      ..color = AppColors.primary.withOpacity(0.6)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawLine(projectedStrikeZoneCenterBottom, projectedStrikeZoneCenterTop, centerBorder);
  }

  void _drawReleasePointPlane(Canvas canvas, Size size) {
    if (projectedReleasePointPlane.length < 4) return;

    final releasePaint = Paint()
      ..color = Colors.cyanAccent.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final p1 = projectedReleasePointPlane[0];
    final p2 = projectedReleasePointPlane[1];
    final p3 = projectedReleasePointPlane[2];
    final p4 = projectedReleasePointPlane[3];

    final path = Path()
      ..moveTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..lineTo(p3.dx, p3.dy)
      ..lineTo(p4.dx, p4.dy)
      ..close();
    canvas.drawPath(path, releasePaint);
  }

  void _drawTrajectories(Canvas canvas, Size size) {
    for (final traj in projectedTrajectories) {
      final name = traj.pitchName;
      if (visiblePitches[name] != true) continue;

      final Color col = traj.color;
      final List<Offset> projectedPoints = traj.projectedPoints;

      if (projectedPoints.length >= 2) {
        for (int i = 0; i < projectedPoints.length - 1; i++) {
          final double t = i / (projectedPoints.length - 1);
          final segmentPaint = Paint()
            ..color = col.withOpacity(t * 0.65 + 0.1) 
            ..strokeWidth = t * 1.5 + 1.5 
            ..style = PaintingStyle.stroke;
          canvas.drawLine(projectedPoints[i], projectedPoints[i + 1], segmentPaint);
        }
      }

      final int animIndex = (progress * (projectedPoints.length - 1)).floor();
      if (animIndex < projectedPoints.length) {
        final ballPos = projectedPoints[animIndex];
        
        canvas.drawCircle(ballPos, 8.0, Paint()..color = col.withOpacity(0.3)..style = PaintingStyle.fill);
        canvas.drawCircle(ballPos, 4.0, Paint()..color = Colors.white..style = PaintingStyle.fill);
        canvas.drawCircle(ballPos, 4.0, Paint()..color = col..strokeWidth = 1.0..style = PaintingStyle.stroke);
      }

      final endPos2D = traj.plateIntersection2D;
      canvas.drawCircle(endPos2D, 3.0, Paint()..color = col..style = PaintingStyle.fill);
    }
  }

  void _drawSmoothLine(Canvas canvas, List<Offset> points, Paint paint) {
    if (points.length < 2) return;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant Pitch3DPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.visiblePitches != visiblePitches ||
        oldDelegate.playerRole != playerRole ||
        oldDelegate.projectedTrajectories != projectedTrajectories ||
        oldDelegate.projectedGroundGridLines != projectedGroundGridLines ||
        oldDelegate.projectedHomePlate != projectedHomePlate ||
        oldDelegate.projectedStrikeZoneFront != projectedStrikeZoneFront ||
        oldDelegate.projectedReleasePointPlane != projectedReleasePointPlane;
  }
}