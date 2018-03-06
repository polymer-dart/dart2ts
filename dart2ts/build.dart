import 'package:build_runner/build_runner.dart';
import 'package:dart2ts/dart2ts.dart';
import 'dart:io';

main() {
  Directory dir = new Directory('dart_sdl/.dart_tool');
  if (dir.existsSync()) dir.deleteSync(recursive: true);
  build([
    new BuildAction(new Dart2TsBuilder(/*new Config(moduleSuffix: '.js')*/), 'dart_sdk', inputs: ['lib/**.dart']),
  ], deleteFilesByDefault: true);
}
