@TestOn('vm')
library my_test;

import 'package:build_runner/build_runner.dart';
import 'package:test/test.dart';
import 'package:dart2ts/dart2ts.dart';
import 'dart:io';

void main() {
  group("test test", () {
    setUpAll(() async {
      print("Build e2e");

      Directory dartTool = new Directory("e2e_test/.dart_tool");
      await dartTool.delete(recursive: true);
      BuildResult buildResult = await dart2tsBuild("e2e_test", new Config());
      expect(buildResult.status, equals(BuildStatus.success), reason: "Build is ok");
      print("TS Build, now running webpack");
      ProcessResult res = await Process.run('npm', ['run', 'tsc'], workingDirectory: 'e2e_test');
      print("RES: ${res.stdout}  / ${res.stderr}");
      expect(res.exitCode, equals(0), reason: "Ts Compile Ok");
    });

    test("execute mocha tests", () async {
      ProcessResult res = await Process.run('npm', ['run', 'test'], workingDirectory: '.');
      print("RES: ${res.stdout}  / ${res.stderr}");
      expect(res.exitCode, equals(0), reason: "mocha test Ok");
    });
  });
}
