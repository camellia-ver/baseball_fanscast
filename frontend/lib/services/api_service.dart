import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/game_situation_model.dart';

/// 백엔드 Spring Boot Gateway와 REST 통신을 수행하여
/// 실시간 중계 대시보드 데이터를 가져오는 네트워킹 서비스 클래스입니다.
class ApiService {
  /// 백엔드 API 서버의 기본 경로 (Base URL)
  static const String baseUrl = 'http://localhost:8080/api/v1/home';

  /// 백엔드 Spring Boot 게이트웨이에 HTTP POST 요청을 보내어
  /// 실시간 렌더링에 필요한 종합 JSON 패키지를 인스턴스화하여 반환합니다.
  Future<GameSituationModel?> fetchLiveFeedDashboard(
      int gameId, int stepIndex, {int? sourceGameId, int? sourceStepIndex}) async {
    String url = '$baseUrl/live-feed/$gameId/step/$stepIndex';
    if (sourceGameId != null && sourceStepIndex != null) {
      url += '?sourceGameId=$sourceGameId&sourceStepIndex=$sourceStepIndex';
    }

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {"Content-Type": "application/json"},
      );

      if (response.statusCode == 200) {
        // ✅ 해결책: 깨지지 않은 원본 바이트 배열(bodyBytes)을 백그라운드 Isolate로 직접 넘깁니다.
        return await compute(_parseLiveFeedDashboard, response.bodyBytes);
      } else {
        print('[ApiService] 백엔드 응답 에러 - 상태코드: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('[ApiService] 백엔드 서버 통신 중 치명적인 오류 발생: $e');
      return null;
    }
  }

  /// 데이터 분석실 화면 필터 리스트 (시즌, 팀 정보) 조회 API
  Future<Map<String, dynamic>?> fetchAnalysisFilters() async {
    final String url = 'http://localhost:8080/api/v1/analysis/filters';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        // 💡 메인 스레드 파싱단에도 깨진 바이트 무시(allowMalformed) 방어 코드 적용
        final utf8Body = utf8.decode(response.bodyBytes, allowMalformed: true);
        return json.decode(utf8Body) as Map<String, dynamic>;
      } else {
        print('[ApiService] 분석 필터 가져오기 실패: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('[ApiService] 분석 필터 통신 오류: $e');
      return null;
    }
  }

  /// 특정 팀의 투수 및 타자 목록 조회 API
  Future<Map<String, dynamic>?> fetchTeamPlayers(int teamId) async {
    final String url = 'http://localhost:8080/api/v1/analysis/players?teamId=$teamId';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final utf8Body = utf8.decode(response.bodyBytes, allowMalformed: true);
        return json.decode(utf8Body) as Map<String, dynamic>;
      } else {
        print('[ApiService] 팀 플레이어 조회 실패: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('[ApiService] 팀 플레이어 통신 오류: $e');
      return null;
    }
  }

  /// 특정 선수의 종합 분석 지표 및 차트 데이터 조회 API
  Future<Map<String, dynamic>?> fetchAnalysisPlayerData(int playerId, bool isPitcher, String split, String season) async {
    final String splitParam = split.contains('득점권') ? 'risp' : (split.contains('주자') ? 'runners' : 'all');
    final String url = 'http://localhost:8080/api/v1/analysis/player-data?playerId=$playerId&isPitcher=$isPitcher&split=$splitParam&season=${Uri.encodeComponent(season)}';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final utf8Body = utf8.decode(response.bodyBytes, allowMalformed: true);
        return json.decode(utf8Body) as Map<String, dynamic>;
      } else {
        print('[ApiService] 선수 분석 데이터 조회 실패: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('[ApiService] 선수 분석 데이터 통신 오류: $e');
      return null;
    }
  }

