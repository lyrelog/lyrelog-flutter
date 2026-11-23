import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lyrelog/lyrelog.dart';

// Checks on what ships rather than on behaviour: the version is the same everywhere it lives,
// and nothing public names a real person. Run from the package root (as `flutter test` does).

String read(String path) => File(path).readAsStringSync();

/// The first capture of [pattern] in the file at [path], failing the test when it isn't there.
String find(String path, RegExp pattern) {
  final match = pattern.firstMatch(read(path));
  expect(match, isNotNull, reason: '$path has no ${pattern.pattern}');
  return match!.group(1)!;
}

void main() {
  group('version', () {
    String version() => find('pubspec.yaml', RegExp(r'^version: (\S+)$', multiLine: true));

    test('is 0.9.0', () {
      expect(version(), '0.9.0');
    });

    test('is the same in every place it lives', () {
      final places = <String, String>{
        'Lyrelog.version': Lyrelog.version,
        'lyrelog_ios/pubspec.yaml': find('lyrelog_ios/pubspec.yaml', RegExp(r'^version: (\S+)$', multiLine: true)),
        'the lyrelog_ios dependency in pubspec.yaml': find(
          'pubspec.yaml',
          RegExp(r'^  lyrelog_ios: \^(\S+)$', multiLine: true),
        ),
        'android/build.gradle.kts': find('android/build.gradle.kts', RegExp(r'^version = "(\S+)"$', multiLine: true)),
        'WRAPPER_VERSION (Kotlin)': find(
          'android/src/main/kotlin/com/lyrelog/flutter/LyrelogPlugin.kt',
          RegExp(r'WRAPPER_VERSION = "(\S+)"'),
        ),
        'the Swift wrapper': find(
          'lyrelog_ios/ios/lyrelog_ios/Sources/lyrelog_ios/LyrelogIosPlugin.swift',
          RegExp(r'static let wrapper = "lyrelog-flutter/(\S+)"'),
        ),
        'README install line': find('README.md', RegExp(r'^  lyrelog: \^(\S+)$', multiLine: true)),
        'CHANGELOG.md': find('CHANGELOG.md', RegExp(r'^## (\S+)', multiLine: true)),
        'lyrelog_ios/CHANGELOG.md': find('lyrelog_ios/CHANGELOG.md', RegExp(r'^## (\S+)', multiLine: true)),
      };
      for (final MapEntry(:key, :value) in places.entries) {
        expect(value, version(), reason: key);
      }
    });

    test('both packages ask for the same Dart and Flutter', () {
      String environment(String path) => find(path, RegExp(r'^environment:\n((?:  .*\n)+)', multiLine: true));
      expect(environment('lyrelog_ios/pubspec.yaml'), environment('pubspec.yaml'));
    });
  });

  group('public files', () {
    // SHA-256 of words that must never appear in a public file (a person's names and accounts),
    // kept as digests so this file doesn't spell them.
    const forbidden = {
      '4859d1729b697a9ccc9bf17b6a3c676bc935834e5640d203a7cfa489bd45d619',
      '976c617a20d12e4261e40bd8e4ce88493578ec463d082af3b2784b642b82ef0d',
      'b9e5b115929357704655d70d95b79daf630c3cea6e084adec79b4bcb7e0cd7b1',
      '34eb8131c759d8ea0bdf432f943e6e78d8bd2e1d9ad50f2bf166fad074edcea8',
      '7e421181fc7b52ab66f2c22bd396acce92c3cdd9a29122dde0f1b7ddc0eb4435',
    };

    /// Every text file that ships or is shown: the packages' metadata, docs, sources, the
    /// example. Not build output, local settings or the agents' guide (none of them tracked).
    List<File> publicFiles() {
      const roots = [
        'README.md',
        'CHANGELOG.md',
        'LICENSE',
        'pubspec.yaml',
        'analysis_options.yaml',
        'lib',
        'test',
        'pigeon',
        'android/build.gradle.kts',
        'android/settings.gradle.kts',
        'android/src',
        'lyrelog_ios/README.md',
        'lyrelog_ios/CHANGELOG.md',
        'lyrelog_ios/LICENSE',
        'lyrelog_ios/pubspec.yaml',
        'lyrelog_ios/ios/lyrelog_ios/Package.swift',
        'lyrelog_ios/ios/lyrelog_ios/Sources',
        'example/README.md',
        'example/pubspec.yaml',
        'example/lib',
        'example/ios/Runner',
        'example/ios/RunnerTests',
        'example/android/app/src',
        'example/android/app/build.gradle.kts',
        'example/android/build.gradle.kts',
        'example/android/settings.gradle.kts',
      ];
      const text = {'.md', '.yaml', '.dart', '.kts', '.kt', '.swift', '.xml', '.plist', '.h', ''};
      final files = <File>[];
      for (final root in roots) {
        final type = FileSystemEntity.typeSync(root);
        expect(type, isNot(FileSystemEntityType.notFound), reason: '$root is missing');
        if (type == FileSystemEntityType.directory) {
          for (final entity in Directory(root).listSync(recursive: true)) {
            if (entity is! File) continue;
            final name = entity.uri.pathSegments.last;
            final dot = name.lastIndexOf('.');
            if (text.contains(dot < 0 ? '' : name.substring(dot))) files.add(entity);
          }
        } else {
          files.add(File(root));
        }
      }
      return files;
    }

    test('name no real person', () {
      final files = publicFiles();
      expect(files.length, greaterThan(20));
      final found = <String>[];
      for (final file in files) {
        final words = file.readAsStringSync().toLowerCase().split(RegExp('[^a-z0-9]+')).toSet();
        for (final word in words) {
          if (word.isEmpty) continue;
          if (forbidden.contains(sha256.convert(utf8.encode(word)).toString())) {
            found.add('${file.path}: a forbidden word (sha256 ${sha256.convert(utf8.encode(word))})');
          }
        }
      }
      expect(found, isEmpty);
    });

    test('the licences are Lyrelog\'s', () {
      for (final path in ['LICENSE', 'lyrelog_ios/LICENSE']) {
        expect(read(path), contains('Copyright (c) 2026 Lyrelog\n'), reason: path);
      }
    });

    test('the metadata points at Lyrelog', () {
      for (final path in ['pubspec.yaml', 'lyrelog_ios/pubspec.yaml']) {
        final pubspec = read(path);
        expect(pubspec, contains('homepage: https://lyrelog.com\n'), reason: path);
        expect(pubspec, contains('repository: https://github.com/lyrelog/lyrelog-flutter\n'), reason: path);
        expect(pubspec, contains('issue_tracker: https://github.com/lyrelog/lyrelog-flutter/issues\n'), reason: path);
      }
    });
  });
}
