import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// A draft read from local storage.
class StoredStatusDraft {
  /// Creates a stored draft.
  const StoredStatusDraft({
    required this.content,
    this.photoPath,
    this.photoBytes,
  });

  /// Unmodified composer text.
  final String content;

  /// Durable local attachment path.
  final String? photoPath;

  /// Attachment preview and upload bytes.
  final Uint8List? photoBytes;
}

/// Persists drafts in an application-owned directory, isolated by account.
class StatusDraftStorage {
  /// Injects the platform-specific application directory lookup.
  const StatusDraftStorage({required this.directory});

  /// Application-owned root directory provider.
  final Future<Directory> Function() directory;

  Future<Directory> _accountDirectory(String accountId) async {
    final root = await directory();
    final key = base64Url.encode(utf8.encode(accountId));
    return Directory('${root.path}/status_drafts/$key');
  }

  /// Restores text and recreates the upload file from durable image bytes.
  Future<StoredStatusDraft?> read(String accountId) async {
    final folder = await _accountDirectory(accountId);
    final file = File('${folder.path}/draft.json');
    if (!file.existsSync()) return null;
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    final content = json['content'] as String;
    final encodedPhoto = json['photo'] as String?;
    if (encodedPhoto == null) return StoredStatusDraft(content: content);
    final extension = json['extension'] as String;
    if (!const ['jpg', 'jpeg', 'png', 'gif'].contains(extension)) {
      throw const FormatException('Unsupported draft photo format');
    }
    final bytes = base64Decode(encodedPhoto);
    final photo = File('${folder.path}/attachment.$extension');
    await photo.writeAsBytes(bytes, flush: true);
    return StoredStatusDraft(
      content: content,
      photoPath: photo.path,
      photoBytes: bytes,
    );
  }

  /// Atomically replaces the draft, including a copy of any temporary photo.
  Future<void> write(String accountId, StoredStatusDraft draft) async {
    final folder = await _accountDirectory(accountId);
    await folder.create(recursive: true);
    final temporary = File('${folder.path}/draft.tmp');
    await temporary.writeAsString(
      jsonEncode({
        'content': draft.content,
        if (draft.photoBytes != null) ...{
          'photo': base64Encode(draft.photoBytes!),
          'extension': draft.photoPath!.split('.').last.toLowerCase(),
        },
      }),
      flush: true,
    );
    await temporary.rename('${folder.path}/draft.json');
  }

  /// Deletes only this account's saved draft and restored attachment.
  Future<void> delete(String accountId) async {
    final folder = await _accountDirectory(accountId);
    if (folder.existsSync()) await folder.delete(recursive: true);
  }
}
