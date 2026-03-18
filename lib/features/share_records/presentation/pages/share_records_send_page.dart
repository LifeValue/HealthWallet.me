import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:health_wallet/features/share_records/presentation/pages/share_records_page.dart';
import 'package:health_wallet/features/records/domain/entity/i_fhir_resource.dart';

@RoutePage()
class ShareRecordsSendPage extends StatelessWidget {
  final List<IFhirResource>? preSelectedResources;
  final List<FhirType>? appliedFilters;

  const ShareRecordsSendPage({
    super.key,
    this.preSelectedResources,
    this.appliedFilters,
  });

  @override
  Widget build(BuildContext context) {
    return ShareRecordsPage(
      autoSelectSendMode: true,
      preSelectedResources: preSelectedResources,
      appliedFilters: appliedFilters,
    );
  }
}
