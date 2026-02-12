# Secure Literals

Secure Literals is a Dart package that enhances the security of your Flutter and Dart applications by encrypting sensitive literals at generation time.

It prevents plain-text strings, integers, lists, and maps from being exposed in your compiled binary, decrypting them only when needed at runtime.

Secure Literals uses a simple CLI generator and does not rely on build_runner.

---

## Features

- Generation-time encryption using AES-256-GCM with a unique IV per value
- Authenticated encryption (tamper detection)
- Lazy runtime decryption with in-memory caching
- YAML-based configuration
- Configurable output file path
- Customizable generated class name
- Strongly typed getters (String, int, List, Map)
- No build_runner dependency

---

## Installation

Add Secure Literals as a development dependency:

```bash
flutter pub add --dev secure_literals
```

No additional encryption package is required.

---

## Usage

### 1. Create Configuration File

Create a file named:

```
secure_literals.yaml
```

in your project root.

Example:

```yaml
output: lib/secure/generated_keys.dart
class_name: AppSecrets

literals:
  apiKey: "SUPER_SECRET_KEY_12345"
  apiSecret: "ANOTHER_SECRET_VALUE"
  maxRetries: 5
  timeoutMs: 30000
  serverEndpoints:
    - "https://api.one.com"
    - "https://api.two.com"
  retryDelays:
    - 1000
    - 2000
    - 5000
  headers:
    X-Request-ID: "request-id"
    X-App-Version: "1.0.0"
```

---

### YAML Options

| Key         | Required | Default                          | Description |
|------------|----------|----------------------------------|-------------|
| output     | No       | `lib/generated_literals.dart`    | Output file path |
| class_name | No       | `SecureLiterals`                 | Generated class name |
| literals   | Yes      | —                                | Map of values to encrypt |

---

### Supported Types

- `String`
- `int`
- `double`
- `List<String>`
- `List<int>`
- `Map<String, dynamic>`

---

### 2. Generate Code

From your project root:

```bash
dart run secure_literals
```

Example output:

```
Generated lib/secure/generated_keys.dart
```

---

### 3. Use the Generated Secrets

Import the generated file:

```dart
import 'package:your_app/secure/generated_keys.dart';

void main() {
  print(AppSecrets.apiKey);
  print(AppSecrets.serverEndpoints);
  print(AppSecrets.headers['X-Request-ID']);
}
```

Secrets are decrypted only on first access and cached afterward.

---

## How It Works

1. YAML values are encrypted using AES-256-GCM.
2. A 256-bit encryption key is generated during code generation.
3. Each literal uses a unique 12-byte IV.
4. The IV and authentication tag are embedded alongside ciphertext.
5. Values are lazily decrypted at runtime.
6. If ciphertext is modified, decryption fails.

---

## Security Notice

This package significantly raises the difficulty of extracting secrets via:

- Binary string inspection
- Basic APK/IPA decompilation
- Static scanning

AES-GCM provides authenticated encryption, meaning tampered values will cause decryption failure.

However, the encryption key is embedded inside the client application.

This protects against casual inspection but not against a determined reverse engineer with full control over the binary.

Do not store highly sensitive backend secrets in client applications.

---

## Recommended Best Practices

- Add `secure_literals.yaml` to `.gitignore`
- Optionally add the generated file to `.gitignore`
- Regenerate secrets before release builds
- Use server-side validation whenever possible

---

## License

This project is licensed under the MIT License. See the LICENSE file for details.
