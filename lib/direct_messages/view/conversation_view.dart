import 'dart:async';

import 'package:dan/app/theme/theme.dart';
import 'package:dan/app/view/app_subpage_app_bar.dart';
import 'package:dan/app/widgets/widgets.dart';
import 'package:dan/direct_messages/cubit/cubit.dart';
import 'package:dan/direct_messages/widgets/direct_message_bubble.dart';
import 'package:dan/l10n/l10n.dart';
import 'package:direct_message_repository/direct_message_repository.dart';
import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:remixicon/remixicon.dart';

/// Renders the conversation states, including the peer-titled app bar.
class ConversationView extends StatelessWidget {
  /// Creates the conversation view.
  const ConversationView({
    required this.activeAccountId,
    this.peerAvatarUrl,
    this.activeAccountAvatarUrl,
    super.key,
  });

  /// Identifier of the active account, used to align message bubbles.
  final String? activeAccountId;

  /// Peer avatar URL retained for API compatibility; chat avatars are hidden.
  final String? peerAvatarUrl;

  /// Active account avatar URL retained for API compatibility.
  final String? activeAccountAvatarUrl;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ConversationCubit, ConversationState>(
      builder: (context, state) {
        final peerScreenName = state.peerScreenName;
        final conversationBody = switch (state) {
          ConversationInitial() || ConversationLoadInProgress() => Center(
            child: CircularProgressIndicator(
              semanticsLabel:
                  context.l10n.directMessageConversationLoadingLabel,
            ),
          ),
          ConversationLoadFailure(:final message) => AppRetryView(
            message: message,
            onRetry: () => unawaited(context.read<ConversationCubit>().load()),
          ),
          ConversationLoadSuccess(
            :final messages,
            :final historyLoadStatus,
          ) =>
            messages.isEmpty
                ? _StatusView(
                    label: context.l10n.directMessageConversationEmptyLabel,
                  )
                : _MessageList(
                    messages: messages,
                    activeAccountId: activeAccountId,
                    historyLoadStatus: historyLoadStatus,
                  ),
        };
        return Scaffold(
          resizeToAvoidBottomInset: true,
          backgroundColor: context.appColors.bgBase,
          appBar: AppSubpageAppBar(
            title:
                peerScreenName ??
                context.l10n.directMessageConversationFallbackTitle,
            toolbarHeight: context.appSizing.appBarToolbarHeight,
          ),
          body: Column(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: FocusScope.of(context).unfocus,
                  child: conversationBody,
                ),
              ),
              const _MessageComposer(),
            ],
          ),
        );
      },
    );
  }
}

class _MessageComposer extends StatefulWidget {
  const _MessageComposer();

  @override
  State<_MessageComposer> createState() => _MessageComposerState();
}

