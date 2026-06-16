import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../theme.dart';
import '../services/api_service.dart';
import '../services/file_saver.dart';

/**
 * AI 요약 데이터를 기반으로 카드뉴스를 커스텀 편집하고 외부로 공유할 수 있는 에디터 화면입니다.
 */
class CardNewsEditorScreen extends StatefulWidget {
  final int gameId;

  const CardNewsEditorScreen({super.key, required this.gameId});

  @override
  State<CardNewsEditorScreen> createState() => _CardNewsEditorScreenState();
}

class _CardNewsEditorScreenState extends State<CardNewsEditorScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  String? _errorMessage;

  // 카드 뉴스 원고 상태
  String _matchup = "";
  String _gameDate = "";
  List<Map<String, dynamic>> _slides = [];

  // 에디터 제어 변수
  int _currentSlideIndex = 0;
  final PageController _pageController = PageController();
  final TextEditingController _mainTextController = TextEditingController();
  final TextEditingController _subTextController = TextEditingController();

  // 디자인 테마 상태 ('acid_tech', 'y2k_retro', 'swiss_punk')
  String _selectedTheme = 'acid_tech';

  // 위젯 캡처용 글로벌 키 목록 (슬라이드 로드 후 동적으로 크기 조정)
  List<GlobalKey> _boundaryKeys = [];

  @override
  void initState() {
    super.initState();
    _loadSummaryData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _mainTextController.dispose();
    _subTextController.dispose();
    super.dispose();
  }

  Future<void> _loadSummaryData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final data = await _apiService.fetchCardNewsSummary(widget.gameId);
    if (!mounted) return;

    if (data != null && data['status'] == 'success') {
      final List<dynamic> slidesData = data['slides'] ?? [];
      setState(() {
        _matchup = data['matchup'] ?? '오늘의 매치';
        _gameDate = data['gameDate'] ?? 'MM/dd';
        _slides = slidesData.map((e) => Map<String, dynamic>.from(e)).toList();
        _boundaryKeys = List.generate(_slides.length, (_) => GlobalKey());
        
        // 첫 번째 슬라이드 텍스트 로드
        if (_slides.isNotEmpty) {
          _mainTextController.text = _slides[0]['mainText'] ?? '';
          _subTextController.text = _slides[0]['subText'] ?? '';
        }
        _isLoading = false;
      });
    } else {
      setState(() {
        _errorMessage = '카드뉴스 요약 데이터를 가져오지 못했습니다.';
        _isLoading = false;
      });
    }
  }

  // 슬라이드 변경 시 텍스트 에디터 동기화
  void _onSlidePageChanged(int index) {
    setState(() {
      _currentSlideIndex = index;
      _mainTextController.text = _slides[index]['mainText'] ?? '';
      _subTextController.text = _slides[index]['subText'] ?? '';
    });
  }

  // 에디터 입력 값을 카드 데이터 상태에 반영
  void _updateCardText() {
    if (_slides.isNotEmpty) {
      setState(() {
        _slides[_currentSlideIndex]['mainText'] = _mainTextController.text;
        _slides[_currentSlideIndex]['subText'] = _subTextController.text;
      });
    }
  }

  // 특정 카드 위젯을 PNG 바이트로 캡처
  Future<Uint8List?> _captureWidget(int index) async {
    try {
      final boundaryKey = _boundaryKeys[index];
      final boundary = boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      
      // 고화질 이미지 저장을 위해 pixelRatio를 3.0으로 설정
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      print("[CardNewsEditor] 위젯 캡처 중 에러 발생 (Index $index): $e");
      return null;
    }
  }

  // 5장의 카드 뉴스를 이미지 파일로 변환하여 네이티브 공유 다이얼로그 구동
  Future<void> _shareCardNews() async {
    // 캡처 진행 중 유저 피드백 로딩 알림
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            SizedBox(width: 16),
            Text('카드뉴스 이미지를 렌더링하는 중입니다...'),
          ],
        ),
        duration: Duration(seconds: 2),
      ),
    );

    // PageView가 그리지 않은 비활성 페이지는 context가 생성되지 않아 boundary가 null이 될 수 있으므로,
    // 안전한 캡처를 위해 순차적으로 각 페이지를 PageView 상에서 강제 렌더링 이동 및 캡처를 동기 처리합니다.
    List<Uint8List> capturedImages = [];
    int originalPageIndex = _currentSlideIndex;

    for (int i = 0; i < _slides.length; i++) {
      _pageController.jumpToPage(i);
      // 프레임 렌더링 보장을 위한 미세 지연시간 부여
      await Future.delayed(const Duration(milliseconds: 300));
      final bytes = await _captureWidget(i);
      if (bytes != null) {
        capturedImages.add(bytes);
      }
    }

    // 원래 보던 페이지로 복구
    _pageController.jumpToPage(originalPageIndex);

    if (capturedImages.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이미지 생성에 실패했습니다. 다시 시도해 주세요.')),
        );
      }
      return;
    }

    // Web 환경일 경우 다중 파일 다운로드로 즉시 폴백
    if (kIsWeb) {
      try {
        for (int i = 0; i < capturedImages.length; i++) {
          await saveFileWeb(capturedImages[i], 'fancast_card_${i + 1}.png');
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('5장의 카드뉴스 이미지가 성공적으로 다운로드되었습니다.')),
          );
        }
        return;
      } catch (webErr) {
        print("[CardNewsEditor] 웹 다중 다운로드 중 에러: $webErr");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('다운로드 중 오류가 발생했습니다: $webErr')),
          );
        }
        return;
      }
    }

    try {
      List<XFile> shareFiles = [];

      for (int i = 0; i < capturedImages.length; i++) {
        shareFiles.add(
          XFile.fromData(
            capturedImages[i],
            mimeType: 'image/png',
            name: 'fancast_card_${i + 1}.png',
          ),
        );
      }

      await Share.shareXFiles(
        shareFiles,
        text: '⚾ Baseball Fancast에서 생성한 $_matchup 경기 요약 카드뉴스입니다! 🔥',
      );
    } catch (e) {
      print("[CardNewsEditor] 공유 처리 중 오류: $e");
      // 공유 실패 시 웹 브라우저가 아니더라도 수동 다운로드 대체 시도
      try {
        for (int i = 0; i < capturedImages.length; i++) {
          await saveFileWeb(capturedImages[i], 'fancast_card_${i + 1}.png');
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('공유하기 기능 미지원으로 카드뉴스 이미지를 직접 다운로드합니다.')),
          );
        }
      } catch (fallbackErr) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('공유하기 중 오류가 발생했습니다: $e')),
          );
        }
      }
    }
  }

  // 스코어 파싱용 헬퍼 메서드
  String _extractScore(String text) {
    final regExp = RegExp(r'(\d+)\s*[:\-~]\s*(\d+)');
    final match = regExp.firstMatch(text);
    if (match != null) {
      return "${match.group(1)} : ${match.group(2)}";
    }
    return "9 : 8"; // 디폴트 야구 스코어
  }

  // 테마에 따른 카드 디자인 빌더
  Widget _buildCardDesign(int idx, Map<String, dynamic> slide) {
    final String mainText = slide['mainText'] ?? '';
    final String subText = slide['subText'] ?? '';
    final String slideType = slide['type'] ?? 'BODY';
    final int slideNo = slide['slideNo'] ?? (idx + 1);

    Widget cardContent;

    switch (_selectedTheme) {
      case 'acid_tech':
        cardContent = _buildAcidTechCard(idx, mainText, subText, slideType, slideNo);
        break;
      case 'y2k_retro':
        cardContent = _buildY2kRetroCard(idx, mainText, subText, slideType, slideNo);
        break;
      case 'swiss_punk':
        cardContent = _buildSwissPunkCard(idx, mainText, subText, slideType, slideNo);
        break;
      default:
        cardContent = _buildAcidTechCard(idx, mainText, subText, slideType, slideNo);
    }

    return RepaintBoundary(
      key: _boundaryKeys[idx],
      child: SizedBox(
        width: 320,
        height: 320,
        child: cardContent,
      ),
    );
  }

  // 테마 1: 애시드 테크 & 글래스모피즘
  Widget _buildAcidTechCard(int idx, String mainText, String subText, String slideType, int slideNo) {
    const accentColor = Color(0xFFCCFF00); // 형광 라임 그린
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF090A1A), Color(0xFF12132D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24.0),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // 오로라 후광 효과 1 (상단 좌측)
          Positioned(
            left: -30,
            top: -30,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF00F2FE).withOpacity(0.25),
                    const Color(0xFF00F2FE).withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),
          // 오로라 후광 효과 2 (하단 우측)
          Positioned(
            right: -20,
            bottom: -20,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFF355DA).withOpacity(0.2),
                    const Color(0xFFF355DA).withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),
          // 글래스모피즘 내부 패널
          Container(
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(24.0),
              border: Border.all(
                color: Colors.white.withOpacity(0.12),
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 상단 헤더
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.sports_baseball, color: accentColor, size: 14),
                        const SizedBox(width: 6.0),
                        Text(
                          slideType,
                          style: const TextStyle(
                            fontFamily: AppTypography.fontFamily,
                            fontSize: 10.0,
                            fontWeight: FontWeight.bold,
                            color: accentColor,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
                      ),
                      child: Text(
                        '$slideNo / 5',
                        style: const TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontSize: 11.0,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12.0),
                Divider(color: Colors.white.withOpacity(0.1), height: 1.0),
                const Spacer(),
                // 메인 타이틀
                Text(
                  mainText,
                  style: const TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    color: Colors.white,
                    fontSize: 20.0,
                    fontWeight: FontWeight.w800,
                    height: 1.4,
                    shadows: [
                      Shadow(
                        color: Colors.black38,
                        offset: Offset(0, 2),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16.0),
                // 본문
                Text(
                  subText,
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w400,
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),
                const Spacer(),
                // 푸터
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        _matchup,
                        style: TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    Text(
                      'FANCAST',
                      style: TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        color: accentColor.withOpacity(0.8),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 테마 2: Y2K 네오-레트로 & 야구 뱃지 스티커 팩
  Widget _buildY2kRetroCard(int idx, String mainText, String subText, String slideType, int slideNo) {
    // 슬라이드 번호에 따라 스티커 문구와 색상 변경
    final List<Map<String, dynamic>> stickers = [
      {'text': 'PLAY BALL!⚾', 'color': const Color(0xFFFBBF24), 'angle': -0.08},
      {'text': 'MVP!🏆', 'color': const Color(0xFFF472B6), 'angle': 0.1},
      {'text': 'HOMERUN!🔥', 'color': const Color(0xFF34D399), 'angle': -0.05},
      {'text': 'WINNER!🎉', 'color': const Color(0xFF60A5FA), 'angle': 0.07},
      {'text': 'FIGHTING!💪', 'color': const Color(0xFFA78BFA), 'angle': -0.06},
    ];
    final sticker = stickers[idx % stickers.length];

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3EF), // 레트로 베이지
        border: Border.all(color: Colors.black, width: 3.0),
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: const [
          BoxShadow(
            color: Colors.black,
            offset: Offset(6, 6),
          )
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // 모눈 그리드 배경
          Positioned.fill(
            child: CustomPaint(
              painter: Y2KGridPainter(),
            ),
          ),
          
          // 콘텐츠 패널
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 상단 헤더
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        slideType,
                        style: const TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontSize: 9.0,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    Text(
                      'SLIDE $slideNo',
                      style: const TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 12.0,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10.0),
                Container(height: 3.0, color: Colors.black),
                const Spacer(),
                // 메인 타이틀
                Text(
                  mainText,
                  style: const TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    color: Colors.black,
                    fontSize: 20.0,
                    fontWeight: FontWeight.w900,
                    height: 1.3,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12.0),
                // 본문
                Text(
                  subText,
                  style: const TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    color: Color(0xFF1F2937),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const Spacer(),
                // 푸터
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        _matchup,
                        style: const TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          color: Colors.black87,
                          fontSize: 11.0,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    const Text(
                      'FANCAST',
                      style: TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        color: Colors.black,
                        fontSize: 11.0,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Y2K 스티커 레이어
          Positioned(
            right: 12,
            top: 40,
            child: Transform.rotate(
              angle: sticker['angle'],
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: sticker['color'],
                  border: Border.all(color: Colors.black, width: 2.0),
                  borderRadius: BorderRadius.circular(8.0),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black,
                      offset: Offset(3, 3),
                    )
                  ],
                ),
                child: Text(
                  sticker['text'],
                  style: const TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 테마 3: 스위스 펑크 & 자이언트 타이포
  Widget _buildSwissPunkCard(int idx, String mainText, String subText, String slideType, int slideNo) {
    const accentColor = Color(0xFFF97316); // 일렉트릭 네온 오렌지
    final score = _extractScore("$mainText $subText $_matchup");

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE53E3E), // 강렬한 스위스 레드
        borderRadius: BorderRadius.circular(16.0),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // 배경 거대 스코어 타이포그래피 (투명도 8%)
          Positioned(
            left: -20,
            right: -20,
            top: 60,
            child: Opacity(
              opacity: 0.08,
              child: FittedBox(
                fit: BoxFit.cover,
                child: Text(
                  score,
                  style: const TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -10,
                  ),
                ),
              ),
            ),
          ),
          
          // 콘텐츠 레이어
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, // 비대칭 좌측 정렬
              children: [
                // 상단 헤더
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      slideType.toUpperCase(),
                      style: const TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 11.0,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 2.0,
                      ),
                    ),
                    Text(
                      'NO. 0$slideNo',
                      style: const TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 12.0,
                        fontWeight: FontWeight.w900,
                        color: accentColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12.0),
                Container(height: 4.0, color: Colors.white),
                const Spacer(),
                // 메인 타이틀
                Text(
                  mainText,
                  style: const TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    color: Colors.white,
                    fontSize: 22.0,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.8,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 14.0),
                // 본문
                Text(
                  subText,
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    height: 1.5,
                  ),
                ),
                const Spacer(),
                // 푸터
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        _matchup.toUpperCase(),
                        style: const TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          color: Colors.white,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    const Text(
                      'FANCAST®',
                      style: TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        color: accentColor,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final bool isDesktop = width >= 1024;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: Text(
          '$_matchup 카드뉴스 커스텀',
          style: const TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontSize: 15.0,
            fontWeight: FontWeight.bold,
            color: AppColors.ink,
          ),
        ),
        backgroundColor: AppColors.surface1,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.ink),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadSummaryData,
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.surface3),
                        child: const Text('다시 로드', style: TextStyle(color: AppColors.ink)),
                      ),
                    ],
                  ),
                )
              : SafeArea(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 데스크톱 vs 모바일 레이아웃 분기
                          if (isDesktop)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 좌측: 카드 프리뷰 캐러셀 및 스위처
                                Expanded(
                                  flex: 1,
                                  child: Column(
                                    children: [
                                      _buildPreviewCarousel(),
                                      const SizedBox(height: 24),
                                      _buildThemeSelector(),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 36),
                                // 우측: 텍스트 에디터 폼 및 제어 버튼
                                Expanded(
                                  flex: 1,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      _buildEditorForm(),
                                      const SizedBox(height: 32),
                                      _buildActionButtons(),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          else
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildPreviewCarousel(),
                                const SizedBox(height: 24),
                                _buildThemeSelector(),
                                const SizedBox(height: 24),
                                _buildEditorForm(),
                                const SizedBox(height: 32),
                                _buildActionButtons(),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
    );
  }

      void _navToPage(int step) {
      final targetPage = _currentSlideIndex + step;
      // 페이지 범위를 벗어나지 않도록 방어 코드 추가
      if (targetPage >= 0 && targetPage < _slides.length) {
        _pageController.animateToPage(
          targetPage,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }

  // 1. 카드 프리뷰 카러셀 위젯
  Widget _buildPreviewCarousel() {
    return Column(
      children: [
        SizedBox(
          height: 330,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 1) 중앙 PageView
              PageView.builder(
                controller: _pageController,
                onPageChanged: _onSlidePageChanged,
                itemCount: _slides.length,
                itemBuilder: (context, idx) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40.0), // 화살표 공간 확보를 위해 패딩 수정
                      child: _buildCardDesign(idx, _slides[idx]),
                    ),
                  );
                },
              ),

              // 2) 좌측 이전 버튼 (첫 페이지가 아닐 때만 노출)
              if (_currentSlideIndex > 0)
                Positioned(
                  left: 0,
                  child: CircleAvatar(
                    backgroundColor: AppColors.surface1.withOpacity(0.8),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.ink, size: 18),
                      onPressed: () => _navToPage(-1),
                    ),
                  ),
                ),

              // 3) 우측 다음 버튼 (마지막 페이지가 아닐 때만 노출)
              if (_currentSlideIndex < _slides.length - 1)
                Positioned(
                  right: 0,
                  child: CircleAvatar(
                    backgroundColor: AppColors.surface1.withOpacity(0.8),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_forward_ios, color: AppColors.ink, size: 18),
                      onPressed: () => _navToPage(1),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // 인디케이터 점등
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_slides.length, (i) {
            final bool isActive = i == _currentSlideIndex;
            return Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 4.0),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive ? AppColors.primary : AppColors.surface4,
              ),
            );
          }),
        ),
      ],
    );
  }

  // 2. 테마 스타일 변경 영역
  Widget _buildThemeSelector() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '디자인 스타일 선택',
            style: TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: 12.0,
              fontWeight: FontWeight.bold,
              color: AppColors.inkSubtle,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildThemeButton('acid_tech', '애시드 테크'),
              _buildThemeButton('y2k_retro', 'Y2K 레트로'),
              _buildThemeButton('swiss_punk', '스위스 펑크'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThemeButton(String themeId, String label) {
    final bool isSelected = _selectedTheme == themeId;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontFamily: AppTypography.fontFamily,
          fontSize: 11.5,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? AppColors.ink : AppColors.inkSubtle,
        ),
      ),
      selected: isSelected,
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.canvas,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedTheme = themeId;
          });
        }
      },
    );
  }

  // 3. 카드 문구 편집 폼
  Widget _buildEditorForm() {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.edit_note, color: AppColors.primary, size: 18),
              const SizedBox(width: 8.0),
              Text(
                '${_currentSlideIndex + 1}번 카드 텍스트 편집',
                style: const TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: 13.0,
                  fontWeight: FontWeight.bold,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            '메인 문안 (핵심 요약)',
            style: TextStyle(
              fontSize: 11.0,
              color: AppColors.inkSubtle,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _mainTextController,
            style: const TextStyle(fontSize: 13.0, color: AppColors.ink),
            maxLines: 2,
            maxLength: 35,
            decoration: InputDecoration(
              hintText: '메인 문구를 작성해 주세요.',
              fillColor: AppColors.canvas,
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
                borderSide: BorderSide.none,
              ),
              counterStyle: const TextStyle(color: AppColors.inkTertiary),
            ),
            onChanged: (val) => _updateCardText(),
          ),
          const SizedBox(height: 16),
          const Text(
            '서브 설명 (세부 데이터/결과)',
            style: TextStyle(
              fontSize: 11.0,
              color: AppColors.inkSubtle,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _subTextController,
            style: const TextStyle(fontSize: 13.0, color: AppColors.ink),
            maxLines: 3,
            maxLength: 65,
            decoration: InputDecoration(
              hintText: '세부 설명 문구를 작성해 주세요.',
              fillColor: AppColors.canvas,
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
                borderSide: BorderSide.none,
              ),
              counterStyle: const TextStyle(color: AppColors.inkTertiary),
            ),
            onChanged: (val) => _updateCardText(),
          ),
        ],
      ),
    );
  }

  // 4. 저장 및 공유 제어 액션 버튼바
  Widget _buildActionButtons() {
    return Row(
      children: [
        // 기기에 저장 피드백 버튼
        Expanded(
          child: OutlinedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('갤러리에 카드뉴스가 정상 저장되었습니다. (성공)'),
                  backgroundColor: AppColors.success,
                ),
              );
            },
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.hairlineStrong),
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.save_alt, color: AppColors.inkSubtle, size: 18),
                SizedBox(width: 8.0),
                Text(
                  '기기 저장',
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 13.0,
                    fontWeight: FontWeight.bold,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16.0),

        // 공유하기 액션 버튼
        Expanded(
          child: ElevatedButton(
            onPressed: _shareCardNews,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.ink,
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.share, size: 18),
                SizedBox(width: 8.0),
                Text(
                  '카드뉴스 공유',
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 13.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class Y2KGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.04)
      ..strokeWidth = 1.0;

    const double step = 20.0;

    // 세로선 그리기
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // 가로선 그리기
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
