import 'package:flutter/material.dart';

/// 애플리케이션의 색상 시스템 (Color Palette)을 통합 관리하는 토큰 클래스입니다.
/// 
/// static const를 활용해 메모리 효율을 극대화하고 앱 전반에 걸쳐 일관성 있는 색상을 표현합니다.
class AppColors {
  // 플러터 16진수 ARGB 표기법: 0xFF(불투명) + 6자리 HexCode
  
  /// 가장 기본이 되는 백그라운드 캔버스 색상 (어두운 블랙 계열)
  static const Color canvas = Color(0xFF010102);       
  
  /// 컴포넌트, 카드 등의 카드 영역 배경색 (어두운 회색)
  static const Color surface1 = Color(0xFF0C0D0E);     
  
  /// surface1 보다 대비가 강한 하이라이트 배경색
  static const Color surface2 = Color(0xFF17191D);     
  
  /// 경계 영역 식별을 위한 밝은 그레이 배경색
  static const Color surface3 = Color(0xFF202227);     
  
  /// 칩(Chip) 및 버튼 배경용 회색
  static const Color surface4 = Color(0xFF262930);     
  
  /// 컴포넌트 분리용 얇은 구분선 색상 (Hairline Border)
  static const Color hairline = Color(0xFF23252A);     
  
  /// 명확한 테두리 구분을 위한 강한 테두리선 색상
  static const Color hairlineStrong = Color(0xFF383A41); 
  
  /// 아주 미묘하게 식별되는 짙은 배경 구분선
  static const Color hairlineTertiary = Color(0xFF1B1C20); 
  
  /// 메인 브랜드 컬러 (시그니처 보라/파란색)
  static const Color primary = Color(0xFF5E6AD2);       
  
  /// 마우스 오버(Hover) 시 사용되는 하이라이트 블루퍼플
  static const Color primaryHover = Color(0xFF828FFF);  
  
  /// 포커스 획득 시 보조용 블루퍼플
  static const Color primaryFocus = Color(0xFF5E69D1);  
  
  /// 텍스트 및 레이아웃 서브 테마 컬러
  static const Color brandSecure = Color(0xFF7A7FAD);   
  
  /// 가장 강조되는 메인 흰색 텍스트 색상
  static const Color ink = Color(0xFFF7F8F8);          
  
  /// 본문 및 일반 설명 텍스트용 회색 텍스트 색상
  static const Color inkMuted = Color(0xFFD0D6E0);     
  
  /// 폼 힌트 및 저채도 텍스트용 어두운 회색 텍스트 색상
  static const Color inkSubtle = Color(0xFF8A8F98);    
  
  /// 비활성화 텍스트 및 플레이스홀더 텍스트용 색상
  static const Color inkTertiary = Color(0xFF62666D);  
  
  /// 긍정 수치 변동 및 안타 결과 표현용 그린
  static const Color success = Color(0xFF27A644);      
  
  /// 다이얼로그 뒤편의 화면을 반투명하게 가리는 블랙 오버레이 색상 (약 60% 투명도)
  static const Color overlay = Color(0x99000000);      
}

/// 애플리케이션의 타이포그래피 (글자 크기, 굵기, 행간) 시스템 정의 클래스입니다.
class AppTypography {
  /// 앱 전역에서 활용될 야구 서체 패밀리 이름
  static const String fontFamily = 'KBODiaGothic';

  /// 디스플레이 초대형 스코어 점수판용 텍스트 스타일 (Display Extra Large)
  static const TextStyle displayXl = TextStyle(
    fontFamily: fontFamily,
    fontSize: 80,
    fontWeight: FontWeight.w700, // 볼드
    height: 1.05,                // 타이트한 행간
    letterSpacing: -3.0,         // 음수 자간으로 시각적 응집력 강화
    color: AppColors.ink,
  );