class _MessageComposerState extends State<_MessageComposer> {
  late final TextEditingController _controller;
  String? _pendingMessageText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sizing = context.appSizing;
    final colors = context.appColors;
    final composerMinHeight = sizing.scaled(44);
    return DecoratedBox(
      key: const Key('conversation-message-composer'),
      decoration: BoxDecoration(
        color: colors.bgBase,
        border: Border(
          top: BorderSide(
            color: colors.divider,
            width: 0,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          key: const Key('conversation-message-composer-padding'),
          padding: EdgeInsets.all(sizing.scaled(AppSpacing.md)),
          child: Align(
            child: SizedBox(
              width: double.infinity,
              child: BlocListener<ConversationCubit, ConversationState>(
                listenWhen: (previous, current) =>
                    previous is ConversationLoadSuccess &&
                    current is ConversationLoadSuccess &&
                    previous.sendStatus == ConversationSendStatus.inProgress &&
                    current.sendStatus != ConversationSendStatus.inProgress,
                listener: (_, state) {
                  if (state is ConversationLoadSuccess &&
                      state.sendStatus == ConversationSendStatus.failure &&
                      _controller.text.isEmpty) {
                    _controller.text = _pendingMessageText ?? '';
                    _controller.selection = TextSelection.collapsed(
                      offset: _controller.text.length,
                    );
                  }
                  _pendingMessageText = null;
                },
                child: BlocBuilder<ConversationCubit, ConversationState>(
                  builder: (context, state) {
                    final sendInProgress =
                        state is ConversationLoadSuccess &&
                        state.sendStatus == ConversationSendStatus.inProgress;
                    final conversationReady = state is ConversationLoadSuccess;
                    return ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _controller,
                      builder: (context, value, _) {
                        final hasMessage = value.text.trim().isNotEmpty;
                        final canSend =
                            conversationReady && !sendInProgress && hasMessage;
                        return Row(
                          children: [
                            Expanded(
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: composerMinHeight,
                                ),
                                child: TextField(
                                  controller: _controller,
                                  minLines: 1,
                                  maxLines: 8,
                                  clipBehavior: Clip.none,
                                  textInputAction: TextInputAction.newline,
                                  onTapOutside: (_) =>
                                      FocusScope.of(context).unfocus(),
                                  onSubmitted: (_) {
                                    if (canSend) {
                                      _submitMessage(context);
                                    }
                                  },
                                  decoration: InputDecoration(
                                    isDense: true,
                                    filled: true,
                                    fillColor:
                                        colors.directMessageInputBackground,
                                    hintText:
                                        context.l10n.directMessageComposerHint,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        sizing.scaled(10),
                                      ),
                                      borderSide: BorderSide.none,
                                    ),
                                    contentPadding:
                                        EdgeInsetsDirectional.symmetric(
                                          horizontal: sizing.scaled(
                                            AppSpacing.sm,
                                          ),
                                          vertical: sizing.scaled(
                                            AppSpacing.xs,
                                          ),
                                        ),
                                  ),
                                ),
                              ),
                            ),
                            if (hasMessage) ...[
                              SizedBox(width: sizing.scaled(AppSpacing.xs)),
                              TextFieldTapRegion(
                                child: TextButton(
                                  style: TextButton.styleFrom(
                                    backgroundColor: colors.wechatGreen,
                                    foregroundColor:
                                        AppColors.wechatGreenForeground,
                                    minimumSize: Size.zero,
                                    fixedSize: Size(
                                      sizing.scaled(50),
                                      sizing.scaled(34),
                                    ),
                                    padding: EdgeInsets.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  onPressed: canSend
                                      ? () => _submitMessage(context)
                                      : null,
                                  child: Icon(
                                    RemixIcons.send_ins_line,
                                    semanticLabel: context.l10n.sendButtonLabel,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _submitMessage(BuildContext context) {
    final cubit = context.read<ConversationCubit>();
    final state = cubit.state;
    final text = _controller.text;
    if (state is! ConversationLoadSuccess ||
        state.sendStatus == ConversationSendStatus.inProgress ||
        text.trim().isEmpty) {
      return;
    }

    _pendingMessageText = text;
    _controller.clear();
    unawaited(cubit.sendMessage(text));
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList({
    required this.messages,
    required this.activeAccountId,
    required this.historyLoadStatus,
  });

  final List<DirectMessage> messages;
  final String? activeAccountId;
  final ConversationHistoryLoadStatus historyLoadStatus;

  /// Minimum gap between two messages before a time divider is shown.
  static const _timeDividerGap = Duration(minutes: 5);

  /// Vertical spacing around a time divider.
  static const _timeDividerSpacing = 20.0;

  @override
  Widget build(BuildContext context) {
    final sizing = context.appSizing;
    // The transcript is rendered with `reverse: true` (newest message at the
    // bottom). Older messages are appended at the far end of the list, which
    // keeps every existing message at its scroll position without any
    // correction, and short transcripts hug the bottom above where the
    // message composer will live.
    return NotificationListener<ScrollNotification>(
      key: const Key('conversation-message-list'),
      onNotification: (notification) {
        final metrics = notification.metrics;
        if (historyLoadStatus != ConversationHistoryLoadStatus.failure &&
            metrics.maxScrollExtent > 0 &&
            metrics.pixels >=
                metrics.maxScrollExtent - metrics.viewportDimension * 0.5) {
          unawaited(context.read<ConversationCubit>().loadMore());
        }
        return false;
      },
      child: ListView.builder(
        reverse: true,
        padding: EdgeInsets.symmetric(
          horizontal: sizing.appBarHorizontalPadding,
          vertical: sizing.scaled(AppSpacing.sm),
        ),
        itemCount: messages.length + 1,
        itemBuilder: (context, index) {
          if (index == messages.length) {
            return _HistoryLoadMoreFooter(
              status: historyLoadStatus,
              onRetry: () =>
                  unawaited(context.read<ConversationCubit>().loadMore()),
            );
          }
          final message = messages[index];
          final isSent = message.senderId == activeAccountId;
          final showTimeDivider = _shouldShowTimeDivider(index);
          final newerNeighborHasTimeDivider =
              index > 0 && _shouldShowTimeDivider(index - 1);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showTimeDivider)
                Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: sizing.scaled(_timeDividerSpacing),
                  ),
                  child: Text(
                    formatConversationTimestamp(message.createdAt),
                    textAlign: TextAlign.center,
                    style: context.appTypography.statusHandle.copyWith(
                      color: context.appColors.textSecondary,
                      fontSize: sizing.scaled(13),
                    ),
                  ),
                ),
              Padding(
                padding: EdgeInsets.only(
                  bottom: sizing.scaled(
                    newerNeighborHasTimeDivider ? 0 : AppSpacing.md,
                  ),
                ),
                child: DirectMessageBubble(
                  message: message,
                  isSentByActiveAccount: isSent,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  bool _shouldShowTimeDivider(int index) {
    final message = messages[index];
    final olderNeighbor = index < messages.length - 1
        ? messages[index + 1]
        : null;
    if (olderNeighbor == null) return true;
    return _exceedsTimeDividerGap(
      olderNeighbor.createdAt,
      message.createdAt,
    );
  }

  bool _exceedsTimeDividerGap(String older, String newer) {
    final olderTime = tryParseFanfouCreatedAt(older);
    final newerTime = tryParseFanfouCreatedAt(newer);
    if (olderTime == null || newerTime == null) return false;
    return newerTime.difference(olderTime) >= _timeDividerGap;
  }
}

class _HistoryLoadMoreFooter extends StatelessWidget {
  const _HistoryLoadMoreFooter({required this.status, required this.onRetry});

  final ConversationHistoryLoadStatus status;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final sizing = context.appSizing;
    return switch (status) {
      ConversationHistoryLoadStatus.idle => const SizedBox.shrink(),
      ConversationHistoryLoadStatus.inProgress => Semantics(
        liveRegion: true,
        label: context.l10n.directMessagesLoadingMoreLabel,
        child: Padding(
          padding: EdgeInsetsDirectional.all(sizing.scaled(AppSpacing.md)),
          child: const Center(child: CupertinoActivityIndicator()),
        ),
      ),
      ConversationHistoryLoadStatus.failure => AppRetryView(
        revealOnDisplay: true,
        message: context.l10n.retryLoadMoreMessage,
        onRetry: onRetry,
      ),
    };
  }
}

class _StatusView extends StatelessWidget {
  const _StatusView({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: context.appTypography.statusBody.copyWith(
              color: context.appColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
