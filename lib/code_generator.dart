import 'dart:async';

import 'package:analyzer/analyzer.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/src/generated/resolver.dart';
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
    Dart2TsVisitor visitor = new Dart2TsVisitor();
    await buildStep.writeAsString(destId, library.unit.accept(visitor));
  }
}

class Dart2TsVisitor extends GeneralizingAstVisitor<String> {
  _ExpressionBuilderVisitor _visitor;

  @override
  visitCompilationUnit(CompilationUnit node) {
    _visitor =
        new _ExpressionBuilderVisitor(new FileContext(node.element.library));
    return "// Generated code\n"
        "${node.declarations.map((d)=>d.accept(this)).join('\n')}"
        "${_visitor._context._prefixes.values.map((i)=>'import * as ${i.prefix} from "${i.path}";').join('\n')}";
  }

  @override
  String visitTopLevelVariableDeclaration(TopLevelVariableDeclaration node) =>
      node.accept(_visitor);

  @override
  String visitClassDeclaration(ClassDeclaration node) =>
      node.accept(new _ClassBuilderVisitor(this));

  @override
  String visitFunctionDeclaration(FunctionDeclaration node) =>
      node.accept(_visitor);
}

class _ConstructorMethodBuilderVisitor extends _FunctionExpressionVisitor {
  final ConstructorDeclaration declaration;

  //final String symName;
  final bool isDefault;
  _ClassBuilderVisitor _classBuilderVisitor;

  /**
   * Builds the instance method that will init the class
   */

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
    return declaration.parameters.accept(this);
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

  _ConstructorMethodBuilderVisitor(
      _ClassBuilderVisitor _classBuilderVisitor, this.declaration)
      : super(_classBuilderVisitor._parentVisitor._visitor._context),
        isDefault = declaration.element.isDefaultConstructor {}

  String buildMethod() {
    String name = isDefault ? "[${symName}]" : declaration.element.name;
    return "${name}${declaration.parameters.accept(this)}${declaration.body.accept(this)}";
  }

  String _initializers() {
    // TODO : call super class default if no super initializers
    return "${declaration.initializers.map((c) => c.accept(this)).join('\n')}";
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
    return "super${_ConstructorMethodBuilderVisitor.accessorFor(node.staticElement)}${node.argumentList.accept(this)};";
  }

  @override
  String _blockPreamble() {
    return "${super._blockPreamble()}${_initializers()}";
  }
}

class _ClassBuilderVisitor extends _ExpressionBuilderVisitor {
  Dart2TsVisitor _parentVisitor;
  List<_ConstructorMethodBuilderVisitor> constructors = [];

  _ClassBuilderVisitor(this._parentVisitor)
      : super(_parentVisitor._visitor._context);

  @override
  String visitClassDeclaration(ClassDeclaration node) {
    // TODO : need a strategy for "named" constructor and "factory"
    // probably we end up in static factory methods or to a constructor with and added parameter

    if (node.element.metadata.any((e) => e.isJS)) {
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

    _ConstructorMethodBuilderVisitor constructorBuilder =
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
        "\n}\n}\nexport class ${node.name.name}${node.typeParameters?.accept(this) ?? ''}${node.extendsClause?.accept(this) ?? ''} {\n"
        "${extra}"
        "constructor(...args){\n"
        " ${superCall}"
        "}\n"
        "${namedConstructors}\n"
        "${members}"
        "}\n";
  }

  @override
  String visitTypeParameterList(TypeParameterList node) {
    return "<${node.typeParameters.map((tp) => tp.accept(this)).join(',')}>";
  }

  @override
  String visitTypeParameter(TypeParameter node) {
    String e;
    if (node.extendsKeyword != null) {
      e = "extends ${toTsType(node.bound.type)}";
    } else {
      e = "";
    }
    return "${node.name.name}${e}";
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
    return "${node.staticKeyword ?? ''} ${node.fields.variables.map((v) => v.accept(this)).join(',')};";
  }

  // Override to avoid init at this level
  String visitVariableDeclaration(VariableDeclaration node) {
    // TODO : variable type
    return "${node.name.name}:${toTsType(node.element.type)}${node.initializer != null ? '= ${node.initializer.accept(this)}' : ''}";
  }

  @override
  String visitMethodDeclaration(MethodDeclaration node) {
    return new _FunctionExpressionVisitor(_parentVisitor._visitor._context)
        .buildMethodDeclaration(node);
  }

  @override
  String visitConstructorDeclaration(ConstructorDeclaration node) {
    _ConstructorMethodBuilderVisitor builder =
        new _ConstructorMethodBuilderVisitor(this, node);
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

    if (node.externalKeyword != null) {
      return "/** EXTERNAL ${node.name} */";
    }

    res =
        "function ${node.functionExpression.element?.name ?? ''}${node.functionExpression.typeParameters?.accept(this) ?? ''}${node.functionExpression.parameters.accept(this)}${node.functionExpression
        .body.accept(this)}";

    return _context.export(res, node.element);
  }

