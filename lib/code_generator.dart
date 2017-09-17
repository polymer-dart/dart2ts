import 'dart:async';
import 'dart:io';
import 'package:analyzer/analyzer.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:args/command_runner.dart';
import 'package:logging/logging.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';
import 'package:build_runner/build_runner.dart';
import 'package:path/path.dart' as path;

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
    PackageGraph graph = new PackageGraph.forPath(argResults['dir']);

    build([new BuildAction(new Dart2TsBuilder(), graph.root.name)],
        packageGraph: graph, onLog: (_) {}, deleteFilesByDefault: true);
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
    AssetId destId = new AssetId(buildStep.inputId.package,
        "${path.withoutExtension(buildStep.inputId.path)}.ts");
    _logger.fine('Processing ${library.location} for ${destId}');
    StringBuffer sink = new StringBuffer();
    Dart2TsVisitor visitor = new Dart2TsVisitor(sink);

    library.unit.accept(visitor);
    //visitor.visitAllNodes(library.unit);

    _logger.fine("Produced : ${sink.toString()}");

    await buildStep.writeAsString(destId, sink.toString());
  }
}

class Dart2TsVisitor extends GeneralizingAstVisitor<dynamic> {
  StringSink _consumer;
  Dart2TsVisitor(this._consumer);

  @override
  visitCompilationUnit(CompilationUnit node) {
    _consumer.writeln("import {print} from 'dart_sdk/core.ts';");
    _consumer.writeln('// Generated code');
    super.visitCompilationUnit(node);
  }

  @override
  visitFunctionDeclaration(FunctionDeclaration node) {
    _consumer.write("function ${node.name}");
    node.functionExpression.parameters.accept(this);
    _consumer.write(" : ");
    node.returnType.accept(this);
    node.functionExpression.body.accept(this);
  }

  @override
  visitFunctionBody(FunctionBody node) {
    _consumer.writeln('{');
    super.visitFunctionBody(node);
    _consumer.writeln('}');
  }

  @override
  visitFormalParameterList(FormalParameterList node) {
    String x = '(';
    node.parameters.forEach((expr) {
      _consumer.write(x);
      _consumer.write(expr.identifier.name);
      _consumer.write(' : ');
      expr.accept(this);
      x = ',';
    });
    _consumer.write(')');
  }

  @override
  visitArgumentList(ArgumentList node) {
    _actualParameterVisitor v = new _actualParameterVisitor();
    _consumer.write("(${node.arguments.map((e)=>e.accept(v)).join(',')})");
  }

  @override
  visitMethodInvocation(MethodInvocation node) {
    _consumer.write(node.methodName.name);
    super.visitMethodInvocation(node);
  }

  @override
  visitBlockFunctionBody(BlockFunctionBody node) {
    _consumer.writeln('{');
    node.block.statements.forEach((s) {
      s.accept(this);
      _consumer.writeln(';');
    });
    _consumer.writeln(('}'));
  }

  @override
  visitInvocationExpression(InvocationExpression node) {
    //_consumer.write("/*${node.runtimeType}*/");
    super.visitInvocationExpression(node);
  }

  @override
  visitTypeAnnotation(TypeAnnotation node) {
    super.visitTypeAnnotation(node);
    DartType t = node.type;
    if (t is TypeParameterType) {
      _consumer.write("IS PARAMETER");
    }
  }

  @override
  visitTypeName(TypeName node) {
    _consumer.write(toTsType(node));
  }
}

class _actualParameterVisitor extends GeneralizingAstVisitor<String> {
  @override
  String visitSimpleStringLiteral(SimpleStringLiteral node) {
    return node.literal.toString();
  }

  @override
  String visitSimpleIdentifier(SimpleIdentifier node) {
    return node.name;
  }
}

class _typeNameVisitor extends GeneralizingAstVisitor<String> {
  @override
  String visitTypeName(TypeName node) {
    return toTsType(node);
  }

  @override
  String visitTypeAnnotation(TypeAnnotation node) {
    return super.visitTypeAnnotation(node);
  }
}

class _typeArgumentListVisitor extends GeneralizingAstVisitor<String> {
  @override
  String visitTypeArgumentList(TypeArgumentList node) {
    if (node?.arguments == null) {
      return "";
    }
    _typeNameVisitor v = new _typeNameVisitor();
    return "<${node.arguments.map((x)=> x.accept(v)).join(',')}>";
  }
}

String toTsType(TypeName annotation) {
  // Todo : check it better if it's a  list
  String actualName;
  if (annotation.name.name == 'List') {
    actualName = 'Array';
  } else {
    actualName = annotation.name.name;
  }
  String res =
      "${actualName}${annotation.typeArguments?.accept(new _typeArgumentListVisitor())??''}";
  return res;
}
