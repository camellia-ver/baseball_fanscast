import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme.dart';
import 'widgets/top_nav.dart';
import 'screens/home_screen.dart';
import 'screens/analysis_screen.dart';
import 'screens/card_news_screen.dart';

// ==========================================
// [1] 앱의 진입점 (Entry Point)
// ==========================================
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  BrowserContextMenu.disableContextMenu();
  runApp(const BaseballFancastApp());
}

// ==========================================
// [2] 커스텀 스크롤 비헤이비어 (Scroll Behavior)
// ==========================================
/// 마우스 드래그, 터치 스크린, 트랙패드, 스타일러스 펜 등 다양한 기기의
/// 입력 방식을 통한 스크롤 드래그 제스처를 허용 및 동기화하기 위한 설정 클래스입니다.
class CustomScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,      // 모바일/태블릿 터치
        PointerDeviceKind.mouse,      // 마우스 휠 드래그 스크롤
        PointerDeviceKind.trackpad,   // 트랙패드 드래그 스크롤
        PointerDeviceKind.stylus,     // 펜 입력 스크롤
      };
}

// ==========================================
// [3] 앱 루트 위젯 (StatelessWidget)
// ==========================================
class BaseballFancastApp extends StatelessWidget {
  const BaseballFancastApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Baseball Fancast',
      debugShowCheckedModeBanner: false,
      theme: getDarkTheme(),                  // 커스텀 다크 테마 적용
      scrollBehavior: CustomScrollBehavior(), // 스크롤 드래그 전역 인입
      home: const MainShell(),                // 최상위 레이아웃을 제공하는 메인 쉘 호출
    );
  }
}

