/// 백엔드 Spring Boot로부터 전달받은 경기 상황 종합 지표 데이터를
/// Flutter 애플리케이션 내에서 타입 안전하게 사용하기 위한 데이터 모델 클래스입니다.
class GameSituationModel {
  /// 요청 성공/실패 여부 상태 ('success' 또는 'fail')
  final String status;
  
  /// 실제 경기 날짜
  final String gameDate;
  
  /// 전반적인 스코어보드 정보 (팀명, 점수, 아웃/볼카운트 등)
  final ScoreBoardInfo scoreBoard;
  
  /// 현재 필드의 주자 배치 및 최근 투구 탄착군 리스트
  final FieldAndPitchInfo fieldAndPitch;
  
  /// 실시간 기대 승률 변화 추이 리스트 (이닝별)
  final List<WinProbabilityPoint> winProbabilityTimeline;
  
  /// AI가 자동 생성한 상황별 해설/코멘터리 패키지
  final AiCommentary aiCommentary;

  /// 동일 날짜에 열린 다른 야구 경기들의 실시간 스코어 리스트
  final List<OtherGame> otherGames;

  /// 시즌 전체 순위 정보 리스트
  final List<SeasonStanding> seasonStandings;

  final ScoreBoardInfo? postScoreBoard;
  final FieldAndPitchInfo? postFieldAndPitch;
  final AiCommentary? postAiCommentary;
  final int currentStepIndex;

  GameSituationModel({
    required this.status,
    required this.gameDate,
    required this.scoreBoard,
    required this.fieldAndPitch,
    required this.winProbabilityTimeline,
    required this.aiCommentary,
    required this.otherGames,
    required this.seasonStandings,
    this.postScoreBoard,
    this.postFieldAndPitch,
    this.postAiCommentary,
    required this.currentStepIndex,
  });

  /// JSON Map 데이터를 객체로 안전하게 파싱 및 인스턴스화하는 팩토리 생성자입니다.
  /// 
  /// 리스트 변환 시 발생할 수 있는 Null 포인터 및 타입 캐스팅 에러(ClassCastException)를
  /// 방지하도록 방어 코드(Null check & Type check)를 보강했습니다.
  factory GameSituationModel.fromJson(Map<String, dynamic> json) {
    return GameSituationModel(
      status: json['status'] ?? 'fail',
      gameDate: json['gameDate'] ?? '05/30',
      scoreBoard: ScoreBoardInfo.fromJson(json['scoreBoard'] ?? {}),
      fieldAndPitch: FieldAndPitchInfo.fromJson(json['fieldAndPitch'] ?? {}),
      winProbabilityTimeline: (json['winProbabilityTimeline'] is List)
          ? (json['winProbabilityTimeline'] as List)
              .map((i) => WinProbabilityPoint.fromJson(i as Map<String, dynamic>))
              .toList()
          : <WinProbabilityPoint>[],
      aiCommentary: AiCommentary.fromJson(json['aiCommentary'] ?? {}),
      otherGames: (json['otherGames'] is List)
          ? (json['otherGames'] as List)
              .map((i) => OtherGame.fromJson(i as Map<String, dynamic>))
              .toList()
          : <OtherGame>[],
      seasonStandings: (json['seasonStandings'] is List)
          ? (json['seasonStandings'] as List)
              .map((i) => SeasonStanding.fromJson(i as Map<String, dynamic>))
              .toList()
          : <SeasonStanding>[],
      postScoreBoard: json['postScoreBoard'] != null
          ? ScoreBoardInfo.fromJson(json['postScoreBoard'] as Map<String, dynamic>)
          : null,
      postFieldAndPitch: json['postFieldAndPitch'] != null
          ? FieldAndPitchInfo.fromJson(json['postFieldAndPitch'] as Map<String, dynamic>)
          : null,
      postAiCommentary: json['postAiCommentary'] != null
          ? AiCommentary.fromJson(json['postAiCommentary'] as Map<String, dynamic>)
          : null,
      currentStepIndex: json['currentStepIndex'] ?? 0,
    );
  }


}

