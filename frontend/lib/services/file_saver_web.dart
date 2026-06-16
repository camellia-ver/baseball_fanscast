import 'dart:html' as html;
import 'dart:typed_data';

/// Flutter Web 브라우저 환경 전용 다중 파일 다운로드 헬퍼 구현체입니다.
Future<void> saveFileWeb(Uint8List bytes, String fileName) async {
  final blob = html.Blob([bytes], 'image/png');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute("download", fileName)
    ..click();
  html.Url.revokeObjectUrl(url);
}
