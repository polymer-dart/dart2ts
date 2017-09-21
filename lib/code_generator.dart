import 'dart:async';

import 'package:analyzer/analyzer.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/src/dart/ast/ast.dart';
import 'package:args/command_runner.dart';
import 'package:build/build.dart';
import 'package:build_runner/build_runner.dart';
import 'package:dart2ts/overrides.dart';
import 'package:dart2ts/utils.dart';
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
  visitTopLevelVariableDeclaration(TopLevelVariableDeclaration node) {
    _consumer.writeln(node.accept(_expressionBuilderVisitor));
  }

  @override
  visitClassDeclaration(ClassDeclaration node) {
    _consumer.writeln(node.accept(new _ClassBuilderVisitor(this)));
  }
}

class ConstructorBuilder {
  final ConstructorDeclaration declaration;

  //final String symName;
  final bool isDefault;
  _ConstructorMethodBuilderVisitor _visitor;
  _ClassBuilderVisitor _classBuilderVisitor;

  ConstructorBuilder(this.declaration, this._classBuilderVisitor)
      : isDefault = declaration.element.isDefaultConstructor {
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

  static String accessorFor(ConstructorElement cons) =>
      cons.isDefaultConstructor ? '[bare.init]' : ".${cons.name}";

  static String interfaceNameFor(ConstructorElement cons) =>
      "${cons.enclosingElement.name}.constructors.${cons.name}";

  String get symName => symbolFor(declaration.element);

  String get accessor => accessorFor(declaration.element);

  String signature() {
    return "${parameters()} => void";
  }

  String parameters() {
    return declaration.parameters.accept(_visitor);
  }

  String defineNamedConstructor() {
    return "static get ${declaration.element.name}() : ${interfaceName()} {\n"
        "return bare.namedConstructor(${declaration.element.enclosingElement.name},'${declaration.element.name}');\n"
        /*"return ${declaration.element.enclosingElement.name}.named('${declaration.element.name}');\n"*/
        "}";
  }

  String constructorInterface() {
    return "export interface ${declaration.element.name} {\n"
        " new ${parameters()}: ${declaration.element.enclosingElement.name};\n"
        "}";
  }

  String interfaceName() => interfaceNameFor(declaration.element);
}

class _ConstructorMethodBuilderVisitor extends _FunctionExpressionVisitor {
  ConstructorBuilder _builder;

  _ConstructorMethodBuilderVisitor(
      _ClassBuilderVisitor _classBuilderVisitor, this._builder)
      : super(_classBuilderVisitor._parentVisitor._context) {}

  String buildMethod() {
    String name = _builder.isDefault
        ? "[${_builder.symName}]"
        : _builder.declaration.element.name;
    return "${name}${_builder.declaration.parameters.accept(this)}${_builder.declaration.body.accept(this)}";
  }

  String _initializers() {
    // TODO : call super class default if no super initializers
    return "${_builder.declaration.initializers.map((c) => c.accept(this)).join('\n')}";
  }

  @override
  String visitRedirectingConstructorInvocation(
      RedirectingConstructorInvocation node) {
    return "/* TODO : REDIR constructor */";
  }

  @override
  String visitConstructorFieldInitializer(ConstructorFieldInitializer node) {
    return "/* TODO: FIELD field initializer */";
  }

  @override
  String visitSuperConstructorInvocation(SuperConstructorInvocation node) {
    return "super${ConstructorBuilder.accessorFor(node.staticElement)}${node.argumentList.accept(this)};";
  }

  @override
  String _blockPreamble() {
    return "${super._blockPreamble()}${_initializers()}";
  }
}

class _ClassBuilderVisitor extends _ExpressionBuilderVisitor {
  Dart2TsVisitor _parentVisitor;
  List<ConstructorBuilder> constructors = [];

  _ClassBuilderVisitor(this._parentVisitor) : super(_parentVisitor._context);