/// 경기 점수판에 노출할 스코어, 이닝, 아웃/볼카운트 등의 상태 모델입니다.
class ScoreBoardInfo {
  final String homeTeamAbbr;     // 홈팀 약어명 (예: 'LAD')
  final String awayTeamAbbr;     // 원정팀 약어명 (예: 'NYY')
  final int homeScore;           // 홈팀 현재 총점
  final int awayScore;           // 원정팀 현재 총점
  final int currentInning;       // 현재 진행 중인 이닝 (1 ~ 9+)
  final bool isBottom;           // 이닝 초(false) / 말(true) 여부
  final int balls;               // 현재 타석의 볼 카운트 (0 ~ 3)
  final int strikes;             // 현재 타석의 스트라이크 카운트 (0 ~ 2)
  final int outs;                // 현재 이닝의 아웃 카운트 (0 ~ 2)
  final List<int> homeInningScores; // 홈팀의 이닝별 득점 이력 리스트
  final List<int> awayInningScores; // 원정팀의 이닝별 득점 이력 리스트
  final int homeHits;            // 홈팀 총 안타 수
  final int awayHits;            // 원정팀 총 안타 수
  final int homeErrors;          // 홈팀 총 실책 수
  final int awayErrors;          // 원정팀 총 실책 수

  ScoreBoardInfo({
    required this.homeTeamAbbr,
    required this.awayTeamAbbr,
    required this.homeScore,
    required this.awayScore,
    required this.currentInning,
    required this.isBottom,
    required this.balls,
    required this.strikes,
    required this.outs,
    required this.homeInningScores,
    required this.awayInningScores,
    required this.homeHits,
    required this.awayHits,
    required this.homeErrors,
    required this.awayErrors,
  });

  factory ScoreBoardInfo.fromJson(Map<String, dynamic> json) {
    return ScoreBoardInfo(
      homeTeamAbbr: json['homeTeamAbbr'] ?? '',
      awayTeamAbbr: json['awayTeamAbbr'] ?? '',
      homeScore: json['homeScore'] ?? 0,
      awayScore: json['awayScore'] ?? 0,
      currentInning: json['currentInning'] ?? 1,
      // 백엔드의 'bottom' 혹은 'isBottom' 키값 매핑 유연화 적용
      isBottom: json['isBottom'] ?? json['bottom'] ?? true, 
      balls: json['balls'] ?? 0,
      strikes: json['strikes'] ?? 0,
      outs: json['outs'] ?? 0,
      homeInningScores: List<int>.from(json['homeInningScores'] ?? const []),
      awayInningScores: List<int>.from(json['awayInningScores'] ?? const []),
      homeHits: json['homeHits'] ?? 0,
      awayHits: json['awayHits'] ?? 0,
      homeErrors: json['homeErrors'] ?? 0,
      awayErrors: json['awayErrors'] ?? 0,
    );
  }
}

/// 현재 누상에 주자가 위치해 있는지 여부와 최근 투구 궤적 좌표 리스트를 담는 모델입니다.
class FieldAndPitchInfo {
  final int runner1b; // 1루 주자 유무 (1: 유, 0: 무)
  final int runner2b; // 2루 주자 유무 (1: 유, 0: 무)
  final int runner3b; // 3루 주자 유무 (1: 유, 0: 무)
  final String runner1bName; // 1루 주자 이름
  final String runner2bName; // 2루 주자 이름
  final String runner3bName; // 3루 주자 이름
  final int pitcherPitchCount; // 현재 투수의 누적 투구수
  final List<PitchCoordinate> pitchCoordinates; // 최근 투구 탄착군 리스트
  final List<SprayPoint> sprayPoints; // 하프 이닝 동안 발생한 극좌표 타구 산점도 리스트

  FieldAndPitchInfo({
    required this.runner1b,
    required this.runner2b,
    required this.runner3b,
    required this.runner1bName,
    required this.runner2bName,
    required this.runner3bName,
    required this.pitcherPitchCount,
    required this.pitchCoordinates,
    required this.sprayPoints,
  });

