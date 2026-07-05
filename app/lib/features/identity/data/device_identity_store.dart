import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class DeviceIdentityStore {
  static const String _installIdKey = 'one_one_install_id';
  static const String _deviceIdKey = 'one_one_device_id';

  Future<LocalDeviceIdentity> getOrCreate() async {
    final prefs = await SharedPreferences.getInstance();
    final uuid = const Uuid();

    final installId = prefs.getString(_installIdKey) ?? uuid.v4();
    final deviceId = prefs.getString(_deviceIdKey) ?? uuid.v4();

    await prefs.setString(_installIdKey, installId);
    await prefs.setString(_deviceIdKey, deviceId);

    return LocalDeviceIdentity(installId: installId, deviceId: deviceId);
  }
}

class LocalDeviceIdentity {
  const LocalDeviceIdentity({required this.installId, required this.deviceId});

  final String installId;
  final String deviceId;
}
