import 'package:flutter/material.dart';
import '../theme.dart';
import 'top_nav.dart'; // TopNav의 LogoPainter를 재활용하기 위해 수입

/// 애플리케이션 최하단에 항상 위치하는 정적 푸터(Footer) 위젯입니다.
/// 
/// 서비스 정보, 관련 약관 링크 목록, 저작권 카피라이트 문구 등을
/// 데스크톱 및 모바일 가로 너비 해상도에 적응하는 반응형 구조로 드로잉합니다.
class Footer extends StatelessWidget {
  const Footer({super.key});

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    // 960px 미만인 좁은 너비의 모바일 화면인 경우 세로 정렬 컬럼 구조로 전환합니다.
    final bool isMobile = width < 960;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.canvas,
        border: Border(
          top: BorderSide(color: AppColors.hairline, width: 1.0),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 64.0, horizontal: 32.0),
      child: Column(
        children: [
          // 1. 상단 링크 맵 영역 (모바일 및 데스크톱 정렬 분기 처리)
          if (!isMobile)
            // 데스크톱 레이아웃: 브랜드 요약 설명(좌측) 및 3개의 카테고리 링크 컬럼(우측)을 양끝 배치
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
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
                    const SizedBox(height: 16.0),
                    const Text(
                      '차세대 야구 분석 및 팬 커뮤니티 플랫폼',
                      style: TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontWeight: FontWeight.w300,
                        fontSize: 14.0,
                        color: AppColors.inkTertiary,
                      ),
                    ),
                  ],
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLinkColumn('서비스', const ['실시간 분석실', '3D 트랙킹', '승률 시뮬레이터', '커뮤니티']),
                    const SizedBox(width: 64.0),
                    _buildLinkColumn('개발 정보', const ['API 문서', '릴리즈 노트', 'GitHub', 'Linear Design']),
                    const SizedBox(width: 64.0),
                    _buildLinkColumn('회사 및 정책', const ['소개', '보안 규정', '개인정보 처리방침', '이용약관']),
                  ],
                ),
              ],
            )
          else
            // 모바일 레이아웃: 좁은 폭에 대응하기 위해 모든 정보를 세로형 일자 컬럼으로 재정렬
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
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
                const SizedBox(height: 16.0),
                const Text(
                  '차세대 야구 분석 및 팬 커뮤니티 플랫폼',
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontWeight: FontWeight.w300,
                    fontSize: 14.0,
                    color: AppColors.inkTertiary,
                  ),
                ),
                const SizedBox(height: 32.0),
                // Wrap 위젯으로 가로 공간 소진 시 자동으로 아래행으로 드롭다운 줄바꿈
                Wrap(
                  spacing: 48.0,
                  runSpacing: 24.0,
                  children: [
                    _buildLinkColumn('서비스', const ['실시간 분석실', '3D 트랙킹', '커뮤니티']),
                    _buildLinkColumn('개발 정보', const ['API', '릴리즈 노트']),
                    _buildLinkColumn('정책', const ['이용약관', '개인정보']),
                  ],
                ),
              ],
            ),

          const SizedBox(height: 48.0),
          const Divider(color: AppColors.hairlineTertiary),
          const SizedBox(height: 16.0),

          // 2. 하단 영역 (저작권 표시 및 언어/공유 보조 아이콘)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '© 2026 baseball fancast Inc. All rights reserved.',
                style: TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontWeight: FontWeight.w300,
                  fontSize: 12.0,
                  color: AppColors.inkTertiary,
                ),
              ),
              Row(
                children: [
                  _buildSocialIcon(Icons.language),
                  const SizedBox(width: 16.0),
                  _buildSocialIcon(Icons.share),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 개별 테마 링크 컬럼을 생성합니다.
  Widget _buildLinkColumn(String title, List<String> links) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontWeight: FontWeight.w500,
            fontSize: 14.0,
            color: AppColors.inkSubtle,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 16.0),
        // Spread 연산자를 활용하여 텍스트 링크들을 차례대로 Column 자식으로 나열
        ...links.map((link) => Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: MouseRegion(
                cursor: SystemMouseCursors.click, // 호버링 시 손가락 포인터로 변환
                child: Text(
                  link,
                  style: const TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontWeight: FontWeight.w300,
                    fontSize: 13.0,
                    color: AppColors.inkTertiary,
                  ),
                ),
              ),
            )),
      ],
    );
  }

  /// 클릭 가능한 소셜 미디어 웹 아이콘을 구성합니다.
  Widget _buildSocialIcon(IconData icon) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Icon(
        icon,
        size: 18.0,
        color: AppColors.inkTertiary,
      ),
    );
  }
}
