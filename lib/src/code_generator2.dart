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

/**
 * TS Generator
 * (to be moved in another lib)
 */

abstract class TSNode {
  void writeCode(IndentingPrinter printer);
}

class TSLibrary extends TSNode {
  String _name;
  List<TSNode> _children = [];

  TSLibrary(this._name) {}

  @override
  void writeCode(IndentingPrinter printer) {
    printer.writeln("/** Library ${_name} */");
    printer.writeln();
    _children.forEach((n) => n.writeCode(printer));
  }

  void addChild(TSNode child) {
    _children.add(child);
  }
}

class TSFunction extends TSNode {
  String _name;
  bool topLevel;

  TSFunction(
    this._name, {
    this.topLevel: false,
  });

  @override
  void writeCode(IndentingPrinter printer) {
    if (topLevel) {
      printer.write('export ');
    }

    printer.write('function ${_name} () {');
    printer.indent();
    printer.writeln('/* body */');
    printer.indent(-1);
    printer.writeln("}");
  }
}

/**
 * Generation Context
 */

class LibraryContext {
  LibraryElement _libraryElement;
  List<FileContext> _fileContexts;

  LibraryContext(this._libraryElement) {
    _fileContexts = new List();
  }

  void addFileContext(FileContext fileContext) {
    this._fileContexts.add(fileContext);
  }

  TSLibrary generateTypescript() {
    TSLibrary tsLibrary = new TSLibrary(_libraryElement.source.uri.toString());
    _fileContexts.forEach((fc) => fc.generateTypescript(tsLibrary));

    return tsLibrary;
  }
}

class FileContext {
  LibraryContext _libraryContext;
  CompilationUnitElement _compilationUnitElement;
  List<TopLevelContext> _topLevelContexts;

  CompilationUnit get compilationUnit => _compilationUnitElement.computeNode();

  FileContext(this._libraryContext, this._compilationUnitElement) {
    this._libraryContext.addFileContext(this);
    _topLevelContexts = new List();
  }

  void generateTypescript(TSLibrary tsLibrary) {
    _topLevelContexts.forEach((t) => t.generateTypescript(tsLibrary));
  }

  void addTopLevelContext(TopLevelContext topLevelContext) {
    _topLevelContexts.add(topLevelContext);
  }
}

abstract class TopLevelContext {
  FileContext _fileContext;

  TopLevelContext(this._fileContext) {
    _fileContext.addTopLevelContext(this);
  }

  void generateTypescript(TSLibrary tsLibrary);
}

class TopLevelFunctionContext extends TopLevelContext {
  FunctionDeclaration _functionDeclaration;

  TopLevelFunctionContext(FileContext fileContext, this._functionDeclaration)
      : super(fileContext);
  @override
  void generateTypescript(TSLibrary tsLibrary) {
    tsLibrary.addChild(new TSFunction(_functionDeclaration.name.toString(),topLevel: true));
  }
}

class ClassContext extends TopLevelContext {
  ClassContext(FileContext fileContext) : super(fileContext);
  @override
  void generateTypescript(TSLibrary tsLibrary) {
    // TODO: implement generateTypescript
  }
}

class MethodContext {
  ClassContext _classContext;
}

/**
 * A visitor that reads the file
 */

/**
 * This will visit a library
 */
class LibraryVisitor extends RecursiveElementVisitor {
  LibraryContext _context;

  LibraryContext get libraryContext => _context;

  LibraryVisitor(LibraryElement libraryElement) {
    _context = new LibraryContext(libraryElement);
  }

  @override
  visitCompilationUnitElement(CompilationUnitElement element) {
    FileVisitor fileVisitor = new FileVisitor(_context, element);
    fileVisitor.run();
  }

  void run() {
    _context._libraryElement.accept(this);
  }
}

/**
 * This will visit one compilationUnit (file)
 */

class FileVisitor extends GeneralizingAstVisitor<dynamic> {
  FileContext _fileContext;

  FileVisitor(
      LibraryContext parent, CompilationUnitElement compilationUnitElement) {
    _fileContext = new FileContext(parent, compilationUnitElement);
  }

  void run() {
    _fileContext.compilationUnit.accept(this);
  }

  @override
  visitTopLevelVariableDeclaration(TopLevelVariableDeclaration node) {}

  @override
  visitFunctionDeclaration(FunctionDeclaration node) {
    new TopLevelFunctionVisitor(_fileContext, node).run();
  }

  @override
  visitClassDeclaration(ClassDeclaration node) {}

  @override
  visitFunctionTypeAlias(FunctionTypeAlias node) {}
}

/**
 * This will visit one function
 */

class TopLevelFunctionVisitor extends GeneralizingAstVisitor<dynamic> {
  TopLevelFunctionContext _topLevelFunctionContext;

  TopLevelFunctionVisitor(FileContext parent, FunctionDeclaration function) {
    _topLevelFunctionContext = new TopLevelFunctionContext(parent, function);
  }

  void run() {
    _topLevelFunctionContext._functionDeclaration.accept(this);
  }
}
