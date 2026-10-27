import 'package:dan/app/navigation/scroll_to_top_scope.dart';
import 'package:dan/app/theme/theme.dart';
import 'package:dan/app/widgets/widgets.dart';
import 'package:dan/l10n/l10n.dart';
import 'package:dan/status/bloc/status_list_bloc.dart';
import 'package:dan/status/models/status_list_layout.dart';
import 'package:dan/status/widgets/monthly_status_photos.dart';
import 'package:dan/status/widgets/status_list_item.dart';
import 'package:dan/status/widgets/status_list_skeleton.dart';
import 'package:flutter/cupertino.dart' show CupertinoSliverRefreshControl;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:status_repository/status_repository.dart' as status_repository;

/// Displays a refreshable, paginated list of Fanfou statuses.
class StatusList extends StatefulWidget {
  /// Creates a status list.
  const StatusList({
    this.scrollToTopKey,
    this.emptyLabel,
    this.enableRefresh = true,
    this.layout = StatusListLayout.timeline,
    super.key,
  });

  /// Layout used for statuses and their loading placeholders.
  final StatusListLayout layout;

  final Object? scrollToTopKey;

  /// Whether pulling down requests the newest statuses.
  final bool enableRefresh;

  /// Optional accessible description for the empty-state illustration.
  final String? emptyLabel;

  @override
  State<StatusList> createState() => _StatusListState();
}

class _StatusListState extends State<StatusList> {
  static const _minimumRefreshIndicatorDuration = Duration(milliseconds: 1000);

