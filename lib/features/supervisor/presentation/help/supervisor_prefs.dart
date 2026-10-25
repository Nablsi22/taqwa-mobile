import '../../../../core/storage/secure_storage_service.dart';

/// What the course director has already been shown on this phone.
///
/// Kept per device and never cleared on sign-out: the introduction is for a
/// first use, not for every sign-in. The welcome animation is not stored —
/// it greets him every time he signs in.
class SupervisorPrefs {
  SupervisorPrefs._();

  static const _tourKey = 'supervisor_tour_seen_v1';
  static const _tipKey = 'supervisor_help_tip_dismissed_v1';

  static final SecureStorageService _storage = SecureStorageService();

  static Future<bool> tourSeen() async => await _storage.readSetting(_tourKey) == '1';

  static Future<void> markTourSeen() => _storage.writeSetting(_tourKey, '1');

  /// The «شرح» tip at the top of the home screen.
  static Future<bool> helpTipDismissed() async => await _storage.readSetting(_tipKey) == '1';

  static Future<void> dismissHelpTip() => _storage.writeSetting(_tipKey, '1');

  /// From the guide: show the introduction and the tip again.
  static Future<void> resetIntroduction() async {
    await _storage.deleteSetting(_tourKey);
    await _storage.deleteSetting(_tipKey);
  }
}
