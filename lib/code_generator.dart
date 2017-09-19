import 'dart:async';

import 'package:analyzer/analyzer.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:args/command_runner.dart';
import 'package:build/build.dart';
import 'package:build_runner/build_runner.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:source_gen/source_gen.dart';

Logger _logger = new Logger('dart2ts.lib.code_generator');

class Dart2TsCommand extends Command<bool> {
  @override
  String get description => "Build a file";

  @override
  String get name => 'build';

  Dart2TsCommand() {
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
      new BuildAction(new Dart2TsBuilder(), graph.root.name)
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
  FileContext _context;

  Dart2TsVisitor(this._consumer);

  _ExpressionBuilderVisitor _expressionBuilderVisitor;

  @override
  visitCompilationUnit(CompilationUnit node) {
    _context = new FileContext(node.element.library);
    _expressionBuilderVisitor = new _ExpressionBuilderVisitor(_context);
    _consumer.writeln('// Generated code');
    super.visitCompilationUnit(node);
    _context._prefixes.values.forEach(
        (i) => _consumer.writeln('import * as ${i.prefix} from "${i.path}";'));
  }

  @override
  visitFunctionDeclaration(FunctionDeclaration node) {
    _consumer.writeln(node.accept(_expressionBuilderVisitor));
  }

  @override
  visitClassDeclaration(ClassDeclaration node) {
    _consumer.writeln(node.accept(new _ClassBuilderVisitor(this)));
  }
}

class ConstructorBuilder {
  final ConstructorDeclaration declaration;
  final String symName;
  final bool isDefault;
  _ConstructorMethodBuilderVisitor _visitor;
  _ClassBuilderVisitor _classBuilderVisitor;

  ConstructorBuilder(this.declaration, this._classBuilderVisitor)
      : isDefault = declaration.element.isDefaultConstructor,
        symName = symbolFor(declaration.element) {
    _visitor = new _ConstructorMethodBuilderVisitor(_classBuilderVisitor, this);
  }

  /**
   * Builds the instance method that will init the class
   */
  String buildMethod() {
    return _visitor.buildMethod();
  }

  static String symbolFor(ConstructorElement cons) => cons.isDefaultConstructor
      ? 'bare.init'
      : "${cons.enclosingElement.name}_${cons.name}";

  String buildSymbolDeclaration() => "export let ${symName}:symbol = Symbol();";

  String defineNamedConstructor() {
    return "bare.defineNamedConstructor(${declaration.element.enclosingElement.name},${symName});";
  }
}

class _ConstructorMethodBuilderVisitor extends _ClassBuilderVisitor {
  ConstructorBuilder _builder;
  _FunctionExpressionVisitor _functionExpressionVisitor;

  _ConstructorMethodBuilderVisitor(
      _ClassBuilderVisitor _classBuilderVisitor, this._builder)
      : super(_classBuilderVisitor._parentVisitor) {
    _functionExpressionVisitor = new _FunctionExpressionVisitor(_classBuilderVisitor._parentVisitor._context);
  }

  @override
  String visitFormalParameterList(FormalParameterList node) {
    return node.accept(_functionExpressionVisitor);
  }

  String buildMethod() {

    return "private [${_builder.symName}]${_builder.declaration.parameters.accept(this)}${_builder.declaration.body.accept(this)}";
  }

  @override
  String visitExpressionFunctionBody(ExpressionFunctionBody node) {
    return "{ ${_initializers()}return ${node.expression.accept(_functionExpressionVisitor)};}";
  }

  String _initializers() {
    // TODO : call super class default if no super initializers
    return "${_functionExpressionVisitor._blockPreamble()}${_builder.declaration.initializers.map((c) => c.accept(this)).join('\n')}";
  }

  @override
  String visitRedirectingConstructorInvocation(
      RedirectingConstructorInvocation node) {
    return "REDIR";
  }

  @override
  String visitConstructorFieldInitializer(ConstructorFieldInitializer node) {
    return "FIELD";
  }

  @override
  String visitSuperConstructorInvocation(SuperConstructorInvocation node) {
    return "super[${ConstructorBuilder.symbolFor(node.staticElement)}]${node.argumentList.accept(_functionExpressionVisitor)};";
  }

  @override
  String visitBlockFunctionBody(BlockFunctionBody node) {
    return "{ ${_initializers()}${node.block.statements.map((s) => s.accept(_functionExpressionVisitor)).join('\n')}}";
  }
}

class _ClassBuilderVisitor extends GeneralizingAstVisitor<String> {
  Dart2TsVisitor _parentVisitor;
  List<ConstructorBuilder> constructors = [];

  _ClassBuilderVisitor(this._parentVisitor);

  @override
  String visitClassDeclaration(ClassDeclaration node) {
    // TODO : need a strategy for "named" constructor and "factory"
    // probably we end up in static factory methods or to a constructor with and added parameter

    String members = node.members.map((m) => m.accept(this)).join('\n');

    String namedConstructors = _namedConstructors();
    return "${_constructorSymbols()}\n"
        "export class ${node.name.name}${node.extendsClause?.accept(this) ?? ' extends bare.Object'} {\n"
        "${members}"
        "}\n"
        "${namedConstructors}";
  }