  /// 카드 뉴스를 제작할 수 있는 전체 경기 목록 조회 API
  Future<List<Map<String, dynamic>>?> fetchCardNewsGames() async {
    final String url = 'http://localhost:8080/api/v1/cardnews/games';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final utf8Body = utf8.decode(response.bodyBytes, allowMalformed: true);
        final List<dynamic> decoded = json.decode(utf8Body);
        return decoded.map((e) => e as Map<String, dynamic>).toList();
      } else {
        print('[ApiService] 카드뉴스 경기 목록 조회 실패: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('[ApiService] 카드뉴스 경기 목록 통신 오류: $e');
      return null;
    }
  }

  /// 특정 경기의 카드 뉴스 요약 정보 조회 API
  Future<Map<String, dynamic>?> fetchCardNewsSummary(int gameId) async {
    final String url = 'http://localhost:8080/api/v1/cardnews/summary?gameId=$gameId';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final utf8Body = utf8.decode(response.bodyBytes, allowMalformed: true);
        return json.decode(utf8Body) as Map<String, dynamic>;
      } else {
        print('[ApiService] 카드뉴스 요약 조회 실패: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('[ApiService] 카드뉴스 요약 통신 오류: $e');
      return null;
    }
  }

  /// 특정 경기 날짜의 타 경기 스코어 목록을 비동기 조회합니다.
  Future<List<OtherGame>?> fetchOtherGames(int gameId, int currentPitchIndex) async {
    final String url = '$baseUrl/other-games?gameId=$gameId&currentPitchIndex=$currentPitchIndex';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        // ✅ 바이트 데이터를 직접 Isolate로 전달
        return await compute(_parseOtherGames, response.bodyBytes);
      } else {
        print('[ApiService] 타 경기 목록 조회 실패: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('[ApiService] 타 경기 목록 통신 오류: $e');
      return null;
    }
  }

  /// 특정 경기 시점까지의 시즌 순위표 목록을 비동기 조회합니다.
  Future<List<SeasonStanding>?> fetchSeasonStandings(int gameId) async {
    final String url = '$baseUrl/season-standings?gameId=$gameId';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        // ✅ 바이트 데이터를 직접 Isolate로 전달
        return await compute(_parseSeasonStandings, response.bodyBytes);
      } else {
        print('[ApiService] 시즌 순위표 조회 실패: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('[ApiService] 시즌 순위표 통신 오류: $e');
      return null;
    }
  }
}

// -------------------------------------------------------------
// 💡 Isolate 전역 파싱 보조 함수들 (List<int> 바이트 기반으로 정정)
// -------------------------------------------------------------

/// 메인 대시보드 데이터를 백그라운드에서 안전하게 디코딩 및 파싱하는 함수
GameSituationModel? _parseLiveFeedDashboard(List<int> responseBytes) {
  // allowMalformed: true 를 주어 손상된 인코딩 바이트 스트림을 만나도 예외를 던지지 않게 방어합니다.
  final String decodedString = utf8.decode(responseBytes, allowMalformed: true);
  final Map<String, dynamic> decodedData = json.decode(decodedString);
  return GameSituationModel.fromJson(decodedData);
}

/// 타 경기 목록 리스트를 백그라운드에서 안전하게 디코딩 및 파싱하는 함수
List<OtherGame> _parseOtherGames(List<int> responseBytes) {
  final String decodedString = utf8.decode(responseBytes, allowMalformed: true);
  final List<dynamic> decoded = json.decode(decodedString);
  return decoded.map((e) => OtherGame.fromJson(e as Map<String, dynamic>)).toList();
}

/// 시즌 순위표 리스트를 백그라운드에서 안전하게 디코딩 및 파싱하는 함수
List<SeasonStanding> _parseSeasonStandings(List<int> responseBytes) {
  final String decodedString = utf8.decode(responseBytes, allowMalformed: true);
  final List<dynamic> decoded = json.decode(decodedString);
  return decoded.map((e) => SeasonStanding.fromJson(e as Map<String, dynamic>)).toList();
}