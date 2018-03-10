@TestOn('vm')
library my_test;

import 'dart:convert';
import 'package:build_runner/build_runner.dart';
import 'package:test/test.dart';
import 'package:dart2ts/dart2ts.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';

final String E2E_TEST_PROJECT_PATH = path.canonicalize(path.absolute(path.joinAll(['..', 'e2e_test'])));

void main() {
  group("test test with ${E2E_TEST_PROJECT_PATH}", () {
    setUpAll(() async {
      print("Build e2e");

      Directory dartTool = new Directory(path.join(E2E_TEST_PROJECT_PATH, '.dart_tool'));
      if (dartTool.existsSync()) {
        await dartTool.delete(recursive: true);
      }
      BuildResult buildResult = await dart2tsBuild(E2E_TEST_PROJECT_PATH, new Config(overrides: new IOverrides.parse('''
      
      
      ''')));
      expect(buildResult.status, equals(BuildStatus.success), reason: "Build is ok");
      print("TS Build, now running webpack");
      Process npm = await Process.start('npm', ['run', 'build'], workingDirectory: E2E_TEST_PROJECT_PATH);
      stdout.addStream(npm.stdout);
      stderr.addStream(npm.stderr);
      int exitCode = await npm.exitCode;
      expect(exitCode, equals(0), reason: "Ts Compile Ok");
    });

    test("execute mocha tests", () async {
      Process res = await Process.start('npm', ['run', 'test'], workingDirectory: '.');
      stdout.addStream(res.stdout);
      stderr.addStream(res.stderr);

      expect(await res.exitCode, equals(0), reason: "mocha test Ok");
    }, timeout: new Timeout(new Duration(minutes: 5)));
  });
}
