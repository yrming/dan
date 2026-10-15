import 'dart:async';

import 'package:authentication_repository/authentication_repository.dart';
import 'package:dan/app/navigation/routes.dart';
import 'package:dan/app/theme/theme.dart';
import 'package:dan/app/view/app_subpage_app_bar.dart';
import 'package:dan/app/widgets/widgets.dart';
import 'package:dan/authentication/authentication.dart';
import 'package:dan/l10n/l10n.dart';
import 'package:dan/status/cubit/status_composer_cubit.dart';
import 'package:dan/status/models/status_composer_mode.dart';
import 'package:dan/status/models/status_text.dart';
import 'package:dan/status/services/status_photo_picker.dart';
import 'package:dan/status/widgets/status_composer_photo_picker.dart';
import 'package:dan/status/widgets/status_composer_text_controller.dart';
import 'package:dan/status/widgets/status_mention_suggestions.dart';
import 'package:dan/status/widgets/status_photo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';
import 'package:status_repository/status_repository.dart';

/// Full-screen page for composing a new status.
class StatusComposerPage extends StatelessWidget {
  /// Creates the status composer page.
  const StatusComposerPage({
    this.mode = StatusComposerMode.compose,
    this.sourceStatusId,
    this.sourceAuthor,
    this.sourceText,
    this.sourcePhotoUrl,
    super.key,
  });

  /// Whether this draft is a new status, a reply, or a repost.
  final StatusComposerMode mode;

  /// Original status identifier.
  final String? sourceStatusId;

  /// Original author's nickname.
  final String? sourceAuthor;

  /// Original status HTML.
  final String? sourceText;

  /// Original photo displayed as a read-only part of a repost.
  final String? sourcePhotoUrl;

  @override
  Widget build(BuildContext context) {
    final account = context.select<AuthenticationBloc, AuthenticatedAccount?>(
      (bloc) => switch (bloc.state) {
        AuthenticationAuthenticated(:final snapshot) => snapshot.activeAccount,
        _ => null,
      },
    );
    final nickname = sourceAuthor ?? context.l10n.statusUnknownAuthor;
    final parts = <StatusTextPart>[
      if (mode == StatusComposerMode.reply) ...[
        StatusTextPart(text: '@$nickname', kind: StatusTextPartKind.mention),
        const StatusTextPart(text: ' '),
      ] else if (mode == StatusComposerMode.repost) ...[
        const StatusTextPart(text: '转'),
        StatusTextPart(
          text: '@$nickname',
          kind: StatusTextPartKind.mention,
        ),
        const StatusTextPart(text: ' '),
        ...parseStatusHtml(sourceText ?? ''),
      ],
    ];
    return BlocProvider(
      create: (context) {
        final cubit = StatusComposerCubit(
          statusRepository: context.read<StatusRepository>(),
          photoPicker: context.read<StatusPhotoPicker>(),
          draftRepository: mode == StatusComposerMode.compose
              ? context.read<StatusDraftRepository>()
              : null,
          accountId: account?.id,
          initialContent: parts.map((part) => part.text).join(),
          inReplyToStatusId: mode == StatusComposerMode.reply
              ? sourceStatusId
              : null,
          repostStatusId: mode == StatusComposerMode.repost
              ? sourceStatusId
              : null,
        );
        unawaited(cubit.restoreDraft());
        return cubit;
      },
      child: StatusComposerView(
        accountId: account?.id,
        avatarUrl: account?.avatarUrl,
        authorName: account == null
            ? null
            : account.name.isEmpty
            ? account.screenName
            : account.name,
        mode: mode,
        sourcePhotoUrl: sourcePhotoUrl,
        initialParts: parts,
        cursorAtStart: mode == StatusComposerMode.repost,
      ),
    );
  }
}

/// Renders the status composer form.
class StatusComposerView extends StatefulWidget {
  /// Creates the status composer view.
  const StatusComposerView({
    this.accountId,
    this.avatarUrl,
    this.authorName,
    this.mode = StatusComposerMode.compose,
    this.initialParts = const [],
    this.cursorAtStart = false,
    this.sourcePhotoUrl,
    super.key,
  });

  /// Account composing this message.
  final String? accountId;

  /// Avatar of the account composing this draft.
  final String? avatarUrl;

  /// Accessible name of the account composing this draft.
  final String? authorName;

  /// Operation used to select the page title.
  final StatusComposerMode mode;

  /// Source entities used to highlight the initial draft.
  final List<StatusTextPart> initialParts;

  /// Whether the initial cursor precedes the draft, as when reposting.
  final bool cursorAtStart;

