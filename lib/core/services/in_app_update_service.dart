import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_update_flutter/in_app_update_flutter.dart';
import 'package:web_pos_mobile/core/constants/app_strings.dart';
import 'package:web_pos_mobile/core/widgets/state_views.dart';

enum InAppUpdateStatus {
  idle,
  checking,
  available,
  downloading,
  downloaded,
  completed,
  noUpdate,
  failed,
}

@immutable
class InAppUpdateState {
  const InAppUpdateState({
    this.status = InAppUpdateStatus.idle,
    this.bytesDownloaded = 0,
    this.totalBytesToDownload = 0,
    this.errorMessage,
    this.androidInfo,
  });

  final InAppUpdateStatus status;
  final int bytesDownloaded;
  final int totalBytesToDownload;
  final String? errorMessage;
  final AppUpdateInfoAndroid? androidInfo;

  bool get isChecking => status == InAppUpdateStatus.checking;
  bool get isDownloading => status == InAppUpdateStatus.downloading;
  bool get isDownloaded => status == InAppUpdateStatus.downloaded;
  bool get isAvailable => status == InAppUpdateStatus.available;

  double get downloadProgress =>
      totalBytesToDownload > 0 ? (bytesDownloaded / totalBytesToDownload).clamp(0.0, 1.0) : 0.0;

  InAppUpdateState copyWith({
    InAppUpdateStatus? status,
    int? bytesDownloaded,
    int? totalBytesToDownload,
    String? errorMessage,
    AppUpdateInfoAndroid? androidInfo,
  }) {
    return InAppUpdateState(
      status: status ?? this.status,
      bytesDownloaded: bytesDownloaded ?? this.bytesDownloaded,
      totalBytesToDownload: totalBytesToDownload ?? this.totalBytesToDownload,
      errorMessage: errorMessage ?? this.errorMessage,
      androidInfo: androidInfo ?? this.androidInfo,
    );
  }
}

final inAppUpdateFlutterPluginProvider = Provider<InAppUpdateFlutter>((ref) {
  return InAppUpdateFlutter();
});

final inAppUpdateServiceProvider =
    NotifierProvider<InAppUpdateService, InAppUpdateState>(InAppUpdateService.new);

class InAppUpdateService extends Notifier<InAppUpdateState> {
  StreamSubscription<InstallStateAndroid>? _installSubscription;

  InAppUpdateFlutter get _plugin => ref.read(inAppUpdateFlutterPluginProvider);
  String get _appStoreId => const String.fromEnvironment('APP_STORE_ID', defaultValue: '');

  @override
  InAppUpdateState build() {
    ref.onDispose(() {
      _installSubscription?.cancel();
    });
    return const InAppUpdateState();
  }

  /// Checks for application updates.
  ///
  /// Set [silent] to true for quiet startup checks that only prompt if an update is
  /// downloaded or immediate update is required. If [silent] is false, user feedback
  /// (e.g. up to date or errors) will be displayed via SnackBar in [context].
  Future<void> checkForUpdate({
    bool silent = true,
    BuildContext? context,
  }) async {
    if (kIsWeb) {
      if (!silent && context != null && context.mounted) {
        showMessage(context, 'Pembaruan aplikasi tidak tersedia di versi web.');
      }
      return;
    }

    if (Platform.isAndroid) {
      await _checkAndroidUpdate(silent: silent, context: context);
    } else if (Platform.isIOS) {
      if (!silent) {
        await _showIosUpdate(context: context);
      }
    }
  }

