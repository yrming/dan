import 'package:equatable/equatable.dart';

/// Domain model for a Fanfou direct message.
final class DirectMessage extends Equatable {
  /// Creates a direct message.
  const DirectMessage({
    required this.id,
    required this.text,
    required this.createdAt,
    required this.senderId,
    required this.recipientId,
    this.senderScreenName,
  });

  /// Stable message identifier.
  final String id;

  /// Message body.
  final String text;

  /// Raw Fanfou creation timestamp.
  final String createdAt;

  /// Identifier of the account that sent the message.
  final String senderId;

  /// Identifier of the account that received the message.
  final String recipientId;

  /// Screen name of the sender, when the API includes it.
  final String? senderScreenName;

  @override
  List<Object?> get props => [
    id,
    text,
    createdAt,
    senderId,
    recipientId,
    senderScreenName,
  ];
}