  @override
  String visitTypeParameterList(TypeParameterList node) {
    return "<${node.typeParameters.map((e) => e.accept(this)).join(',')}>";
  }

  @override
  String visitTypeParameter(TypeParameter node) {
    return toTsType((node.name.staticElement as TypeParameterElement).type);
  }

  String buildMethodDeclaration(MethodDeclaration node) {
    if (node.isGetter) {
      return "get ${node.name}() : ${toTsType(node.element.returnType)}${node.body.accept(this)}";
    } else if (node.isSetter) {
      return "set ${node.name}${node.parameters.accept(this)}${node.body.accept(this)}";
    } else {
      return "${node.name.name}${node.parameters.accept(this)}${node.body.accept(this)}";
    }
  }

  @override
  String visitEmptyFunctionBody(EmptyFunctionBody node) =>
      "{ ${_blockPreamble()}}";

  @override
  String _blockPreamble() {
    String namedArgs;
    if (_namedParameters?.named?.isNotEmpty ?? false) {
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
            ?.join() ??
        '';

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
  String visitIfStatement(IfStatement node) {
    _ExpressionBuilderVisitor inner = new _ExpressionBuilderVisitor(_context);
    return "if (${node.condition.accept(this)}) ${node.thenStatement.accept(inner)} ${node.elseStatement?.accept(inner)??''}";
  }

  @override
  String visitTryStatement(TryStatement node) {
    _ExpressionBuilderVisitor inner = new _ExpressionBuilderVisitor(_context);
    return "try ${node.body.accept(inner)} ${node.catchClauses?.map((c)=>c.accept(inner))?.join('\n')??''} ${_finally(node.finallyBlock?.accept(inner))}";
  }

  @override
  String visitCatchClause(CatchClause node) {
    String p = node.exceptionParameter != null
        ? "(${node.exceptionParameter.accept(this)})"
        : '';
    return "catch ${p} ${node.body.accept(this)}";
  }

  static String _finally(x) => x != null ? 'finally ${x}' : '';

  @override
  String visitDeclaredIdentifier(DeclaredIdentifier node) {
    if (node.isConst) {
      return "const ${node.identifier.name};";
    }
    return node.identifier.name;
  }

  String toTsType(DartType t, {bool noTypeArgs: false}) =>
      _context.toTsType(t, noTypeArgs: noTypeArgs);

  @override
  String visitCascadeExpression(CascadeExpression node) {
    return "(((_) => {${node.cascadeSections.map((e) => "_.${e.accept(this)};").join('\n')}\nreturn _;})(${node.target.accept(this)}))";
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
    AstNode p = node.parent;
    if (node.staticElement is ClassElement) {
      return toTsType((node.staticElement as ClassElement).type);
    }

    // Is actually ever happening ?
    if ((node.staticElement is VariableElement) &&
        getAnnotation(node.staticElement.metadata, isJS) != null) {
      return _context.toJSName(node.staticElement);
    }

    if ((node.staticElement is PropertyAccessorElement) &&
        getAnnotation(
                (node.staticElement as PropertyAccessorElement)
                    .variable
                    .metadata,
                isJS) !=
            null) {
      return _context
          .toJSName((node.staticElement as PropertyAccessorElement).variable);
    }

    if (node.token.previous?.type != TokenType.PERIOD) {
      return "${_checkImplicitThis(node)}${node.name}";
    }

    return node.name;
  }

  @override
  String visitTopLevelVariableDeclaration(TopLevelVariableDeclaration node) {
    return node.variables.variables.map((v) {
      if (v.element.metadata?.any((a) => a.isJS) ?? false) {
        return "/* external var ${v}*/";
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

    if (node is CompilationUnit) {
      return node.element;
    }

    return _findEnclosingScope(node.parent);
  }

  FileContext _context;

  String _resolve(Element ele, {Element from}) {
    return "${_prefixFor(ele, from: from)}${ele.name}";
  }

  String _prefixFor(Element ele, {Element from}) {
    if (ele.library == from.library ||
        ele.kind == ElementKind.CLASS && ele.library.name == 'dart.core') {
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

    return "${node.name.name}:${toTsType(node.element.type)}${node.initializer != null ? '= ${node.initializer.accept(this)}' : ''}";
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

    String p = _prefixFor(node.staticElement.enclosingElement, from: el);
    return translatorRegistry.newInstance(
        node.staticElement,
        "${toTsType(node.staticType,noTypeArgs: true)}",
        arguments(node.argumentList).toList());
  }

  @override
  String visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.staticElement == null) {
      String t = node.target != null ? "${node.target.accept(this)}." : '';
      return "${t}${node.methodName.name}${node.argumentList.accept(this)}";
    }

    if (node.methodName.staticElement is FunctionElement ||
        node.methodName.staticElement is! ExecutableElement) {
      //Invoke a function
      return "${_resolve(node.methodName.staticElement, from: _findEnclosingScope(node))}${node.typeArguments != null ? node.typeArguments.accept(this) : ''}${node.argumentList.accept(this)}";
    }

    ExecutableElement executableElement = node.methodName.staticElement;

    if (executableElement is MethodElement) {
      String target;
      if (node.isCascaded) {
        target = "";
      } else if (executableElement.isStatic) {
        target =
            toTsType(executableElement.enclosingElement.type, noTypeArgs: true);
      } else {
        target = node?.target?.accept(this) ?? 'this';
      }

      return translatorRegistry.invokeMethod(
          node.methodName.staticElement,
          target,
          "${_methodName(node.methodName.staticElement)}${node.typeArguments != null ? node.typeArguments.accept(this) : ''}",
          this.arguments(node.argumentList).toList());
    }

    throw "What else ?";
  }

  String _methodName(MethodElement method) {
    return method.name;
  }

  @override
  String visitPrefixedIdentifier(PrefixedIdentifier node) {
    if (node.prefix.staticElement is PrefixElement) {
      return "${_prefixFor(node.prefix.staticElement, from: node.identifier.staticElement)}${node.identifier}";
    }

    assert(node.identifier.staticElement == null ||
        node.identifier.staticElement is PropertyAccessorElement);

    PropertyAccessorElement accessor = node.identifier.staticElement;

    if (accessor == null && node.identifier.bestType != null) {
      // Try to get it from propagation
      accessor =
          findField(node.identifier.bestType.element, node.identifier.name)
              ?.getter;
    }

    assert(accessor == null ||
        accessor.isGetter); // Setter case should be handler by assignament

    String name = accessor != null
        ? _context.toJSName(accessor.variable, nopath: true)
        : node.identifier.name;

    return translatorRegistry.getProperty(
        node.prefix.bestType, accessor, node.prefix.accept(this), name);
  }

  @override
  String visitPropertyAccess(PropertyAccess node) {
    PropertyAccessorElement access = node.propertyName.staticElement;
    assert(access.isGetter); // Setter is handled in assignment

    String target = node?.target?.accept(this);

    return translatorRegistry.getProperty(node?.target?.bestType, access,
        target, _context.toJSName(access.variable, nopath: true));
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
    return !(e is MethodElement && (e.returnType.isVoid) ||
        e is PropertyAccessorElement && e.isSetter);
  }

  @override
  String visitEmptyFunctionBody(EmptyFunctionBody node) {
    return ";";
  }

  @override
  String visitExpressionFunctionBody(ExpressionFunctionBody node) =>
      "{ ${_blockPreamble()}${canReturn((node.parent as dynamic).element) ? 'return ' : ''}${node.expression.accept(this)}; }";

  @override
  String visitBlockFunctionBody(BlockFunctionBody node) =>
      node.block.accept(this);

  @override
  String visitTypeName(TypeName node) => toTsType(node.type);

  @override
  String visitParenthesizedExpression(ParenthesizedExpression node) =>
      "${node.leftParenthesis}${node.expression.accept(this)}${node.rightParenthesis}";

  @override
  String visitAssignmentExpression(AssignmentExpression node) {
    PropertyAccessorElement accessor;
    String target;
    DartType targetType;
    String fallbackName;
    if (node.leftHandSide is PropertyAccess) {
      PropertyAccess propertyAccess = node.leftHandSide;
      accessor = propertyAccess.propertyName.staticElement;

      target = propertyAccess?.target?.accept(this);
      targetType = propertyAccess?.target?.bestType;
      fallbackName = propertyAccess.propertyName.name;

      // if accessor is null (because static analysis couldn't determine it, try with type prop)
      if (accessor == null && targetType != null) {
        accessor = findField(targetType.element, fallbackName)?.setter;
      }
    } else if (node.leftHandSide is PrefixedIdentifier) {
      PrefixedIdentifier prefixedIdentifier = node.leftHandSide;
      accessor = prefixedIdentifier.identifier.staticElement;
      target = prefixedIdentifier.prefix.accept(this);
      targetType = prefixedIdentifier.prefix.bestType;

      fallbackName = prefixedIdentifier.identifier.name;

      // if accessor is null (because static analysis couldn't determine it, try with type prop)
      if (accessor == null && targetType != null) {
        accessor = findField(targetType.element, fallbackName)?.setter;
      }
    } else if (node.leftHandSide is IndexExpression) {
      IndexExpression indexExpression = node.leftHandSide;
      return translatorRegistry.indexSet(
          indexExpression.target.bestType,
          indexExpression.realTarget.accept(this),
          indexExpression.index.accept(this),
          node.rightHandSide.accept(this));
    } else {
      // normal assignament
      return "${node.leftHandSide.accept(this)} = ${node.rightHandSide.accept(this)}";
    }

    assert(accessor?.isSetter ?? true);

    String name = accessor != null
        ? _context.toJSName(accessor.variable, nopath: true)
        : fallbackName;

    return translatorRegistry.setProperty(
        targetType, accessor, target, name, node.rightHandSide.accept(this));
  }

  @override
  String visitIndexExpression(IndexExpression node) {
    assert(!node.inSetterContext());
    return translatorRegistry.indexGet(node.target.bestType,
        node.realTarget.accept(this), node.index.accept(this));
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
    return "(${node.function.accept(this)})${node.argumentList.accept(this)}";
  }

  Iterable<String> arguments(ArgumentList node) {
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
        yield "{${namedPars.map((n) => n.accept(this)).join(',')}}";
      }
    })();

    return args;
  }

  @override
  String visitArgumentList(ArgumentList node) =>
      "(${arguments(node).join(',')})";

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

  String _checkImplicitThis(SimpleIdentifier id) {
    if (id.staticElement is PropertyAccessorElement &&
        id.staticElement.enclosingElement.kind !=
            ElementKind.COMPILATION_UNIT) {
      PropertyAccessorElement el = id.staticElement;
      if (el.isStatic) {
        return toTsType((el.enclosingElement as ClassElement).type,
                noTypeArgs: true) +
            '.';
      }
      return "this.";
    }

    if (id.staticElement is MethodElement &&
        id.staticElement.enclosingElement.kind !=
            ElementKind.COMPILATION_UNIT) {
      MethodElement el = id.staticElement;
      if (el.isStatic) {
        return toTsType(el.enclosingElement.type, noTypeArgs: true) + '.';
      }
      return "this.";
    }

    if (id.staticElement is FieldElement) {
      FieldElement el = id.staticElement;
      if (el.isStatic) {
        return toTsType(el.enclosingElement.type, noTypeArgs: true) + '.';
      }
      return "this.";
    }

    return "";
  }
}

class TSImport {
  String prefix;
  String path;
  LibraryElement library;

