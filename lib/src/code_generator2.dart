import 'dart:async';

import 'package:analyzer/analyzer.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/src/dart/element/member.dart';
import 'package:analyzer/src/generated/resolver.dart';
import 'package:args/command_runner.dart';
import 'package:build/build.dart';
import 'package:build_runner/build_runner.dart';
import 'package:dart2ts/src/utils.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as _P;
import 'package:resource/resource.dart' as res;
import 'package:source_gen/source_gen.dart';
import 'package:yaml/yaml.dart';

part 'package:dart2ts/src/parts/contexts.dart';

part 'package:dart2ts/src/parts/ts_simple_ast.dart';

part 'parts/type_manager.dart';

final _P.Context path = new _P.Context(style: _P.Style.posix, current: '/');

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
      ..addOption('dir', defaultsTo: '.', abbr: 'd', help: 'the base path of the package to process')
      ..addOption('module-prefix', defaultsTo: '../node_modules/', help: 'The absolute module prefix')
      ..addOption('module-suffix', defaultsTo: '.js', help: 'The modules suffix')
      ..addFlag('watch', abbr: 'w', defaultsTo: false, help: 'watch for changes');
  }

  @override
  void run() {
    PackageGraph graph = new PackageGraph.forPath(argResults['dir']);

    List<BuildAction> actions = [
      new BuildAction(
          new Dart2TsBuilder(
              new Config(modulePrefix: argResults['module-prefix'], moduleSuffix: argResults['module-suffix'])),
          graph.root.name,
          inputs: ['lib/**.dart', 'web/**.dart'])
    ];

    if (argResults['watch'] == true) {
      watch(actions, packageGraph: graph, onLog: (_) {}, deleteFilesByDefault: true);
    } else {
      build(actions, packageGraph: graph, onLog: (_) {}, deleteFilesByDefault: true);
    }
  }
}

Future<BuildResult> dart2tsBuild(String path, Config config) {
  PackageGraph graph = new PackageGraph.forPath(path);

  List<BuildAction> actions = [
    new BuildAction(new Dart2TsBuilder(config), graph.root.name, inputs: ['lib/**.dart', 'web/**.dart'])
  ];

  return build(actions, packageGraph: graph, onLog: (_) {}, deleteFilesByDefault: true);
}

Future<ServeHandler> dart2tsWatch(String path, Config config) {
  PackageGraph graph = new PackageGraph.forPath(path);

  List<BuildAction> actions = [
    new BuildAction(new Dart2TsBuilder(config), graph.root.name, inputs: ['lib/**.dart', 'web/**.dart'])
  ];

  return watch(actions, packageGraph: graph, onLog: (_) {}, deleteFilesByDefault: true);
}

Builder dart2TsBuilder([Config config]) {
  return new Dart2TsBuilder(config ?? new Config());
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
  Config _config;

  Dart2TsBuilder([this._config]) {
    this._config ??= new Config();
  }

  @override
  Future generateForLibrary(LibraryElement library, BuildStep buildStep) async {
    AssetId destId = new AssetId(buildStep.inputId.package, "${path.withoutExtension(buildStep.inputId.path)}.ts");
    _logger.fine('Processing ${library.location} for ${destId}');

    IndentingPrinter printer = new IndentingPrinter();
    Overrides overrides = await Overrides.forCurrentContext();
    runWithContext(library.context, () {
      LibraryContext libraryContext = new LibraryContext(library, overrides, _config);

      libraryContext
        ..translate()
        ..tsLibrary.writeCode(printer);
    });
    await buildStep.writeAsString(destId, printer.buffer);
  }
}

typedef void PrinterConsumer(IndentingPrinter p);

/**
 * Printer
 */

class IndentingPrinter {
  int defaultIndent;
  StringBuffer _buffer = new StringBuffer();

  int _currentIndent = 0;
  bool _newLine = true;

  IndentingPrinter({this.defaultIndent = 4});

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
    _buffer.write(new String.fromCharCodes(new List.filled(_currentIndent, ' '.codeUnitAt(0))));
    _newLine = false;
  }

  void indent([int count]) => _currentIndent += count ?? defaultIndent;

  void deindent([int count]) => _currentIndent -= count ?? defaultIndent;

  void indented(void consumer(IndentingPrinter), {int count}) {
    indent(count);
    consumer(this);
    deindent(count);
  }

  void writeln([String line = '']) {
    write(line);
    _buffer.writeln();
    _newLine = true;
  }

  void accept(PrinterWriter w) => w.writeCode(this);

  void join(Iterable<PrinterWriter> writers, {String delim = ',', bool newLine = false}) {
    joinConsumers(
        writers.map((w) => (p) {
              p.accept(w);
            }),
        delim: delim,
        newLine: newLine);
  }

  void consume(PrinterConsumer c) => c(this);

  void joinConsumers(Iterable<PrinterConsumer> writers, {String delim = ',', bool newLine: false}) {
    bool first = true;
    writers.forEach((w) {
      if (!first) {
        write(delim);
        if (newLine) {
          writeln();
        }
      } else {
        first = false;
      }
      this.consume(w);
    });
  }

  String get buffer => _buffer.toString();
}

abstract class PrinterWriter {
  void writeCode(IndentingPrinter printer);
}
