import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:code_builder/code_builder.dart';
import 'package:dart_style/dart_style.dart';
import 'package:pointycastle/export.dart';
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

  final secureRandom = Random.secure();

  Uint8List randomBytes(int length) {
    return Uint8List.fromList(
      List.generate(length, (_) => secureRandom.nextInt(256)),
    );
  }

  final keyBytes = randomBytes(32); // 256-bit key

  String encrypt(String plainText) {
    final iv = randomBytes(12); // GCM recommended IV size

    final cipher = GCMBlockCipher(AESEngine())
    ..init(
      true,
      AEADParameters(
        KeyParameter(keyBytes),
        128, // MAC size
        iv,
        Uint8List(0),
      ),
    );

    final input = Uint8List.fromList(utf8.encode(plainText));
    final output = cipher.process(input);

    final combined = Uint8List.fromList([
      ...iv,
      ...output,
    ]);

    return base64Encode(combined);
  }

  final encryptedMap = <String, String>{};

  for (final entry in literals.entries) {
    encryptedMap[entry.key.toString()] =
    encrypt(jsonEncode(entry.value));
  }

  final classBuilder = Class((c) {
    c.name = className;

    c.fields.add(
      Field((f) => f
      ..name = '_key'
      ..static = true
      ..modifier = FieldModifier.final$
      ..assignment = Code('[${keyBytes.join(', ')}]')
      ..type = Reference('List<int>')),
    );

    c.methods.add(
      Method((m) => m
      ..name = '_decrypt'
      ..static = true
      ..returns = Reference('String')
      ..requiredParameters.add(
        Parameter((p) => p
        ..name = 'encoded'
        ..type = Reference('String')),
      )
      ..body = Block.of([
        const Code('final bytes = base64Decode(encoded);'),
        const Code('final iv = bytes.sublist(0, 12);'),
        const Code('final cipherText = bytes.sublist(12);'),
        const Code(
          'final cipher = GCMBlockCipher(AESEngine())'
        '..init(false, AEADParameters('
        'KeyParameter(Uint8List.fromList(_key)),'
        '128,'
        'iv,'
        'Uint8List(0)'
        '));'),
        const Code('final output = cipher.process(cipherText);'),
        const Code('return utf8.decode(output);'),
      ])),
    );

    for (final entry in encryptedMap.entries) {
      final name = entry.key;
      final encrypted = entry.value;

      c.fields.add(
        Field((f) => f
        ..name = '_$name'
        ..static = true
        ..type = Reference('dynamic')),
      );

      c.methods.add(
        Method((m) => m
        ..name = name
        ..static = true
        ..returns = Reference('dynamic')
        ..type = MethodType.getter
        ..lambda = true
        ..body = Code(
          '_$name ??= jsonDecode(_decrypt(\'$encrypted\'))')),
      );
    }
  });

  final library = Library((l) => l
  ..directives.addAll([
    Directive.import('dart:convert'),
    Directive.import('dart:typed_data'),
    Directive.import('package:pointycastle/export.dart'),
  ])
  ..body.add(classBuilder));

  final emitter =
  DartEmitter(allocator: Allocator.simplePrefixing());

  final formatted = DartFormatter(
    languageVersion: DartFormatter.latestShortStyleLanguageVersion,
  ).format('${library.accept(emitter)}');

  return (outputPath, formatted);
}