  Future<void> _checkAndroidUpdate({
    required bool silent,
    BuildContext? context,
  }) async {
    if (state.isChecking || state.isDownloading) return;

    state = state.copyWith(status: InAppUpdateStatus.checking, errorMessage: null);

    try {
      final info = await _plugin.checkUpdateAndroid();
      debugPrint('InAppUpdateService: $info');

      if (info.updateAvailability == UpdateAvailabilityAndroid.updateAvailable) {
        state = state.copyWith(
          status: InAppUpdateStatus.available,
          androidInfo: info,
        );

        if (info.isImmediateUpdateAllowed && info.updatePriority >= 4) {
          await _plugin.startImmediateUpdateAndroid();
          return;
        }

        if (info.isFlexibleUpdateAllowed) {
          _startFlexibleDownload();
          return;
        }

        if (info.isImmediateUpdateAllowed) {
          await _plugin.startImmediateUpdateAndroid();
          return;
        }
      } else if (info.updateAvailability ==
          UpdateAvailabilityAndroid.developerTriggeredUpdateInProgress) {
        if (info.installStatus == InstallStatusAndroid.downloaded) {
          state = state.copyWith(
            status: InAppUpdateStatus.downloaded,
            androidInfo: info,
          );
        } else {
          await _plugin.startImmediateUpdateAndroid();
        }
      } else {
        state = state.copyWith(status: InAppUpdateStatus.noUpdate, androidInfo: info);
        if (!silent && context != null && context.mounted) {
          showMessage(context, AboutStrings.noUpdateAvailable);
        }
      }
    } on PlatformException catch (e) {
      debugPrint('InAppUpdateService Android check failed: [${e.code}] ${e.message}');
      state = state.copyWith(
        status: InAppUpdateStatus.failed,
        errorMessage: e.message ?? e.code,
      );
      if (!silent && context != null && context.mounted) {
        showMessage(context, AboutStrings.updateCheckFailed, isError: true);
      }
    } catch (e) {
      debugPrint('InAppUpdateService check error: $e');
      state = state.copyWith(
        status: InAppUpdateStatus.failed,
        errorMessage: e.toString(),
      );
      if (!silent && context != null && context.mounted) {
        showMessage(context, AboutStrings.updateCheckFailed, isError: true);
      }
    }
  }

  void _startFlexibleDownload() {
    state = state.copyWith(status: InAppUpdateStatus.downloading);

    _installSubscription?.cancel();
    _installSubscription = _plugin.installStateStreamAndroid.listen(
      (installState) {
        debugPrint('InAppUpdateService installState: $installState');
        if (installState.status == InstallStatusAndroid.downloading) {
          state = state.copyWith(
            status: InAppUpdateStatus.downloading,
            bytesDownloaded: installState.bytesDownloaded,
            totalBytesToDownload: installState.totalBytesToDownload,
          );
        } else if (installState.status == InstallStatusAndroid.downloaded) {
          state = state.copyWith(status: InAppUpdateStatus.downloaded);
        } else if (installState.status == InstallStatusAndroid.failed) {
          state = state.copyWith(
            status: InAppUpdateStatus.failed,
            errorMessage: 'Download failed',
          );
        }
      },
      onError: (err) {
        debugPrint('InAppUpdateService stream error: $err');
      },
    );

    _plugin.startFlexibleUpdateAndroid().catchError((err) {
      debugPrint('startFlexibleUpdateAndroid failed: $err');
      return UpdateResultAndroid.inAppUpdateFailed;
    });
  }

  /// Triggers an immediate app restart to complete the installation of a downloaded update.
  Future<void> completeFlexibleUpdate() async {
    try {
      await _plugin.completeUpdateAndroid();
      state = state.copyWith(status: InAppUpdateStatus.completed);
    } catch (e) {
      debugPrint('InAppUpdateService.completeFlexibleUpdate error: $e');
    }
  }

  Future<void> _showIosUpdate({BuildContext? context}) async {
    if (_appStoreId.isEmpty) {
      if (context != null && context.mounted) {
        showMessage(context, AboutStrings.noUpdateAvailable);
      }
      return;
    }

    try {
      await _plugin.showUpdateForIos(appStoreId: _appStoreId);
    } on PlatformException catch (e) {
      debugPrint('InAppUpdateService iOS error: [${e.code}] ${e.message}');
      if (context != null && context.mounted) {
        showMessage(context, AboutStrings.updateCheckFailed, isError: true);
      }
    } catch (e) {
      debugPrint('InAppUpdateService iOS error: $e');
      if (context != null && context.mounted) {
        showMessage(context, AboutStrings.updateCheckFailed, isError: true);
      }
    }
  }
}
