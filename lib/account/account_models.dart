class AccountUser {
  final String uid;
  final String phone;
  final String nick;
  final String token;
  final int rating;
  final int wins;
  final int losses;
  final int draws;
  final int created;

  const AccountUser({
    required this.uid,
    required this.phone,
    required this.nick,
    required this.token,
    this.rating = 1200,
    this.wins = 0,
    this.losses = 0,
    this.draws = 0,
    this.created = 0,
  });

  String get maskedPhone {
    if (phone.length < 7) return phone;
    return '${phone.substring(0, 3)}****${phone.substring(phone.length - 4)}';
  }

  AccountUser copyWith({
    String? uid,
    String? phone,
    String? nick,
    String? token,
    int? rating,
    int? wins,
    int? losses,
    int? draws,
    int? created,
  }) {
    return AccountUser(
      uid: uid ?? this.uid,
      phone: phone ?? this.phone,
      nick: nick ?? this.nick,
      token: token ?? this.token,
      rating: rating ?? this.rating,
      wins: wins ?? this.wins,
      losses: losses ?? this.losses,
      draws: draws ?? this.draws,
      created: created ?? this.created,
    );
  }

  Map<String, Object?> toJson() => {
        'uid': uid,
        'phone': phone,
        'nick': nick,
        'token': token,
        'rating': rating,
        'wins': wins,
        'losses': losses,
        'draws': draws,
        'created': created,
      };

  static AccountUser? fromJson(Map<String, dynamic> json) {
    try {
      final uid = json['uid']?.toString();
      final nick = json['nick']?.toString();
      final token = json['token']?.toString();
      if (uid == null || nick == null || token == null) return null;
      return AccountUser(
        uid: uid,
        phone: json['phone']?.toString() ?? '',
        nick: nick,
        token: token,
        rating: (json['rating'] as num?)?.toInt() ?? 1200,
        wins: (json['wins'] as num?)?.toInt() ?? 0,
        losses: (json['losses'] as num?)?.toInt() ?? 0,
        draws: (json['draws'] as num?)?.toInt() ?? 0,
        created: (json['created'] as num?)?.toInt() ?? 0,
      );
    } catch (_) {
      return null;
    }
  }
}

class AccountException implements Exception {
  final String message;
  final int? statusCode;

  const AccountException(this.message, [this.statusCode]);

  @override
  String toString() => message;
}
