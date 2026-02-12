import 'dart:io';
import 'package:secure_literals/generator.dart';

Future<void> main() async {
  final input = File('secure_literals.yaml');

  if (!input.existsSync()) {
    print('secure_literals.yaml not found in project root.');
    exit(1);
  }

  final content = await input.readAsString();
  final (outputPath, generatedCode) =
    await generateSecureLiterals(content);


  await File(outputPath)
    ..createSync(recursive: true)
    ..writeAsStringSync(generatedCode);


  print('Generated ${outputPath}');
}
