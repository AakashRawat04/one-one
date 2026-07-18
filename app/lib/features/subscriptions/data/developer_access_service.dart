import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/network/api_client.dart';

class DeveloperAccessService {
  DeveloperAccessService({FirebaseAuth? auth, ApiClient? apiClient})
    : _auth = auth ?? FirebaseAuth.instance,
      _apiClient = apiClient ?? ApiClient(auth: auth);

  static const String claimName = 'oneOneDeveloper';

  final FirebaseAuth _auth;
  final ApiClient _apiClient;

  Future<bool> hasDeveloperBypass({bool forceRefresh = false}) async {
    final user = _auth.currentUser;
    if (user == null) return false;
    final result = await user.getIdTokenResult(forceRefresh);
    return result.claims?[claimName] == true;
  }

  Future<bool> redeem(String code) async {
    final normalized = code.trim();
    if (normalized.isEmpty) return false;

    final response = await _apiClient.postJson('/v1/subscriptions/redeem', {
      'code': normalized,
    });
    if (response['redeemed'] != true) return false;
    return hasDeveloperBypass(forceRefresh: true);
  }
}
