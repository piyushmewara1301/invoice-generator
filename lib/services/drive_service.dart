import 'dart:convert';
import 'dart:typed_data';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

/// Stores all app data as a single encrypted file inside an
/// "InvoiceGenerator" folder in the user's Google Drive.
class DriveService {
  final drive.DriveApi _api;
  String? _folderId;

  static const _folderName = 'InvoiceGenerator';
  static const _dataFileName = 'invoice_data.json';
  static const _keyFileName = 'encryption_key.bin';

  DriveService(http.Client client) : _api = drive.DriveApi(client);

  Future<String> _ensureFolder() async {
    if (_folderId != null) return _folderId!;

    final result = await _api.files.list(
      q: "name='$_folderName' "
          "and mimeType='application/vnd.google-apps.folder' "
          "and trashed=false "
          "and 'root' in parents",
      $fields: 'files(id)',
    );

    if (result.files?.isNotEmpty == true) {
      _folderId = result.files!.first.id!;
      return _folderId!;
    }

    final folder = drive.File()
      ..name = _folderName
      ..mimeType = 'application/vnd.google-apps.folder';
    final created = await _api.files.create(folder, $fields: 'id');
    _folderId = created.id!;
    return _folderId!;
  }

  Future<String?> _findFileId(String name) async {
    final folderId = await _ensureFolder();
    final result = await _api.files.list(
      q: "name='$name' and '$folderId' in parents and trashed=false",
      $fields: 'files(id)',
    );
    return result.files?.isNotEmpty == true ? result.files!.first.id : null;
  }

  Future<String?> _readFile(String name) async {
    final fileId = await _findFileId(name);
    if (fileId == null) return null;

    final media = await _api.files.get(
      fileId,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;

    final bytes = <int>[];
    await for (final chunk in media.stream) {
      bytes.addAll(chunk);
    }
    return utf8.decode(bytes);
  }

  Future<void> _writeFile(String name, String content) async {
    final folderId = await _ensureFolder();
    final encoded = utf8.encode(content);
    final mediaStream = drive.Media(Stream.value(encoded), encoded.length);

    final existingId = await _findFileId(name);
    if (existingId != null) {
      await _api.files.update(
        drive.File(),
        existingId,
        uploadMedia: mediaStream,
      );
    } else {
      final meta = drive.File()
        ..name = name
        ..parents = [folderId];
      await _api.files.create(meta, uploadMedia: mediaStream);
    }
  }

  // ── Encryption key ───────────────────────────────────────────────────────

  /// Returns the base64-encoded encryption key stored in Drive, or null.
  Future<String?> loadKey() => _readFile(_keyFileName);

  /// Writes the base64-encoded encryption key to Drive.
  Future<void> saveKey(String keyBase64) => _writeFile(_keyFileName, keyBase64);

  // ── App data ─────────────────────────────────────────────────────────────

  /// Returns the raw file content (an encrypted string), or null if no file.
  Future<String?> loadData() => _readFile(_dataFileName);

  /// Writes raw content (an encrypted string) to Drive.
  Future<void> saveData(String content) => _writeFile(_dataFileName, content);

  // ── CSV exports ──────────────────────────────────────────────────────────

  /// Uploads (or replaces) a CSV export file in the InvoiceGenerator folder.
  /// Makes it publicly readable and returns a shareable web-view link.
  Future<String> uploadCsvFile(String filename, String csvContent) async {
    final folderId = await _ensureFolder();
    final encoded = utf8.encode(csvContent);
    final media = drive.Media(
      Stream.value(encoded.toList()),
      encoded.length,
      contentType: 'text/csv',
    );

    final existingId = await _findFileId(filename);
    final String fileId;

    if (existingId != null) {
      await _api.files.update(drive.File(), existingId, uploadMedia: media);
      fileId = existingId;
    } else {
      final meta = drive.File()
        ..name = filename
        ..parents = [folderId]
        ..mimeType = 'text/csv';
      final created = await _api.files.create(
        meta,
        uploadMedia: media,
        $fields: 'id',
      );
      fileId = created.id!;
    }

    // Ensure the file is readable by anyone with the link.
    await _api.permissions.create(
      drive.Permission()
        ..role = 'reader'
        ..type = 'anyone',
      fileId,
    );

    final file = await _api.files.get(fileId, $fields: 'webViewLink') as drive.File;
    return file.webViewLink ?? '';
  }

  // ── Verification documents ────────────────────────────────────────────────

  /// Uploads a binary document (image/PDF) to the InvoiceGenerator folder.
  /// Returns a web view link for sharing with the admin reviewer.
  Future<String> uploadVerificationDocument(
      Uint8List bytes, String fileName, String mimeType) async {
    final folderId = await _ensureFolder();
    final mediaStream = drive.Media(
      Stream.value(bytes.toList()),
      bytes.length,
      contentType: mimeType,
    );
    final meta = drive.File()
      ..name = fileName
      ..parents = [folderId]
      ..mimeType = mimeType;
    final file = await _api.files.create(
      meta,
      uploadMedia: mediaStream,
      $fields: 'id,webViewLink',
    );
    // Make file viewable by anyone with the link so the admin can open it.
    await _api.permissions.create(
      drive.Permission()
        ..role = 'reader'
        ..type = 'anyone',
      file.id!,
    );
    return file.webViewLink ?? '';
  }
}