  late final ScrollController _scrollController;
  ScrollToTopController? _scrollToTopController;
  VoidCallback? _unregisterScrollToTop;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = ScrollToTopScope.maybeOf(context);
    if (identical(controller, _scrollToTopController)) return;
    _unregisterScrollToTop?.call();
    _scrollToTopController = controller;
    _unregisterScrollToTop = controller?.register(
      widget.scrollToTopKey,
      _scrollToTop,
    );
  }

  void _scrollToTop() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: Durations.medium2,
      curve: Easing.standard,
    );
  }

  @override
  void dispose() {
    _unregisterScrollToTop?.call();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() => _requestMoreIfNearEnd();

  void _requestMoreIfNearEnd({
    bool fillViewportOnly = false,
    bool retryAfterFailure = false,
  }) {
    if (!mounted || !_scrollController.hasClients) return;
    if (context.read<StatusListBloc>().state.loadMoreStatus ==
            StatusLoadMoreStatus.failure &&
        !retryAfterFailure) {
      return;
    }
    final position = _scrollController.position;
    if (fillViewportOnly &&
        position.maxScrollExtent > position.viewportDimension * 0.5) {
      // The content already fills the viewport; further pagination is driven
      // by the user's scrolling so an off-screen list cannot paginate on its
      // own.
      return;
    }
    if (position.extentAfter <= position.viewportDimension * 0.5) {
      context.read<StatusListBloc>().add(
        const StatusListLoadMoreRequested(),
      );
    }
  }

  /// Whether [current] completed a load cycle into a state that may still
  /// leave the viewport under-filled, warranting one automatic fill attempt.
  bool _shouldAutoFill(StatusListState previous, StatusListState current) {
    return current.status == StatusListStatus.success &&
        current.refreshStatus == StatusRefreshStatus.idle &&
        current.loadMoreStatus == StatusLoadMoreStatus.idle &&
        current.hasMore &&
        (previous.status != current.status ||
            previous.refreshStatus != current.refreshStatus ||
            previous.loadMoreStatus != current.loadMoreStatus);
  }

  Future<void> _refresh() async {
    final bloc = context.read<StatusListBloc>();
    final minimumDisplayElapsed = Future<void>.delayed(
      _minimumRefreshIndicatorDuration,
    );
    final refreshCompleted = bloc.stream
        .skipWhile(
          (state) => state.refreshStatus != StatusRefreshStatus.inProgress,
        )
        .firstWhere(
          (state) => state.refreshStatus != StatusRefreshStatus.inProgress,
        );
    bloc.add(const StatusListRefreshRequested());
    await Future.wait<Object?>([
      minimumDisplayElapsed,
      refreshCompleted,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        final userScroll =
            notification is ScrollUpdateNotification &&
                notification.dragDetails != null &&
                (notification.scrollDelta ?? 0) > 0 ||
            notification is OverscrollNotification &&
                notification.dragDetails != null &&
                notification.overscroll > 0;
        if (notification.depth == 0 &&
            userScroll &&
            context.read<StatusListBloc>().state.loadMoreStatus ==
                StatusLoadMoreStatus.failure) {
          _requestMoreIfNearEnd(retryAfterFailure: true);
        }
        return false;
      },
      child: MultiBlocListener(
        listeners: [
          BlocListener<StatusListBloc, StatusListState>(
            listenWhen: _shouldAutoFill,
            listener: (context, state) {
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => _requestMoreIfNearEnd(fillViewportOnly: true),
              );
            },
          ),
          BlocListener<StatusListBloc, StatusListState>(
            listenWhen: (previous, current) =>
                (previous.refreshStatus != current.refreshStatus &&
                    current.refreshStatus == StatusRefreshStatus.failure) ||
                (previous.loadMoreStatus != current.loadMoreStatus &&
                    current.loadMoreStatus == StatusLoadMoreStatus.failure),
            listener: (context, state) {
              // The full-page failure view already reports this error in
              // place; toasts are for failures behind visible content.
              if (state.status == StatusListStatus.failure) return;
              showAppFailureToast(
                context,
                message: state.requestFailureMessage,
              );
            },
          ),
        ],
        child: BlocConsumer<StatusListBloc, StatusListState>(
          listenWhen: (previous, current) =>
              (previous.actionFailure != current.actionFailure &&
                  current.actionFailure?.action == StatusAction.favorite) ||
              (previous.favoriteSuccess != current.favoriteSuccess &&
                  current.favoriteSuccess != null),
          listener: (context, state) {
            final message = state.actionFailure?.action == StatusAction.favorite
                ? state.actionFailure?.message ??
                      context.l10n.statusFavoriteFailure
                : state.favoriteSuccess!.isFavorited
                ? context.l10n.statusFavoriteSuccess
                : context.l10n.statusUnfavoriteSuccess;
            showAppToast(context, message);
          },
          builder: (context, state) {
            return switch (state.status) {
              StatusListStatus.initial ||
              StatusListStatus.loading => StatusListSkeleton(
                semanticLabel: context.l10n.statusListLoadingLabel,
                layout: widget.layout,
              ),
              StatusListStatus.empty => _RefreshableStatusListMessage(
                scrollController: _scrollController,
                onRefresh: widget.enableRefresh ? _refresh : null,
                child: state.hasProfileCountMismatch
                    ? _StatusListMessage(
                        text: context.l10n.statusListEmptyLabel,
                      )
                    : AppEmptyView(semanticLabel: widget.emptyLabel),
              ),
              StatusListStatus.failure => _RefreshableStatusListMessage(
                scrollController: _scrollController,
                onRefresh: widget.enableRefresh ? _refresh : null,
                child: _StatusListFailure(
                  message: state.requestFailureMessage,
                  onRetry: () => context.read<StatusListBloc>().add(
                    const StatusListInitialLoadRequested(),
                  ),
                ),
              ),
              StatusListStatus.success => _StatusListView(
                layout: widget.layout,
                scrollController: _scrollController,
                statuses: state.statuses,
                loadMoreStatus: state.loadMoreStatus,
                onRefresh: widget.enableRefresh ? _refresh : null,
              ),
            };
          },
        ),
      ),
    );
  }
}

class _StatusListView extends StatelessWidget {
  const _StatusListView({
    required this.scrollController,
    required this.statuses,
    required this.loadMoreStatus,
    required this.onRefresh,
    required this.layout,
  });

  final ScrollController scrollController;
  final List<status_repository.Status> statuses;
  final StatusLoadMoreStatus loadMoreStatus;
  final RefreshCallback? onRefresh;
  final StatusListLayout layout;

