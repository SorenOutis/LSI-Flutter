import '../../../core/utils/json_parsing.dart';

/// XP, level and streak for the signed-in student.
///
/// `currentXP`/`maxXPForLevel` are already reduced modulo 100 server-side, so the
/// progress bar takes them at face value. [streak] counts *dashboard visits*, and
/// [loginDates] lists days the student earned XP — neither is a literal record of
/// opening the app, so the UI must not describe them as logins.
class UserStats {
  const UserStats({
    required this.totalXP,
    required this.level,
    required this.currentXP,
    required this.maxXPForLevel,
    required this.points,
    required this.streak,
    required this.longestStreak,
  });

  final double totalXP;
  final int level;
  final double currentXP;
  final double maxXPForLevel;
  final double points;
  final int streak;
  final int longestStreak;

  double get levelProgress => maxXPForLevel <= 0 ? 0 : (currentXP / maxXPForLevel).clamp(0.0, 1.0);

  /// XP still needed to reach the next level.
  ///
  /// The server computes `level = floor(exp / 100) + 1` and sends `currentXP` as
  /// `exp % 100` against a fixed `maxXPForLevel` of 100, so this remainder is
  /// exact rather than a rounded approximation. Clamped at zero so the last XP of
  /// a level reads "0 XP to go" rather than a negative.
  double get xpToNextLevel {
    if (level < 1) return maxXPForLevel;
    return (maxXPForLevel - currentXP).clamp(0, maxXPForLevel);
  }

  /// The level after this one.
  ///
  /// `BadgeAwardService` grants every badge whose `required_level` is at or below
  /// the level held, and the bundled set is one badge per level, so arriving at
  /// [nextLevel] earns exactly one more.
  int get nextLevel => level + 1;

  /// The season total at which [nextLevel] begins.
  double get xpAtNextLevel => totalXP + xpToNextLevel;

  factory UserStats.fromJson(Map<String, dynamic> json) {
    return UserStats(
      totalXP: json.asDouble('totalXP'),
      level: json.asInt('level', fallback: 1),
      currentXP: json.asDouble('currentXP'),
      maxXPForLevel: json.asDouble('maxXPForLevel', fallback: 100),
      points: json.asDouble('points'),
      streak: json.asInt('streak'),
      longestStreak: json.asInt('longestStreak'),
    );
  }
}

class Announcement {
  const Announcement({
    required this.id,
    required this.title,
    required this.description,
    required this.link,
    required this.sectionName,
    required this.createdAtLabel,
  });

  final int id;
  final String title;
  final String? description;
  final String? link;
  final String? sectionName;
  final String? createdAtLabel;

  factory Announcement.fromJson(Map<String, dynamic> json) {
    return Announcement(
      id: json.asInt('id'),
      title: json.asString('title'),
      description: json.asStringOrNull('description'),
      link: json.asStringOrNull('link'),
      sectionName: json.asStringOrNull('sectionName'),
      createdAtLabel: json.asStringOrNull('createdAt'),
    );
  }
}

class AssignmentSummary {
  const AssignmentSummary({
    required this.id,
    required this.title,
    required this.description,
    required this.dueLabel,
    required this.dueAt,
    required this.isOverdue,
    required this.submitted,
    required this.status,
    required this.grade,
  });

  final int id;
  final String title;
  final String? description;
  final String dueLabel;
  final DateTime? dueAt;
  final bool isOverdue;
  final bool submitted;
  final String status;
  final String? grade;

  factory AssignmentSummary.fromJson(Map<String, dynamic> json) {
    return AssignmentSummary(
      id: json.asInt('id'),
      title: json.asString('title'),
      description: json.asStringOrNull('description'),
      dueLabel: json.asString('dueDate', fallback: 'No deadline'),
      // `dueAtIso` has no timezone offset by design (dueDateForClient), so it
      // is read as a local wall-clock time rather than converted to UTC.
      dueAt: json.asDateOrNull('dueAtIso')?.toLocal(),
      isOverdue: json.asBool('isOverdue'),
      submitted: json.asBool('submitted'),
      status: json.asString('status', fallback: 'Pending'),
      grade: json.asStringOrNull('grade'),
    );
  }
}

/// A dashboard exam card. Mirrors `UpcomingExamsService::forUser`.
class UpcomingExam {
  const UpcomingExam({
    required this.id,
    required this.title,
    required this.description,
    required this.examDateLabel,
    required this.startsAt,
    required this.endsAt,
    required this.durationMinutes,
    required this.status,
    required this.partsCount,
    required this.submittedParts,
    required this.isCompleted,
    required this.isOpenNow,
    required this.isUpcoming,
    required this.hasEnded,
    required this.setTitle,
  });

