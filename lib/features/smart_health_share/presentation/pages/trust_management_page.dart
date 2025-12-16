import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/features/smart_health_share/presentation/bloc/trust/trust_bloc.dart';

@RoutePage()
class TrustManagementPage extends StatelessWidget {
  const TrustManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: getIt<TrustBloc>(),
      child: const _TrustManagementPageView(),
    );
  }
}

class _TrustManagementPageView extends StatefulWidget {
  const _TrustManagementPageView();

  @override
  State<_TrustManagementPageView> createState() => _TrustManagementPageState();
}

class _TrustManagementPageState extends State<_TrustManagementPageView> {
  @override
  void initState() {
    super.initState();
    context.read<TrustBloc>().add(const TrustEvent.initialized());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Trusted Issuers',
          style: AppTextStyle.titleMedium,
        ),
        backgroundColor: context.colorScheme.inversePrimary,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.router.pop(),
        ),
      ),
      // ignore: undefined_class
      body: BlocBuilder<TrustBloc, TrustState>(
        builder: (context, state) {
          // ignore: undefined_getter
          final isLoading = state.isLoading;
          if (isLoading == true) {
            return const Center(child: CircularProgressIndicator());
          }

          // ignore: undefined_getter
          final errorMessage = state.errorMessage;
          // ignore: undefined_getter
          final successMessage = state.successMessage;
          // ignore: undefined_getter
          final issuers = state.issuers;

          return Column(
            children: [
              if (errorMessage != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(Insets.medium),
                  color: AppColors.error.withOpacity(0.1),
                  child: Text(
                    errorMessage,
                    style: AppTextStyle.labelMedium.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                ),
              if (successMessage != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(Insets.medium),
                  color: AppColors.success.withOpacity(0.1),
                  child: Text(
                    successMessage,
                    style: AppTextStyle.labelMedium.copyWith(
                      color: AppColors.success,
                    ),
                  ),
                ),
              Expanded(
                child: (issuers.isEmpty)
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.shield, size: 64),
                            const SizedBox(height: Insets.medium),
                            const Text(
                              'No trusted issuers',
                              style: AppTextStyle.titleMedium,
                            ),
                            const SizedBox(height: Insets.small),
                            const Text(
                              'Add issuers to verify health cards',
                              style: AppTextStyle.labelLarge,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(Insets.medium),
                        itemCount: issuers.length,
                        itemBuilder: (context, index) {
                          final issuer = issuers[index];
                          return Card(
                            child: ListTile(
                              leading: const Icon(Icons.shield),
                              title: Text(issuer.name),
                              subtitle: Text(
                                'ID: ${issuer.issuerId}\nSource: ${issuer.source}',
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () {
                                  context.read<TrustBloc>().add(
                                        TrustEvent.removeIssuer(
                                            issuer.issuerId),
                                      );
                                },
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
