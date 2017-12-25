import 'package:args/command_runner.dart';
import 'package:dart2ts/src/deps_installer.dart' show Dart2TsInstallCommand;
import 'package:logging/logging.dart';
import 'package:dart2ts/src/code_generator2.dart' show Dart2TsBuildCommand;

Logger _logger = new Logger('dart2ts.lib.command');

class Dart2TsCommandRunner extends CommandRunner<bool> {
  Dart2TsCommandRunner() : super('dart2ts', 'a better interface to TS') {
    addCommand(new Dart2TsBuildCommand());
    addCommand(new Dart2TsInstallCommand());
  }
}
