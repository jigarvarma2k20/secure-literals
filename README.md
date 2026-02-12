# Secure Literals

Secure Literals is a Dart package designed to enhance the security of your Flutter and Dart applications by encrypting sensitive literals at build time. It prevents plain-text strings, integers, and lists from being exposed in your compiled binary, decrypting them only when needed at runtime.

[![Pub Version](https://img.shields.io/pub/v/secure_literals)](https://pub.dev/packages/secure_literals)
[![License](https://img.shields.io/github/license/Jigarvarma2k20/secure-literals)](https://github.com/Jigarvarma2k20/secure-literals/blob/master/LICENSE)

## Features

- **Build-time Encryption**: Secrets are encrypted during the build process using AES-256-CTR. We use unique Initialization Vectors (IVs) for every entry to ensure maximum security.
- **Runtime Decryption**: Values are decrypted on demand and cached in memory, so there is no performance penalty for subsequent accesses.
- **YAML Configuration**: Manage your secrets easily using a `secure_literals.yaml` file.
- **Type Safe**: The package generates strictly typed getters for `String`, `int`, `List<String>`, and `List<int>`, ensuring compile-time safety.

## Installation

Run the following commands to add the package to your project:

```bash
flutter pub add secure_literals
flutter pub add --dev build_runner
```

## Usage

### 1. Configure Secrets

Create a file named `secure_literals.yaml` in the root of your project. This file will hold your sensitive configuration.

```yaml
literals:
  apiKey: "AIzaShdhdereyCX..."
  apiSecret: "836dd343f3...1a"
  maxRetries: 3
  supportedLocales:
    - "en_US"
    - "fr_FR"
```

### 2. Generate Code

Run the build runner to generate the secure class containing your encrypted data:

```bash
dart run build_runner build
```

This will create a file located at `lib/generated_literals.dart` (by default).

### 3. Access Secrets

Import the generated file and access your secrets through the static properties of the generated class.

```dart
import 'package:secure_literals/generated_literals.dart';

void main() {
  // Secrets are decrypted the first time they are accessed
  print('API Key: ${AppSecrets.apiKey}');
  
  // Lists are automatically parsed and cast to the correct type
  print('Locales: ${AppSecrets.supportedLocales}');
}
```

## Security Note

This package obfuscates your secrets and significantly raises the bar for casual inspection (like running `strings` on the binary). However, it is important to understand that the encryption key is embedded alongside the ciphertext in the client application. Therefore, it cannot protect against a determined attacker who has the resources to reverse-engineer your application code.

**Best Practices:**
- Add `secure_literals.yaml` to your `.gitignore` file to prevent committing secrets to version control.
- Add the generated file (e.g., `lib/generated_literals.dart`) to your `.gitignore` file.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
