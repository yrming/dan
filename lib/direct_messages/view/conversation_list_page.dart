import 'package:dan/app/theme/theme.dart';
import 'package:dan/app/view/app_subpage_app_bar.dart';
import 'package:dan/direct_messages/bloc/conversation_list_bloc.dart';
import 'package:dan/direct_messages/view/conversation_list_view.dart';
import 'package:dan/l10n/l10n.dart';
import 'package:direct_message_repository/direct_message_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Shell route boundary for the direct message conversation list.
class ConversationListPage extends StatelessWidget {
  /// Creates the conversation list page.
  const ConversationListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppSubpageAppBar(
        title: context.l10n.directMessagesPageTitle,
        toolbarHeight: context.appSizing.appBarToolbarHeight,
      ),
      body: BlocProvider(
        create: (context) => ConversationListBloc(
          directMessageRepository: context.read<DirectMessageRepository>(),
        )..add(const ConversationListInitialLoadRequested()),
        child: const ConversationListView(),
      ),
    );
  }
}
