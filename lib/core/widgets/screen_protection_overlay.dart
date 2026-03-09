import 'package:flutter/material.dart';

class ScreenProtectionOverlay extends StatelessWidget {
  const ScreenProtectionOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.asset(
                  'assets/icons/app-icon.png',
                  width: 80,
                  height: 80,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.health_and_safety, size: 80),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'HealthWallet.me',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2C2D30),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              const Text(
                'NO SCREENSHOT ALLOWED ON THE SHARED HEALTH RECORDS',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
