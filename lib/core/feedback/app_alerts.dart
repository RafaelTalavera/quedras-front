import 'dart:async';

import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/material.dart';

import '../theme/costa_norte_brand.dart';
import '../widgets/app_dialog_dimensions.dart';

final class AppAlerts {
  static Future<void> success(
    BuildContext context, {
    required String title,
    required String message,
    String buttonLabel = 'Fechar',
  }) {
    _show(
      context,
      dialogType: DialogType.success,
      title: title,
      message: message,
      buttonLabel: buttonLabel,
      buttonColor: CostaNorteBrand.success,
    );
    return Future<void>.value();
  }

  static Future<void> error(
    BuildContext context, {
    required String title,
    required String message,
    String buttonLabel = 'Entendi',
  }) {
    _show(
      context,
      dialogType: DialogType.error,
      title: title,
      message: message,
      buttonLabel: buttonLabel,
      buttonColor: CostaNorteBrand.error,
    );
    return Future<void>.value();
  }

  static Future<void> warning(
    BuildContext context, {
    required String title,
    required String message,
    String buttonLabel = 'Entendi',
  }) {
    _show(
      context,
      dialogType: DialogType.warning,
      title: title,
      message: message,
      buttonLabel: buttonLabel,
      buttonColor: CostaNorteBrand.goldDeep,
    );
    return Future<void>.value();
  }

  static Future<void> info(
    BuildContext context, {
    required String title,
    required String message,
    String buttonLabel = 'Fechar',
  }) {
    _show(
      context,
      dialogType: DialogType.info,
      title: title,
      message: message,
      buttonLabel: buttonLabel,
      buttonColor: CostaNorteBrand.royalBlue,
    );
    return Future<void>.value();
  }

  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirmar',
    String cancelLabel = 'Voltar',
  }) {
    final Completer<bool> completer = Completer<bool>();

    AwesomeDialog(
      context: context,
      dialogType: DialogType.question,
      customHeader: _buildHeader(
        dialogType: DialogType.question,
        iconColor: CostaNorteBrand.royalBlue,
      ),
      animType: AnimType.scale,
      title: title,
      desc: message,
      dialogBackgroundColor: Colors.white,
      width: AppDialogDimensions.alertWidth,
      titleTextStyle: Theme.of(context).textTheme.headlineSmall,
      descTextStyle: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(color: CostaNorteBrand.mutedInk),
      btnOkText: confirmLabel,
      btnCancelText: cancelLabel,
      btnOkColor: CostaNorteBrand.royalBlue,
      btnCancelColor: Colors.white,
      buttonsTextStyle: Theme.of(
        context,
      ).textTheme.labelLarge?.copyWith(color: Colors.white),
      dismissOnBackKeyPress: true,
      dismissOnTouchOutside: true,
      btnOkOnPress: () {
        if (!completer.isCompleted) {
          completer.complete(true);
        }
      },
      btnCancelOnPress: () {
        if (!completer.isCompleted) {
          completer.complete(false);
        }
      },
      onDismissCallback: (_) {
        if (!completer.isCompleted) {
          completer.complete(false);
        }
      },
    ).show();

    return completer.future;
  }

  static void _show(
    BuildContext context, {
    required DialogType dialogType,
    required String title,
    required String message,
    required String buttonLabel,
    required Color buttonColor,
  }) {
    AwesomeDialog(
      context: context,
      dialogType: dialogType,
      customHeader: _buildHeader(
        dialogType: dialogType,
        iconColor: buttonColor,
      ),
      animType: AnimType.scale,
      title: title,
      desc: message,
      dialogBackgroundColor: Colors.white,
      width: AppDialogDimensions.alertWidth,
      titleTextStyle: Theme.of(context).textTheme.headlineSmall,
      descTextStyle: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(color: CostaNorteBrand.mutedInk),
      btnOkText: buttonLabel,
      btnOkColor: buttonColor,
      buttonsTextStyle: Theme.of(
        context,
      ).textTheme.labelLarge?.copyWith(color: Colors.white),
      dismissOnBackKeyPress: true,
      dismissOnTouchOutside: true,
      btnOkOnPress: () {},
    ).show();
  }

  static Widget _buildHeader({
    required DialogType dialogType,
    required Color iconColor,
  }) {
    return Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.12),
        shape: BoxShape.circle,
        border: Border.all(color: iconColor.withValues(alpha: 0.24), width: 2),
      ),
      alignment: Alignment.center,
      child: Icon(_iconFor(dialogType), color: iconColor, size: 40),
    );
  }

  static IconData _iconFor(DialogType dialogType) {
    switch (dialogType) {
      case DialogType.success:
        return Icons.check_circle_rounded;
      case DialogType.error:
        return Icons.error_rounded;
      case DialogType.warning:
        return Icons.warning_rounded;
      case DialogType.question:
        return Icons.help_rounded;
      case DialogType.info:
      case DialogType.infoReverse:
        return Icons.info_rounded;
      case DialogType.noHeader:
        return Icons.notifications_active_rounded;
    }
  }
}
