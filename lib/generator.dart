import 'dart:convert';
import 'dart:typed_data';

import 'package:code_builder/code_builder.dart';
import 'package:dart_style/dart_style.dart';
import 'package:encrypt/encrypt.dart';
import 'package:yaml/yaml.dart';

Future<(String outputPath, String generatedCode)>
generateSecureLiterals(String yamlContent) async {
  final yaml = loadYaml(yamlContent);

  if (yaml is! Map || !yaml.containsKey('literals')) {
    throw Exception('secure_literals.yaml must contain a "literals" map.');
  }

  final literals = yaml['literals'];
  if (literals is! Map) {
    throw Exception('"literals" must be a map.');
  }

  final outputPath =
  yaml['output']?.toString() ?? 'lib/generated_literals.dart';

  final className =
  yaml['class_name']?.toString() ?? 'SecureLiterals';

  final key = Key.fromSecureRandom(32);
  final encrypter = Encrypter(AES(key, mode: AESMode.sic));

  String encryptWithIv(String plainText) {
    final iv = IV.fromSecureRandom(16);
    final encrypted = encrypter.encrypt(plainText, iv: iv);
    final combined = [...iv.bytes, ...encrypted.bytes];
    return base64Encode(combined);
  }

  final classBuilder = Class((c) {
    c.name = className;

    c.fields.add(
      Field((f) => f
      ..name = '_keyBytes'
      ..static = true
      ..modifier = FieldModifier.final$
      ..assignment = Code('[${key.bytes.join(', ')}]')
      ..type = Reference('List<int>')),
    );

    c.methods.add(
      Method((m) => m
      ..name = '_decrypt'
      ..static = true
      ..returns = Reference('String')
      ..requiredParameters.add(Parameter((p) => p
      ..name = 'encryptedBase64'
      ..type = Reference('String')))
      ..body = Block.of([
        const Code('final key = Key(Uint8List.fromList(_keyBytes));'),
        const Code('final bytes = base64Decode(encryptedBase64);'),
        const Code('final iv = IV(bytes.sublist(0, 16));'),
        const Code('final cipherText = Encrypted(bytes.sublist(16));'),
        const Code(
          'final encrypter = Encrypter(AES(key, mode: AESMode.sic));'),
          const Code('return encrypter.decrypt(cipherText, iv: iv);'),
      ])),
    );

    literals.forEach((dynamic rawKey, dynamic value) {
      final name = rawKey.toString();

      Reference type;
      Code extractionCode;

      if (value is String) {
        final encryptedValue = encryptWithIv(value);
        type = Reference('String');
        extractionCode = Code("_decrypt('$encryptedValue')");
      } else if (value is int) {
        final encryptedValue = encryptWithIv(value.toString());
        type = Reference('int');
        extractionCode =
        Code("int.parse(_decrypt('$encryptedValue'))");
      } else if (value is YamlList || value is List) {
        final list = (value as List).toList();
        final jsonList = jsonEncode(list);
        final encryptedValue = encryptWithIv(jsonList);

        if (list.isNotEmpty && list.first is int) {
          type = Reference('List<int>');
          extractionCode = Code(
            "(jsonDecode(_decrypt('$encryptedValue')) as List).cast<int>()");
        } else {
          type = Reference('List<String>');
          extractionCode = Code(
            "(jsonDecode(_decrypt('$encryptedValue')) as List).cast<String>()");
        }
      } else {
        return;
      }

      c.fields.add(
        Field((f) => f
        ..name = '_$name'
        ..static = true
        ..type = Reference('${type.symbol}?')),
      );

      c.methods.add(
        Method((m) => m
        ..name = name
        ..static = true
        ..returns = type
        ..type = MethodType.getter
        ..lambda = true
        ..body = Code('_$name ??= $extractionCode')),
      );
    });
  });

  final library = Library((l) => l
  ..directives.addAll([
    Directive.import('dart:typed_data'),
    Directive.import('dart:convert'),
    Directive.import('package:encrypt/encrypt.dart'),
  ])
  ..body.add(classBuilder));

  final emitter =
  DartEmitter(allocator: Allocator.simplePrefixing());

  final formatted = DartFormatter(
    languageVersion: DartFormatter.latestShortStyleLanguageVersion,
  ).format('${library.accept(emitter)}');

  return (outputPath, formatted);
}
