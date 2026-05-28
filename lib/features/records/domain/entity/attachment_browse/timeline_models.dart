import 'package:freezed_annotation/freezed_annotation.dart';

part 'timeline_models.freezed.dart';

@freezed
class TimelineYear with _$TimelineYear {
  const factory TimelineYear({
    required int year,
    @Default([]) List<TimelineMonth> months,
  }) = _TimelineYear;
}

@freezed
class TimelineMonth with _$TimelineMonth {
  const factory TimelineMonth({
    required int month,
    @Default(0) int recordCount,
    @Default(0) int firstRecordIndex,
  }) = _TimelineMonth;
}
