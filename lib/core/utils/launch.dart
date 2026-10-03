import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:web_pos_mobile/core/constants/app_strings.dart';

import '../widgets/state_views.dart';

Future<void> openExternal(BuildContext context, Uri uri, {String failure = CoreStrings.errorLinkOpenFailed}) async {
  final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!opened && context.mounted) {
    showMessage(context, failure, isError: true);
  }
}

/// Same normalisation as the server: local "08xx" numbers become "628xx".
String? whatsappNumber(String? phone) {
  final digits = (phone ?? '').replaceAll(RegExp(r'\D'), '');
  if (digits.length < 9) {
    return null;
  }

  return digits.startsWith('0') ? '62${digits.substring(1)}' : digits;
}