// ==========================================
// [4] 메인 쉘 위젯 (StatefulWidget)
// ==========================================
/// 헤더바(TopNav), 드로어(Drawer), 하단푸터(Footer), 플로팅 챗버튼(FAB) 등
/// 뷰포트 최상위 계층 레이아웃과 탭 화면 분기를 관리하는 쉘 프레임입니다.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  /// 활성화된 탭 페이지 인덱스 (0: Home, 1: 분석실, 2: 카드뉴스, 3: 커뮤니티, 4: 마이페이지)
  int _activeTabIndex = 0; 
  
  /// 실시간 팬 응원 채팅 오버레이 노출 여부
  bool _showChat = false; 
  
  /// 샘플 채팅 메시지 데이터 리스트
  final List<String> _chatMessages = [
    '팬1: 와 오늘 류현진 제구 미쳤네 ㄷㄷ',
    '팬2: 김대한 홈런 하나 쳐주자!!',
    '야구조아: 다이노스 오늘 승리가자~',
  ];
  
  /// 채팅 텍스트 입력창 제어 컨트롤러
  final TextEditingController _chatInputController = TextEditingController();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    // 텍스트 컨트롤러 사용 종료 후 하드웨어 리소스 해제하여 메모리 누수 방지
    _chatInputController.dispose();
    super.dispose();
  }

  /// 탭 메뉴 클릭 시 뷰 체인지 처리
  void _onTabChanged(int index) {
    setState(() {
      _activeTabIndex = index;
    });
  }

  /// 응원 채팅 전송 로직
  void _sendMessage() {
    final text = _chatInputController.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        _chatMessages.add('나: $text'); // 사용자가 적은 글을 로컬 배열에 삽입
        _chatInputController.clear(); // 텍스트 입력 칸 리셋
      });
    }
  }

  /// 뷰포트 위에 띄워질 실시간 팬 응원 플로팅 채팅 팝업창을 구성합니다.
  Widget _buildChatWindow() {
    return Container(
      width: 280,
      height: 360,
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: AppColors.hairline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 16.0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // A. 채팅창 헤더바
          Container(
            padding: const EdgeInsets.all(12.0),
            decoration: const BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.vertical(top: Radius.circular(12.0)),
              border: Border(bottom: BorderSide(color: AppColors.hairline)),
            ),
            child: const Row(
              children: [
                Icon(Icons.chat, color: AppColors.primary, size: 14),
                SizedBox(width: 8.0),
                Text(
                  '실시간 팬 응원 챗',
                  style: TextStyle(fontSize: 12.0, fontWeight: FontWeight.bold, color: AppColors.ink),
                ),
              ],
            ),
          ),

          // B. 스크롤링 채팅 메시지 수집 리스트 영역
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12.0),
              itemCount: _chatMessages.length,
              itemBuilder: (context, idx) {
                final String msg = _chatMessages[idx];
                final bool isAi = msg.startsWith('AI캐스터');
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    msg,
                    style: TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontSize: 11.5,
                      color: isAi ? AppColors.primaryHover : AppColors.inkMuted,
                      fontWeight: isAi ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                );
              },
            ),
          ),

          // C. 사용자 텍스트 인풋창 및 전송 버튼
          const Divider(color: AppColors.hairline, height: 1.0),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: TextField(
                      controller: _chatInputController,
                      style: const TextStyle(fontSize: 12.0, color: AppColors.ink),
                      decoration: InputDecoration(
                        hintText: '메시지를 입력하세요...',
                        hintStyle: const TextStyle(fontSize: 12.0, color: AppColors.inkTertiary),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
                        fillColor: AppColors.canvas,
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6.0),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (val) => _sendMessage(),
                    ),
                  ),
                ),
                const SizedBox(width: 8.0),
                IconButton(
                  icon: const Icon(Icons.send, color: AppColors.primary, size: 18),
                  onPressed: _sendMessage,
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
    return Scaffold(
      backgroundColor: AppColors.canvas,
      
      // 최상단 고정 헤더 네비게이션
      appBar: TopNav(
        activeIndex: _activeTabIndex,
        onTabChanged: _onTabChanged,
      ),

      // 모바일 전용 엔드 드로어 서랍장 슬라이드 메뉴 구성
      endDrawer: Drawer(
        backgroundColor: AppColors.surface1,
        child: Container(
          decoration: const BoxDecoration(
            border: Border(left: BorderSide(color: AppColors.hairline)),
          ),
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: const BoxDecoration(
                  color: AppColors.canvas,
                  border: Border(bottom: BorderSide(color: AppColors.hairline)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        CustomPaint(
                          size: const Size(20, 20),
                          painter: LogoPainter(),
                        ),
                        const SizedBox(width: 8.0),
                        const Text(
                          'baseball fancast',
                          style: TextStyle(
                            fontFamily: AppTypography.fontFamily,
                            fontWeight: FontWeight.bold,
                            fontSize: 16.0,
                            color: AppColors.ink,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12.0),
                    const Text(
                      '차세대 실시간 야구 분석',
                      style: TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 11.5,
                        color: AppColors.inkTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              _buildDrawerItem('Home', 0),
              _buildDrawerItem('데이터 분석실', 1),
              _buildDrawerItem('카드뉴스', 2),
              _buildDrawerItem('커뮤니티', 3),
              _buildDrawerItem('My Page', 4),
              const Padding(
                padding: EdgeInsets.all(24.0),
                child: Divider(color: AppColors.hairline),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: TextButton(
                  onPressed: () {},
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  child: const Text('로그인', style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),

      body: SafeArea(
        child: Stack(
          children: [
            // 💡 [개선] 랙을 유발하던 외부 LayoutBuilder, SingleChildScrollView, Offstage 스택을 
            // 전부 걷어내고 화면 공간을 완벽히 격리해주는 IndexedStack으로 전면 교체합니다.
            IndexedStack(
              index: _activeTabIndex,
              children: [
                // 0번 탭: 홈 화면
                HomeScreen(isActive: _activeTabIndex == 0),
                
                // 1번 탭: 데이터 분석실
                AnalysisScreen(isActive: _activeTabIndex == 1),
                
                // 2번 탭: 카드뉴스
                const CardNewsScreen(),
                
                // 3번 탭: 커뮤니티 플레이스홀더
                _buildPlaceholderScreen('커뮤니티 (Community)'),
                
                // 4번 탭: 마이페이지 플레이스홀더
                _buildPlaceholderScreen('My Page (마이페이지)'),
              ],
            ),

            // 2층 레이어: 플로팅 채팅 메시지 박스 윈도우 (기존 로직 유지)
            if (_activeTabIndex == 0 && _showChat)
              Positioned(
                bottom: 80.0, 
                right: 24.0,
                child: _buildChatWindow(),
              ),
          ],
        ),
      ),

      // 플로팅 채팅 열기/닫기 토글 원형 액션 버튼 (홈 화면 탭에서만 활성화)
      floatingActionButton: _activeTabIndex == 0
          ? FloatingActionButton(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.ink,
              elevation: 8.0,
              onPressed: () {
                setState(() {
                  _showChat = !_showChat;
                });
              },
              child: Icon(_showChat ? Icons.close : Icons.chat_bubble_outline),
            )
          : null,
    );
  }

  /// 모바일 사이드 드로어 내 메뉴 아이템 클릭 시 탭 교체 및 드로어 닫기 처리
  Widget _buildDrawerItem(String label, int index) {
    final bool isActive = _activeTabIndex == index;
    return ListTile(
      title: Text(
        label,
        style: TextStyle(
          fontFamily: AppTypography.fontFamily,
          fontWeight: isActive ? FontWeight.w500 : FontWeight.w300,
          color: isActive ? AppColors.primaryHover : AppColors.inkSubtle,
        ),
      ),
      onTap: () {
        _onTabChanged(index);   
        Navigator.pop(context); // 서랍창 드로어 닫음
      },
    );
  }

  /// 서비스 준비 중 상태를 알리는 플레이스홀더 화면 렌더링 헬퍼 메소드
  Widget _buildPlaceholderScreen(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 120.0, horizontal: 24.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.hourglass_empty_rounded,
              size: 48,
              color: AppColors.primary,
            ),
            const SizedBox(height: 24.0),
            Text(
              title,
              style: const TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontWeight: FontWeight.w700,
                fontSize: 20.0,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 12.0),
            const Text(
              '이 페이지는 준비 중입니다. 상단 내비게이션을 통해 Home과 데이터 분석실, 카드뉴스를 탐색할 수 있습니다.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontSize: 13.0,
                color: AppColors.inkTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
