import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:health_wallet/core/l10n/l10n.dart';
import 'package:health_wallet/core/navigation/app_router.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/core/widgets/app_button.dart';
import 'package:health_wallet/features/scan/domain/entity/processing_session.dart';
import 'package:health_wallet/features/scan/presentation/pages/load_model/bloc/load_model_bloc.dart';
import 'package:health_wallet/features/scan/presentation/widgets/session_list.dart';
import 'package:health_wallet/gen/assets.gen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:health_wallet/core/widgets/custom_app_bar.dart';
import 'package:health_wallet/features/scan/presentation/bloc/scan_bloc.dart';
import 'package:health_wallet/features/scan/presentation/widgets/dialog_helper.dart';
import 'package:health_wallet/features/scan/presentation/helpers/document_handler.dart';
import 'package:health_wallet/features/dashboard/presentation/helpers/page_view_navigation_controller.dart';
import 'package:health_wallet/features/dashboard/presentation/helpers/navigation_settled_callback_mixin.dart';

@RoutePage()
class ScanPage extends StatelessWidget {
  const ScanPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => GetIt.instance.get<LoadModelBloc>(),
      child: const ScanView(),
    );
  }
}

class ScanView extends StatefulWidget {
  const ScanView({super.key});

  @override
  State<ScanView> createState() => _ScanViewState();
}

class _ScanViewState extends State<ScanView>
    with DocumentHandler, NavigationSettledCallbackMixin {
  bool _hasAutoScanned = false;
  late final PageViewNavigationController _navigationController;

  @override
  PageViewNavigationController? get navigationController =>
      _navigationController;

  @override
  void onPageSettled() {
    context.read<LoadModelBloc>().add(const LoadModelInitialized());
    _autoStartScanning();
  }

  @override
  void onPageLeft() {
    setState(() {
      _hasAutoScanned = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _navigationController = GetIt.instance.get<PageViewNavigationController>();
    initializeNavigationSettledListener(2);
  }

  @override
  void dispose() {
    disposeNavigationSettledListener();
    super.dispose();
  }

  Future<void> _autoStartScanning() async {
    if (_hasAutoScanned) {
      return;
    }

    _hasAutoScanned = true;

    final currentState = context.read<ScanBloc>().state;
    final hasAnySessions = currentState.sessions
        .any((session) => session.origin == ProcessingOrigin.scan);

    if (!hasAnySessions) {
      await _handleScanButtonPressed(context);
    }
  }

  void _resetAutoScanFlag() {
    if (_hasAutoScanned) {
      setState(() {
        _hasAutoScanned = false;
      });
      resetTriggerFlag();
    }
  }

  Future<void> _handleScanButtonPressed(BuildContext context) async {
    final cameraStatus = await Permission.camera.request();

    if (cameraStatus.isGranted) {
      if (context.mounted) {
        context.read<ScanBloc>().add(const ScanButtonPressed());
      }
    } else if (cameraStatus.isPermanentlyDenied) {
      DialogHelper.showPermissionDeniedDialog(context);
    } else {
      DialogHelper.showPermissionRequiredDialog(
        context,
        () => _handleScanButtonPressed(context),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: AppLocalizationsX(context).l10n.onboardingScanButton,
        automaticallyImplyLeading: false,
        actions: [
          BlocBuilder<LoadModelBloc, LoadModelState>(
            builder: (context, state) {
              // Hide the button entirely if model is loaded
              if (state.status == LoadModelStatus.modelLoaded) {
                return const SizedBox.shrink();
              }

              return TextButton.icon(
                onPressed: () => context.router.push(LoadModelRoute()),
                icon: const Icon(Icons.memory_outlined),
                label: Text(
                  AppLocalizationsX(context).l10n.onboardingAiModelTitle,
                  style: TextStyle(
                    color: context.colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: context.colorScheme.primary,
                ),
              );
            },
          ),
        ],
      ),
      body: MultiBlocListener(
        listeners: [
          BlocListener<ScanBloc, ScanState>(
            listenWhen: (previous, current) {
              return previous.sessions.isNotEmpty && current.sessions.isEmpty;
            },
            listener: (context, state) {
              if (state.sessions.isEmpty && _hasAutoScanned) {
                _resetAutoScanFlag();

                if (_navigationController.currentPage == 2) {
                  _autoStartScanning();
                }
              }
            },
          ),
          BlocListener<ScanBloc, ScanState>(
            listenWhen: (previous, current) =>
                previous.status != current.status,
            listener: (context, state) {
              if (state.status case SessionCreated(:final session)) {
                if (_navigationController.currentPage == 2) {
                  navigateToFhirMapper(context, session);
                }
              }
            },
          ),
        ],
        child: BlocBuilder<ScanBloc, ScanState>(
          builder: (context, state) {
            return state.status.maybeWhen(
              initial: () => _buildMainView(context, state),
              loading: () => _buildLoadingView(),
              sessionCreated: (session) => _buildMainView(context, state),
              failure: (error) => _buildMainView(context, state),
              orElse: () => _buildMainView(context, state),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLoadingView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Opening scanner...'),
        ],
      ),
    );
  }

  Widget _buildMainView(BuildContext context, ScanState state) {
  List<ProcessingSession> scanSessions = state.sessions
      .where((element) => element.origin == ProcessingOrigin.scan)
      .toList();

  return Padding(
    padding: const EdgeInsets.all(16.0),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        if (scanSessions.isNotEmpty)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Active scan sessions:",
                  style: AppTextStyle.titleMedium,
                ),
                const SizedBox(height: 12),
                const Text(
                  "Only one processing session can run at a time!",
                  style: AppTextStyle.bodySmall,
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: SessionList(sessions: scanSessions),
                ),
                const SizedBox(height: 16),
               Padding(
                  padding: const EdgeInsets.only(bottom: 80.0),
                  child: AppButton(
                    label: 'Scan Document',
                    icon: Assets.icons.scan.svg(),
                    variant: AppButtonVariant.primary,
                    onPressed: () => _handleDirectScan(context),
                  ),
                ),
              ],
            ),
          ),
        if (scanSessions.isEmpty)
          Column(
            children: [
              const SizedBox(height: 16),
              Assets.images.emptyScan.svg(),
              const SizedBox(height: 36),
              const Text(
                "No scans yet",
                style: AppTextStyle.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                "Scan or import documents to get started",
                style: AppTextStyle.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              AppButton(
                label: 'Scan Document',
                icon: Assets.icons.scan.svg(),
                variant: AppButtonVariant.primary,
                onPressed: () => _handleDirectScan(context),
              ),
            ],
          ),
      ],
    ),
  );
}

  Future<void> _handleDirectScan(BuildContext context) async {
    final cameraStatus = await Permission.camera.request();

    if (cameraStatus.isGranted) {
      if (context.mounted) {
        context.read<ScanBloc>().add(const ScanButtonPressed());
      }
    } else if (cameraStatus.isPermanentlyDenied) {
      DialogHelper.showPermissionDeniedDialog(context);
    } else {
      DialogHelper.showPermissionRequiredDialog(
        context,
        () => _handleDirectScan(context),
      );
    }
  }
}