  /// Original photo displayed as a read-only part of a repost.
  final String? sourcePhotoUrl;

  @override
  State<StatusComposerView> createState() => _StatusComposerViewState();
}

class _StatusComposerViewState extends State<StatusComposerView> {
  late final StatusComposerTextController _controller;
  final _textFocusNode = FocusNode();
  bool _allowPop = false;
  bool _showingClosePrompt = false;
  final _sourcePhotoHeroTag = 'status-composer-source-photo-${UniqueKey()}';

  @override
  void initState() {
    super.initState();
    _controller = StatusComposerTextController(
      text: context.read<StatusComposerCubit>().state.content,
      parts: widget.initialParts,
      cursorAtStart: widget.cursorAtStart,
    );
  }

  @override
  void dispose() {
    _textFocusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sizing = context.appSizing;
    return BlocListener<StatusComposerCubit, StatusComposerState>(
      listenWhen: (previous, current) =>
          (previous.photoSelectionStatus ==
                  StatusPhotoSelectionStatus.picking &&
              current.photoSelectionStatus !=
                  StatusPhotoSelectionStatus.picking) ||
          previous.draftStatus == StatusDraftStatus.loading &&
              current.draftStatus != StatusDraftStatus.loading,
      listener: (context, state) {
        if (!state.isBusy && ModalRoute.of(context)?.isCurrent == true) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && ModalRoute.of(context)?.isCurrent == true) {
              _textFocusNode.requestFocus();
            }
          });
        }
      },
      child: BlocConsumer<StatusComposerCubit, StatusComposerState>(
        listenWhen: (previous, current) =>
            previous.draftStatus != current.draftStatus ||
            previous.submissionStatus != current.submissionStatus ||
            previous.photoSelectionStatus != current.photoSelectionStatus ||
            previous.failureMessage != current.failureMessage,
        listener: (context, state) {
          if (state.draftStatus == StatusDraftStatus.restored &&
              _controller.text != state.content) {
            _controller.value = TextEditingValue(
              text: state.content,
              selection: TextSelection.collapsed(offset: state.content.length),
            );
          }
          if (state.draftStatus == StatusDraftStatus.failure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.l10n.statusComposerDraftLoadFailure),
              ),
            );
          }
          if (state.photoSelectionStatus ==
              StatusPhotoSelectionStatus.unsupportedFormat) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.l10n.statusComposerPhotoFormatFailure),
              ),
            );
            return;
          }
          if (state.photoSelectionStatus ==
              StatusPhotoSelectionStatus.failure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.l10n.statusComposerPhotoPickFailure),
              ),
            );
            return;
          }
          switch (state.submissionStatus) {
            case StatusComposerSubmissionStatus.unsupportedPhotoFormat:
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(context.l10n.statusComposerPhotoFormatFailure),
                ),
              );
            case StatusComposerSubmissionStatus.success:
              context.pop();
            case StatusComposerSubmissionStatus.failure:
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    state.failureMessage ?? context.l10n.statusComposerFailure,
                  ),
                ),
              );
            case StatusComposerSubmissionStatus.initial ||
                StatusComposerSubmissionStatus.inProgress:
              break;
          }
        },
        builder: (context, state) {
          final sourcePhotoUrl = widget.sourcePhotoUrl?.trim() ?? '';
          final isPublishing =
              state.submissionStatus ==
              StatusComposerSubmissionStatus.inProgress;
          return PopScope(
            canPop:
                _allowPop ||
                widget.mode != StatusComposerMode.compose ||
                state.submissionStatus ==
                    StatusComposerSubmissionStatus.success,
            onPopInvokedWithResult: (didPop, result) {
              if (!didPop) unawaited(_requestClose());
            },
            child: Scaffold(
              key: const Key('status-composer-page'),
              appBar: AppSubpageAppBar(
                title: switch (widget.mode) {
                  StatusComposerMode.compose =>
                    context.l10n.statusComposerPageTitle,
                  StatusComposerMode.reply =>
                    context.l10n.statusActionReplyLabel,
                  StatusComposerMode.repost =>
                    context.l10n.statusActionRepostLabel,
                },
                toolbarHeight: sizing.appBarToolbarHeight,
                showBottomDivider: false,
                automaticallyImplyLeading: false,
                leading: IconButton(
                  key: const Key('status-composer-close'),
                  tooltip: context.l10n.statusComposerCloseLabel,
                  onPressed: state.isBusy
                      ? null
                      : () => unawaited(_requestClose()),
                  icon: const Icon(Icons.close),
                ),
                actions: [
                  FilledButton(
                    key: const Key('status-composer-publish'),
                    style: FilledButton.styleFrom(
                      minimumSize: Size(0, sizing.scaled(_publishButtonHeight)),
                      fixedSize: Size(
                        _publishButtonWidth,
                        sizing.scaled(_publishButtonHeight),
                      ),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: state.canPublish
                        ? () => context.read<StatusComposerCubit>().publish()
                        : null,
                    child: isPublishing
                        ? SizedBox.square(
                            dimension: sizing.scaled(_publishIndicatorSize),
                            child: CircularProgressIndicator(
                              color: Theme.of(context).colorScheme.onPrimary,
                              strokeCap: StrokeCap.round,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(context.l10n.statusComposerPublishLabel),
                  ),
                ],
              ),
              body: SafeArea(
                top: false,
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsetsDirectional.all(
                          sizing.scaled(AppSpacing.md),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            UserAvatar(
                              key: const Key('status-composer-avatar'),
                              imageUrl: widget.avatarUrl,
                              semanticLabel: widget.authorName,
                              size: sizing.scaled(40),
                              borderColor: context.appColors.divider,
                              borderWidth: 0.5,
                            ),
                            SizedBox(width: sizing.scaled(AppSpacing.sm)),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                spacing: sizing.scaled(AppSpacing.md),
                                children: [
                                  ConstrainedBox(
                                    constraints: BoxConstraints(
                                      minHeight: sizing.scaled(40),
                                    ),
                                    child: Align(
                                      alignment:
                                          AlignmentDirectional.centerStart,
                                      heightFactor: 1,
                                      child: StatusMentionSuggestions(
                                        controller: _controller,
                                        focusNode: _textFocusNode,
                                        enabled:
                                            widget.accountId != null &&
                                            !state.isBusy,
                                        onChanged: context
                                            .read<StatusComposerCubit>()
                                            .contentChanged,
                                        child: TextField(
                                          key: const Key(
                                            'status-composer-text-field',
                                          ),
                                          controller: _controller,
                                          focusNode: _textFocusNode,
                                          autofocus: true,
                                          enabled:
                                              !isPublishing &&
                                              state.draftStatus !=
                                                  StatusDraftStatus.loading &&
                                              state.draftStatus !=
                                                  StatusDraftStatus.saving,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyLarge!
                                              .copyWith(
                                                fontSize: sizing.statusFontSize,
                                              ),
                                          minLines: 1,
                                          maxLines: null,
                                          textAlignVertical:
                                              TextAlignVertical.center,
                                          keyboardType: TextInputType.multiline,
                                          onChanged: context
                                              .read<StatusComposerCubit>()
                                              .contentChanged,
                                          decoration: InputDecoration(
                                            border: InputBorder.none,
                                            isDense: true,
                                            contentPadding: EdgeInsets.zero,
                                            hintText:
                                                context.l10n.statusComposerHint,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (widget.mode ==
                                          StatusComposerMode.compose &&
                                      state.photo != null)
                                    StatusComposerPhotoPicker(
                                      photo: state.photo!,
                                      isBusy: state.isBusy,
                                      onRemove: context
                                          .read<StatusComposerCubit>()
                                          .removePhoto,
                                    ),
                                  if (widget.mode ==
                                          StatusComposerMode.repost &&
                                      sourcePhotoUrl.isNotEmpty)
                                    StatusPhoto.x(
                                      key: const Key(
                                        'status-composer-source-photo',
                                      ),
                                      imageUrl: sourcePhotoUrl,
                                      semanticLabel: context
                                          .l10n
                                          .statusComposerPreviewPhotoLabel,
                                      heroTag: _sourcePhotoHeroTag,
                                      onTap: state.isBusy
                                          ? null
                                          : () => _previewSourcePhoto(
                                              sourcePhotoUrl,
                                            ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    _ComposerToolbar(
                      isBusy: state.isBusy,
                      isPicking:
                          state.photoSelectionStatus ==
                          StatusPhotoSelectionStatus.picking,
                      hasPhoto: state.photo != null,
                      onMention: _pickMention,
                      onHashtag: _pickHashtag,
                      remainingCharacters: state.remainingCharacters,
                      onPick: widget.mode == StatusComposerMode.compose
                          ? _pickPhoto
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _leaveComposer() {
    if (!mounted) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.pop();
    });
  }

  Future<void> _requestClose() async {
    final cubit = context.read<StatusComposerCubit>();
    if (cubit.state.isBusy || _showingClosePrompt) return;
    if (widget.mode != StatusComposerMode.compose) {
      _leaveComposer();
      return;
    }
    if (!cubit.state.hasContent) {
      try {
        await cubit.finishDraft(keep: false);
        _leaveComposer();
      } on Object {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.statusComposerDraftSaveFailure),
          ),
        );
      }
      return;
    }
    _showingClosePrompt = true;
    _textFocusNode.unfocus();
    final l10n = context.l10n;
    await showAppAlertDialog(
      context,
      title: l10n.statusComposerKeepDraftTitle,
      content: l10n.statusComposerKeepDraftMessage,
      cancelAction: AppDialogAction(
        label: l10n.statusComposerDiscardDraftLabel,
        color: context.appColors.textBase,
        onSubmit: () => cubit.finishDraft(keep: false),
        failureLabel: l10n.statusComposerDraftSaveFailure,
        onPressed: _leaveComposer,
      ),
      confirmAction: AppDialogAction(
        label: l10n.statusComposerKeepDraftLabel,
        color: context.appColors.wechatLinkText!,
        onSubmit: () => cubit.finishDraft(keep: true),
        failureLabel: l10n.statusComposerDraftSaveFailure,
        onPressed: _leaveComposer,
      ),
    );
    _showingClosePrompt = false;
  }

  void _pickMention() {
    _controller.startMention();
    context.read<StatusComposerCubit>().contentChanged(_controller.text);
    _textFocusNode.requestFocus();
  }

  void _pickHashtag() {
    _controller.startHashtag();
    context.read<StatusComposerCubit>().contentChanged(_controller.text);
    _textFocusNode.requestFocus();
  }

  void _pickPhoto() {
    FocusScope.of(context).unfocus();
    unawaited(context.read<StatusComposerCubit>().pickPhoto());
  }

  void _previewSourcePhoto(String imageUrl) {
    _textFocusNode.unfocus();
    unawaited(
      context.pushNamed<void>(
        AppRouteName.statusImageViewer,
        queryParameters: {
          'url': imageUrl,
          'heroTag': _sourcePhotoHeroTag,
          'semanticLabel': context.l10n.statusComposerPreviewPhotoLabel,
        },
      ),
    );
  }
}

const _publishButtonWidth = 80.0;
const _publishButtonHeight = 36.0;
const _publishIndicatorSize = 16.0;

class _ComposerToolbar extends StatelessWidget {
  const _ComposerToolbar({
    required this.isBusy,
    required this.isPicking,
    required this.hasPhoto,
    required this.onPick,
    required this.onMention,
    required this.onHashtag,
    required this.remainingCharacters,
  });

  final bool isBusy;
  final bool isPicking;
  final bool hasPhoto;
  final VoidCallback? onPick;
  final VoidCallback onMention;
  final VoidCallback onHashtag;
  final int remainingCharacters;

  @override
  Widget build(BuildContext context) {
    final sizing = context.appSizing;
    return DecoratedBox(
      key: const Key('status-composer-photo-toolbar'),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: context.appColors.divider, width: 0),
        ),
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.symmetric(
          horizontal: sizing.scaled(AppSpacing.xs),
          vertical: sizing.scaled(AppSpacing.xxs),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: sizing.scaled(48)),
          child: Row(
            children: [
              if (onPick != null)
                IconButton(
                  key: const Key('status-composer-add-photo'),
                  tooltip: hasPhoto
                      ? context.l10n.statusComposerReplacePhotoLabel
                      : context.l10n.statusComposerAddPhotoLabel,
                  color: Theme.of(context).colorScheme.primary,
                  onPressed: isBusy ? null : onPick,
                  icon: isPicking
                      ? SizedBox.square(
                          dimension: sizing.scaled(24),
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : Icon(RemixIcons.image_line, size: sizing.scaled(24)),
                ),
              IconButton(
                key: const Key('status-composer-mention'),
                tooltip: context.l10n.statusMentionTitle,
                color: Theme.of(context).colorScheme.primary,
                onPressed: isBusy ? null : onMention,
                icon: Icon(RemixIcons.at_line, size: sizing.scaled(24)),
              ),
              IconButton(
                key: const Key('status-composer-hashtag'),
                tooltip: context.l10n.statusHashtagTitle,
                color: Theme.of(context).colorScheme.primary,
                onPressed: isBusy ? null : onHashtag,
                icon: Icon(RemixIcons.hashtag, size: sizing.scaled(24)),
              ),
              const Spacer(),
              Padding(
                padding: EdgeInsetsDirectional.only(
                  end: sizing.scaled(AppSpacing.sm),
                ),
                child: Text(
                  '$remainingCharacters',
                  key: const Key('status-composer-remaining-characters'),
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    color: remainingCharacters < 0
                        ? Theme.of(context).colorScheme.error
                        : context.appColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
