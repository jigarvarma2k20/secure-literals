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

    for (final entry in literals.entries) {
      final name = entry.key.toString();
      final value = entry.value;
      final encrypted = encryptedMap[name]!;

      Reference returnType;
      Code extraction;

      if (value is String) {
        returnType = Reference('String');
        extraction = Code('_$name ??= _decrypt(\'$encrypted\')');
      }
      else if (value is int) {
        returnType = Reference('int');
        extraction = Code(
          '_$name ??= int.parse(_decrypt(\'$encrypted\'))'
        );
      }
      else if (value is double) {
        returnType = Reference('double');
        extraction = Code(
          '_$name ??= double.parse(_decrypt(\'$encrypted\'))'
        );
      }
      else if (value is List) {
        final list = value.toList();

        if (list.isNotEmpty && list.first is int) {
          returnType = Reference('List<int>');
          extraction = Code(
            '_$name ??= (jsonDecode(_decrypt(\'$encrypted\')) as List).cast<int>()'
          );
        } else {
          returnType = Reference('List<String>');
          extraction = Code(
            '_$name ??= (jsonDecode(_decrypt(\'$encrypted\')) as List).cast<String>()'
          );
        }
      }
      else if (value is Map) {
        returnType = Reference('Map<String, dynamic>');
        extraction = Code(
          '_$name ??= jsonDecode(_decrypt(\'$encrypted\')) as Map<String, dynamic>'
        );
      }
      else {
        continue;
      }

      c.fields.add(
        Field((f) => f
        ..name = '_$name'
        ..static = true
        ..type = Reference('${returnType.symbol}?')),
      );

      c.methods.add(
        Method((m) => m
        ..name = name
        ..static = true
        ..returns = returnType
        ..type = MethodType.getter
        ..lambda = true
        ..body = extraction),
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