  @override
  String visitClassDeclaration(ClassDeclaration node) {
    // TODO : need a strategy for "named" constructor and "factory"
    // probably we end up in static factory methods or to a constructor with and added parameter

    if (node.element.metadata.any((e)=>e.isJS)) {
      return "/* external class ${node.name} */";
    }


    String members = node.members.map((m) => m.accept(this)).join('\n');

    String namedConstructors = _namedConstructors();

    String superCall;

    if (node.extendsClause != null) {
      superCall =
          "super(...args);\nsuper[bare.init] || this[bare.init](...args);\n";
    } else {
      superCall = "this[bare.init](...args);\n";
    }

    ConstructorBuilder constructorBuilder =
        constructors.firstWhere((b) => b.isDefault, orElse: () => null);
    String extra;
    if (constructorBuilder != null) {
      extra = "constructor${constructorBuilder.parameters()};\n";
    } else {
      extra = "constructor();\n";
    }

    return "export namespace ${node.name.name} {\n"
        "export namespace constructors {\n"
        "${_namedInterfaces()}"
        "\n}\n}\nexport class ${node.name.name}${node.extendsClause?.accept(this) ?? ''} {\n"
        "${extra}"
        "constructor(...args){\n"
        " ${superCall}"
        "}\n"
        "${namedConstructors}\n"
        "${members}"
        "}\n";
  }

  String _namedInterfaces() => constructors
      .where((c) => !c.isDefault)
      .map((c) => c.constructorInterface())
      .join("\n");

  @override
  String visitExtendsClause(ExtendsClause node) {
    return " extends ${toTsType(node.superclass.type)}";
  }

  String _namedConstructors() {
    return "${constructors.where((c) => !c.isDefault).map((c) => c.defineNamedConstructor()).join('\n')}";
  }


  @override
  String visitFieldDeclaration(FieldDeclaration node) {
    return "${node.staticKeyword??''} ${node.fields.variables.map((v)=>v.accept(this)).join(',')};";
  }

  // Override to avoid init at this level
  String visitVariableDeclaration(VariableDeclaration node) {
    // TODO : variable type
    return "${node.name.name}:${toTsType(node.element.type)}${node.initializer != null ? '= ${node.initializer.accept(this)}' : ''}";
  }




  @override
  String visitMethodDeclaration(MethodDeclaration node) {
    return new _FunctionExpressionVisitor(_parentVisitor._context)
        .buildMethodDeclaration(node);
  }

  @override
  String visitConstructorDeclaration(ConstructorDeclaration node) {
    ConstructorBuilder builder = new ConstructorBuilder(node, this);
    constructors.add(builder);
    return builder.buildMethod();
  }
}

class _NamedParameterCollector extends GeneralizingAstVisitor<dynamic> {
  Map<String, FormalParameter> _bag = {};
  List<FormalParameter> _ordinal;

  Map<String, FormalParameter> get named => _bag;

  List<SimpleFormalParameter> get ordinal => _ordinal;

  @override
  visitFormalParameterList(FormalParameterList node) {
    _bag = {};
    _ordinal = [];
    super.visitFormalParameterList(node);
  }

  @override
  visitFormalParameter(FormalParameter node) {
    if (node.kind == ParameterKind.NAMED) {
      _bag[node.identifier.name] = node;
    } else {
      _ordinal.add(node);
    }
  }
}

class _FunctionExpressionVisitor extends _ExpressionBuilderVisitor {
  _FunctionExpressionVisitor(FileContext context) : super(context);

  String buildFunction(FunctionExpression node) {
    return "${node.element.name}${node.parameters.accept(this)} => ${node.body.accept(this)}";
  }

  @override
  String visitFormalParameter(FormalParameter node) {
    return "${node.identifier}${node.kind.isOptional ? '?' : ''} : ${toTsType(node.element.type)}";
  }

  _NamedParameterCollector _namedParameters;

  @override
  String visitFormalParameterList(FormalParameterList node) {
    // Create the named optional parameter
    _namedParameters = new _NamedParameterCollector();
    node.accept(_namedParameters);

    // All parameters
    Iterable<String> decls = (() sync* {
      yield* _namedParameters.ordinal.map((f) => f.accept(this));
      if (_namedParameters.named.isNotEmpty) {
        yield "__namedParameters__? : {${_namedParameters.named.values.map((f) => "${f.identifier}?:${toTsType(f.element.type)}").join(',')}}";
      }
    })();

    // Join and return
    return "(${decls.join(',')})";
  }

