@TestOn('vm')
library my_test;

import 'dart:convert';
import 'package:build_runner/build_runner.dart';
import 'package:test/test.dart';
import 'package:dart2ts/dart2ts.dart';
import 'dart:io';

void main() {
  group("test test", () {
    setUpAll(() async {
      print("Build e2e");

      Directory dartTool = new Directory("e2e_test/.dart_tool");
      if (dartTool.existsSync()) {
        await dartTool.delete(recursive: true);
      }
      BuildResult buildResult = await dart2tsBuild("e2e_test", new Config());
      expect(buildResult.status, equals(BuildStatus.success), reason: "Build is ok");
      print("TS Build, now running webpack");
      Process npm = await Process.start('npm', ['run', 'build'], workingDirectory: 'e2e_test');
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
    });
  });
}