  final int id;
  final String title;
  final String? description;
  final String? examDateLabel;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final int durationMinutes;
  final String status;
  final int partsCount;
  final int submittedParts;
  final bool isCompleted;
  final bool isOpenNow;
  final bool isUpcoming;
  final bool hasEnded;

  /// The set title (a plain string here, not `{id, title}` as elsewhere).
  final String? setTitle;

  factory UpcomingExam.fromJson(Map<String, dynamic> json) {
    return UpcomingExam(
      id: json.asInt('id'),
      title: json.asString('title'),
      description: json.asStringOrNull('description'),
      examDateLabel: json.asStringOrNull('exam_date'),
      startsAt: json.asDateOrNull('starts_at_iso')?.toLocal(),
      endsAt: json.asDateOrNull('ends_at_iso')?.toLocal(),
      durationMinutes: json.asInt('duration_minutes'),
      status: json.asString('status'),
      partsCount: json.asInt('parts_count'),
      submittedParts: json.asInt('submitted_parts'),
      isCompleted: json.asBool('is_completed'),
      isOpenNow: json.asBool('is_open_now'),
      isUpcoming: json.asBool('is_upcoming'),
      hasEnded: json.asBool('has_ended'),
      setTitle: json.asStringOrNull('set'),
    );
  }
}

class LeaderboardUser {
  const LeaderboardUser({
    required this.id,
    required this.publicId,
    required this.name,
    required this.xp,
    required this.level,
    required this.xpProgress,
    required this.streak,
    required this.trend,
    required this.isCurrentUser,
    required this.blurred,
  });

  final int id;
  final String publicId;
  final String name;
  final double xp;
  final int level;
  final int xpProgress;
  final int streak;
  final String trend;
  final bool isCurrentUser;
  final bool blurred;

  factory LeaderboardUser.fromJson(Map<String, dynamic> json) {
    return LeaderboardUser(
      id: json.asInt('id'),
      publicId: json.asString('publicId'),
      name: json.asString('name'),
      xp: json.asDouble('xp'),
      level: json.asInt('level', fallback: 1),
      xpProgress: json.asInt('xpProgress'),
      streak: json.asInt('streak'),
      trend: json.asString('trend', fallback: 'stable'),
      isCurrentUser: json.asBool('isCurrentUser'),
      blurred: json.asBool('blurred'),
    );
  }
}

class SectionLeaderboard {
  const SectionLeaderboard({
    required this.sectionId,
    required this.sectionName,
    required this.leaderboardEnabled,
    required this.users,
    required this.userRank,
    required this.totalPlayers,
  });

  final int sectionId;
  final String sectionName;
  final bool leaderboardEnabled;
  final List<LeaderboardUser> users;
  final int userRank;
  final int totalPlayers;

  /// Whether this account's name is hidden on the board, or null when the viewer
  /// is not among the returned rows.
  ///
  /// `blur_leaderboard` is a column on the user, so the flag is the same on every
  /// section's copy of the viewer; reading it off the rows avoids a second call
  /// just to show a privacy switch.
  bool? get viewerIsBlurred {
    for (final LeaderboardUser user in users) {
      if (user.isCurrentUser) return user.blurred;
    }
    return null;
  }

  factory SectionLeaderboard.fromJson(Map<String, dynamic> json) {
    return SectionLeaderboard(
      sectionId: json.asInt('sectionId'),
      sectionName: json.asString('sectionName'),
      leaderboardEnabled: json.asBool('leaderboardEnabled', fallback: true),
      users: json.asMapList('users').map(LeaderboardUser.fromJson).toList(growable: false),
      userRank: json.asInt('userRank'),
      totalPlayers: json.asInt('totalPlayers'),
    );
  }
}

class ClaimStatus {
  const ClaimStatus({required this.canClaim, required this.amount, this.nextClaimAt, this.showPrompt = false});

  final bool canClaim;
  final int amount;
  final DateTime? nextClaimAt;
  final bool showPrompt;

  factory ClaimStatus.fromJson(Map<String, dynamic> json) {
    return ClaimStatus(
      canClaim: json.asBool('canClaim'),
      amount: json.asInt('amount'),
      nextClaimAt: json.asDateOrNull('nextClaimAt')?.toLocal(),
      showPrompt: json.asBool('showPrompt'),
    );
  }
}

class XpClaimResult {
  const XpClaimResult({required this.claimed, required this.amount, required this.totalXp, required this.streak});

  final bool claimed;
  final int amount;
  final double totalXp;
  final int streak;

