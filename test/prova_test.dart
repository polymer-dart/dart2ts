@TestOn('vm')
library my_test;

import 'package:test/test.dart';
import 'package:dart2ts/src/commands.dart' as dart2ts;
import 'dart:io';

void main() {
  group("test test", () {
    setUpAll(() async {
      print("Build e2e");

      await dart2ts.main([
        "build",
        "-d","e2e_test"
      ]);
      print("TS Build, now running webpack");
      ProcessResult res = await Process.run('npm', ['run-script','build'],workingDirectory: 'e2e_test');
      print("RES: ${res.stdout}  / ${res.stderr}");
      expect(res.exitCode,equals(true),reason: "Ts Compile Ok");
    });

    test("something",() {
      print("It's ok");
    });

    test("something2",() {
      print("It's ok2");
    });
  });
}