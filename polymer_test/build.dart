import 'package:dart2ts/dart2ts.dart';
import 'package:build_runner/build_runner.dart';

void main(List<String> args) {
  build([
    new BuildAction(new Dart2TsBuilder(), 'polymer_test',
        inputs: ['lib/**.dart']),
  ],deleteFilesByDefault: true);
}