  TSImport({this.prefix, this.path, this.library});
}

class JSPath {
  List<String> modulePathElements = [];
  List<String> namespacePathElements = [];

  String get moduleUri =>
      modulePathElements.isEmpty ? null : "module:${modulePath}";

  String get modulePath => modulePathElements.join('/');

  String get name => namespacePathElements.join('.');
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
      List<String> parts = path.split(uri.substring(6));
      return new AssetId(parts.first, path.joinAll(parts.sublist(1)));
    }
    throw "Cannot convert to assetId : ${uri}";
  }

/*
  String namespace(LibraryElement lib) {
    String uri = lib.source.uri.toString();

    AssetId currentId = _toAssetId(_current.source.uri.toString());
    return _prefixes.putIfAbsent(uri, () {
      if (lib.isInSdk) {
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
      } else {
        libPath = "${id.package}/${path.withoutExtension(id.path)}";
      }

      // TODO : Extract package name and path and produce a nodemodule path
      return new TSImport(prefix: _nextPrefix(), path: libPath, library: lib);
    }).prefix;
  }*/

  String namespace(LibraryElement lib) => namespaceFor(lib: lib);

  String namespaceFor({String uri, String modulePath, LibraryElement lib}) {
    uri ??= lib.source.uri.toString();

    return _prefixes.putIfAbsent(uri, () {
      if (lib == null) {
        return new TSImport(prefix: _nextPrefix(), path: modulePath);
      }
      if (lib.isInSdk) {
        // Replace with ts_sdk

        String name = lib.name.substring(5);

        return new TSImport(
            prefix: name, path: "dart_sdk/${name}", library: lib);
      }

      // TODO : If same package produce a relative path
      AssetId currentId = _toAssetId(_current.source.uri.toString());
      AssetId id = _toAssetId(uri);

      String libPath;

      if (id.package == currentId.package) {
        libPath =
            "./${path.withoutExtension(path.relative(id.path, from: path.dirname(currentId.path)))}";
      } else {
        libPath = "${id.package}/${path.withoutExtension(id.path)}";
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

  static final RegExp NAME_PATTERN = new RegExp('(([^#]+)#)?(.*)');

  JSPath _collectJSPath(Element start) {
    var collector = (Element e, JSPath p, var c) {
      if (e is! CompilationUnitElement) {
        c(e.enclosingElement, p, c);
      }

      // Collect if metadata
      String name =
          getAnnotation(e.metadata, isJS)?.getField('name')?.toStringValue();
      if (name != null && name.isNotEmpty) {
        Match m = NAME_PATTERN.matchAsPrefix(name);
        if (m != null && m[2] != null) {
          p.modulePathElements.add(m[2]);
          if ((m[3] ?? '').isNotEmpty) p.namespacePathElements.add(m[3]);
        } else {
          p.namespacePathElements.add(name);
        }
      } else if (e == start) {
        // Add name if it's the first
        p.namespacePathElements.add(e.name);
      }
    };

    JSPath p = new JSPath();
    collector(start, p, collector);
    return p;
  }

  static Set<DartType> nativeTypes(Element e) =>
      ((TypeProvider x) => new Set.from([
            x.boolType,
            x.stringType,
            x.intType,
            x.numType,
            x.doubleType,
            x.functionType,
          ]))(e.context.typeProvider);

  static Set<String> nativeClasses = new Set.from(['List', 'Map']);

  static bool isNativeType(DartType t) =>
      nativeTypes(t.element).contains(t) ||
      t.element.library.isDartCore && (nativeClasses.contains(t.element.name));

  String toJSName(Element element, {bool nopath: false}) {
    JSPath jspath = _collectJSPath(
        element); // note: we should check if var is top, but ... whatever.
    String name;
    if (nopath) {
      return jspath.namespacePathElements.last;
    }
    if (jspath.namespacePathElements.isNotEmpty) {
      if (jspath.modulePathElements.isNotEmpty) {
        name =
            namespaceFor(uri: jspath.moduleUri, modulePath: jspath.modulePath) +
                "." +
                jspath.name;
      } else {
        name = jspath.name;
      }
    } else {
      name = element.name;
    }

    return name;
  }

  String toTsType(DartType type, {bool noTypeArgs: false}) {
    // Look for @JS annotations
    if (type is TypeParameterType) {
      return type.element.name;
    }

    if (getAnnotation(type.element.metadata, isJS) != null) {
      // check if we got a package annotation
      JSPath path = _collectJSPath(type.element);
      // Lookup for prefix
      String moduleUri = path.moduleUri;

      String prefix;
      if (moduleUri != null) {
        prefix =
            namespaceFor(uri: path.moduleUri, modulePath: path.modulePath) +
                '.';
      } else {
        prefix = "";
      }

      String typeArgs;
      if (!noTypeArgs &&
              type is ParameterizedType &&
              type.typeArguments?.isNotEmpty ??
          false) {
        typeArgs =
            "<${((type as ParameterizedType).typeArguments).map((t) => toTsType(t)).join(',')}>";
      } else {
        typeArgs = "";
      }

      return "${prefix}${path.name}${typeArgs}";
    }

    if (type.isDynamic) {
      return "any";
    }

    String p;
    if (type.element.library != _current && !isNativeType(type)) {
      p = "${namespace(type.element.library)}.";
    } else {
      p = "";
    }

    String actualName;
    if (isListType(type)) {
      actualName = "Array";
    } else if (type == type.element.context.typeProvider.numType ||
        type == type.element.context.typeProvider.intType) {
      actualName = 'number';
    } else if (type == type.element.context.typeProvider.stringType) {
      actualName = 'string';
    } else if (type == type.element.context.typeProvider.boolType) {
      actualName = 'boolean';
    } else {
      actualName = type.name;
    }
    if (!noTypeArgs &&
        type is ParameterizedType &&
        type.typeArguments.isNotEmpty) {
      return "${p}${actualName}<${type.typeArguments.map((t) => toTsType(t)).join(',')}>";
    } else {
      return "${p}${actualName}";
    }
  }
}
