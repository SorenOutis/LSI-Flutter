import '../../../core/utils/json_parsing.dart';

class AppUser {
  const AppUser({
    required this.id,
    required this.publicId,
    required this.name,
    required this.email,
    this.firstName,
    this.lastName,
    this.middleName,
    this.currentStreak,
    this.level,
    this.exp,
  });

  final int id;
  final String publicId;
  final String name;
  final String email;
  final String? firstName;
  final String? lastName;
  final String? middleName;
  final int? currentStreak;
  final int? level;
  final double? exp;

  String get firstNameOrTitle {
    final String? first = firstName?.trim();
    return first != null && first.isNotEmpty ? first : name;
  }

  String get initials {
    final List<String> parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((String p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json.asInt('id'),
      publicId: json.asString('public_id'),
      name: json.asString('name'),
      email: json.asString('email'),
      firstName: json.asStringOrNull('first_name'),
      lastName: json.asStringOrNull('last_name'),
      middleName: json.asStringOrNull('middle_name'),
      currentStreak: json['current_streak'] == null ? null : json.asInt('current_streak'),
      level: json['level'] == null ? null : json.asInt('level'),
      exp: json.asDoubleOrNull('exp'),
    );
  }

  AppUser copyWith({
    String? name,
    String? firstName,
    String? lastName,
    int? currentStreak,
    int? level,
    double? exp,
  }) {
    return AppUser(
      id: id,
      publicId: publicId,
      name: name ?? this.name,
      email: email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      middleName: middleName,
      currentStreak: currentStreak ?? this.currentStreak,
      level: level ?? this.level,
      exp: exp ?? this.exp,
    );
  }
}