  /// 대형 인덱스 지표 강조용 텍스트 스타일 (Display Large)
  static const TextStyle displayLg = TextStyle(
    fontFamily: fontFamily,
    fontSize: 56,
    fontWeight: FontWeight.w700,
    height: 1.10,
    letterSpacing: -1.8,
    color: AppColors.ink,
  );

  /// 대시보드 지표 및 이닝 점수 요약용 텍스트 스타일
  static const TextStyle displayMd = TextStyle(
    fontFamily: fontFamily,
    fontSize: 40,
    fontWeight: FontWeight.w700,
    height: 1.15,
    letterSpacing: -1.0,
    color: AppColors.ink,
  );

  /// 일반적인 큰 제목용 헤드라인 스타일
  static const TextStyle headline = TextStyle(
    fontFamily: fontFamily,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.20,
    letterSpacing: -0.6,
    color: AppColors.ink,
  );

  /// 카드 위젯의 고정 제목 스타일
  static const TextStyle cardTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    height: 1.25,
    letterSpacing: -0.4,
    color: AppColors.ink,
  );

  /// 하위 컴포넌트의 보조 제목용 중간 볼드 스타일
  static const TextStyle subhead = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w500, // 미디움
    height: 1.40,
    letterSpacing: -0.2,
    color: AppColors.ink,
  );

  /// 가독성을 높인 본문 대형 크기 스타일
  static const TextStyle bodyLg = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w300, // 라이트
    height: 1.50,
    letterSpacing: -0.1,
    color: AppColors.inkMuted,
  );

  /// 가장 일반적인 정보 전달 본문 텍스트 스타일
  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w300,
    height: 1.50,
    letterSpacing: -0.05,
    color: AppColors.inkMuted,
  );

  /// 컴포넌트 내 세부 캡션 및 부연설명 스타일
  static const TextStyle bodySm = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w300,
    height: 1.50,
    letterSpacing: 0,
    color: AppColors.inkMuted,
  );

  /// 최하단 카피라이트 및 메타 데이터 표현용 극소형 설명구 스타일
  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w300,
    height: 1.40,
    letterSpacing: 0,
    color: AppColors.inkSubtle,
  );

  /// 버튼 내부에 명확히 정렬되어 들어갈 라벨용 텍스트 스타일
  static const TextStyle button = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.20,
    letterSpacing: 0,
    color: AppColors.ink,
  );

  /// 카테고리 태그 및 제목 상단 분류를 나타내는 아이브로우 스타일
  static const TextStyle eyebrow = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.30,
    letterSpacing: 0.4,
    color: AppColors.primary,
  );
}

/// MaterialApp 테마 설정을 반환하는 글로벌 메소드입니다.
/// 
/// 개별 위젯에서 스타일을 수동 명시하지 않더라도 통일성 있는 테마를 유지해 줍니다.
ThemeData getDarkTheme() {
  return ThemeData(
    brightness: Brightness.dark,             // 다크모드 시스템 활성화
    scaffoldBackgroundColor: AppColors.canvas, // Scaffold 배경을 캔버스 색으로 칠함
    cardColor: AppColors.surface1,           // 카드 기본 컬러 지정
    dividerColor: AppColors.hairline,        // 구분선 기본 컬러 지정
    fontFamily: AppTypography.fontFamily,    // 메인 야구 서체 전역 설정
    
    // 머티리얼 디자인 3 대응 컬러 그룹핑 설정
    colorScheme: const ColorScheme.dark(
      background: AppColors.canvas,
      surface: AppColors.surface1,
      primary: AppColors.primary,
      secondary: AppColors.primaryHover,
      onPrimary: AppColors.ink,
      onSurface: AppColors.ink,
    ),
    
    // TextButton 위젯들에 공통 적용될 테마 정의
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.ink,       // 글씨색을 ink로 지정
        textStyle: AppTypography.button,      // 기본 텍스트 스타일 연동
      ),
    ),
  );
}
