class StartupSessionPolicy {
  const StartupSessionPolicy._();

  static bool shouldResume({
    required bool hadInitialFirebaseUser,
    required bool hasCurrentFirebaseUser,
  }) {
    return hadInitialFirebaseUser || hasCurrentFirebaseUser;
  }
}