  @override
  String visitExtendsClause(ExtendsClause node) {
    return " extends ${toTsType(node.superclass.type)}";
  }

  String _namedConstructors() {
    return "${constructors.where((c) => !c.isDefault).map((c) => c.defineNamedConstructor()).join('\n')}";
  }

  String _constructorSymbols() {
    return "${constructors.where((b) => !b.isDefault).map((b) => b.buildSymbolDeclaration()).join('\n')}";
  }

  @override
  String visitMethodDeclaration(MethodDeclaration node) {
    return new _FunctionExpressionVisitor(_parentVisitor._context).buildMethodDeclaration(node);
  }

  @override
  String visitConstructorDeclaration(ConstructorDeclaration node) {
    ConstructorBuilder builder = new ConstructorBuilder(node, this);
    constructors.add(builder);
    return builder.buildMethod();
  }

}

class _FunctionExpressionVisitor extends _ExpressionBuilderVisitor {
  _FunctionExpressionVisitor(FileContext context) : super(context);

  String buildFunction(FunctionExpression node) {
    return "${node.element.name}${node.parameters.accept(this)} => ${node.body.accept(this)}";
  }

  @override
  String visitSimpleFormalParameter(SimpleFormalParameter node) =>
      "${node.identifier} : ${toTsType(node.element.type)}";

  @override
  String visitFormalParameterList(FormalParameterList node) {
    return "(${node.parameters.map((p) => p.accept(this)).join(',')})";
  }

  String buildFunctionDeclaration(FunctionDeclaration node) {
    String res;

    res =
    "function ${node.functionExpression.element?.name ?? ''}${node.functionExpression.parameters.accept(this)}${node.functionExpression.body.accept(this)}";

    return _context.export(res, node.element);
  }

  String buildMethodDeclaration(MethodDeclaration node) {
    return "${node.name.name}${node.parameters.accept(this)}${node.body.accept(this)}";
  }

  @override
  String _blockPreamble() {
    return "/* BLOCK PREAMBLE */";
  }


}

class _ExpressionBuilderVisitor extends GeneralizingAstVisitor<String> {
  _ExpressionBuilderVisitor(this._context);

  @override
  String visitFunctionDeclaration(FunctionDeclaration node) {
    return new _FunctionExpressionVisitor(_context).buildFunctionDeclaration(node);
  }

  @override
  String visitFunctionDeclarationStatement(FunctionDeclarationStatement node) =>
      '${node.functionDeclaration.accept(this)}';

  @override
  String visitSimpleStringLiteral(SimpleStringLiteral node) {
    return node.literal.toString();
  }

  @override
  String visitSimpleIdentifier(SimpleIdentifier node) {
    return node.name;
  }

  @override
  String visitFunctionExpression(FunctionExpression node) {
    return new _FunctionExpressionVisitor(_context).buildFunction(node);
  }

  Element _findEnclosingScope(AstNode node) {
    if (node is FunctionExpression) {
      return node.element;
    }
    if (node is MethodDeclaration) {
      return node.element;
    }

    if (node is ConstructorDeclaration) {
      return node.element;
    }

    return _findEnclosingScope(node.parent);
  }

  FileContext _context;

  String _resolve(Element ele, {Element from}) {
    return "${_prefixFor(ele, from: from)}${ele.name}";
  }

  String _prefixFor(Element ele, {Element from}) {
    if (ele.library == from.library) {
      return "";
    }

    return "${_context.namespace(ele.library)}.";
  }

  @override
  String visitBinaryExpression(BinaryExpression node) {
    return "${node.leftOperand.accept(this)}${node.operator}${node.rightOperand.accept(this)}";
  }

  @override
  String visitVariableDeclaration(VariableDeclaration node) {
    // TODO : variable type
    return "${node.name.name}${node.initializer != null ? '= ${node.initializer.accept(this)}' : ''}";
  }

  @override
  String visitVariableDeclarationStatement(VariableDeclarationStatement node) {
    return "${node.variables.accept(this)};";
  }

  @override
  String visitInstanceCreationExpression(InstanceCreationExpression node) {
    Element el = _findEnclosingScope(node);
    // TODO : handle named constructors, factory "constructors"
    // (and initializers, etc.)

    if (node.staticElement.isDefaultConstructor) {
      return "new ${_resolve(node.staticElement.enclosingElement, from: el)}${node.argumentList.accept(this)}";
    } else {
      // Calling named constructors
      String p = _prefixFor(node.staticElement.enclosingElement, from: el);
      return "new ${p}${node.staticElement.enclosingElement.name}[${p}${ConstructorBuilder.symbolFor(node.staticElement)}]${node.argumentList.accept(this)}";
    }
  }

