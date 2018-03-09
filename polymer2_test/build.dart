import 'package:dart2ts/dart2ts.dart';
import 'package:build_runner/build_runner.dart';
import 'dart:async';
import 'package:glob/glob.dart';
import 'package:polymer2_builder/polymer2_builder.dart';

Future main(List<String> args) async {
  BuildResult res = await build([
    new BuildAction(new InitCodePackageBuilder(), 'polymer2_test', inputs: ['lib/myelement.dart']),
    new BuildAction(new Dart2TsBuilder(), 'polymer2_test', inputs: ['lib/**.dart']),
  ], deleteFilesByDefault: true);

  if (res.status == BuildStatus.success) {
    await tsc();
  }
}
