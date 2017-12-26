import 'dart:async';

import 'package:analyzer/analyzer.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
//import 'package:analyzer/src/generated/engine.dart' show AnalysisContext;
import 'package:analyzer/src/generated/resolver.dart';
import 'package:args/command_runner.dart';
import 'package:build/build.dart';
import 'package:build_runner/build_runner.dart';
import 'package:dart2ts/src/overrides.dart';
import 'package:dart2ts/src/utils.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:source_gen/source_gen.dart';
import 'package:analyzer/dart/element/visitor.dart';

part 'visitors.dart';
part 'contexts.dart';
part 'ts_simple_ast.dart';

/**
 * Second version of the code generator.
 */

Logger _logger = new Logger('dart2ts.lib.code_generator');

class Dart2TsBuildCommand extends Command<bool> {
  @override
  String get description => "Build a file";

  @override
  String get name => 'build';

  Dart2TsBuildCommand() {
    this.argParser
      ..addOption('dir',
          defaultsTo: '.',
          abbr: 'd',
          help: 'the base path of the package to process')
      ..addFlag('watch',
          abbr: 'w', defaultsTo: false, help: 'watch for changes');
  }

  @override
  void run() {
    PackageGraph graph = new PackageGraph.forPath(argResults['dir']);

    List<BuildAction> actions = [
      new BuildAction(new Dart2TsBuilder(), graph.root.name,
          inputs: ['lib/**.dart', 'web/**.dart'])
    ];

    if (argResults['watch'] == true) {
      watch(actions,
          packageGraph: graph, onLog: (_) {}, deleteFilesByDefault: true);
    } else {
      build(actions,
          packageGraph: graph, onLog: (_) {}, deleteFilesByDefault: true);
    }
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

    await runWithContext(lib.context, () => generateForLibrary(lib, buildStep));
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
    AssetId destId = new AssetId(buildStep.inputId.package,
        "${path.withoutExtension(buildStep.inputId.path)}.ts");
    _logger.fine('Processing ${library.location} for ${destId}');

    LibraryVisitor visitor = new LibraryVisitor(library);
    visitor.run();
    LibraryContext libraryContext = visitor.libraryContext;

    IndentingPrinter printer = new IndentingPrinter();
    libraryContext.generateTypescript().writeCode(printer);

    await buildStep.writeAsString(destId, printer.buffer);
  }
}

/**
 * Printer
 */

class IndentingPrinter {
  StringBuffer _buffer = new StringBuffer();

  int _currentIndent = 0;
  bool _newLine = true;

  void write(String some) {
    if (some?.isEmpty ?? true) {
      return;
    }

    if (_newLine) {
      _startLine();
    }

    _buffer.write(some);
  }

  void _startLine() {
    _buffer.write(new String.fromCharCodes(
        new List.filled(_currentIndent, ' '.codeUnitAt(0))));
    _newLine = false;
  }

  void indent([int count = 1]) => _currentIndent += count;

  void writeln([String line = '']) {
    write(line);
    _buffer.writeln();
    _newLine = true;
  }

  String get buffer => _buffer.toString();
}


