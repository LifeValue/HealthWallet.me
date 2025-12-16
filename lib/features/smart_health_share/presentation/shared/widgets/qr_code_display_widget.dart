import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:health_wallet/core/theme/app_insets.dart';

class QRCodeDisplayWidget extends StatelessWidget {
  final String qrData;
  final double size;

  const QRCodeDisplayWidget({
    super.key,
    required this.qrData,
    this.size = 300,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Insets.medium),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: QrImageView(
        data: qrData,
        size: size,
        backgroundColor: Colors.white,
      ),
    );
  }
}