  factory FieldAndPitchInfo.fromJson(Map<String, dynamic> json) {
    return FieldAndPitchInfo(
      runner1b: json['runner1b'] ?? 0,
      runner2b: json['runner2b'] ?? 0,
      runner3b: json['runner3b'] ?? 0,
      runner1bName: json['runner1bName'] ?? '',
      runner2bName: json['runner2bName'] ?? '',
      runner3bName: json['runner3bName'] ?? '',
      pitcherPitchCount: json['pitcherPitchCount'] ?? 0,
      pitchCoordinates: (json['pitchCoordinates'] is List)
          ? (json['pitchCoordinates'] as List)
              .map((i) => PitchCoordinate.fromJson(i as Map<String, dynamic>))
              .toList()
          : <PitchCoordinate>[],
      sprayPoints: (json['sprayPoints'] is List)
          ? (json['sprayPoints'] as List)
              .map((i) => SprayPoint.fromJson(i as Map<String, dynamic>))
              .toList()
          : <SprayPoint>[],
    );
  }
}

/// 스트라이크 존 렌더링에 사용되는 단일 투구의 좌표 및 정보 모델입니다.
class PitchCoordinate {
  final String pitchType; // 투구 구종 (예: 'FF', 'SL')
  final double plateX;    // 홈플레이트 통과 시점 가로 좌표 (pfx_x와 매핑)
  final double plateZ;    // 홈플레이트 통과 시점 높이 좌표 (pfx_z와 매핑)
  final int zone;         // 스트라이크존 구역 번호 (1 ~ 14)
  final double releaseSpeed;    // 구속 (mph)
  final double releaseSpinRate; // 회전수 (rpm)
  final String result;          // 투구 결과
  final int pitchNumber;        // 타석별 투구 순서 (1구째, 2구째 등)
  final double? pfxX;
  final double? pfxZ;

  PitchCoordinate({
    required this.pitchType,
    required this.plateX,
    required this.plateZ,
    required this.zone,
    required this.releaseSpeed,
    required this.releaseSpinRate,
    required this.result,
    required this.pitchNumber,
    this.pfxX,
    this.pfxZ,
  });

  factory PitchCoordinate.fromJson(Map<String, dynamic> json) {
    return PitchCoordinate(
      pitchType: json['pitchType'] ?? 'None',
      // num 타입으로 안전하게 파싱한 뒤 double로 명시적 변환 수행
      plateX: (json['plateX'] as num? ?? 0.0).toDouble(),
      plateZ: (json['plateZ'] as num? ?? 0.0).toDouble(),
      zone: json['zone'] ?? 0,
      releaseSpeed: (json['releaseSpeed'] as num? ?? 0.0).toDouble(),
      releaseSpinRate: (json['releaseSpinRate'] as num? ?? 0.0).toDouble(),
      result: json['result'] ?? '',
      pitchNumber: json['pitchNumber'] ?? 0,
      pfxX: json['pfxX'] != null ? (json['pfxX'] as num).toDouble() : null,
      pfxZ: json['pfxZ'] != null ? (json['pfxZ'] as num).toDouble() : null,
    );
  }
}

/// 승률 변동 그래프의 개별 지점을 구성하는 이닝 정보 및 승률 수치 모델입니다.
class WinProbabilityPoint {
  final String inningLabel; // 이닝 라벨 (예: '1회초', '2회말')
  final double homeWinPct;  // 홈팀 기대 승률 (0.0 ~ 1.0)

  WinProbabilityPoint({
    required this.inningLabel,
    required this.homeWinPct,
  });

  factory WinProbabilityPoint.fromJson(Map<String, dynamic> json) {
    return WinProbabilityPoint(
      inningLabel: json['inningLabel'] ?? '',
      homeWinPct: (json['homeWinPct'] as num? ?? 0.50).toDouble(),
    );
  }
}

