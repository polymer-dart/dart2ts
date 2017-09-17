import 'dart:async';
import 'dart:io';
import 'package:analyzer/dart/element/element.dart';
import 'package:args/command_runner.dart';
import 'package:logging/logging.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';
import 'package:build_runner/build_runner.dart';

Logger _logger = new Logger('dart2ts.lib.code_generator');

class Dart2TsCommand extends Command<bool> {
  // TODO: implement description
  @override
  String get description => "Build a file";

  // TODO: implement name
  @override
  String get name => 'build';

  Dart2TsCommand() {
    this.argParser.addOption('dir',
        defaultsTo: '.',
        abbr: 'd',
        help: 'the base path of the package to process');
  }

  @override
  void run() {
    build([new BuildAction(new Dart2TsBuilder(), 'dart2ts')],
        packageGraph: new PackageGraph.forPath(argResults['dir']),
        onLog: (_) {});
  }
}

class Dart2TsCommandRunner extends CommandRunner<bool> {
  Dart2TsCommandRunner() : super('dart2ts', 'a better interface to TS') {
    addCommand(new Dart2TsCommand());
  }
}

Builder dart2TsBuilder() {
  return new Dart2TsBuilder();
}

/// A [Builder] wrapping on one or more [Generator]s.
abstract class _BaseBuilder extends Builder {
  /// Wrap [_generators] to form a [Builder]-compatible API.
  _BaseBuilder() {}

  @override
  Future build(BuildStep buildStep) async {
    var resolver = buildStep.resolver;
    if (!await resolver.isLibrary(buildStep.inputId)) return;
    var lib = await buildStep.inputLibrary;
    await generateForLibrary(lib, buildStep);
  }

  Future generateForLibrary(LibraryElement library, BuildStep buildStep);

  @override
  Map<String, List<String>> get buildExtensions => {
        '.dart': ['.ts']
      };
}

class Dart2TsBuilder extends _BaseBuilder {
  @override
  Future generateForLibrary(LibraryElement library, BuildStep buildStep) async {
    // TODO: implement generateForLibrary
    _logger.info('Processing ${library.location}');
  }
}
