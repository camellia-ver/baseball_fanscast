import 'dart:typed_data';

/// 웹이 아닌 네이티브 플랫폼용 다중 파일 다운로드 헬퍼 스텁입니다.
/// (네이티브 플랫폼 빌드 시 에러를 방지하기 위해 dart:html 의존성을 우회합니다)
Future<void> saveFileWeb(Uint8List bytes, String fileName) async {
  throw UnsupportedError('웹 플랫폼에서만 지원되는 동작입니다.');
}