/// AI 해설가가 상황을 요약 분석한 캐스터용 코멘터리 텍스트 모델입니다.
class AiCommentary {
  final String analysis; // 전반적인 국면 상황 분석 요약
  final String pitching; // 직전 투구의 구속, 무브먼트, 탄착군 평가
  final String record;   // 볼카운트 및 누적 상대 전적 등 통계 분석
  final bool hasError;

  AiCommentary({
    required this.analysis,
    required this.pitching,
    required this.record,
    required this.hasError,
  });

  factory AiCommentary.fromJson(Map<String, dynamic> json) {
    return AiCommentary(
      analysis: json['analysis'] ?? '',
      pitching: json['pitching'] ?? '',
      record: json['record'] ?? '',
      hasError: json['hasError'] ?? false,
    );
  }
}

/// 타구 극좌표 낙하 지점 정보를 표현하는 모델 클래스입니다.
class SprayPoint {
  final double angle;    // 3루 파울선(-45도) ~ 1루 파울선(+45도) 각도 값
  final double distance; // 홈플레이트 기점 타구 비거리 (ft 피트 단위)
  final String type;     // 타구 결과 유형 ('HIT', 'HR', 'OUT')
  final String eventDescription; // 한글 타구 결과
  final double launchSpeed; // 타구 속도 (mph)
  final double launchAngle; // 발사각 (도)
  final int pitchNumber; // 타격 시 투구 순서
  final String batterName; // 타자 이름

  SprayPoint({
    required this.angle,
    required this.distance,
    required this.type,
    required this.eventDescription,
    required this.launchSpeed,
    required this.launchAngle,
    required this.pitchNumber,
    required this.batterName,
  });

  factory SprayPoint.fromJson(Map<String, dynamic> json) {
    return SprayPoint(
      angle: (json['angle'] as num? ?? 0.0).toDouble(),
      distance: (json['distance'] as num? ?? 0.0).toDouble(),
      type: json['type'] ?? 'OUT',
      eventDescription: json['eventDescription'] ?? '',
      launchSpeed: (json['launchSpeed'] as num? ?? 0.0).toDouble(),
      launchAngle: (json['launchAngle'] as num? ?? 0.0).toDouble(),
      pitchNumber: json['pitchNumber'] ?? 0,
      batterName: json['batterName'] ?? '타자',
    );
  }
}

/// 동일 날짜에 진행 중인 다른 야구 경기들의 스코어 정보를 표현하는 모델 클래스입니다.
class OtherGame {
  final int gameId;
  final String awayTeamName;
  final int awayScore;
  final String homeTeamName;
  final int homeScore;
  final String status;

  OtherGame({
    required this.gameId,
    required this.awayTeamName,
    required this.awayScore,
    required this.homeTeamName,
    required this.homeScore,
    required this.status,
  });

  factory OtherGame.fromJson(Map<String, dynamic> json) {
    return OtherGame(
      gameId: json['gameId'] ?? 0,
      awayTeamName: json['awayTeamName'] ?? '',
      awayScore: json['awayScore'] ?? 0,
      homeTeamName: json['homeTeamName'] ?? '',
      homeScore: json['homeScore'] ?? 0,
      status: json['status'] ?? '종료',
    );
  }
}

/// 시즌 전체 순위 정보를 표현하는 모델 클래스입니다.
class SeasonStanding {
  final int rank;
  final String teamName;
  final String teamAbbr;
  final int wins;
  final int losses;
  final String winRate;
  final String streak;

  SeasonStanding({
    required this.rank,
    required this.teamName,
    required this.teamAbbr,
    required this.wins,
    required this.losses,
    required this.winRate,
    required this.streak,
  });

  factory SeasonStanding.fromJson(Map<String, dynamic> json) {
    return SeasonStanding(
      rank: json['rank'] ?? 0,
      teamName: json['teamName'] ?? '',
      teamAbbr: json['teamAbbr'] ?? '',
      wins: json['wins'] ?? 0,
      losses: json['losses'] ?? 0,
      winRate: json['winRate'] ?? '.500',
      streak: json['streak'] ?? '-',
    );
  }
}