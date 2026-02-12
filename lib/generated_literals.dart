import 'dart:typed_data';
import 'dart:convert';
import 'package:encrypt/encrypt.dart';

class SecureLiterals {
  static final List<int> _keyBytes = [
    103,
    50,
    133,
    0,
    93,
    130,
    91,
    145,
    161,
    159,
    73,
    64,
    199,
    34,
    221,
    218,
    242,
    138,
    13,
    10,
    173,
    22,
    62,
    106,
    2,
    96,
    49,
    24,
    165,
    15,
    26,
    171
  ];

  static String? _apiKey;

  static String? _apiSecret;

  static int? _maxRetries;

  static int? _timeoutMs;

  static List<String>? _serverEndpoints;

  static List<int>? _retryDelays;

  static String _decrypt(String encryptedBase64) {
    final key = Key(Uint8List.fromList(_keyBytes));
    final bytes = base64Decode(encryptedBase64);
    final iv = IV(bytes.sublist(0, 16));
    final cipherText = Encrypted(bytes.sublist(16));
    final encrypter = Encrypter(AES(key, mode: AESMode.sic));
    return encrypter.decrypt(cipherText, iv: iv);
  }

  static String get apiKey => _apiKey ??= _decrypt(
      'dvXXsh/4RaKsSBa9erWfLh9Ol3dqaILey4F0Tj0NQCOP3/l2T5Vys80rXj2krCsE');

  static String get apiSecret => _apiSecret ??= _decrypt(
      '1djTMIfvmVXSHxsXLw4oRs/owgxgeGQIpFDyuIn3LmjB306BNpu8xBqi1gEePrmT');

  static int get maxRetries => _maxRetries ??=
      int.parse(_decrypt('0z+brxKmgmxrkyMMNjsB9QpG0KyrhQ+RiokcuC+bqYY='));

  static int get timeoutMs => _timeoutMs ??=
      int.parse(_decrypt('mGcPIO8LphsFFYkBN8rKPUpj9ZgwNmUZx5oYM3hJGSc='));

  static List<
      String> get serverEndpoints => _serverEndpoints ??= (jsonDecode(_decrypt(
              'AeKIaMMbM54+8b4034w7qtZbteSdv3UCJ9dIFsUDbq8dxUZzHqSAa336uUnXU+DSDq5G05+K4Jyfwm+pV/Gp/Q=='))
          as List)
      .cast<String>();

  static List<int> get retryDelays => _retryDelays ??= (jsonDecode(_decrypt(
              'ZbfcTGA72hbv9kS5Pp6g7eomRlzZT6J+tA8PQ3ogMRfSMFLS+L8x2+tB5ONy3bgq'))
          as List)
      .cast<int>();
}