  String buildFunctionDeclaration(FunctionDeclaration node) {
    String res;

    if (node.externalKeyword!=null) {
      return "/** EXTERNAL ${node.name} */";
    }


    res =
        "function ${node.functionExpression.element?.name ?? ''}${node.functionExpression.parameters.accept(this)}${node.functionExpression.body.accept(this)}";

    return _context.export(res, node.element);
  }






  String buildMethodDeclaration(MethodDeclaration node) {

    if (node.isGetter) {
      return "get ${node.name}() : ${toTsType(node.element.returnType)}${node.body.accept(this)}";
    } else if(node.isSetter) {
      return "set ${node.name}${node.parameters.accept(this)}${node.body.accept(this)}";
    } else {
      return "${node.name.name}${node.parameters.accept(this)}${node.body.accept(this)}";
    }
  }

  @override
  String _blockPreamble() {
    String namedArgs;
    if (_namedParameters?.named?.isNotEmpty??false) {
      String defaults = _namedParameters.named.values.map((p) {
        if (p is DefaultFormalParameter) {
          return "${p.identifier} : ${p.defaultValue?.accept(this) ?? 'null'}";
        } else {
          return "${p.identifier} : null";
        }
      }).join(',');
      namedArgs =
          "let {${_namedParameters.named.keys.join(',')}} = Object.assign({${defaults}},__namedParameters__);\n";
    } else {
      namedArgs = "";
    }

    String defaults = _namedParameters?.ordinal
        ?.where((x) =>
            x.kind.isOptional &&
            (x is DefaultFormalParameter) &&
            x.defaultValue != null)
        ?.map((d) => d as DefaultFormalParameter)
        ?.map((d) =>
            '${d.identifier} = ${d.identifier} || ${d.defaultValue.accept(this)};\n')
        ?.join()??'' ;

    return "${namedArgs}"
        "${defaults}\n/* BODY */";
  }
}

class _ExpressionBuilderVisitor extends GeneralizingAstVisitor<String> {
  _ExpressionBuilderVisitor(this._context);

  @override
  String visitFunctionDeclaration(FunctionDeclaration node) {
    return new _FunctionExpressionVisitor(_context)
        .buildFunctionDeclaration(node);
  }

  @override
  String visitCascadeExpression(CascadeExpression node) {
    return "(((_) => {${node.cascadeSections.map((e)=>"_.${e.accept(this)};").join('\n')}\nreturn _;})(${node.target.accept(this)}))";
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
    if ((node.staticElement is FieldElement || node.staticElement is PropertyAccessorElement) && node.parent is!PrefixedIdentifier && node.staticElement.enclosingElement is! CompilationUnitElement) {
      return "this.${node.name}";
    }
    return node.name;
  }

  @override
  String visitTopLevelVariableDeclaration(TopLevelVariableDeclaration node) {

    return node.variables.variables.map((v) {
      if (v.element.metadata?.any((a)=>a.isJS)??false) {
        return "/* external var ${node.variables}*/";
      }

      return "export let ${v.accept(this)};";
    }).join('\n');



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
    if (ele.library == from.library || ele.kind==ElementKind.CLASS&& ele.library.isInSdk) {
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
    return "${node.name.name}:${_prefixFor(node.element.type.element,from:node.element)}${toTsType(node.element.type)}${node.initializer != null ? '= ${node.initializer.accept(this)}' : ''}";
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
      return "new ${p}${node.staticElement.enclosingElement.name}${ConstructorBuilder.accessorFor(node.staticElement)}${node.argumentList.accept(this)}";
    }
  }

