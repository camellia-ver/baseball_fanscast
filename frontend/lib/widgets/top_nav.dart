import 'package:flutter/material.dart';
import '../theme.dart';

/// 앱 최상단에 고정되는 반응형 네비게이션 헤더 바 위젯입니다.
/// 
/// Scaffold의 appBar 슬롯에 연결하기 위해 [PreferredSizeWidget] 인터페이스를 상속합니다.
class TopNav extends StatelessWidget implements PreferredSizeWidget {
  /// 현재 사용자가 탭하여 활성화한 메뉴 인덱스 (0-based)
  final int activeIndex;
  
  /// 메뉴 탭 클릭 시 활성화 인덱스 전환을 부모에 전달하는 콜백
  final ValueChanged<int> onTabChanged;

  const TopNav({
    super.key,
    required this.activeIndex,
    required this.onTabChanged,
  });

  /// PreferredSizeWidget 구현 요건에 의거하여 헤더 바의 표준 세로 높이(56.0)를 지정합니다.
  @override
  Size get preferredSize => const Size.fromHeight(56.0);

  @override
  Widget build(BuildContext context) {
    // 뷰포트 너비를 구해 모바일 가로 제한 조건 분기점(960px)과 대조합니다.
    final double width = MediaQuery.of(context).size.width;
    final bool isMobile = width < 960;

    return Container(
      height: 56.0,
      decoration: const BoxDecoration(
        color: AppColors.canvas,
        border: Border(
          bottom: BorderSide(color: AppColors.hairline, width: 1.0),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween, // 좌측 로고 - 중앙 탭 - 우측 로그인 영역 정렬
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. 로고 및 타이틀 터치 구역 (터치 시 인덱스 0 홈으로 전환)
          GestureDetector(
            onTap: () => onTabChanged(0),
            child: Row(
              children: [
                // CustomPaint를 사용해 하단의 LogoPainter를 드로잉합니다.
                CustomPaint(
                  size: const Size(24, 24),
                  painter: LogoPainter(),
                ),
                const SizedBox(width: 8.0),
                const Text(
                  'baseball fancast',
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontWeight: FontWeight.w700,
                    fontSize: 18.0,
                    color: AppColors.ink,
                    letterSpacing: -0.4,
                  ),
                ),
              ],
            ),
          ),

          // 2. 중앙 메뉴 탭 리스트 (데스크톱 데모 전용, 모바일 시 숨김 처리)
          if (!isMobile)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildNavItem('Home', 0),
                const SizedBox(width: 24.0),
                _buildNavItem('데이터 분석실', 1),
                const SizedBox(width: 24.0),
                _buildNavItem('카드뉴스', 2),
                const SizedBox(width: 24.0),
                _buildNavItem('커뮤니티', 3),
                const SizedBox(width: 24.0),
                _buildNavItem('My Page', 4),
              ],
            ),

          // 3. 우측 액션 버튼 구역 (모바일에서는 햄버거 메뉴를 오픈)
          Row(
            children: [
              if (!isMobile) ...[
                _buildPrimaryButton('로그인'),
              ] else ...[
                IconButton(
                  icon: const Icon(Icons.menu, color: AppColors.ink),
                  onPressed: () {
                    // Scaffold의 상태(State)를 찾아와 우측 Drawer 메뉴를 서랍처럼 오픈합니다.
                    Scaffold.of(context).openEndDrawer();
                  },
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// 개별 텍스트 탭 위젯을 생성합니다. 활성화 여부에 따라 굵기와 채도를 다르게 적용합니다.
  Widget _buildNavItem(String label, int index) {
    final bool isActive = activeIndex == index;
    return InkWell(
      onTap: () => onTabChanged(index),
      borderRadius: BorderRadius.circular(4.0),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontWeight: isActive ? FontWeight.w500 : FontWeight.w300,
            fontSize: 14.0,
            color: isActive ? AppColors.ink : AppColors.inkSubtle,
            letterSpacing: -0.05,
          ),
        ),
      ),
    );
  }

  /// 마우스 오버 시 반응형 인터랙션을 주는 강조형(Primary) 호버 버튼을 조립합니다.
  Widget _buildPrimaryButton(String label) {
    return HoverButton(
      onPressed: () {},
      backgroundColor: AppColors.primary,
      hoverColor: AppColors.primaryHover,
      borderRadius: BorderRadius.circular(8.0),
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: AppTypography.fontFamily,
          fontWeight: FontWeight.w500,
          fontSize: 14.0,
          color: AppColors.ink,
        ),
      ),
    );
  }
}

/// Canvas 2D 드로잉 API를 활용하여 야구공 실밥을 포함한 로고를 수학적으로 그리는 Painter 클래스입니다.
class LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final center = Offset(w / 2, h / 2); // 캔버스 정중앙 좌표
    final radius = w / 2 - 2;            // 야구공 외곽 원 지름

    // 외곽 테두리 링 붓 설정
    final paint = Paint()
      ..color = AppColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // 흰색 바탕 원형 외벽 드로잉
    canvas.drawCircle(center, radius, paint);

    // 야구공 시그니처 보라색 실밥(Seams) 드로잉을 위한 붓 설정
    final seamPaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    // 왼쪽 실밥 베지에 곡선 경로 설정 (시작점 이동 후 조절점 기준으로 곡선 매핑)
    final leftPath = Path()
      ..moveTo(center.dx - radius * 0.707, center.dy - radius * 0.707)
      ..quadraticBezierTo(
        center.dx - radius * 0.2, center.dy, // 곡선이 모여드는 중앙 조절점
        center.dx - radius * 0.707, center.dy + radius * 0.707,
      );
    canvas.drawPath(leftPath, seamPaint);

    // 오른쪽 실밥 베지에 곡선 경로 설정
    final rightPath = Path()
      ..moveTo(center.dx + radius * 0.707, center.dy - radius * 0.707)
      ..quadraticBezierTo(
        center.dx + radius * 0.2, center.dy,
        center.dx + radius * 0.707, center.dy + radius * 0.707,
      );
    canvas.drawPath(rightPath, seamPaint);
  }

  /// 로고는 변경사항이 없는 정적 드로잉이므로 무조건 false(캐싱) 설정
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 웹/데스크톱 마우스 포인터 진입/퇴장을 감지하여 배경 컬러를 부드럽게 전환하는 애니메이션 버튼입니다.
class HoverButton extends StatefulWidget {
  final VoidCallback onPressed;
  final Widget child;
  final Color backgroundColor;
  final Color hoverColor;
  final BorderRadius borderRadius;
  final BoxBorder? border;
  final EdgeInsetsGeometry padding;

  const HoverButton({
    super.key,
    required this.onPressed,
    required this.child,
    required this.backgroundColor,
    required this.hoverColor,
    required this.borderRadius,
    this.border,
    required this.padding,
  });

  @override
  State<HoverButton> createState() => _HoverButtonState();
}

class _HoverButtonState extends State<HoverButton> {
  /// 현재 마우스 커서가 버튼 위에 떠 있는지 여부 상태값
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    // MouseRegion을 감싸 커서 진입/퇴장 상태를 갱신
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        // AnimatedContainer를 사용하여 배경색 변화 시 지정된 시간 동안 부드러운 그라데이션 트랜지션 연출
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150), // 0.15초 동안 전환
          padding: widget.padding,
          decoration: BoxDecoration(
            color: _isHovered ? widget.hoverColor : widget.backgroundColor,
            borderRadius: widget.borderRadius,
            border: widget.border,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
