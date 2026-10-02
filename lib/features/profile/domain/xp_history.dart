import '../../../core/utils/json_parsing.dart';

/// A group of ledger entries, as the level sheet summarises them.
enum XpCategory {
  exam('Exams'),
  assignment('Assignments'),
  daily('Daily check-in'),
  bonus('Bonus'),
  season('Season & adjustments'),
  other('Other');

  const XpCategory(this.label);

  final String label;

  static XpCategory fromReason(String reason) {
    return switch (reason) {
      'Daily Claim' => XpCategory.daily,
      'Bonus Claim' => XpCategory.bonus,
      'Assignment Graded' => XpCategory.assignment,
      'Exam Submission' ||
      'Exam Completion XP' ||
      'On-time Exam XP' ||
      'Exam Accuracy XP' => XpCategory.exam,
      'Season Reward' || 'Admin Adjustment' => XpCategory.season,
      _ => XpCategory.other,
    };
  }
}

/// One entry in the student's XP ledger.
class XpEntry {
  const XpEntry({
    required this.id,
    required this.amountXp,
    required this.reason,
    this.description,
    this.sectionName,
    this.createdAt,
    required this.createdAtLabel,
  });

  final int id;
  final double amountXp;

  /// Short machine-ish reason ("Exam submitted", "Daily streak"), which is what
  /// the ledger row leads with.
  final String reason;

  /// What exactly earned it — an exam title, an assignment, a day count.
  final String? description;

  final String? sectionName;
  final DateTime? createdAt;

  /// The server's own "M d, Y H:i" string, kept for display so the row still
  /// reads correctly even if the date cannot be parsed.
  final String createdAtLabel;

  bool get isCredit => amountXp >= 0;

  String get amountLabel => '${isCredit ? '+' : '−'}${amountXp.abs().toStringAsFixed(0)} XP';

  /// What kind of work this entry was, for grouping a summary.
  ///
  /// `reason` is a closed set the server writes: `Daily Claim`, `Bonus Claim`,
  /// `Assignment Graded`, `Exam Submission`, and the three per-component exam
  /// reasons `Exam Completion XP` / `On-time Exam XP` / `Exam Accuracy XP`. A
  /// reason this app does not recognise still renders — it just falls into
  /// [XpCategory.other], so a new server-side reason cannot make an entry vanish.
  XpCategory get category => XpCategory.fromReason(reason);

  factory XpEntry.fromJson(Map<String, dynamic> json) {
    return XpEntry(
      id: json.asInt('id'),
      amountXp: json.asDouble('amount_xp'),
      reason: json.asString('reason'),
      description: json.asStringOrNull('description'),
      sectionName: json.asStringOrNull('section_name'),
      createdAt: json.asDateOrNull('created_at'),
      createdAtLabel: json.asString('created_at'),
    );
  }
}

/// A cursor page of [XpEntry].
class XpHistory {
  const XpHistory({this.entries = const <XpEntry>[], this.hasMore = false, this.nextCursor});

  final List<XpEntry> entries;
  final bool hasMore;
  final String? nextCursor;

  bool get isEmpty => entries.isEmpty;

  double get netXp => entries.fold<double>(0, (double sum, XpEntry e) => sum + e.amountXp);

  double get earnedXp => entries
      .where((XpEntry e) => e.isCredit)
      .fold<double>(0, (double sum, XpEntry e) => sum + e.amountXp);

  int get deductionCount => entries.where((XpEntry e) => !e.isCredit).length;

  /// XP per [XpCategory] across this page.
  ///
  /// A page, not a season: the endpoint is cursor-paginated and this holds only
  /// what has been fetched, so the sheet labels the total as recent.
  Map<XpCategory, double> get byCategory {
    final Map<XpCategory, double> totals = <XpCategory, double>{};

    for (final XpEntry entry in entries) {
      totals.update(
        entry.category,
        (double sum) => sum + entry.amountXp,
        ifAbsent: () => entry.amountXp,
      );
    }

    return totals;
  }

  static const XpHistory empty = XpHistory();

  factory XpHistory.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> meta = json.asMap('meta');

    return XpHistory(
      entries: json.asMapList('data').map(XpEntry.fromJson).toList(growable: false),
      hasMore: meta.asBool('hasMore'),
      nextCursor: meta.asStringOrNull('nextCursor'),
    );
  }
}
