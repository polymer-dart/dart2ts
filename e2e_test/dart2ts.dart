import 'package:build_runner/build_runner.dart';
import 'package:dart2ts/dart2ts.dart';

main() {
  build([
    new BuildAction(new Dart2TsBuilder(new Config(moduleSuffix: '')), 'sample_project', inputs: ['lib/**.dart']),
  ], deleteFilesByDefault: true);
}
