import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/core/l10n/l10n.dart';

class QRScannerWidget extends StatefulWidget {
  final Function(String) onQRCodeDetected;
  final VoidCallback? onCancel;
  final String? title;
  final String? cancelButtonText;

  const QRScannerWidget({
    super.key,
    required this.onQRCodeDetected,
    this.onCancel,
    this.title,
    this.cancelButtonText,
  });

  @override
  State<QRScannerWidget> createState() => _QRScannerWidgetState();
}

class _QRScannerWidgetState extends State<QRScannerWidget> {
  bool _isScannerActive = true;
  final MobileScannerController _controller = MobileScannerController();
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _isScannerActive = false;
    _controller.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.l10n.scanQRMessage,
            style: AppTextStyle.labelLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Insets.medium),
          SizedBox(
            height: 450,
            child: ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(12)),
              child: Stack(
                children: [
                  MobileScanner(
                    controller: _controller,
                    onDetect: (capture) {
                      if (!_isScannerActive) return;
                      final List<Barcode> barcodes = capture.barcodes;
                      if (barcodes.isNotEmpty) {
                        final String code = barcodes.first.rawValue ?? '';
                        if (code.isNotEmpty) {
                          setState(() {
                            _isScannerActive = false;
                          });
                          widget.onQRCodeDetected(code);
                        }
                      }
                    },
                  ),
                  if (_errorMessage != null)
                    Container(
                      color: Colors.black54,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(Insets.normal),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: Colors.white,
                                size: 48,
                              ),
                              const SizedBox(height: Insets.small),
                              Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: Insets.medium),
                              ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    _errorMessage = null;
                                  });
                                  _controller.start();
                                },
                                child: Text(context.l10n.retry),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Insets.medium),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                setState(() {
                  _isScannerActive = false;
                });
                if (widget.onCancel != null) {
                  widget.onCancel!();
                }
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: context.isDarkMode
                    ? Colors.white
                    : context.colorScheme.primary,
                side: BorderSide(color: context.colorScheme.primary),
                padding: const EdgeInsets.all(10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                widget.cancelButtonText ?? context.l10n.cancel,
                style: AppTextStyle.buttonSmall
                    .copyWith(color: context.colorScheme.primary),
              ),
            ),
          ),
        ],
    );
  }
}
