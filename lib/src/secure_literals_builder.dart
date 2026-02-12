import 'dart:async';
import 'dart:convert';

import 'package:build/build.dart';
import 'package:code_builder/code_builder.dart';
import 'package:dart_style/dart_style.dart';
import 'package:encrypt/encrypt.dart';
import 'package:yaml/yaml.dart';

class SecureLiteralsBuilder implements Builder {
  @override
  final buildExtensions = const {
    'secure_literals.yaml': ['lib/generated_literals.dart'],
  };

  @override
  Future<void> build(BuildStep buildStep) async {
    final inputId = buildStep.inputId;
    final content = await buildStep.readAsString(inputId);
    final yaml = loadYaml(content);
    if (yaml is! Map || !yaml.containsKey('literals')) {
      return;
    }
    final literals = yaml['literals'];
    if (literals is! Map) return;

    // Generate Key (IV will be generated per item)
    final key = Key.fromSecureRandom(32);
    // Encrypter with SIC (CTR) mode - no padding needed, IV required
    final encrypter = Encrypter(AES(key, mode: AESMode.sic));

    final classBuilder = Class((c) {
      c.name = 'SecureLiterals';

      // Private Key field
      c.fields.add(
        Field(
          (f) => f
            ..name = '_keyBytes'
            ..static = true
            ..modifier = FieldModifier.final$
            ..assignment = Code('[${key.bytes.join(', ')}]')
            ..type = Reference('List<int>'),
        ),
      );

      // Decrypt method handling embedded IV
      c.methods.add(
        Method(
          (m) => m
            ..name = '_decrypt'
            ..static = true
            ..returns = Reference('String')
            ..requiredParameters.add(
              Parameter(
                (p) => p
                  ..name = 'encryptedBase64'
                  ..type = Reference('String'),
              ),
            )
            ..body = Block.of([
              const Code('final key = Key(Uint8List.fromList(_keyBytes));'),
              const Code('final bytes = base64Decode(encryptedBase64);'),
              const Code('final iv = IV(bytes.sublist(0, 16));'),
              const Code('final cipherText = Encrypted(bytes.sublist(16));'),
              const Code(
                'final encrypter = Encrypter(AES(key, mode: AESMode.sic));',
              ),
              const Code('return encrypter.decrypt(cipherText, iv: iv);'),
            ]),
        ),
      );

      literals.forEach((key, value) {
        final name = key as String;

        String? encryptedValue;
        Reference type;
        Code extractionCode;

        // Helper to encrypt with unique IV
        String encryptWithIv(String plainText) {
          final iv = IV.fromSecureRandom(16);
          final encrypted = encrypter.encrypt(plainText, iv: iv);
          final combined = [...iv.bytes, ...encrypted.bytes];
          return base64Encode(combined);
        }

        if (value is String) {
          encryptedValue = encryptWithIv(value);
          type = Reference('String');
          extractionCode = Code("_decrypt('$encryptedValue')");
        } else if (value is int) {
          encryptedValue = encryptWithIv(value.toString());
          type = Reference('int');
          extractionCode = Code("int.parse(_decrypt('$encryptedValue'))");
        } else if (value is YamlList || value is List) {
          final list = (value as List).toList();
          if (list.isEmpty) {
            // Default to List<String> if empty, or handle error?
            // Let's assume String for safety or skip
            type = Reference('List<String>');
            encryptedValue = encryptWithIv('[]');
            extractionCode = Code(
              "(jsonDecode(_decrypt('$encryptedValue')) as List).cast<String>()",
            );
          } else {
            final firstItem = list.first;
            String jsonList;
            if (firstItem is int) {
              type = Reference('List<int>');
              // Ensure all items are treated as proper types
              final intItems = list.map((e) => e as int).toList();
              jsonList = jsonEncode(intItems);
              encryptedValue = encryptWithIv(jsonList);
              extractionCode = Code(
                "(jsonDecode(_decrypt('$encryptedValue')) as List).cast<int>()",
              );
            } else {
              type = Reference('List<String>');
              final stringItems = list.map((e) => e.toString()).toList();
              jsonList = jsonEncode(stringItems);
              encryptedValue = encryptWithIv(jsonList);
              extractionCode = Code(
                "(jsonDecode(_decrypt('$encryptedValue')) as List).cast<String>()",
              );
            }
          }
        } else {
          return;
        }

        // Private backing field
        c.fields.add(
          Field(
            (f) => f
              ..name = '_$name'
              ..static = true
              ..type = Reference('${type.symbol}?'),
          ),
        );

        // Public getter with lazy initialization
        c.methods.add(
          Method(
            (m) => m
              ..name = name
              ..static = true
              ..returns = type
              ..type = MethodType.getter
              ..lambda = true
              ..body = Code('_$name ??= $extractionCode'),
          ),
        );
      });
    });

    final library = Library(
      (l) => l
        ..directives.addAll([
          Directive.import('dart:typed_data'),
          Directive.import('dart:convert'),
          Directive.import('package:encrypt/encrypt.dart'),
        ])
        ..body.add(classBuilder),
    );

    final emitter = DartEmitter(
      allocator: Allocator.simplePrefixing(),
    ); // Use simplePrefixing to avoid conflicts
    final generatedCode = DartFormatter(
      languageVersion: DartFormatter.latestShortStyleLanguageVersion,
    ).format('${library.accept(emitter)}');

    await buildStep.writeAsString(
      AssetId(buildStep.inputId.package, 'lib/generated_literals.dart'),
      generatedCode,
    );
  }
}

Builder secureLiteralsBuilder(BuilderOptions options) =>
    SecureLiteralsBuilder();
