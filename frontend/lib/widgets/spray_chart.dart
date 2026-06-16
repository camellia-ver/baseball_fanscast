import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme.dart';

/// 타구 낙하 지점 공간 분포 스프레이 차트 (SprayChartVisualizer)입니다.
/// 
/// 야구 그라운드 2D 탑다운 평면을 직접 드로잉하고, 극좌표계(각도와 비거리)로 구성된
/// 타구 낙하 포인트 데이터를 2D 화면 픽셀 좌표(x, y)로 수학적 변환하여 산점도를 맵핑합니다.
class SprayChartVisualizer extends StatefulWidget {
  /// 'HITTER'(타자) 또는 'PITCHER'(투수) 역할 구분
  final String playerRole;
  final List<SprayPoint> points;

  const SprayChartVisualizer({
    super.key, 
    required this.playerRole,
    this.points = const [],
  });

  @override
  State<SprayChartVisualizer> createState() => _SprayChartVisualizerState();
}

class _SprayChartVisualizerState extends State<SprayChartVisualizer> {
  // 데모 타구 결과 데이터 목록 (angle: 각도, distance: 비거리 ft, type: 결과)
  // 타격각 -45도(3루 파울라인) ~ +45도(1루 파울라인), 0도(2루 정중앙 외야) 기준
  final List<SprayPoint> _batterHits = [
    SprayPoint(angle: -30, distance: 280, type: 'HIT'),
    SprayPoint(angle: -15, distance: 340, type: 'HIT'),
    SprayPoint(angle: 0, distance: 395, type: 'HR'),
    breakPoint(10, 320, 'HIT'), // 가독성 헬퍼 또는 기존 명시 데이터
    SprayPoint(angle: 25, distance: 290, type: 'HIT'),
    SprayPoint(angle: -5, distance: 410, type: 'HR'),
    SprayPoint(angle: -20, distance: 210, type: 'OUT'),
    SprayPoint(angle: -40, distance: 150, type: 'OUT'),
    SprayPoint(angle: 0, distance: 310, type: 'OUT'),
    SprayPoint(angle: 15, distance: 240, type: 'OUT'),
    SprayPoint(angle: 35, distance: 320, type: 'OUT'),
    SprayPoint(angle: -10, distance: 120, type: 'OUT'),
  ];

  static SprayPoint breakPoint(double angle, double dist, String type) => 
      SprayPoint(angle: angle, distance: dist, type: type);

  final List<SprayPoint> _pitcherHits = [
    SprayPoint(angle: -25, distance: 260, type: 'HIT'),
    SprayPoint(angle: 5, distance: 310, type: 'HIT'),
    SprayPoint(angle: 30, distance: 270, type: 'HIT'),
    SprayPoint(angle: -35, distance: 330, type: 'OUT'),
    SprayPoint(angle: -15, distance: 210, type: 'OUT'),
    SprayPoint(angle: 0, distance: 380, type: 'OUT'),
    SprayPoint(angle: 10, distance: 160, type: 'OUT'),
    SprayPoint(angle: 20, distance: 290, type: 'OUT'),
    SprayPoint(angle: 40, distance: 180, type: 'OUT'),
  ];

  /// 투수/타격 상태 구분에 따른 활성 타구 포인트 획득
  List<SprayPoint> get _currentPoints {
    if (widget.points.isNotEmpty) {
      return widget.points;
    }
    return widget.playerRole == 'PITCHER' ? _pitcherHits : _batterHits;
  }

  @override
  Widget build(BuildContext context) {
    final bool isPitcher = widget.playerRole == 'PITCHER';
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
          // 1. 헤더 타이틀 및 점 종류 설명 범례
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isPitcher ? '피안타 공간 분포 스프레이 차트' : '극좌표계 타구 스프레이 차트',
                    style: const TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontWeight: FontWeight.w700,
                      fontSize: 16.0,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2.0),
                  Text(
                    isPitcher ? '야구장 2D 레이아웃 기반 피안타/피홈런 마커 산점도' : '야구장 2D 레이아웃 기반 극좌표 안타/홈런 마커 산점도',
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
                children: isPitcher
                    ? [
                        _buildLegendItem('피안타', const Color(0xFF27A644)),
                        const SizedBox(width: 12.0),
                        _buildLegendItem('범타', AppColors.inkSubtle),
                      ]
                    : [
                        _buildLegendItem('안타', const Color(0xFF27A644)),
                        const SizedBox(width: 12.0),
                        _buildLegendItem('홈런', Colors.orangeAccent),
                        const SizedBox(width: 12.0),
                        _buildLegendItem('아웃', AppColors.inkSubtle),
                      ],
              ),
            ],
          ),

          const SizedBox(height: 24.0),

          // 2. 야구장 외벽 및 그라운드 CustomPainter 드로잉 구역
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // 부채꼴 구조가 비율에 맞게 조립되도록 크기 한정
                final double sizeLimit = math.min(constraints.maxWidth, constraints.maxHeight);
                return Center(
                  child: SizedBox(
                    width: sizeLimit * 1.2,
                    height: sizeLimit,
                    child: CustomPaint(
                      painter: BaseballFieldPainter(
                        points: _currentPoints,
                        playerRole: widget.playerRole,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 범례 정보 박스 조립 헬퍼
  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
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

/// 개별 타구 데이터를 정의하는 정보 구조체입니다.
class SprayPoint {
  final double angle;    // 3루 파울선(-45도) ~ 1루 파울선(+45도) 각도 값
  final double distance; // 홈플레이트 기점 타구 비거리 (ft 피트 단위)
  final String type;     // 타구 종류 결과 ('HIT', 'HR', 'OUT')

  SprayPoint({
    required this.angle,
    required this.distance,
    required this.type,
  });
}

/// 야구장 그라운드, 흙 다이아몬드, 내외야 펜스 및 타구 안타/홈런 마커를 캔버스에 그리는 Painter 클래스입니다.
class BaseballFieldPainter extends CustomPainter {
  final List<SprayPoint> points;
  final String playerRole;

  BaseballFieldPainter({required this.points, required this.playerRole});

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

    // 외야 담장 펜스 라인 그리기
    // 실제 야구장은 파울폴보다 중앙 담장(400ft) 거리가 머므로 
    // 코사인 삼각비 가중치를 곱해 자연스러운 아치형 부채꼴 담장을 생성합니다.
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
    // 홈(0) -> 1루(90) -> 2루(127.28) -> 3루(90)를 잇는 적갈색 다이아몬드 사각형 그리기
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

    // 3. 개별 타구 결과 마커 흩뿌리기
    for (final p in points) {
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
      
      canvas.drawCircle(pt, 5.5, dotPaint);

      // 아웃이 아닌 정상 안타/홈런인 경우 점 복판에 입체성을 주기 위한 흰색 링 코어 추가
      if (p.type != 'OUT') {
        canvas.drawCircle(
          pt,
          5.5,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant BaseballFieldPainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.playerRole != playerRole;
  }
}
