# Secure Literals

Secure Literals is a Dart package that enhances the security of your Flutter and Dart applications by encrypting sensitive literals at generation time.

It prevents plain-text strings, integers, and lists from being exposed in your compiled binary, decrypting them only when needed at runtime.

Secure Literals uses a simple CLI generator and does not rely on build_runner.


## Features

- Generation-time encryption using AES-256-GCM with a unique IV per value
- Lazy runtime decryption with in-memory caching
- YAML-based configuration
- Configurable output file path
- Customizable generated class name
- No build_runner dependency

---

## Installation

Add the packages:
```bash
flutter pub add encrypt
flutter pub add --dev secure_literals
```
---

## Usage

### 1. Create Configuration File

Create a file named secure_literals.yaml in your project root.

Example:
```
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
```

YAML Options

- output (optional)  
  Default: lib/generated_literals.dart  
  Description: Output file path

- class_name (optional)  
  Default: SecureLiterals  
  Description: Generated class name

- literals (required)  
  Description: Map of values to encrypt

Supported Types:
- String
- int
- List<String>
- List<int>

---

### 2. Generate Code

From your project root:
```
dart run secure_literals
```
Example output:
```
Generated lib/secure/generated_keys.dart
```
---

### 3. Use the Generated Secrets
```
// Import the generated file:
import 'package:your_app/secure/generated_keys.dart';

void main() {
  print(AppSecrets.apiKey);
  print(AppSecrets.serverEndpoints);
}
```
Secrets are decrypted only on first access and cached afterward.

---

## How It Works

1. YAML values are encrypted using AES-256-GCM.
2. The encryption key is embedded in the generated file.
3. Each value uses a unique IV.
4. Values are lazily decrypted at runtime.

---

## Security Notice

This package significantly raises the difficulty of extracting secrets via:

- Binary string inspection
- Basic APK/IPA decompilation
- Static scanning

However, the encryption key is bundled inside the client application.

This protects against casual inspection but not against a determined reverse engineer.

---

## Recommended Best Practices

- Add secure_literals.yaml to .gitignore
- Optionally add the generated file to .gitignore
- Avoid storing highly sensitive backend secrets in client applications
- Use server-side validation whenever possible

---

## License

This project is licensed under the MIT License. See the LICENSE file for details.