  factory XpClaimResult.fromJson(Map<String, dynamic> json) {
    return XpClaimResult(
      claimed: json.asBool('claimed'),
      amount: json.asInt('amount'),
      totalXp: json.asDouble('total_xp'),
      streak: json.asInt('streak'),
    );
  }
}

class SeasonOption {
  const SeasonOption({required this.id, required this.name});

  final int id;
  final String name;

  factory SeasonOption.fromJson(Map<String, dynamic> json) {
    return SeasonOption(id: json.asInt('id'), name: json.asString('name'));
  }
}

/// Design-first restore state. Backend can fill it later (`StreakService`).
///
/// All fields have safe defaults so old `/dashboard` payloads without
/// `streakRestore` still parse — the UI just hides the restore banner.
class StreakRestoreInfo {
  const StreakRestoreInfo({
    this.isBroken = false,
    this.canRestore = false,
    this.restoreCost = 100,
    this.pointsBalance = 340,
    this.previousStreak = 0,
    this.breakLabel = 'yesterday',
    this.deadlineLabel = 'Restore within 48 hours',
    this.freezeAvailable = false,
  });

  final bool isBroken;
  final bool canRestore;
  final int restoreCost;
  final int pointsBalance;
  final int previousStreak;
  final String breakLabel;
  final String deadlineLabel;
  final bool freezeAvailable;

  bool get canAfford => pointsBalance >= restoreCost;

  factory StreakRestoreInfo.fromJson(Map<String, dynamic> json) {
    return StreakRestoreInfo(
      isBroken: json.asBool('isBroken'),
      canRestore: json.asBool('canRestore'),
      restoreCost: json.asInt('restoreCost', fallback: 100),
      pointsBalance: json.asInt('pointsBalance', fallback: 340),
      previousStreak: json.asInt('previousStreak'),
      breakLabel: json.asString('breakLabel', fallback: 'yesterday'),
      deadlineLabel: json.asString('deadlineLabel', fallback: 'Restore within 48 hours'),
      freezeAvailable: json.asBool('freezeAvailable'),
    );
  }
}

/// Result of a restore attempt (design stub — backend wires later).
class StreakRestoreResult {
  const StreakRestoreResult({required this.restored, required this.streak, this.message});

  final bool restored;
  final int streak;
  final String? message;
}

/// Everything `/api/dashboard` returns in one payload.
class DashboardData {
  const DashboardData({
    required this.userStats,
    required this.loginDates,
    required this.announcements,
    required this.assignments,
    required this.upcomingExams,
    required this.sectionLeaderboards,
    required this.claimXp,
    required this.bonusXp,
    required this.availableSeasons,
    required this.activeSeasonName,
    this.streakRestore = const StreakRestoreInfo(),
  });

  final UserStats userStats;

  /// `yyyy-MM-dd` for the last 90 days, used to draw the login streak heatmap.
  final Set<String> loginDates;
  final List<Announcement> announcements;
  final List<AssignmentSummary> assignments;
  final List<UpcomingExam> upcomingExams;
  final List<SectionLeaderboard> sectionLeaderboards;
  final ClaimStatus claimXp;
  final ClaimStatus bonusXp;
  final List<SeasonOption> availableSeasons;
  final String? activeSeasonName;
  final StreakRestoreInfo streakRestore;

  static final RegExp _dateKey = RegExp(r'^\d{4}-\d{2}-\d{2}');

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> activeSeason = json.asMap('activeSeason');

    return DashboardData(
      userStats: UserStats.fromJson(json.asMap('userStats')),
      loginDates: json
          .asMapList('loginDates')
          .map((Map<String, dynamic> e) => e.values.first)
          .whereType<String>()
          .where(_dateKey.hasMatch)
          .toSet(),
      announcements: json.asMapList('announcements').map(Announcement.fromJson).toList(growable: false),
      assignments: json.asMapList('assignments').map(AssignmentSummary.fromJson).toList(growable: false),
      upcomingExams: json.asMapList('upcomingExams').map(UpcomingExam.fromJson).toList(growable: false),
      sectionLeaderboards: json
          .asMapList('sectionLeaderboards')
          .map(SectionLeaderboard.fromJson)
          .toList(growable: false),
      claimXp: ClaimStatus.fromJson(json.asMap('claimXp')),
      bonusXp: ClaimStatus.fromJson(json.asMap('bonusXp')),
      availableSeasons: json.asMapList('availableSeasons').map(SeasonOption.fromJson).toList(growable: false),
      activeSeasonName: activeSeason['name'] as String?,
      streakRestore: json.asMap('streakRestore').isEmpty
          ? const StreakRestoreInfo()
          : StreakRestoreInfo.fromJson(json.asMap('streakRestore')),
    );
  }
}