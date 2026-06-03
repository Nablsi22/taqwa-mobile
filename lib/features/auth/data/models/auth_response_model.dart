class AuthResponseModel {
  final String accessToken;
  final String? refreshToken;

  const AuthResponseModel({
    required this.accessToken,
    this.refreshToken,
  });

  factory AuthResponseModel.fromJson(Map<String, dynamic> json) {
    return AuthResponseModel(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String?,
    );
  }
}