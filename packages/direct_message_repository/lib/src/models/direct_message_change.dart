import 'package:equatable/equatable.dart';

/// Account-scoped direct-message mutation published by the repository.
sealed class DirectMessageChange extends Equatable {
  /// Creates a direct message change.
  const DirectMessageChange({required this.accountId});

  /// Account whose data changed.
  final String accountId;

  /// Stable identifier of the changed message.
  String get messageId;

  @override
  List<Object?> get props => [accountId];
}

/// A direct message was deleted successfully.
final class DirectMessageDeleted extends DirectMessageChange {
  /// Creates a deletion change.
  const DirectMessageDeleted({
    required super.accountId,
    required this.messageId,
  });

  @override
  final String messageId;

  @override
  List<Object?> get props => [...super.props, messageId];
}
