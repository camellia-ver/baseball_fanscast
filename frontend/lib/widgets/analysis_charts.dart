import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme.dart';
import '../models/game_situation_model.dart';
import 'strike_zone.dart' show PitchTranslationService;


// -------------------------------------------------------------
// [1] 구종 무브먼트 맵 (MovementMapChart)
// -------------------------------------------------------------
class MovementMapChart extends StatelessWidget {
  final String playerRole;
  final List<PitchCoordinate> pitches;

  const MovementMapChart({
    super.key, 
    required this.playerRole,
    this.pitches = const [],
  });

  @override
  Widget build(BuildContext context) {
    final double currentWidth = MediaQuery.of(context).size.width;
    final bool isPitcher = playerRole == 'PITCHER';
    
    final List<ScatterSpot> spots = pitches.isNotEmpty
        ? pitches.map((p) {
            final double x = ((p.pfxX ?? 0.0) * 12).clamp(-24.0, 24.0);
            final double y = ((p.pfxZ ?? 0.0) * 12).clamp(-24.0, 24.0);
            final Color color = PitchTranslationService.getPitchColor(p.pitchType);
            return ScatterSpot(
              x,
              y,
              dotPainter: FlDotCirclePainter(radius: 4, color: color),
            );
          }).toList()
        : (isPitcher
            ? [
                ScatterSpot(8.5, 18.2, dotPainter: FlDotCirclePainter(radius: 4, color: const Color(0xFFFF5252))),
                ScatterSpot(8.0, 17.5, dotPainter: FlDotCirclePainter(radius: 4, color: const Color(0xFFFF5252))),
                ScatterSpot(9.0, 18.9, dotPainter: FlDotCirclePainter(radius: 4, color: const Color(0xFFFF5252))),
                ScatterSpot(-6.2, 2.1, dotPainter: FlDotCirclePainter(radius: 4, color: const Color(0xFF40C4FF))),
                ScatterSpot(-5.8, 1.8, dotPainter: FlDotCirclePainter(radius: 4, color: const Color(0xFF40C4FF))),
                ScatterSpot(-9.1, -12.4, dotPainter: FlDotCirclePainter(radius: 4, color: const Color(0xFFFFD740))),
                ScatterSpot(-8.7, -13.0, dotPainter: FlDotCirclePainter(radius: 4, color: const Color(0xFFFFD740))),
                ScatterSpot(9.8, 6.2, dotPainter: FlDotCirclePainter(radius: 4, color: const Color(0xFFE040FB))),
              ]
            : [
                ScatterSpot(8.2, 14.5, dotPainter: FlDotCirclePainter(radius: 4, color: const Color(0xFFFF5252))),
                ScatterSpot(7.8, 13.9, dotPainter: FlDotCirclePainter(radius: 4, color: const Color(0xFFFF5252))),
                ScatterSpot(-5.4, 1.2, dotPainter: FlDotCirclePainter(radius: 4, color: const Color(0xFF40C4FF))),
                ScatterSpot(-5.0, 0.8, dotPainter: FlDotCirclePainter(radius: 4, color: const Color(0xFF40C4FF))),
                ScatterSpot(-8.0, -10.8, dotPainter: FlDotCirclePainter(radius: 4, color: const Color(0xFFFFD740))),
                ScatterSpot(9.1, 5.1, dotPainter: FlDotCirclePainter(radius: 4, color: const Color(0xFFE040FB))),
              ]);

    return Container(
      height: 320,
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '구종 무브먼트 맵',
                    style: TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontWeight: FontWeight.w700,
                      fontSize: 14.0,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2.0),
                  Text(
                    isPitcher ? '순수 무브먼트 pfx_x, pfx_z 격자 좌표 2D 산점도' : '상대 투구의 무브먼트 pfx_x, pfx_z 격자 좌표 2D 산점도',
                    style: const TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontWeight: FontWeight.w300,
                      fontSize: 11.0,
                      color: AppColors.inkTertiary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(4.0),
                  border: Border.all(color: AppColors.hairline),
                ),
                child: const Text(
                  'PFX MOVEMENT',
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 10.0,
                    fontWeight: FontWeight.w700,
                    color: AppColors.inkSubtle,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20.0),
          Expanded(
            child: ScatterChart(
              ScatterChartData(
                // 💡 [조치] 버전별 에러 유발 속성(duration, swapAnimationDuration)을 모두 안전하게 제외
                scatterSpots: spots,
                minX: -25,
                maxX: 25,
                minY: -25,
                maxY: 25,
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: AppColors.hairline),
                ),
                gridData: FlGridData(
                  show: true,
                  drawHorizontalLine: true,
                  drawVerticalLine: true,
                  horizontalInterval: 10,
                  verticalInterval: 10,
                  getDrawingHorizontalLine: (val) {
                    final bool isCenter = val == 0;
                    return FlLine(
                      color: isCenter ? AppColors.inkSubtle.withOpacity(0.5) : AppColors.hairline.withOpacity(0.3),
                      strokeWidth: isCenter ? 1.5 : 0.8,
                    );
                  },
                  getDrawingVerticalLine: (val) {
                    final bool isCenter = val == 0;
                    return FlLine(
                      color: isCenter ? AppColors.inkSubtle.withOpacity(0.5) : AppColors.hairline.withOpacity(0.3),
                      strokeWidth: isCenter ? 1.5 : 0.8,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  leftTitles: AxisTitles(
                    axisNameWidget: const Text(
                      '수직 무브먼트 (pfx_z, 인치)',
                      style: TextStyle(fontFamily: AppTypography.fontFamily, fontSize: 10, color: AppColors.inkSubtle),
                    ),
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      interval: 10,
                      getTitlesWidget: (val, meta) => Text(
                        val.toInt().toString(),
                        style: const TextStyle(fontSize: 10, color: AppColors.inkSubtle),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    axisNameWidget: const Text(
                      '수평 무브먼트 (pfx_x, 인치)',
                      style: TextStyle(fontFamily: AppTypography.fontFamily, fontSize: 10, color: AppColors.inkSubtle),
                    ),
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      interval: 10,
                      getTitlesWidget: (val, meta) => Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          val.toInt().toString(),
                          style: const TextStyle(fontSize: 10, color: AppColors.inkSubtle),
                        ),
                      ),
                    ),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                scatterTouchData: ScatterTouchData(
                  enabled: currentWidth > 0 && pitches.isNotEmpty, 
                  handleBuiltInTouches: currentWidth > 0 && pitches.isNotEmpty,
                  touchTooltipData: ScatterTouchTooltipData(
                    getTooltipColor: (spot) => AppColors.surface3,
                    getTooltipItems: (ScatterSpot touchedSpot) {
                      String pitchName = '기타';
                      double pfxX = touchedSpot.x;
                      double pfxZ = touchedSpot.y;

                      if (pitches.isNotEmpty) {
                        double minDistance = double.infinity;
                        PitchCoordinate? closestPitch;
                        for (final p in pitches) {
                          final double px = ((p.pfxX ?? 0.0) * 12).clamp(-24.0, 24.0);
                          final double py = ((p.pfxZ ?? 0.0) * 12).clamp(-24.0, 24.0);
                          final double dist = (px - touchedSpot.x) * (px - touchedSpot.x) + 
                                              (py - touchedSpot.y) * (py - touchedSpot.y);
                          if (dist < minDistance) {
                            minDistance = dist;
                            closestPitch = p;
                          }
                        }
                        if (closestPitch != null) {
                          pitchName = PitchTranslationService.getPitchKoreanName(closestPitch.pitchType);
                          pfxX = closestPitch.pfxX != null ? closestPitch.pfxX! * 12 : touchedSpot.x;
                          pfxZ = closestPitch.pfxZ != null ? closestPitch.pfxZ! * 12 : touchedSpot.y;
                        }
                      } else {
                        final colorVal = touchedSpot.dotPainter.mainColor.value;
                        if (colorVal == const Color(0xFFFF5252).value) {
                          pitchName = '직구';
                        } else if (colorVal == const Color(0xFF40C4FF).value) {
                          pitchName = '슬라이더';
                        } else if (colorVal == const Color(0xFFFFD740).value) {
                          pitchName = '커브';
                        } else if (colorVal == const Color(0xFFE040FB).value) {
                          pitchName = '체인지업';
                        }
                      }

                      return ScatterTooltipItem(
                        '$pitchName\n수평: ${pfxX.toStringAsFixed(1)}", 수직: ${pfxZ.toStringAsFixed(1)}"',
                        textStyle: const TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontWeight: FontWeight.bold,
                          fontSize: 12.0,
                          color: Colors.white,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------
// [2] 타구 속도 vs 발사각 배럴 존 (LaunchAngleVelocityChart)
// -------------------------------------------------------------
class LaunchAngleVelocityChart extends StatelessWidget {
  final String playerRole;
  final List<Map<String, dynamic>> sprayPoints;

  const LaunchAngleVelocityChart({
    super.key, 
    required this.playerRole,
    this.sprayPoints = const [],
  });

  @override
  Widget build(BuildContext context) {
    final double currentWidth = MediaQuery.of(context).size.width;

    final List<ScatterSpot> spots = sprayPoints.isNotEmpty
        ? sprayPoints.map((p) {
            final double angle = (p['launchAngle'] as num? ?? 0.0).toDouble();
            final double speedMph = (p['launchSpeed'] as num? ?? 0.0).toDouble();
            final double speedKmh = speedMph * 1.60934;
            
            final bool isBarrel = angle >= 10 && angle <= 30 && speedKmh >= 145 && speedKmh <= 170;
            final Color color = isBarrel ? Colors.orangeAccent : Colors.cyanAccent;
            
            final double clampedAngle = angle.clamp(-28.0, 58.0);
            final double clampedSpeed = speedKmh.clamp(62.0, 178.0);
            
            return ScatterSpot(
              clampedAngle,
              clampedSpeed,
              dotPainter: FlDotCirclePainter(radius: 4, color: color),
            );
          }).toList()
        : [
            ScatterSpot(15, 160, dotPainter: FlDotCirclePainter(radius: 4, color: Colors.orangeAccent)),
            ScatterSpot(18, 155, dotPainter: FlDotCirclePainter(radius: 4, color: Colors.orangeAccent)),
            ScatterSpot(22, 162, dotPainter: FlDotCirclePainter(radius: 4, color: Colors.orangeAccent)),
            ScatterSpot(26, 158, dotPainter: FlDotCirclePainter(radius: 4, color: Colors.orangeAccent)),
            
            ScatterSpot(-12, 110, dotPainter: FlDotCirclePainter(radius: 4, color: Colors.cyanAccent)),
            ScatterSpot(5, 128, dotPainter: FlDotCirclePainter(radius: 4, color: Colors.cyanAccent)),
            ScatterSpot(8, 135, dotPainter: FlDotCirclePainter(radius: 4, color: Colors.cyanAccent)),
            ScatterSpot(12, 130, dotPainter: FlDotCirclePainter(radius: 4, color: Colors.cyanAccent)),
            ScatterSpot(35, 142, dotPainter: FlDotCirclePainter(radius: 4, color: Colors.cyanAccent)),
            ScatterSpot(48, 118, dotPainter: FlDotCirclePainter(radius: 4, color: Colors.cyanAccent)),
            ScatterSpot(-22, 95, dotPainter: FlDotCirclePainter(radius: 4, color: Colors.cyanAccent)),
          ];

    return Container(
      height: 320,
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '타구 속도 vs 발사각 (배럴 존)',
                    style: TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontWeight: FontWeight.w700,
                      fontSize: 14.0,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2.0),
                  const Text(
                    '이상적 장타 생산 영역(Barrel Zone) 및 정타 밀도 분석',
                    style: TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontWeight: FontWeight.w300,
                      fontSize: 11.0,
                      color: AppColors.inkTertiary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                decoration: BoxDecoration(
                  color: const Color(0xFF332211),
                  borderRadius: BorderRadius.circular(4.0),
                  border: Border.all(color: Colors.orangeAccent.withOpacity(0.5)),
                ),
                child: const Text(
                  'BARREL ZONE',
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 10.0,
                    fontWeight: FontWeight.w700,
                    color: Colors.orangeAccent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20.0),
          Expanded(
            child: Stack(
              children: [
                ScatterChart(
                  ScatterChartData(
                    scatterSpots: spots,
                    minX: -30,
                    maxX: 60,
                    minY: 60,
                    maxY: 180,
                    borderData: FlBorderData(
                      show: true,
                      border: Border.all(color: AppColors.hairline),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawHorizontalLine: true,
                      drawVerticalLine: true,
                      horizontalInterval: 20,
                      verticalInterval: 10,
                      getDrawingHorizontalLine: (val) => FlLine(color: AppColors.hairline.withOpacity(0.3), strokeWidth: 0.8),
                      getDrawingVerticalLine: (val) => FlLine(color: AppColors.hairline.withOpacity(0.3), strokeWidth: 0.8),
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      leftTitles: AxisTitles(
                        axisNameWidget: const Text(
                          '타구 속도 (km/h)',
                          style: TextStyle(fontFamily: AppTypography.fontFamily, fontSize: 10, color: AppColors.inkSubtle),
                        ),
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 32,
                          interval: 20,
                          getTitlesWidget: (val, meta) => Text(
                            val.toInt().toString(),
                            style: const TextStyle(fontSize: 10, color: AppColors.inkSubtle),
                          ),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        axisNameWidget: const Text(
                          '발사각 (도, °)',
                          style: TextStyle(fontFamily: AppTypography.fontFamily, fontSize: 10, color: AppColors.inkSubtle),
                        ),
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 22,
                          interval: 15,
                          getTitlesWidget: (val, meta) => Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              val.toInt().toString(),
                              style: const TextStyle(fontSize: 10, color: AppColors.inkSubtle),
                            ),
                          ),
                        ),
                      ),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    scatterTouchData: ScatterTouchData(
                      enabled: currentWidth > 0 && sprayPoints.isNotEmpty, 
                      handleBuiltInTouches: currentWidth > 0 && sprayPoints.isNotEmpty,
                      touchTooltipData: ScatterTouchTooltipData(
                        getTooltipColor: (spot) => AppColors.surface3,
                        getTooltipItems: (ScatterSpot touchedSpot) {
                          double angle = touchedSpot.x;
                          double speedKmh = touchedSpot.y;
                          bool isBarrel = false;

                          if (sprayPoints.isNotEmpty) {
                            double minDistance = double.infinity;
                            Map<String, dynamic>? closestPoint;
                            for (final p in sprayPoints) {
                              final double pAngle = (p['launchAngle'] as num? ?? 0.0).toDouble();
                              final double pSpeedMph = (p['launchSpeed'] as num? ?? 0.0).toDouble();
                              final double pSpeedKmh = pSpeedMph * 1.60934;
                              final double clampedAngle = pAngle.clamp(-28.0, 58.0);
                              final double clampedSpeed = pSpeedKmh.clamp(62.0, 178.0);

                              final double dist = (clampedAngle - touchedSpot.x) * (clampedAngle - touchedSpot.x) + 
                                                  (clampedSpeed - touchedSpot.y) * (clampedSpeed - touchedSpot.y);
                              if (dist < minDistance) {
                                minDistance = dist;
                                closestPoint = p;
                              }
                            }
                            if (closestPoint != null) {
                              angle = (closestPoint['launchAngle'] as num? ?? 0.0).toDouble();
                              final double pSpeedMph = (closestPoint['launchSpeed'] as num? ?? 0.0).toDouble();
                              speedKmh = pSpeedMph * 1.60934;
                              isBarrel = angle >= 10 && angle <= 30 && speedKmh >= 145 && speedKmh <= 170;
                            }
                          } else {
                            isBarrel = touchedSpot.dotPainter.mainColor.value == Colors.orangeAccent.value;
                          }

                          final String title = isBarrel ? '배럴 타구' : '일반 타구';
                          return ScatterTooltipItem(
                            '$title\n발사각: ${angle.toStringAsFixed(1)}°, 속도: ${speedKmh.toStringAsFixed(1)} km/h',
                            textStyle: const TextStyle(
                              fontFamily: AppTypography.fontFamily,
                              fontWeight: FontWeight.bold,
                              fontSize: 12.0,
                              color: Colors.white,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: BarrelZoneOverlayPainter(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------
// [3] 배럴 존 영역 강조 드로잉 (BarrelZoneOverlayPainter)
// -------------------------------------------------------------
class BarrelZoneOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const double leftPadding = 52.0;
    const double rightPadding = 12.0;
    const double bottomPadding = 36.0;
    const double topPadding = 12.0;

    final double plotW = size.width - leftPadding - rightPadding;
    final double plotH = size.height - bottomPadding - topPadding;

    double mapX(double xVal) {
      final double pct = (xVal - (-30)) / (60 - (-30));
      return leftPadding + pct * plotW;
    }

    double mapY(double yVal) {
      final double pct = (yVal - 60) / (180 - 60);
      return size.height - bottomPadding - pct * plotH;
    }

    final double left = mapX(10);
    final double right = mapX(30);
    final double top = mapY(170);
    final double bottom = mapY(145);

    final rect = Rect.fromLTRB(left, top, right, bottom);

    final bgPaint = Paint()
      ..color = Colors.orangeAccent.withOpacity(0.08)
      ..style = PaintingStyle.fill;
    canvas.drawRect(rect, bgPaint);

    final strokePaint = Paint()
      ..color = Colors.orangeAccent.withOpacity(0.7)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    _drawDashedRect(canvas, rect, strokePaint, 4.0, 3.0);
  }

  void _drawDashedRect(Canvas canvas, Rect rect, Paint paint, double dashLength, double gapLength) {
    void drawDashedLine(Offset p1, Offset p2) {
      final double dx = p2.dx - p1.dx;
      final double dy = p2.dy - p1.dy;
      final double distance = math.sqrt(dx * dx + dy * dy);
      final double steps = distance / (dashLength + gapLength);

      for (int i = 0; i < steps; i++) {
        final double tStart = i / steps;
        final double tEnd = (i + 0.6) / steps;
        canvas.drawLine(
          Offset(p1.dx + dx * tStart, p1.dy + dy * tStart),
          Offset(p1.dx + dx * tEnd, p1.dy + dy * tEnd),
          paint,
        );
      }
    }

    drawDashedLine(Offset(rect.left, rect.top), Offset(rect.right, rect.top));
    drawDashedLine(Offset(rect.right, rect.top), Offset(rect.right, rect.bottom));
    drawDashedLine(Offset(rect.right, rect.bottom), Offset(rect.left, rect.bottom));
    drawDashedLine(Offset(rect.left, rect.bottom), Offset(rect.left, rect.top));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// -------------------------------------------------------------
// [4] WPA 경기 기대 승률 변곡점 그래프 (WinProbabilityChart)
// -------------------------------------------------------------
class WinProbabilityChart extends StatelessWidget {
  final String playerRole; 
  final List<WinProbabilityPoint> timeline; 
  final String gameDate; 
  final String homeTeamName; 

  const WinProbabilityChart({
    super.key, 
    required this.playerRole,
    this.timeline = const [], 
    this.gameDate = '05/30',
    this.homeTeamName = '홈팀',
  });

  @override
  Widget build(BuildContext context) {
    final double currentWidth = MediaQuery.of(context).size.width;
    final bool isPitcher = playerRole == 'PITCHER';
    
    final List<FlSpot> spots;
    final Map<double, String> xToLabelMap = {};

    if (timeline.isNotEmpty) {
      spots = [];
      for (int i = 0; i < timeline.length; i++) {
        final point = timeline[i];
        double xVal = (i + 1).toDouble();
        final RegExp regExp = RegExp(r'(\d+)회(초|말)');
        final match = regExp.firstMatch(point.inningLabel);
        
        if (match != null) {
          final double inningNum = double.parse(match.group(1)!);
          final bool isBot = match.group(2) == '말';
          xVal = inningNum + (isBot ? 0.5 : 0.0);
        }
        
        spots.add(FlSpot(xVal, point.homeWinPct * 100));
        xToLabelMap[xVal] = point.inningLabel;
      }
    } else {
      spots = isPitcher
        ? const [
            FlSpot(1, 50),
            FlSpot(2.5, 60),
            FlSpot(4.5, 75),
            FlSpot(6.5, 82),
            FlSpot(9, 95),
          ]
        : const [
            FlSpot(1, 45),
            FlSpot(2.5, 62),
            FlSpot(5, 80),
            FlSpot(7.5, 60),
            FlSpot(9, 92),
          ];

      for (final spot in spots) {
        final int inningNum = spot.x.floor();
        final bool isBot = (spot.x - inningNum) > 0.1;
        xToLabelMap[spot.x] = '$inningNum회${isBot ? "말" : "초"}';
      }
    }

    final String matchLabel = gameDate;

    return Container(
      height: 300,
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '경기 흐름 및 WPA 승률 변곡점 그래프',
                    style: TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontWeight: FontWeight.w700,
                      fontSize: 14.0,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2.0),
                  Text(
                    '$homeTeamName(홈) 기대 승리확률 변곡 영역 하이라이트 및 WPA 분석',
                    style: const TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontWeight: FontWeight.w300,
                      fontSize: 11.0,
                      color: AppColors.inkTertiary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4.0),
                  border: Border.all(color: AppColors.primary.withOpacity(0.4)),
                ),
                child: Text(
                  matchLabel,
                  style: const TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 10.0,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primaryHover,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24.0),
          
          // --- 차트 영역 (LineChart) ---
          Expanded(
            child: LineChart(
              LineChartData(
                lineTouchData: LineTouchData(
                  enabled: currentWidth > 0 && spots.isNotEmpty,
                  handleBuiltInTouches: currentWidth > 0 && spots.isNotEmpty,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (spot) => AppColors.surface3,
                    getTooltipItems: (List<LineBarSpot> touchedSpots) {
                      return touchedSpots.map((barSpot) {
                        final int val = barSpot.y.round();
                        return LineTooltipItem(
                          '$val%',
                          const TextStyle(
                            fontFamily: AppTypography.fontFamily,
                            fontWeight: FontWeight.w700,
                            fontSize: 13.0,
                            color: Colors.white,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
                minX: 1,
                maxX: spots.isEmpty ? 9.0 : math.max(9.0, spots.map((s) => s.x).reduce(math.max)),
                minY: 0,
                maxY: 100,
                borderData: FlBorderData(show: false), 
                
                gridData: FlGridData(
                  show: true,
                  drawHorizontalLine: true, 
                  drawVerticalLine: false,
                  horizontalInterval: 20, 
                  getDrawingHorizontalLine: (val) => FlLine(
                    color: val == 50 ? AppColors.inkSubtle.withOpacity(0.3) : AppColors.hairline.withOpacity(0.2),
                    strokeWidth: val == 50 ? 1.2 : 0.8,
                  ),
                ),
                
                titlesData: FlTitlesData(
                  show: true,
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      interval: 20,
                      getTitlesWidget: (val, meta) => Text(
                        '${val.toInt()}%',
                        style: const TextStyle(fontSize: 10, color: AppColors.inkSubtle),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      interval: 0.5, 
                      getTitlesWidget: (val, meta) {
                        final double closestX = xToLabelMap.keys.firstWhere(
                          (x) => (x - val).abs() < 0.1,
                          orElse: () => -1.0,
                        );

                        if (closestX == -1.0) {
                          return const SizedBox.shrink();
                        }

                        final String label = xToLabelMap[closestX] ?? '';
                        return Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            label,
                            style: const TextStyle(
                              fontFamily: AppTypography.fontFamily,
                              fontSize: 10,
                              color: AppColors.inkSubtle,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true, 
                    curveSmoothness: 0.35, 
                    color: AppColors.primary, 
                    barWidth: 3.5, 
                    isStrokeCapRound: true, 
                    
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                        radius: 5,
                        color: Colors.white, 
                        strokeColor: AppColors.primary, 
                        strokeWidth: 2,
                      ),
                    ),
                    
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary.withOpacity(0.3), 
                          AppColors.primary.withOpacity(0.01), 
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------
// [5] 최근 경기력 사이클 및 변화 추이 (PerformanceTrendChart)
// -------------------------------------------------------------
class PerformanceTrendChart extends StatelessWidget {
  final String playerRole;
  final List<Map<String, dynamic>> trends;

  const PerformanceTrendChart({
    super.key, 
    required this.playerRole,
    this.trends = const [],
  });

  @override
  Widget build(BuildContext context) {
    final double currentWidth = MediaQuery.of(context).size.width;
    final bool isPitcher = playerRole == 'PITCHER';

    final List<FlSpot> leftSpots;
    final List<FlSpot> rightSpots;
    final List<String> dates;
    
    double minLVal = isPitcher ? 1.80 : 0.310;
    double maxLVal = isPitcher ? 2.40 : 0.325;
    double minRVal = isPitcher ? 0.88 : 0.900;
    double maxRVal = isPitcher ? 1.04 : 0.955;

    if (trends.isNotEmpty) {
      leftSpots = [];
      rightSpots = [];
      dates = [];
      for (int i = 0; i < trends.length; i++) {
        final t = trends[i];
        final double x = (i + 1).toDouble();
        leftSpots.add(FlSpot(x, (t['val1'] as num? ?? 0.0).toDouble()));
        rightSpots.add(FlSpot(x, (t['val2'] as num? ?? 0.0).toDouble()));
        dates.add(t['date'] ?? '');
      }
      
      double calculatedMinL = double.infinity;
      double calculatedMaxL = -double.infinity;
      double calculatedMinR = double.infinity;
      double calculatedMaxR = -double.infinity;
      for (final spot in leftSpots) {
        if (spot.y < calculatedMinL) calculatedMinL = spot.y;
        if (spot.y > calculatedMaxL) calculatedMaxL = spot.y;
      }
      for (final spot in rightSpots) {
        if (spot.y < calculatedMinR) calculatedMinR = spot.y;
        if (spot.y > calculatedMaxR) calculatedMaxR = spot.y;
      }
      
      if (calculatedMinL == calculatedMaxL) {
        minLVal = calculatedMinL - (isPitcher ? 0.3 : 0.01);
        maxLVal = calculatedMaxL + (isPitcher ? 0.3 : 0.01);
      } else {
        final double pad = (calculatedMaxL - calculatedMinL) * 0.2;
        minLVal = calculatedMinL - pad;
        maxLVal = calculatedMaxL + pad;
      }
      
      if (calculatedMinR == calculatedMaxR) {
        minRVal = calculatedMinR - (isPitcher ? 0.1 : 0.01);
        maxRVal = calculatedMaxR + (isPitcher ? 0.1 : 0.01);
      } else {
        final double pad = (calculatedMaxR - calculatedMinR) * 0.2;
        minRVal = calculatedMinR - pad;
        maxRVal = calculatedMaxR + pad;
      }
    } else {
      leftSpots = isPitcher
          ? const [
              FlSpot(1, 2.35),
              FlSpot(2, 2.22),
              FlSpot(3, 2.15),
              FlSpot(4, 2.02),
              FlSpot(5, 1.88),
              FlSpot(6, 1.98),
              FlSpot(7, 1.92),
            ]
          : const [
              FlSpot(1, 0.311),
              FlSpot(2, 0.314),
              FlSpot(3, 0.312),
              FlSpot(4, 0.317),
              FlSpot(5, 0.316),
              FlSpot(6, 0.321),
              FlSpot(7, 0.318),
            ];

      rightSpots = isPitcher
          ? const [
              FlSpot(1, 1.02),
              FlSpot(2, 0.98),
              FlSpot(3, 0.96),
              FlSpot(4, 0.92),
              FlSpot(5, 0.90),
              FlSpot(6, 0.95),
              FlSpot(7, 0.92),
            ]
          : const [
              FlSpot(1, 0.912),
              FlSpot(2, 0.925),
              FlSpot(3, 0.922),
              FlSpot(4, 0.938),
              FlSpot(5, 0.934),
              FlSpot(6, 0.948),
              FlSpot(7, 0.944),
            ];
      dates = const ['5/18', '5/20', '5/22', '5/24', '5/26', '5/28', '5/31'];
    }

    if (minLVal < 0.0) minLVal = 0.0;
    if (minRVal < 0.0) minRVal = 0.0;

    final double minL = minLVal;
    final double maxL = maxLVal;
    final double minR = minRVal;
    final double maxR = maxRVal;

    final double rangeL = maxL - minL;
    final double leftInterval = rangeL > 0 ? rangeL / 5 : 0.1;

    final List<FlSpot> normalizedRightSpots = rightSpots.map((spot) {
      final double normalizedValue = (spot.y - minR) / (maxR - minR);
      final double mappedValue = minL + normalizedValue * (maxL - minL);
      return FlSpot(spot.x, mappedValue);
    }).toList();

    return Container(
      height: 320,
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isPitcher ? '투구 방어 퍼포먼스 추세' : '타격 사이클 트렌드 추세',
                    style: const TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontWeight: FontWeight.w700,
                      fontSize: 14.0,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2.0),
                  const Text(
                    '최근 10경기 이동평균 지표 추적',
                    style: TextStyle(
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
                  _buildLegendLabel(isPitcher ? '방어율 (ERA)' : '타율 (AVG)', Colors.cyanAccent),
                  const SizedBox(width: 16.0),
                  _buildLegendLabel(isPitcher ? 'WHIP (이닝당 출루허용)' : 'OPS (출루율+장타율)', Colors.orangeAccent),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24.0),
          Expanded(
            child: LineChart(
              LineChartData(
                minX: 0.5,
                maxX: leftSpots.isEmpty ? 7.5 : leftSpots.length.toDouble() + 0.5,
                minY: minL,
                maxY: maxL,
                clipData: const FlClipData.all(),
                borderData: FlBorderData(show: false),

                lineTouchData: LineTouchData(
                  enabled: currentWidth > 0 && leftSpots.isNotEmpty,
                  handleBuiltInTouches: currentWidth > 0 && leftSpots.isNotEmpty,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (touchedBar) => AppColors.surface1.withOpacity(0.9),
                    
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((touchedSpot) {
                        final barIndex = touchedSpot.barIndex;
                        final double yVal = touchedSpot.y;

                        if (barIndex == 0) {
                          String formattedValue = yVal.toStringAsFixed(3);
                          return LineTooltipItem(
                            formattedValue,
                            const TextStyle(
                              color: Colors.cyanAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          );
                        } else {
                          final double pct = ((yVal - minL) / (maxL - minL)).clamp(0.0, 1.0);
                          final double deNorm = minR + pct * (maxR - minR);
                          String formattedValue = deNorm.toStringAsFixed(3);

                          return LineTooltipItem(
                            formattedValue,
                            const TextStyle(
                              color: Colors.orangeAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          );
                        }
                      }).toList() as dynamic; 
                    },
                  ),
                ),

                gridData: FlGridData(
                  show: true,
                  drawHorizontalLine: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (val) => FlLine(color: AppColors.hairline.withOpacity(0.2), strokeWidth: 0.8),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 42,
                      interval: leftInterval,
                      getTitlesWidget: (val, meta) => Text(
                         isPitcher ? val.toStringAsFixed(2) : '.${(val * 1000).toInt().toString()}',
                        style: const TextStyle(fontSize: 9, color: Colors.cyanAccent),
                      ),
                    ),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 42,
                      interval: leftInterval,
                      getTitlesWidget: (val, meta) {
                        final double pct = ((val - minL) / (maxL - minL)).clamp(0.0, 1.0);
                        final double deNorm = minR + pct * (maxR - minR);
                        return Text(
                          isPitcher ? deNorm.toStringAsFixed(2) : '.${(deNorm * 1000).toInt().toString()}',
                          style: const TextStyle(fontSize: 9, color: Colors.orangeAccent),
                          textAlign: TextAlign.right,
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      interval: 1,
                      getTitlesWidget: (val, meta) {
                        if ((val - meta.min).abs() < 0.001 || (val - meta.max).abs() < 0.001) {
                          return const SizedBox.shrink();
                        }
                        final int idx = val.toInt() - 1;
                        if (idx >= 0 && idx < dates.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              dates[idx],
                              style: const TextStyle(fontSize: 9, color: AppColors.inkSubtle),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: leftSpots,
                    isCurved: true,
                    preventCurveOverShooting: true,
                    color: Colors.cyanAccent,
                    barWidth: 2.5,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                        radius: 3.5,
                        color: Colors.white,
                        strokeColor: Colors.cyan,
                        strokeWidth: 1.5,
                      ),
                    ),
                  ),
                  LineChartBarData(
                    spots: normalizedRightSpots,
                    isCurved: true,
                    preventCurveOverShooting: true,
                    color: Colors.orangeAccent,
                    barWidth: 2.5,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                        radius: 3.5,
                        color: Colors.white,
                        strokeColor: Colors.orange,
                        strokeWidth: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendLabel(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 3,
          color: color,
        ),
        const SizedBox(width: 6.0),
        Text(
          label,
          style: const TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontSize: 11.0,
            color: AppColors.inkMuted,
          ),
        ),
      ],
    );
  }
}