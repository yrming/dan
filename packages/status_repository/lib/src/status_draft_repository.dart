import 'dart:io';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:status_draft_storage/status_draft_storage.dart';

/// A saved original status, including an optional photo.
final class StatusDraft extends Equatable {
  /// Creates an immutable draft.
  StatusDraft({required this.content, this.photoPath, Uint8List? photoBytes})
    : photoBytes = photoBytes == null
          ? null
          : Uint8List.fromList(photoBytes).asUnmodifiableView();

  /// Exact text entered by the author.
  final String content;

  /// Path used to upload the photo.
  final String? photoPath;

  /// Saved photo bytes.
  final Uint8List? photoBytes;

  @override
  List<Object?> get props => [content, photoPath, photoBytes];
}

/// Domain interface for local status drafts.
class StatusDraftRepository {
  /// Creates a repository with injected local storage.
  const StatusDraftRepository({required StatusDraftStorage storage})
    : this._(storage);

  const StatusDraftRepository._(this._storage);

  /// Wires file storage with a platform directory provider.
  factory StatusDraftRepository.local({
    required Future<Directory> Function() directory,
  }) =>
      StatusDraftRepository(storage: StatusDraftStorage(directory: directory));

  final StatusDraftStorage _storage;

  /// Loads a draft belonging to one account.
  Future<StatusDraft?> load(String accountId) async {
    final draft = await _storage.read(accountId);
    if (draft == null) return null;
    return StatusDraft(
      content: draft.content,
      photoPath: draft.photoPath,
      photoBytes: draft.photoBytes,
    );
  }

  /// Saves text and a durable copy of the selected photo.
  Future<void> save(String accountId, StatusDraft draft) => _storage.write(
    accountId,
    StoredStatusDraft(
      content: draft.content,
      photoPath: draft.photoPath,
      photoBytes: draft.photoBytes,
    ),
  );

  /// Clears a discarded or published draft.
  Future<void> clear(String accountId) => _storage.delete(accountId);
}
