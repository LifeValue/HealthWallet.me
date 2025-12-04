import 'package:health_wallet/gen/assets.gen.dart';

class RecordInfoLine {
  const RecordInfoLine({
    required this.icon,
    required this.info,
    this.isSection = false,
  });

  final SvgGenImage icon;
  final String info;
  final bool isSection;
}
