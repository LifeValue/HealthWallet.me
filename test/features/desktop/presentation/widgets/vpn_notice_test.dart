import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/features/desktop/presentation/widgets/vpn_notice.dart';

void main() {
  Future<void> pump(WidgetTester tester, {double width = 400}) =>
      tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: width,
                child: const VpnNotice(
                  message:
                      'A VPN is on for this computer. It can stop your '
                      'phone from connecting.',
                ),
              ),
            ),
          ),
        ),
      );

  testWidgets('shows the message in the warning colour', (tester) async {
    await pump(tester);

    final text = tester.widget<Text>(find.textContaining('A VPN is on'));
    expect(text.style?.color, AppColors.warning);
  });

  testWidgets('shows the VPN lock icon in the warning colour', (tester) async {
    await pump(tester);

    final icon = tester.widget<Icon>(find.byIcon(Icons.vpn_lock));
    expect(icon.color, AppColors.warning);
    expect(icon.size, 14);
  });

  testWidgets('wraps a long message instead of overflowing', (tester) async {
    await pump(tester, width: 120);

    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byType(Text)).height,
      greaterThan(tester.getSize(find.byIcon(Icons.vpn_lock)).height),
    );
  });
}
