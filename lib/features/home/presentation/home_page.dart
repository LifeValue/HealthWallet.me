import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/navigation/app_router.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/core/utils/patient_source_utils.dart';
import 'package:health_wallet/core/widgets/custom_app_bar.dart';
import 'package:health_wallet/core/widgets/overlay_annotations/overlay_annotations.dart';
import 'package:health_wallet/features/home/core/constants/home_constants.dart';
import 'package:health_wallet/features/home/presentation/bloc/home_bloc.dart';
import 'package:health_wallet/features/home/presentation/widgets/home_dashboard_sections.dart';
import 'package:health_wallet/features/home/presentation/widgets/home_greeting_title.dart';
import 'package:health_wallet/features/home/presentation/widgets/home_patient_bar.dart';
import 'package:health_wallet/features/sync/presentation/bloc/sync_bloc.dart';
import 'package:health_wallet/features/sync/presentation/widgets/sync_placeholder_widget.dart';
import 'package:health_wallet/core/utils/responsive.dart';
import 'package:health_wallet/features/user/presentation/bloc/user_bloc.dart';
import 'package:health_wallet/features/user/presentation/preferences_modal/sections/patient/bloc/patient_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

@RoutePage()
class HomePage extends StatelessWidget {
  final PageController pageController;
  const HomePage({super.key, required this.pageController});

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<PatientBloc, PatientState>(
          listenWhen: (previous, current) {
            final selectionChanged =
                previous.selectedPatientId != current.selectedPatientId;

            final selectedId = current.selectedPatientId;
            if (selectedId != null) {
              final previousPatient = previous.patients
                  .where((p) => p.id == selectedId)
                  .firstOrNull;
              final currentPatient =
                  current.patients.where((p) => p.id == selectedId).firstOrNull;
              final dataChanged =
                  previousPatient?.displayTitle != currentPatient?.displayTitle;

              return selectionChanged || dataChanged;
            }

            return selectionChanged;
          },
          listener: (context, patientState) {
            PatientSourceUtils.handlePatientChange(context, patientState);
            context.read<HomeBloc>().add(const HomeRefreshPreservingOrder());
          },
        ),
        BlocListener<SyncBloc, SyncState>(
          listenWhen: (previous, current) =>
              (previous.hasDemoData != current.hasDemoData) ||
              (previous.hasSyncedData != current.hasSyncedData),
          listener: (context, state) {
            if (state.hasDemoData || state.hasSyncedData) {
              context.read<HomeBloc>().add(const HomeRefreshPreservingOrder());
            }
          },
        ),
        BlocListener<UserBloc, UserState>(
          listenWhen: (previous, current) =>
              previous.regionPreset != current.regionPreset,
          listener: (context, state) {
            context.read<HomeBloc>().add(const HomeRefreshPreservingOrder());
          },
        ),
      ],
      child: HomeView(pageController: pageController),
    );
  }
}

class HomeView extends StatefulWidget {
  final PageController pageController;
  const HomeView({super.key, required this.pageController});

  @override
  State<HomeView> createState() => HomeViewState();
}

class HomeViewState extends State<HomeView> {
  late final HomeHighlightController _highlightController;
  late final MultiHighlightOverlayController _overlayController;

  bool _hasShownOnboarding = false;
  bool _isScrolled = false;
  final GlobalKey _patientRowKey = GlobalKey();
  double _patientRowHeight = 0;

  @override
  void initState() {
    super.initState();
    _highlightController = HomeHighlightController();
    _overlayController = MultiHighlightOverlayController();
  }

  @override
  void dispose() {
    _overlayController.hide();
    super.dispose();
  }

  void showOnboardingDirectly() {
    _hasShownOnboarding = false;
    _showOnboardingOverlay();
  }

  void _showOnboardingOverlay() {
    if (!mounted) return;

    _overlayController.show(
      context: context,
      targetKeys: _highlightController.highlightTargetKeys,
      message: context.l10n.homeOnboardingReorderMessage,
      subtitle: context.l10n.tapToContinue,
      onDismiss: () async {
        context.read<SyncBloc>().add(const ResetTutorial());

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('onboarding_shown', true);

        _hasShownOnboarding = false;
      },
    );
  }

  Future<void> _onRefresh() async {
    context.read<HomeBloc>().add(const HomeRefreshPreservingOrder());
    await Future.delayed(HomeConstants.refreshDelay);
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SyncBloc, SyncState>(
      listenWhen: (previous, current) {
        return previous.shouldShowTutorial != current.shouldShowTutorial;
      },
      listener: (context, syncState) {
        if (!syncState.shouldShowTutorial) {
          _hasShownOnboarding = false;
          return;
        }

        if (syncState.shouldShowTutorial && !_hasShownOnboarding) {
          _hasShownOnboarding = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _showOnboardingOverlay();
            }
          });
        }
      },
      child: BlocBuilder<HomeBloc, HomeState>(
        builder: (context, state) {
          if (state.status.runtimeType ==
              const HomeStatus.initial().runtimeType) {
            return Scaffold(
              backgroundColor: context.colorScheme.surface,
              body: Center(
                child: CircularProgressIndicator(
                  color: context.colorScheme.primary,
                ),
              ),
            );
          }

          return Scaffold(
            backgroundColor: context.colorScheme.surface,
            extendBody: true,
            appBar: CustomAppBar(
              automaticallyImplyLeading: false,
              titleWidget: HomeGreetingTitle(homeState: state),
              actions: const [],
              extraTopPadding: context.isTablet ? 16 : 0,
            ),
            body: RefreshIndicator(
              onRefresh: _onRefresh,
              color: context.colorScheme.primary,
              child: _buildHomeContent(context, state),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHomeContent(BuildContext context, HomeState state) {
    if (state.shouldShowPlaceholder) {
      final placeholder = SyncPlaceholderWidget(
        pageController: widget.pageController,
        onSyncPressed: () {
          context.router.push(const SyncRoute());
        },
        recordTypeName: null,
      );

      if (context.isTablet) {
        return LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: Align(
                  alignment: const Alignment(0, -0.3),
                  child: placeholder,
                ),
              ),
            );
          },
        );
      }

      return placeholder;
    }

    return _buildDashboardLayout(context, state);
  }

  Widget _buildDashboardLayout(BuildContext context, HomeState state) {
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (state.hasDataLoaded)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                height: _patientRowHeight,
                color: Colors.transparent,
              ),
            Expanded(
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  final scrolled = notification.metrics.pixels > 0;
                  if (scrolled != _isScrolled) {
                    setState(() => _isScrolled = scrolled);
                  }
                  return false;
                },
                child: CustomScrollView(
                  slivers: [
                    HomeDashboardSections(
                      state: state,
                      editMode: state.editMode,
                      highlightController: _highlightController,
                      pageController: widget.pageController,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (state.hasDataLoaded)
          HomePatientBar(
            state: state,
            isScrolled: _isScrolled,
            patientRowKey: _patientRowKey,
            onHeightMeasured: (height) {
              if (height != _patientRowHeight && mounted) {
                setState(() => _patientRowHeight = height);
              }
            },
          ),
      ],
    );
  }
}
