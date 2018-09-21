import 'package:build_runner/build_runner.dart';
import 'package:dart2ts/dart2ts.dart';
import 'dart:io';

main(List<String> args) {
  if ((args.length > 0 && args[0] == '-c')) {
    Directory dir = new Directory('.dart_tool');
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    print("Deleted ${dir.absolute.path}");
  }

  Config config = new Config(overrides: new IOverrides.parse('''
overrides:      
      
      '''));
  build([
    new BuildAction(new Dart2TsBuilder(), 'sample_project', inputs: ['lib/**.dart']),
  ], deleteFilesByDefault: true);
}
