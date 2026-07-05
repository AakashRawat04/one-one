import 'app_user_profile.dart';
import 'user_device_record.dart';
import 'user_settings_record.dart';

class IdentitySession {
  const IdentitySession({
    required this.user,
    required this.device,
    required this.settings,
  });

  final AppUserProfile user;
  final UserDeviceRecord device;
  final UserSettingsRecord settings;

  String get userId => user.userId;
  String get deviceId => device.deviceId;
}