  @override
  String visitMethodInvocation(MethodInvocation node) {
    Expression t = node.realTarget;
    String reference;

    if (t == null ||
        (t is SimpleIdentifier && t.staticElement is PrefixElement)) {
      // get the function name for ts
      Element el = _findEnclosingScope(node);

      reference = _resolve(node.methodName.staticElement, from: el);
    } else {
      reference = "${t.accept(this)}.${node.methodName}";
    }

    return "${reference}${node.argumentList.accept(this)}";
  }

  @override
  String visitVariableDeclarationList(VariableDeclarationList node) {
    return "let ${node.variables.map((v) => v.accept(this)).join(',')}";
  }

  @override
  String visitReturnStatement(ReturnStatement node) =>
      "return ${node.expression.accept(this)};";


  @override
  String visitExpressionStatement(ExpressionStatement node) =>
      "${node.expression.accept(this)};";

  @override
  String visitBlock(Block node) =>
      "{${_blockPreamble()}${node.statements.map((s) => s.accept(this)).join('\n')}}";

  String _blockPreamble() => "";

  @override
  String visitExpressionFunctionBody(ExpressionFunctionBody node) =>
      "{ ${_blockPreamble()}return ${node.expression.accept(this)}; }";

  @override
  String visitBlockFunctionBody(BlockFunctionBody node) =>
      node.block.accept(this);


  @override
  String visitTypeName(TypeName node) => toTsType(node.type);

  @override
  String visitParenthesizedExpression(ParenthesizedExpression node) =>
      "${node.leftParenthesis}${node.expression.accept(this)}${node.rightParenthesis}";

  @override
  String visitAssignmentExpression(AssignmentExpression node) =>
      "${node.leftHandSide.accept(this)} = ${node.rightHandSide.accept(this)}";

  @override
  String visitIndexExpression(IndexExpression node) {
    return "${node.realTarget.accept(this)}[${node.index.accept(this)}]";
  }

  @override
  String visitListLiteral(ListLiteral node) {
    return "[${node.elements.map((x) => x.accept(this)).join(',')}]";
  }

  @override
  String visitLiteral(Literal node) {
    return "${node}";
  }

  @override
  String visitFunctionExpressionInvocation(FunctionExpressionInvocation node) {
    return "${node.function.accept(this)} ${node.argumentList.accept(this)}";
  }

  @override
  String visitArgumentList(ArgumentList node) {
    return "(${node.arguments.map((e) => e.accept(this)).join(',')})";
  }

  @override
  String visitStringInterpolation(StringInterpolation node) =>
      "`${node.elements.map((e) => e.accept(this)).join()}`";

  @override
  String visitInterpolationExpression(InterpolationExpression node) =>
      "\${${node.expression.accept(this)}}";

  @override
  String visitInterpolationString(InterpolationString node) => node.value;
}

String toTsType(DartType type) {
  if (type.isDynamic) {
    return "any";
  }

  String actualName;
  if ((type is ParameterizedType) &&
      type.typeArguments.length == 1 &&
      type.isSubtypeOf(type.element.context.typeProvider.listType
          .instantiate([type.typeArguments.single]))) {
    actualName = "Array";
  } else {
    actualName = type.name;
  }
  if (type is ParameterizedType && type.typeArguments.isNotEmpty) {
    return "${actualName}<${type.typeArguments.map((t) => toTsType(t)).join(',')}>";
  } else {
    return actualName;
  }
}

class TSImport {
  String prefix;
  String path;
  LibraryElement library;

  TSImport({this.prefix, this.path, this.library});
}

class FileContext {
  LibraryElement _current;

  FileContext(this._current);

  Map<String, TSImport> _prefixes = {
    '#NOURI#': new TSImport(prefix: 'bare', path: './dart_sdk/bare')
  };

  String _nextPrefix() => "lib${_prefixes.length}";

  AssetId _toAssetId(String uri) {
    if (uri.startsWith('asset:')) {
      List<String> parts = path.split(uri.substring(7));
      return new AssetId(parts.first, path.joinAll(parts.sublist(1)));
    }
    throw "Cannot convert to assetId : ${uri}";
  }

  String namespace(LibraryElement lib) {
    String uri = lib.source.uri.toString();

    AssetId currentId = _toAssetId(_current.source.uri.toString());
    return _prefixes.putIfAbsent(uri, () {
      if (_current.context.sourceFactory.dartSdk.uris.contains(uri)) {
        // Replace with ts_sdk
        return new TSImport(
            prefix: _nextPrefix(),
            path: "./dart_sdk/${lib.name.substring(5)}",
            library: lib);
      }

      // TODO : If same package produce a relative path

      AssetId id = _toAssetId(uri);

      String libPath;

      if (id.package == currentId.package) {
        libPath =
            "./${path.withoutExtension(path.relative(id.path, from: path.dirname(currentId.path)))}";
      }

      // TODO : Extract package name and path and produce a nodemodule path
      return new TSImport(prefix: _nextPrefix(), path: libPath, library: lib);
    }).prefix;
  }

  String export(String res, Element e) {
    if (e.enclosingElement == _current.definingCompilationUnit) {
      return 'export ${res}';
    }
    return res;
  }
}
