import 'package:in_app_update/in_app_update.dart';
import 'package:flutter/foundation.dart';

class UpdateService {
  static final UpdateService _instance = UpdateService._internal();
  factory UpdateService() => _instance;
  UpdateService._internal();

  /// Checks for updates on Google Play.
  /// This should be called on app startup.
  Future<void> checkForUpdate() async {
    if (kIsWeb || (defaultTargetPlatform != TargetPlatform.android)) {
      return;
    }

    try {
      final info = await InAppUpdate.checkForUpdate();
      
      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        // If the update is "Immediate" (Hard Update suggested by Play Store)
        if (info.immediateUpdateAllowed) {
          await InAppUpdate.performImmediateUpdate();
        } 
        // If the update is "Flexible" (Soft Update suggested by Play Store)
        else if (info.flexibleUpdateAllowed) {
          await InAppUpdate.startFlexibleUpdate();
          // After download, we could prompt to install, but Play Store usually handles this.
          await InAppUpdate.completeFlexibleUpdate();
        }
      }
    } catch (e) {
      debugPrint('UpdateService Error: $e');
    }
  }
}
