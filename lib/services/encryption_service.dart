import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// AES-256-CBC encryption service.
/// The key is stored in the OS secure enclave (Keychain / Keystore)
/// and also backed up to Drive as `encryption_key.bin` so the user
/// can recover data on a new device.
///
/// Ciphertext format: base64( iv[16 bytes] + ciphertext )
class EncryptionService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );
  static const _keyStorageKey = 'invoice_enc_key';

  enc.Key? _key;

  bool get isReady => _key != null;

  /// The current key as base64 — used to back up to Drive.
  String? get keyBase64 =>
      _key != null ? base64Encode(_key!.bytes) : null;

  /// Attempts to load the key from secure storage.
  /// Returns true if a key was found and loaded.
  Future<bool> tryLoadLocalKey() async {
    try {
      final stored = await _storage.read(key: _keyStorageKey);
      if (stored == null) return false;
      _key = enc.Key(Uint8List.fromList(base64Decode(stored)));
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Loads a key received from Drive, persists it locally.
  Future<void> loadFromDriveKey(String keyB64) async {
    _key = enc.Key(Uint8List.fromList(base64Decode(keyB64)));
    await _storage.write(key: _keyStorageKey, value: keyB64);
  }

  /// Generates a fresh random key, stores it locally, and returns
  /// the base64 representation so the caller can back it up to Drive.
  Future<String> generateAndStore() async {
    final bytes = Uint8List(32);
    final rng = Random.secure();
    for (int i = 0; i < 32; i++) {
      bytes[i] = rng.nextInt(256);
    }
    final keyB64 = base64Encode(bytes);
    _key = enc.Key(bytes);
    await _storage.write(key: _keyStorageKey, value: keyB64);
    return keyB64;
  }

  /// Encrypts [plaintext] and returns base64(iv + ciphertext).
  /// Returns [plaintext] unchanged when no key is loaded (pre-login state).
  String encrypt(String plaintext) {
    if (!isReady) return plaintext;
    final iv = enc.IV.fromSecureRandom(16);
    final encrypter = enc.Encrypter(enc.AES(_key!, mode: enc.AESMode.cbc));
    final encrypted = encrypter.encrypt(plaintext, iv: iv);
    final combined = Uint8List(16 + encrypted.bytes.length)
      ..setAll(0, iv.bytes)
      ..setAll(16, encrypted.bytes);
    return base64Encode(combined);
  }

  /// Decrypts [cipherB64] (base64-encoded iv + ciphertext).
  String decrypt(String cipherB64) {
    final combined = base64Decode(cipherB64);
    final iv = enc.IV(Uint8List.fromList(combined.sublist(0, 16)));
    final cipher =
        enc.Encrypted(Uint8List.fromList(combined.sublist(16)));
    final encrypter = enc.Encrypter(enc.AES(_key!, mode: enc.AESMode.cbc));
    return encrypter.decrypt(cipher, iv: iv);
  }

  /// Decrypts safely: falls back to returning [stored] as-is if decryption
  /// fails. This handles unencrypted legacy data written before encryption
  /// was introduced — those strings are migrated on the next save.
  String decryptSafe(String stored) {
    if (!isReady) return stored;
    try {
      return decrypt(stored);
    } catch (_) {
      return stored;
    }
  }

  /// Removes the key from secure storage (called on sign-out so that
  /// encrypted local data cannot be read without re-authenticating).
  Future<void> clearKey() async {
    await _storage.delete(key: _keyStorageKey);
    _key = null;
  }
}
