import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/l10n/l10n.dart';
import 'package:health_wallet/features/records/domain/entity/encounter/encounter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:health_wallet/features/processing/presentation/bloc/processing_bloc.dart';
import 'package:auto_route/auto_route.dart';
import 'package:health_wallet/core/navigation/app_router.dart';

class DialogHelper {
  static void showPermissionRequiredDialog(
      BuildContext context, VoidCallback onRetry) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(context.l10n.cameraPermissionRequired),
          content: Text(
            context.l10n.cameraPermissionRequiredMessage,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.l10n.cancel),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onRetry();
              },
              child: Text(context.l10n.tryAgain),
            ),
          ],
        );
      },
    );
  }

  static void showPermissionDeniedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(context.l10n.cameraPermissionDenied),
          content: Text(
            context.l10n.cameraPermissionDeniedMessage,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.l10n.cancel),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                openAppSettings();
              },
              child: Text(context.l10n.openSettings),
            ),
          ],
        );
      },
    );
  }

  static Widget buildAttachmentSuccessDialog(
      BuildContext context, int count, Encounter encounter, ProcessingBloc bloc) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green),
          const SizedBox(width: 8),
          Text(context.l10n.successTitle),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.attachmentSuccessMessage(count),
          ),
          const SizedBox(height: 8),
          Text(
            '${context.l10n.encounterLabel}: ${encounter.id}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text(context.l10n.ok),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            context.router.push(RecordsRoute());
          },
          child: Text(context.l10n.viewRecords),
        ),
      ],
    );
  }

  static void showAttachmentSuccessDialog(
      BuildContext context, int count, Encounter encounter, ProcessingBloc bloc) {
    showDialog(
      context: context,
      builder: (context) =>
          buildAttachmentSuccessDialog(context, count, encounter, bloc),
    );
  }

  static void showErrorDialog(BuildContext context, String errorMessage) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.error, color: Colors.red),
            const SizedBox(width: 8),
            Text(context.l10n.errorTitle),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.l10n.somethingWentWrong),
            const SizedBox(height: 8),
            Text(
              errorMessage,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.ok),
          ),
        ],
      ),
    );
  }

  static void showLoadingDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Text(message),
          ],
        ),
      ),
    );
  }
}
