import 'package:build_runner/build_runner.dart';
import 'package:dart2ts/dart2ts.dart';
import 'dart:io';

main(List<String> args) {
  if (args.length > 1 && args[0] == '-c') {
    Directory dir = new Directory('.dart_tool');
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  }
  build([
    new BuildAction(new Dart2TsBuilder(new Config(overrides: new IOverrides.parse('''
overrides:      
      
      '''))), 'dart_sdk', inputs: ['lib/**.dart']),
  ], deleteFilesByDefault: true);
}