  @override
  Widget build(BuildContext context) {
    return _PlatformRefreshableScrollView(
      scrollController: scrollController,
      onRefresh: onRefresh,
      slivers: [
        if (layout == StatusListLayout.monthlyPhotos)
          MonthlyStatusPhotos(statuses: statuses)
        else
          SliverList.separated(
            itemBuilder: (context, index) {
              final status = statuses[index];
              return StatusListItem(
                status: status,
                key: ValueKey(status.id),
                layout: layout,
                previousCreatedAt: index == 0
                    ? null
                    : statuses[index - 1].createdAt,
                onStatusDelete: () async {
                  final bloc = context.read<StatusListBloc>();
                  final completed = bloc.stream
                      .skipWhile(
                        (state) => !state.deletingStatusIds.contains(status.id),
                      )
                      .firstWhere(
                        (state) => !state.deletingStatusIds.contains(status.id),
                      );
                  bloc.add(StatusListStatusDeletionRequested(status.id));
                  final result = await completed;
                  if (result.actionFailure case final failure?
                      when failure.statusId == status.id &&
                          failure.action == StatusAction.delete) {
                    throw StateError('Status deletion failed.');
                  }
                },
                onStatusFavoriteToggle: () =>
                    context.read<StatusListBloc>().add(
                      StatusListStatusFavoriteToggled(status.id),
                    ),
              );
            },
            separatorBuilder: (context, index) {
              if (layout == StatusListLayout.timeline) {
                return const Divider(height: 1);
              }
              final sizing = context.appSizing;
              return Padding(
                padding: EdgeInsetsDirectional.only(
                  start: sizing.scaled(
                    AppSpacing.md + AppLayout.momentsDateColumnWidth,
                  ),
                ),
                child: const Divider(height: 1),
              );
            },
            itemCount: statuses.length,
          ),
        if (layout == StatusListLayout.timeline)
          const SliverToBoxAdapter(child: Divider(height: 1)),
        SliverToBoxAdapter(
          child: _StatusListFooter(
            layout: layout,
            status: loadMoreStatus,
          ),
        ),
      ],
    );
  }
}

class _RefreshableStatusListMessage extends StatelessWidget {
  const _RefreshableStatusListMessage({
    required this.scrollController,
    required this.onRefresh,
    required this.child,
  });

  final ScrollController scrollController;
  final RefreshCallback? onRefresh;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _PlatformRefreshableScrollView(
      scrollController: scrollController,
      onRefresh: onRefresh,
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: child,
        ),
      ],
    );
  }
}

class _PlatformRefreshableScrollView extends StatelessWidget {
  const _PlatformRefreshableScrollView({
    required this.scrollController,
    required this.onRefresh,
    required this.slivers,
  });

  final ScrollController scrollController;
  final RefreshCallback? onRefresh;
  final List<Widget> slivers;

  @override
  Widget build(BuildContext context) {
    final scrollView = CustomScrollView(
      controller: scrollController,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        if (onRefresh != null)
          CupertinoSliverRefreshControl(onRefresh: onRefresh),
        ...slivers,
      ],
    );

    return scrollView;
  }
}

class _StatusListMessage extends StatelessWidget {
  const _StatusListMessage({
    required this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    final sizing = context.appSizing;
    return Center(
      child: Padding(
        padding: EdgeInsetsDirectional.all(sizing.scaled(AppSpacing.lg)),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: context.appTypography.statusBody.copyWith(
            color: context.appColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _StatusListFailure extends StatelessWidget {
  const _StatusListFailure({required this.onRetry, this.message});

  final VoidCallback onRetry;
  final String? message;

  @override
  Widget build(BuildContext context) =>
      AppRetryView(message: message, onRetry: onRetry);
}

class _StatusListFooter extends StatelessWidget {
  const _StatusListFooter({
    required this.status,
    required this.layout,
  });

  final StatusLoadMoreStatus status;
  final StatusListLayout layout;

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      StatusLoadMoreStatus.idle => const SizedBox.shrink(),
      StatusLoadMoreStatus.inProgress => StatusListSkeleton(
        layout: layout,
        semanticLabel: context.l10n.statusListLoadingLabel,
        itemCount: 1,
        shrinkWrap: true,
      ),
      StatusLoadMoreStatus.failure => const SizedBox.shrink(),
    };
  }
}
