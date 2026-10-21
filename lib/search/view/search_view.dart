import 'package:dan/app/navigation/scroll_to_top_scope.dart';
import 'package:dan/app/theme/theme.dart';
import 'package:dan/app/widgets/widgets.dart';
import 'package:dan/l10n/l10n.dart';
import 'package:dan/search/models/search_scope.dart';
import 'package:dan/status/status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:remixicon/remixicon.dart';

/// Search input and paginated status results.
class SearchView extends StatefulWidget {
  const SearchView({
    this.initialQuery,
    this.initialScope = SearchScope.all,
    this.mineBloc,
    this.userBloc,
    super.key,
  });

  final String? initialQuery;
  final SearchScope initialScope;
  final StatusListBloc? mineBloc;
  final StatusListBloc? userBloc;

  @override
  State<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<SearchView> {
  final _scrollToTopController = ScrollToTopController();
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  late SearchScope _scope;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChanged);
    _scope =
        widget.userBloc == null &&
            widget.initialScope != SearchScope.all &&
            widget.initialScope != SearchScope.mine
        ? SearchScope.all
        : widget.initialScope;
    final query = widget.initialQuery?.trim() ?? '';
    if (query.isNotEmpty) {
      _controller.text = query;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _submit();
      });
    }
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_handleFocusChanged)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleFocusChanged() {
    if (mounted) setState(() {});
  }

  void _submit() {
    if (_controller.text.trim().isEmpty) return;
    FocusScope.of(context).unfocus();
    final bloc = _statusBloc;
    final state = bloc.state;
    if (state.status == StatusListStatus.loading &&
        state.searchQuery == _controller.text.trim()) {
      return;
    }
    bloc.add(StatusListSearchSubmitted(_controller.text));
  }

  void _clearResults() {
    _statusBloc.add(const StatusListSearchSubmitted(''));
  }

  StatusListBloc get _statusBloc =>
      _scope == SearchScope.mine && widget.mineBloc != null
      ? widget.mineBloc!
      : _scope != SearchScope.all && widget.userBloc != null
      ? widget.userBloc!
      : context.read<StatusListBloc>();

  void _selectScope(SearchScope scope) {
    if (_scope == scope) return;
    setState(() => _scope = scope);
    if (_controller.text.trim().isNotEmpty) {
      _submit();
    } else {
      _clearResults();
    }
  }

  Future<void> _showScopePicker() async {
    await showAppActionSheet(
      context,
      groups: [
        AppActionSheetGroup(
          children: [
            for (final scope in _availableScopes)
              AppActionSheetItem(
                label: _scopeLabel(context, scope),
                icon: _scope == scope ? Icons.check : null,
                iconColor: _scope == scope
                    ? Theme.of(context).colorScheme.primary
                    : context.appColors.textSecondary,
                onPressed: () => _selectScope(scope),
              ),
          ],
        ),
      ],
    );
  }

  List<SearchScope> get _availableScopes => [
    SearchScope.all,
    SearchScope.mine,
    if (widget.userBloc != null &&
        widget.initialScope != SearchScope.all &&
        widget.initialScope != SearchScope.mine)
      widget.initialScope,
  ];

  String _scopeLabel(BuildContext context, SearchScope scope) =>
      switch (scope) {
        SearchScope.all => context.l10n.searchScopeAll,
        SearchScope.mine => context.l10n.searchScopeMine,
        SearchScope.his => context.l10n.searchScopeHis,
        SearchScope.hers => context.l10n.searchScopeHers,
        SearchScope.theirs => context.l10n.searchScopeTheirs,
      };

  String _scopeHint(BuildContext context, SearchScope scope) => switch (scope) {
    SearchScope.all => context.l10n.searchHintAll,
    SearchScope.mine => context.l10n.searchHintMine,
    SearchScope.his => context.l10n.searchHintHis,
    SearchScope.hers => context.l10n.searchHintHers,
    SearchScope.theirs => context.l10n.searchHintTheirs,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final controlHeight = context.appSizing.scaled(40);
    const inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(16)),
      borderSide: BorderSide.none,
    );
    return ScrollToTopScope(
      controller: _scrollToTopController,
      child: Scaffold(
        backgroundColor: context.appColors.groupedBackground,
        appBar: PreferredSize(
          preferredSize: Size.fromHeight(
            context.appSizing.appBarToolbarHeight + AppSpacing.xs,
          ),
          child: DoubleTapListener(
            onDoubleTap: _scrollToTopController.scrollToTop,
            child: AppBar(
              backgroundColor: context.appColors.groupedBackground,
              shape: const Border(),
              toolbarHeight: context.appSizing.appBarToolbarHeight,
              bottom: const PreferredSize(
                preferredSize: Size.fromHeight(AppSpacing.xs),
                child: SizedBox(height: AppSpacing.xs),
              ),
              titleSpacing: 0,
              title: Padding(
                padding: const EdgeInsetsDirectional.only(end: AppSpacing.md),
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  autofocus: widget.initialQuery?.trim().isEmpty ?? true,
                  textInputAction: TextInputAction.search,
                  style: context.appTypography.statusBody,
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    constraints: BoxConstraints.tightFor(height: controlHeight),
                    hintText: _scopeHint(context, _scope),
                    prefixIcon: InkWell(
                      onTap: _showScopePicker,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(width: AppSpacing.sm),
                          const Icon(RemixIcons.equalizer_2_line, size: 18),
                          const SizedBox(width: AppSpacing.xxs),
                          Text(_scopeLabel(context, _scope)),
                          const SizedBox(width: AppSpacing.xxs),
                        ],
                      ),
                    ),
                    isDense: true,
                    filled: true,
                    fillColor: context.appColors.bgBase,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    border: inputBorder,
                    enabledBorder: inputBorder,
                    focusedBorder: inputBorder,
                    suffixIconConstraints: const BoxConstraints(maxHeight: 40),
                    suffixIcon: BlocBuilder<StatusListBloc, StatusListState>(
                      bloc: _statusBloc,
                      builder: (context, state) =>
                          ValueListenableBuilder<TextEditingValue>(
                            valueListenable: _controller,
                            builder: (context, value, _) => Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (value.text.isNotEmpty)
                                  IconButton(
                                    style: IconButton.styleFrom(
                                      minimumSize: Size.square(
                                        context.appSizing.scaled(40),
                                      ),
                                      fixedSize: Size.square(
                                        context.appSizing.scaled(40),
                                      ),
                                      padding: EdgeInsets.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    tooltip: l10n.searchClearLabel,
                                    icon: const Icon(
                                      RemixIcons.close_line,
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      _controller.clear();
                                      _clearResults();
                                    },
                                  ),
                                if (_focusNode.hasFocus &&
                                    value.text.trim().isNotEmpty) ...[
                                  Container(
                                    key: const ValueKey(
                                      'search-action-divider',
                                    ),
                                    width: 1,
                                    height: context.appSizing.scaled(16),
                                    color: context.appColors.divider,
                                  ),
                                  _SearchAction(
                                    label: l10n.searchPageTitle,
                                    enabled:
                                        value.text.trim().isNotEmpty &&
                                        state.status !=
                                            StatusListStatus.loading,
                                    onSubmit: _submit,
                                  ),
                                ],
                              ],
                            ),
                          ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        body: SafeArea(
          top: false,
          bottom: false,
          child: BlocBuilder<StatusListBloc, StatusListState>(
            bloc: _statusBloc,
            buildWhen: (previous, current) =>
                previous.searchQuery != current.searchQuery ||
                previous.status != current.status,
            builder: (context, state) {
              if (state.status == StatusListStatus.initial) {
                return const SizedBox.shrink();
              }
              return BlocProvider.value(
                value: _statusBloc,
                child: StatusList(
                  key: ValueKey((_scope, state.searchQuery)),
                  emptyLabel: l10n.searchEmpty,
                  enableRefresh: false,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SearchAction extends StatelessWidget {
  const _SearchAction({
    required this.label,
    required this.enabled,
    required this.onSubmit,
  });
  final String label;
  final bool enabled;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: enabled,
    child: InkWell(
      onTap: enabled ? onSubmit : null,
      borderRadius: BorderRadius.circular(AppLayout.buttonRadius),
      child: Padding(
        padding: const EdgeInsetsDirectional.only(
          start: AppSpacing.sm,
          end: AppSpacing.sm,
          top: AppSpacing.xs,
          bottom: AppSpacing.xs,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    ),
  );
}