  @override
  String visitMethodInvocation(MethodInvocation node) {
    Expression t = node.target;
    String reference;

    String target;
    String name;

    if (t == null ||
        (t is SimpleIdentifier && t.staticElement is PrefixElement)) {
      // get the function name for ts
      Element el = _findEnclosingScope(node);
      target = null;

      if (node.isCascaded) {
        name = node.methodName.name;
      } else {
        name = _resolve(node.methodName.staticElement, from: el);
      }
    } else {
      target = t.accept(this);
      name = node.methodName.name;
    }

    if (t == null &&
        node.realTarget == null &&
        (node.methodName.staticElement is MethodElement)) {
      target = "this";
    }

    // check for interceptors
    MethodInterceptor interceptor = lookupInterceptor(node);

    String arguments = node.argumentList.accept(this);
    if (interceptor != null) {
      return interceptor.build(node, target, name, arguments);
    } else {
      reference = "${target != null ? '${target}.' : ''}${name}";

      return "${reference}${arguments}";
    }
  }


  @override
  String visitPrefixedIdentifier(PrefixedIdentifier node) {
    if (node.prefix.staticElement is PrefixElement) {
      return "${_prefixFor(node.prefix.staticElement,from:node.identifier.staticElement)}${node.identifier}";
    }

    // Is this a property access instead ?
    AccessorInterceptor interceptor = node.parent is! AssignmentExpression
        ? lookupAccessorInterceptor(node.identifier.staticElement)
        : null;

    if (interceptor != null) {
      return interceptor.buildRead(node.identifier.staticElement, node.prefix.accept(this), node.identifier.name);
    } else {
      return "${node.prefix.accept(this)}.${node.identifier.accept(this)}";
    }

  }

  @override
  String visitPropertyAccess(PropertyAccess node) {
    Expression t = node.target;
    String reference;

    String target;
    String name;

    if (t == null) {
      target = null;
    } else {
      target = t.accept(this);
    }
    name = node.propertyName.name;

    if (t == null &&
        node.realTarget == null &&
        (node.propertyName.staticElement is FieldElement || node.propertyName.staticElement is PropertyAccessorElement)) {
      target = "this";
    }

    // check for interceptors
    AccessorInterceptor interceptor = node.parent is! AssignmentExpression
        ? lookupAccessorInterceptorFromAccess(node)
        : null;

    if (interceptor != null) {
      return interceptor.buildRead(node.propertyName.staticElement, target, name);
    } else {
      reference = "${target != null ? '${target}.' : ''}${name}";

      return "${reference}";
    }
  }


  @override
  String visitThisExpression(ThisExpression node) {
    return "this";
  }

  @override
  String visitConditionalExpression(ConditionalExpression node) {
    return "${node.condition.accept(this)}?${node.thenExpression.accept(this)}:${node.elseExpression.accept(this)}";
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

  bool canReturn(Element e) {
    return !(e is MethodElement && (e.returnType.isVoid) || e is PropertyAccessorElement && e.isSetter);
  }


  @override
  String visitEmptyFunctionBody(EmptyFunctionBody node) {
    return ";";
  }

  @override
  String visitExpressionFunctionBody(ExpressionFunctionBody node) =>
      "{ ${_blockPreamble()}${canReturn((node.parent as dynamic).element)?'return ':''}${node.expression.accept(this)}; }";

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
    List<Expression> normalPars = [];
    List<NamedExpression> namedPars = [];

    node.arguments.forEach((e) {
      if (e is NamedExpression) {
        namedPars.add(e);
      } else {
        normalPars.add(e);
      }
    });

    Iterable<String> args = (() sync* {
      yield* normalPars.map((e) => e.accept(this));
      if (namedPars.isNotEmpty) {
        yield "{${namedPars.map((n)=>n.accept(this)).join(',')}}";
      }
    })();

    return "(${args.join(',')})";
  }

  @override
  String visitNamedExpression(NamedExpression node) {
    return "${node.name.label} : ${node.expression.accept(this)}";
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
  if (isListType(type)) {
    actualName = "Array";
  } else if (type == type.element.context.typeProvider.numType ||
      type == type.element.context.typeProvider.intType) {
    actualName = 'number';
  } else if (type == type.element.context.typeProvider.stringType) {
    actualName = 'string';
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
    '#NOURI#': new TSImport(prefix: 'bare', path: 'dart_sdk/bare')
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
            path: "dart_sdk/${lib.name.substring(5)}",
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
