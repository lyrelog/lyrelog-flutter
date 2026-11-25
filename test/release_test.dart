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

    test('is 1.0.5', () {
      expect(version(), '1.0.5');
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
      'f9744307fc9594a5eb864e9985ff0c89049a38d6296dedf4fdb1de060026af72',
      '8c1f2223a334499ddaf4a7766e2f3a737d13dea150e8276f679353f6ac3f59af',
      '581f689aa61c4ba463c3a341c2e8ad190e556e9fd406126444bb1d0e3a03d7f5',
      '69040a334ba12e14ddbdfd1ce418bca0cc9c815821c3a3fc8d7cff8e461cbbbd',
      '3e321b156622dee42a32fa28375a5265343e5ccf98f01bd3736bb15f30edd8a0',
      '3a4476b0d32cfc2a67e76142cf19bd49f81995ecbb9e87037a80d69f0b98ec54',
      'd79f181eeeab44eac51ed1311f4a930b8287ff77c2102d95f379c7ef2c40e8e1',
      'bf372aa4f4a8ed51c8ad1704e09d0af6f33efcb27da29112295caabd1965bcf3',
      'c09e52f5c52c2b7d67b7c2b07ac26811953c0e87fca1511e37b9de030cac47ed',
      '7cd6103d8391f49943e123ae089e6fffdba641108b7ee145fc9aaaaeddeabb16',
      '36a6e33145f824f805ea3585c637f8082cb2fb4543dbe32076e60b6a5260b7a1',
      '7b82c523924430937ced2ce962d3858a26c006a64ed606ca20ab301fbd4c9919',
      'e3cfb6acbaca0d4d56a04cac7ff5a4c288aaa8c90e60a4c1c99c87204a736fc9',
      'eaa734a79af4f283eab33f5704730a5c4c2f37f73b432558213464384d649b51',
      '81240b78fc3f5be98b4b4729348f00b46fa4361b5f66074187be1e1ff4f0825e',
      '7022a485fd53aa97a093899684340b7fbe5c071718cf6087d1d7087dd3a0b07c',
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

    // A signing team id names the developer it belongs to (Apple shows it beside their apps):
    // the example signs with whoever runs it.
    test('sign with no team of anyone\'s', () {
      final found = <String>[];
      for (final entity in Directory('example').listSync(recursive: true)) {
        if (entity is! File || !(entity.path.endsWith('.pbxproj') || entity.path.endsWith('.xcconfig') || entity.path.endsWith('.plist'))) continue;
        for (final m in RegExp(r'(DEVELOPMENT_TEAM|DevelopmentTeam|teamID)\W*=?\W*([A-Z0-9]{10})').allMatches(entity.readAsStringSync())) {
          found.add('${entity.path}: ${m.group(1)}');
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
