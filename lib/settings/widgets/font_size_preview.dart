import 'package:dan/l10n/l10n.dart';
import 'package:dan/status/status.dart';
import 'package:flutter/material.dart';
import 'package:status_repository/status_repository.dart' as status_repository;

/// Previews font changes using the same message renderer as the timeline.
class FontSizePreview extends StatelessWidget {
  /// Creates a sample message with no navigation or status actions.
  const FontSizePreview({super.key});

  @override
  Widget build(BuildContext context) {
    final authorName = context.l10n.appearanceFontPreviewName;
    final status = status_repository.Status(
      id: 'font-size-preview',
      text: context.l10n.appearanceFontPreviewText,
      createdAt: '2019-09-25',
      author: status_repository.StatusAuthor(
        id: '',
        name: authorName,
        screenName: '',
        avatarUrl:
            'https://s3.meituan.net/v1/'
            'mss_3d027b52ec5a4d589e68050845611e68/'
            'avatar/l0/01/d9/ta.jpg?1381056277',
      ),
    );
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: WeChatStatusListItem(
        status: status,
        authorName: authorName,
        onAuthorTap: null,
        onStatusTap: null,
      ),
    );
  }
}
