import 'dart:async';
import 'dart:math' as math;

import 'package:dan/app/theme/theme.dart';
import 'package:dan/app/widgets/widgets.dart';
import 'package:dan/l10n/l10n.dart';
import 'package:dan/status/cubit/status_mention_cubit.dart';
import 'package:dan/status/widgets/status_composer_text_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:status_repository/status_repository.dart';

/// Anchors mention suggestions below the active @ in the editor.
class StatusMentionSuggestions extends StatefulWidget {
  const StatusMentionSuggestions({
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.onChanged,
    required this.child,
    super.key,
  });
  final StatusComposerTextController controller;
  final FocusNode focusNode;
  final bool enabled;
  final ValueChanged<String> onChanged;
  final Widget child;

  @override
  State<StatusMentionSuggestions> createState() =>
      _StatusMentionSuggestionsState();
}

class _StatusMentionSuggestionsState extends State<StatusMentionSuggestions> {
  final _portal = OverlayPortalController();
  final LayerLink _link = LayerLink();
  RenderEditable? _editor;
  final GlobalKey _target = GlobalKey();
  StatusMentionCubit? _cubit;
  bool _scheduled = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_schedule);
    widget.focusNode.addListener(_schedule);
  }

  @override
  void didUpdateWidget(StatusMentionSuggestions oldWidget) {
    super.didUpdateWidget(oldWidget);
    _schedule();
  }

  void _schedule() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted) return;
      final range = widget.controller.activeMention;
      if (!widget.enabled || !widget.focusNode.hasFocus || range == null) {
        _portal.hide();
        return;
      }
      if (_cubit == null) {
        _cubit = StatusMentionCubit(
          statusRepository: context.read<StatusRepository>(),
        );
        unawaited(_cubit!.load());
      }
      _cubit!.queryChanged(
        widget.controller.text.substring(
          range.start + 1,
          widget.controller.selection.end,
        ),
      );
      _editor = _editable();
      _portal.show();
      setState(() {});
    });
  }

  RenderEditable? _editable() {
    RenderEditable? result;
    void visit(Element element) {
      if (element.widget is EditableText) {
        result = (element as StatefulElement).state is EditableTextState
            ? (element.state as EditableTextState).renderEditable
            : null;
      } else {
        element.visitChildren(visit);
      }
    }

    _target.currentContext?.visitChildElements(visit);
    return result;
  }

  @override
  void dispose() {
    widget.controller.removeListener(_schedule);
    widget.focusNode.removeListener(_schedule);
    unawaited(_cubit?.close());
    super.dispose();
  }

  Widget _overlay(BuildContext context) {
    final range = widget.controller.activeMention;
    final editable = _editor;
    final target = _target.currentContext?.findRenderObject() as RenderBox?;
    if (range == null || editable == null || target == null || _cubit == null) {
      return const SizedBox.shrink();
    }
    final media = MediaQuery.of(context);
    final caret = editable.getLocalRectForCaret(
      TextPosition(offset: range.start),
    );
    final global = editable.localToGlobal(caret.bottomLeft);
    final left = target.localToGlobal(Offset.zero).dx;
    final double width = math.min(340, media.size.width - left - 16);
    final bottom = media.size.height - media.viewInsets.bottom - 64;
    final double available = math.max(0, bottom - global.dy - 4);
    if (available < 48) return const SizedBox.shrink();
    final offset = target.globalToLocal(Offset(left, global.dy + 4));
    return Positioned(
      width: width,
      child: CompositedTransformFollower(
        link: _link,
        showWhenUnlinked: false,
        offset: offset,
        child: TextFieldTapRegion(
          child: Material(
            key: const Key('status-mention-suggestions'),
            color: Theme.of(context).colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: context.appColors.divider, width: 0.5),
            ),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: math.min(240, available)),
              child: BlocBuilder<StatusMentionCubit, StatusMentionState>(
                bloc: _cubit,
                builder: (context, state) {
                  if (state.loading) {
                    return const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (state.failed) {
                    return TextButton(
                      onPressed: () => unawaited(_cubit!.load()),
                      child: Text(context.l10n.retryButtonLabel),
                    );
                  }
                  if (state.users.isEmpty) {
                    return AppEmptyView(
                      semanticLabel: context.l10n.statusMentionEmpty,
                    );
                  }
                  return ListView.separated(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: state.users.length,
                    separatorBuilder: (context, index) => Divider(
                      height: 0.5,
                      thickness: 0.5,
                      color: context.appColors.divider,
                    ),
                    itemBuilder: (context, index) {
                      final user = state.users[index];
                      final name = user.name.isEmpty
                          ? user.screenName
                          : user.name;
                      final id = user.id;
                      return ListTile(
                        leading: UserAvatar(
                          imageUrl: user.avatarUrl,
                          semanticLabel: name,
                          size: context.appSizing.scaled(40),
                        ),
                        title: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '@$id',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () {
                          final current = widget.controller.activeMention;
                          if (current == null) return;
                          widget.controller.insertMention(
                            name,
                            selection: TextSelection(
                              baseOffset: current.start,
                              extentOffset: current.end,
                            ),
                          );
                          widget.onChanged(widget.controller.text);
                          _portal.hide();
                          widget.focusNode.requestFocus();
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => OverlayPortal(
    controller: _portal,
    overlayChildBuilder: _overlay,
    child: CompositedTransformTarget(
      link: _link,
      child: SizedBox(key: _target, child: widget.child),
    ),
  );
}
