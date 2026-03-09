import '../../features/shared/models/app_models.dart';

class AppSession {
  AppSession._();

  static final AppSession instance = AppSession._();

  String? token;
  SessionProfile? profile;

  bool get isLoggedIn => token != null && profile != null;

  void setSession({
    required String token,
    required SessionProfile profile,
  }) {
    this.token = token;
    this.profile = profile;
  }

  void clear() {
    token = null;
    profile = null;
  }

  void updateProfile(SessionProfile nextProfile) {
    profile = nextProfile;
  }
}
