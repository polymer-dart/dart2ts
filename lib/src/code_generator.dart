import 'dart:async';

import 'package:analyzer/analyzer.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/src/generated/engine.dart' show AnalysisContext;
import 'package:analyzer/src/generated/resolver.dart';
import 'package:args/command_runner.dart';
import 'package:build/build.dart';
import 'package:build_runner/build_runner.dart';
import 'package:dart2ts/src/overrides.dart';
import 'package:dart2ts/src/utils.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:source_gen/source_gen.dart';

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
    Dart2TsVisitor visitor = new Dart2TsVisitor(new FileContext(library));
    await buildStep.writeAsString(
        destId,
        library.units.map((u) => u.computeNode().accept(visitor)).join('\n') +
            visitor._context._prefixes.values
                .map((i) => 'import * as ${i.prefix} from "${i.path}";')
                .join('\n'));
  }
}

class Dart2TsVisitor extends GeneralizingAstVisitor<String> {
  ExpressionBuilderVisitor _visitor;
  FileContext _context;

  Dart2TsVisitor(this._context);

  @override
  visitCompilationUnit(CompilationUnit node) {
    _visitor = new ExpressionBuilderVisitor(_context, true);
    return "// Generated code\n"
        "${node.declarations.map((d) => d.accept(this)).join('\n')}";
  }

  @override
  String visitFunctionTypeAlias(FunctionTypeAlias node) {
    return "/* TYPEDEF ${node} */";
  }

  @override
  String visitCompilationUnitMember(CompilationUnitMember node) {
    return super.visitCompilationUnitMember(node);
  }

  @override
  String visitVariableDeclaration(VariableDeclaration node) {
    return super.visitVariableDeclaration(node);
  }

  @override
  String visitTopLevelVariableDeclaration(TopLevelVariableDeclaration node) =>
      node.accept(_visitor);

  @override
  String visitClassDeclaration(ClassDeclaration node) =>
      node.accept(new ClassBuilderVisitor(this));

  @override
  String visitFunctionDeclaration(FunctionDeclaration node) =>
      node.accept(_visitor);
}

class ConstructorMethodBuilderVisitor extends FunctionExpressionBuilderVisitor {
  final ConstructorDeclaration declaration;

  //final String symName;
  final bool isDefault;
  ClassBuilderVisitor _classBuilderVisitor;

  /**
   * Builds the instance method that will init the class
   */

  static String symbolFor(ConstructorElement cons) =>
      isAnonymousConstructor(cons)
          ? 'bare.init'
          : "${cons.enclosingElement.name}_${cons.name}";

  static String accessorFor(ConstructorElement cons) =>
      isAnonymousConstructor(cons) ? '[bare.init]' : ".${cons.name}";

  static String interfaceNameFor(ConstructorElement cons) =>
      "${cons.enclosingElement.name}_Constructors.${cons.name}";

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
        "}";
  }

  String constructorInterface() {
    return "export interface ${declaration.element.name} {\n"
        " new ${parameters()}: ${declaration.element.enclosingElement.name};\n"
        "}";
  }

  String interfaceName() => interfaceNameFor(declaration.element);

  ConstructorMethodBuilderVisitor(
      ClassBuilderVisitor _classBuilderVisitor, this.declaration)
      : isDefault = isAnonymousConstructor(declaration.element),
        super(_classBuilderVisitor._parentVisitor._visitor._context) {}

  String buildMethod() {
    if (declaration.element.isFactory) {
      String name = (declaration.element.name ?? '').isEmpty
          ? "new"
          : tsMethodName(declaration.element.name);
      return "/* factory constructor */ static ${name}${declaration.parameters.accept(this)}${declaration.body.accept(this)}";
    } else {
      String name = isDefault ? "[${symName}]" : tsMethodName(declaration.element.name);
      return "${name}${declaration.parameters.accept(this)}${declaration.body.accept(this)}";
    }
  }

  String _initializers() {
    // TODO : call super class default if no super initializers

    String i1 = _namedParameters.ordinal
        .where(
            (p) => p is FieldFormalParameter || p.element.isInitializingFormal)
        .map((p) => "this.${p.identifier.name}=${p.identifier.name};\n")
        .join('');
    String i2 = _namedParameters.named.values
        .where(
            (p) => p is FieldFormalParameter || p.element.isInitializingFormal)
        .map((p) => "this.${p.identifier.name}=${p.identifier.name};\n")
        .join('');
    return "$i1$i2${declaration.initializers.map((c) => c.accept(this)).join('\n')}";
  }

  @override
  String visitRedirectingConstructorInvocation(
      RedirectingConstructorInvocation node) {
    return "this${ConstructorMethodBuilderVisitor.accessorFor(node.staticElement)}";
  }

  @override
  String visitConstructorFieldInitializer(ConstructorFieldInitializer node) {
    return "this.${node.fieldName.name} = ${node.expression.accept(this)};";
  }

  @override
  String visitSuperConstructorInvocation(SuperConstructorInvocation node) {
    return "super${ConstructorMethodBuilderVisitor.accessorFor(node.staticElement)}${node.argumentList.accept(this)};";
  }

  @override
  String _blockPreamble() {
    return "${super._blockPreamble()}${_initializers()}";
  }
}

class ClassBuilderVisitor extends ExpressionBuilderVisitor {
  Dart2TsVisitor _parentVisitor;
  List<ConstructorMethodBuilderVisitor> constructors = [];

  ClassBuilderVisitor(this._parentVisitor)
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

    ConstructorMethodBuilderVisitor constructorBuilder =
        constructors.firstWhere((b) => b.isDefault, orElse: () => null);
    String extra;
    if (constructorBuilder != null) {
      extra = "constructor${constructorBuilder.parameters()};\n";
    } else {
      extra = "constructor();\n";
    }

    String namedInterfaces = _namedInterfaces();
    if (namedInterfaces.isNotEmpty) {
      namedInterfaces = "export namespace ${node.name.name}_Constructors {\n"
          "${namedInterfaces}"
          "\n}\n";
    }

    String a = node.isAbstract ? "abstract " : "";

    return "${namedInterfaces}export ${a}class ${node.name.name}${node.typeParameters?.accept(this) ?? ''}${node.extendsClause?.accept(this) ?? ''}${node.implementsClause?.accept(this) ?? ''} {\n"
        "${extra}"
        "constructor(...args){\n"
        " ${superCall}"
        "}\n"
        "${namedConstructors}\n"
        "${members}"
        "}\n";
  }

  @override
  String visitImplementsClause(ImplementsClause node) {
    return " implements ${node.interfaces.map((t) => t.accept(this)).join(',')}";
  }

  @override
  String visitTypeParameterList(TypeParameterList node) {
    return "<${node.typeParameters.map((tp) => tp.accept(this)).join(',')}>";
  }

  @override
  String visitTypeParameter(TypeParameter node) {
    String e;
    if (node.extendsKeyword != null) {
      e = " extends ${toTsType(node.bound.type)}";
    } else {
      e = "";
    }
    return "${node.name.name}${e}";
  }

  String _namedInterfaces() => constructors
      .where((c) => !c.isDefault && !c.declaration.element.isFactory)
      .map((c) => c.constructorInterface())
      .join("\n");

  @override
  String visitExtendsClause(ExtendsClause node) {
    return " extends ${toTsType(node.superclass.type)}";
  }

  String _namedConstructors() {
    return "${constructors.where((c) => !c.isDefault && !c.declaration.element.isFactory).map((c) => c.defineNamedConstructor()).join('\n')}";
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
    return new FunctionExpressionBuilderVisitor(
            _parentVisitor._visitor._context)
        .buildMethodDeclaration(node);
  }

  @override
  String visitConstructorDeclaration(ConstructorDeclaration node) {
    ConstructorMethodBuilderVisitor builder =
        new ConstructorMethodBuilderVisitor(this, node);
    constructors.add(builder);
    return builder.buildMethod();
  }
}

class NamedParameterCollectorVisitor extends GeneralizingAstVisitor<dynamic> {
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

class FunctionExpressionBuilderVisitor extends ExpressionBuilderVisitor {
  FunctionExpressionBuilderVisitor(FileContext context, [bool isTop = false])
      : super(context, isTop);

  String buildFunction(FunctionExpression node) {
    return "${node.element.name}${node.parameters.accept(this)} => ${node.body.accept(this)}";
  }

  @override
  String visitAssertStatement(AssertStatement node) {
    return "/* assert ${node} */"; // TODO: add bare.assert and a compile flag to suppress it
  }

  @override
  String visitFormalParameter(FormalParameter node) {
    return "${node.identifier}${node.kind.isOptional ? '?' : ''} : ${toTsType(node.element.type)}";
  }

  /*
  @override
  String visitFunctionTypedFormalParameter(FunctionTypedFormalParameter node) {
    return "/*FTFP*/";
  }*/

  NamedParameterCollectorVisitor _namedParameters;

  @override
  String visitFunctionDeclaration(FunctionDeclaration node) {
    return new FunctionExpressionBuilderVisitor(_context)
        .buildFunctionDeclaration(node);
  }

  @override
  String visitFormalParameterList(FormalParameterList node) {
    // Create the named optional parameter
    _namedParameters = new NamedParameterCollectorVisitor();
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

    if (node.element.isGenerator) {
      return "${isTop ? 'export ' : ''}function ${node.functionExpression.element?.name ?? ''}${node.functionExpression.typeParameters?.accept(this) ?? ''}${node.functionExpression.parameters?.accept(
          this) ?? '(/*TOP LEVEL GETTER :${node.isGetter}*/)'}"
          " { return { [Symbol.iterator]: ${node.element.isAsynchronous ? 'async ' : ''}function*()${node.functionExpression.body.accept(this)}};}";
    }

    return "${isTop ? 'export ' : ''}${node.element.isAsynchronous ? 'async ' : ''}function${node.element.isGenerator ? '*' : ''} ${node.functionExpression.element?.name ?? ''}${node
        .functionExpression.typeParameters?.accept(this) ?? ''}${node.functionExpression.parameters?.accept(this) ?? '(/*TOP LEVEL GETTER*/)'}:${toTsType(node.element.returnType)}${node.functionExpression
        .body.accept(this)}";
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
    String s = node.isStatic ? 'static ' : '';
    String a = node.isAbstract ? 'abstract ' : '';
    if (node.isGetter) {
      return "${s}${a}get ${node.name}() : ${toTsType(node.element.returnType)}${node.body.accept(this)}";
    } else if (node.isSetter) {
      return "${s}${a}set ${node.name}${node.parameters.accept(this)}${node.body.accept(this)}";
    } else {
      return "${s}${a}${node.name.name}${node.parameters.accept(this)}${node.body.accept(this)}";
    }
  }

  @override
  String visitEmptyFunctionBody(EmptyFunctionBody node) {
    AstNode p = node.parent;
    if (p is MethodDeclaration && p.isAbstract) {
      return ";";
    }
    return "{ ${_blockPreamble()}}";
  }

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
                x is DefaultFormalParameter &&
                (x as DefaultFormalParameter).defaultValue != null)
            ?.map((d) => d as DefaultFormalParameter)
            ?.map((d) =>
                '${d.identifier} = ${d.identifier} || ${d.defaultValue.accept(this)};\n')
            ?.join() ??
        '';

    return "${namedArgs}"
        "${defaults}\n/* BODY */";
  }
}

class ExpressionBuilderVisitor extends GeneralizingAstVisitor<String> {
  bool isTop;

  ExpressionBuilderVisitor(this._context, [this.isTop = false]);

  @override
  String visitGenericFunctionType(GenericFunctionType node) {
    return "/* GEN */";
  }

  @override
  String visitAsExpression(AsExpression node) {
    return "<${toTsType(node.type.type)}>${node.expression.accept(this)}";
  }

  @override
  String visitFunctionDeclaration(FunctionDeclaration node) {
    return new FunctionExpressionBuilderVisitor(_context, isTop)
        .buildFunctionDeclaration(node);
  }

  @override
  String visitMapLiteral(MapLiteral node) {
    ParameterizedType t = node.staticType;
    if (t.typeParameters[0].type == currentContext.typeProvider.stringType) {
      return "{${node.entries.map((e) => e.accept(this)).join(',')}}";
    } else {
      // Produce a map
      return "new Map([${node.entries.map((e)=>"[${e.key.accept(this)},${e.value.accept(this)}]").join(',')}])";
    }
  }

  @override
  String visitMapLiteralEntry(MapLiteralEntry node) {
    return "${node.key.accept(this)} : ${node.value.accept(this)}";
  }

  @override
  String visitForEachStatement(ForEachStatement node) {
    return "${node.awaitKeyword != null ? 'await ' : ''}for (let ${node.loopVariable.accept(this)} of ${node.iterable.accept(this)})${node.body.accept(this)}";
  }

  @override
  String visitIfStatement(IfStatement node) {
    ExpressionBuilderVisitor inner = new ExpressionBuilderVisitor(_context);
    String els = node.elseStatement != null
        ? " else ${node.elseStatement.accept(this)}"
        : "";
    return "if (${node.condition.accept(this)}) ${node.thenStatement.accept(inner)}${els}";
  }

  @override
  String visitIsExpression(IsExpression node) {
    String op = (node.notOperator == null) ? "is" : "isNot";
    return "bare.${op}(${node.expression.accept(this)},${toTsType(node.type.type, inTypeOf: true)})";
  }

  @override
  String visitThrowExpression(ThrowExpression node) {
    return "throw ${node.expression.accept(this)}";
  }

  @override
  String visitTryStatement(TryStatement node) {
    ExpressionBuilderVisitor inner = new ExpressionBuilderVisitor(_context);
    return "try ${node.body.accept(inner)} ${node.catchClauses?.map((c) => c.accept(inner))?.join('\n') ?? ''} ${_finally(node.finallyBlock?.accept(inner))}";
  }

  @override
  String visitDoStatement(DoStatement node) {
    ExpressionBuilderVisitor inner = new ExpressionBuilderVisitor(_context);
    return "do ${node.body.accept(inner)} while (${node.condition.accept(this)});";
  }

  @override
  String visitWhileStatement(WhileStatement node) {
    ExpressionBuilderVisitor inner = new ExpressionBuilderVisitor(_context);
    return "while (${node.condition.accept(this)}) ${node.body.accept(inner)}";
  }

  @override
  String visitForStatement(ForStatement node) {
    ExpressionBuilderVisitor inner = new ExpressionBuilderVisitor(_context);
    return "for(${(node.variables?.variables ?? []).map((d) => "let ${d.accept(this)}").join(',')};${node.condition?.accept(this) ?? ''};${node.updaters.map((u) => u.accept(this)).join(',')}) ${node
        .body.accept(inner)}";
  }

  @override
  String visitPostfixExpression(PostfixExpression node) {
    return "${node.operand.accept(this)}${node.operator}";
  }

  @override
  String visitSwitchStatement(SwitchStatement node) {
    ExpressionBuilderVisitor inner = new ExpressionBuilderVisitor(_context);
    return "switch (${node.expression.accept(this)}) {"
        "${node.members.map((m) => m.accept(inner)).join('\n')}"
        "}";
  }

  @override
  String visitSwitchCase(SwitchCase node) {
    return "case ${node.expression.accept(this)}:\n"
        "${node.statements.map((s) => s.accept(this)).join('\n')}";
  }

  @override
  String visitYieldStatement(YieldStatement node) {
    return "yield ${node.expression.accept(this)};";
  }

  @override
  String visitBreakStatement(BreakStatement node) {
    return "break;";
  }

  @override
  String visitSwitchDefault(SwitchDefault node) {
    return "default:\n"
        "${node.statements.map((s) => s.accept(this)).join('\n')}";
  }

  @override
  String visitPrefixExpression(PrefixExpression node) {
    return "${node.operator}${node.operand.accept(this)}";
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

  String toTsType(DartType t, {bool noTypeArgs: false, bool inTypeOf: false}) =>
      _context.toTsType(t, noTypeArgs: noTypeArgs, inTypeOf: inTypeOf);

  @override
  String visitCascadeExpression(CascadeExpression node) {
    return "(((_) => {${node.cascadeSections.map((e) => "_.${e.accept(this)};").join('\n')}\nreturn _;})(${node.target.accept(this)}))";
  }

  @override
  String visitFunctionDeclarationStatement(FunctionDeclarationStatement node) =>
      '${node.functionDeclaration.accept(this)}';

  @override
  String visitSimpleStringLiteral(SimpleStringLiteral node) {
    if (node.isRaw) {
      return node.literal.toString().substring(1);
    }
    return node.literal.toString();
    //return node.literal.toString();
  }

  @override
  String visitSimpleIdentifier(SimpleIdentifier node) {
    if (node.staticElement is ClassElement) {
      return toTsType((node.staticElement as ClassElement).type);
    }

    // Is actually ever happening ?
    if ((node.staticElement is VariableElement) &&
        getAnnotation(node.staticElement.metadata, isJS) != null) {
      return _context.toTsName(node.staticElement);
    }

    if ((node.staticElement is PropertyAccessorElement) &&
        getAnnotation(
                (node.staticElement as PropertyAccessorElement)
                    .variable
                    .metadata,
                isJS) !=
            null) {
      return _context
          .toTsName((node.staticElement as PropertyAccessorElement).variable);
    }

    String name;
    String prefix;
    // If there's a js anno use that

    if (getAnnotation(node.staticElement?.metadata ?? [], isJS) != null) {
      name = _context.toTsName(node.staticElement);
      prefix = "";
    } else {
      name = node.name;
      bool isTopLevelGetter = node.staticElement is PropertyAccessorElement &&
          !node.staticElement.isSynthetic &&
          node.staticElement.enclosingElement is CompilationUnitElement;
      if (isTopLevelGetter) {
        name = "${name}()";
      }
      prefix = _prefixFor(node.staticElement, from: _findEnclosingScope(node));
    }

    if (node.token.previous?.type != TokenType.PERIOD) {
      String that = _checkImplicitThis(node);
      return "${that ?? prefix}${name}";
    }

    return "${prefix}${name}";
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
    return new FunctionExpressionBuilderVisitor(_context).buildFunction(node);
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
    if (node.operator.type == TokenType.QUESTION_QUESTION) {
      return "${node.leftOperand.accept(this)} || ${node.rightOperand.accept(this)}";
    }

    // Because of a different operator precedence
    if (node.operator.type == TokenType.EQ_EQ ||
        node.operator.type == TokenType.BANG_EQ) {
      return "(${node.leftOperand.accept(this)})${node.operator}(${node.rightOperand.accept(this)})";
    }
    return "${node.leftOperand.accept(this)}${node.operator}${node.rightOperand.accept(this)}";
  }

  @override
  String visitVariableDeclaration(VariableDeclaration node) {
    return "${node.name.name}:${toTsType(node.element.type)}${node.initializer != null ? '= ${node.initializer.accept(this)}' : ''}";
  }

  @override
  String visitVariableDeclarationStatement(VariableDeclarationStatement node) {
    return "${node.variables.accept(this)};";
  }

  @override
  String visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (getAnnotation(node.staticType.element.metadata, isAnonymous) != null) {
      // Create the literal

      ClassElement c = node.staticType.element;

      return "{${c.fields.map((f) => "${f.name}:null").join(',')}}";
    }

    return translatorRegistry.newInstance(
        node.staticElement,
        "${toTsType(node.staticType, noTypeArgs: true)}",
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
      // Check for JS ANNO

      String executable;

      if (getAnnotation(node.methodName.staticElement.metadata, isJS) != null) {
        // Call a js
        executable = _context.toTsName(node.methodName.staticElement);
      } else {
        executable = _resolve(node.methodName.staticElement,
            from: _findEnclosingScope(node));
      }

      return "${executable}${node.typeArguments != null ? node.typeArguments.accept(this) : ''}${node.argumentList.accept(this)}";
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
          node.target,
          target,
          "${_methodName(node.methodName.staticElement)}${node.typeArguments != null ? node.typeArguments.accept(this) : ''}",
          this.arguments(node.argumentList).toList());
    }

    // Else is an expression that resolves to a function

    String target = node.methodName.accept(this);
    return translatorRegistry.invokeMethod(
        null,
        node.target,
        null,
        "${target}${node.typeArguments != null ? node.typeArguments.accept(this) : ''}",
        this.arguments(node.argumentList).toList());
  }

  String _methodName(MethodElement method) {
    return method.name;
  }

  @override
  String visitPrefixedIdentifier(PrefixedIdentifier node) {
    if (node.prefix.staticElement is PrefixElement) {
      return node.identifier.accept(this);
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
        accessor.isGetter); // Setter case should be handled by assignament

    String name = accessor != null
        ? _context.toTsName(accessor.variable, nopath: true)
        : node.identifier.name;

    return translatorRegistry.getProperty(
        node.prefix.bestType, accessor, node.prefix.accept(this), name);
  }

  @override
  String visitPropertyAccess(PropertyAccess node) {
    PropertyAccessorElement access = node.propertyName.staticElement;
    assert(access?.isGetter ?? true); // Setter is handled in assignment

    String target = node?.target?.accept(this);

    return translatorRegistry.getProperty(
        node?.target?.bestType,
        access,
        target,
        access != null
            ? _context.toTsName(access.variable, nopath: true)
            : node.propertyName.name);
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
      "return ${node.expression?.accept(this) ?? ''};";

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
      accessor =
          accessor?.isSetter ?? true ? accessor : accessor.correspondingSetter;

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
      accessor =
          accessor?.isSetter ?? true ? accessor : accessor.correspondingSetter;
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
        ? _context.toTsName(accessor.variable, nopath: true)
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
  String visitAdjacentStrings(AdjacentStrings node) {
    return "${node.strings.map((l) => l.accept(this)).join(' + ')}";
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

    return null;
  }
}

class TSImport {
  String prefix;
  String path;
  LibraryElement library;

  TSImport({this.prefix, this.path, this.library});
}

class TSPath {
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

      // If same package produce a relative path
      AssetId currentId = _toAssetId(_current.source.uri.toString());
      AssetId id = _toAssetId(uri);

      String libPath;

      if (id.package == currentId.package) {
        libPath =
            "./${path.withoutExtension(path.relative(id.path, from: path.dirname(currentId.path)))}";
      } else {
        libPath = "${id.package}/${path.withoutExtension(id.path)}";
      }

      // Extract package name and path and produce a nodemodule path
      return new TSImport(prefix: _nextPrefix(), path: libPath, library: lib);
    }).prefix;
  }

  static final RegExp NAME_PATTERN = new RegExp('(([^#]+)#)?(.*)');

  TSPath _collectJSPath(Element start) {
    var collector = (Element e, TSPath p, var c) {
      if (e is! LibraryElement) {
        c(e.enclosingElement, p, c);
      }

      // Collect if metadata
      String name =
          getAnnotation(e.metadata, isJS)?.getField('name')?.toStringValue();
      if (name != null && name.isNotEmpty) {
        Match m = NAME_PATTERN.matchAsPrefix(name);
        String module = getAnnotation(e.metadata, isModule)
            ?.getField('path')
            ?.toStringValue();
        if (m != null && (m[2] != null || module != null)) {
          p.modulePathElements.add(module ?? m[2]);
          if ((m[3] ?? '').isNotEmpty) p.namespacePathElements.add(m[3]);
        } else {
          p.namespacePathElements.add(name);
        }
      } else if (e == start) {
        // Add name if it's the first
        p.namespacePathElements.add(e.name);
      }
    };

    TSPath p = new TSPath();
    collector(start, p, collector);
    return p;
  }

  static Set<DartType> nativeTypes() => ((TypeProvider x) => new Set.from([
        x.boolType,
        x.stringType,
        x.intType,
        x.numType,
        x.doubleType,
        x.functionType,
      ]))(currentContext.typeProvider);

  static Set<String> nativeClasses =
      new Set.from(['List', 'Map', 'Iterable', 'Iterator']);

  static bool isNativeType(DartType t) =>
      nativeTypes().contains(t) ||
      t.element.library.isDartCore && (nativeClasses.contains(t.element.name));

  String toTsName(Element element, {bool nopath: false}) {
    TSPath jspath = _collectJSPath(
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

  String toTsType(DartType type,
      {bool noTypeArgs: false, bool inTypeOf: false}) {
    // Look for @JS annotations
    if (type is TypeParameterType) {
      return type.element.name;
    }

    if (type is FunctionType) {
      Iterable<String> args = () sync* {
        for (var p in type.normalParameterTypes) {
          yield toTsType(p);
        }
        for (var p in type.optionalParameterTypes) {
          yield toTsType(p) + "?";
        }

        if (type.namedParameterTypes.isNotEmpty) {
          yield "{${type.namedParameterTypes.keys.map((k)=>"${k}?:${toTsType(type.namedParameterTypes[k])}").join(',')}}?";
        }
      }();

      String ta;
      if (type.typeArguments?.isNotEmpty ?? false) {
        ta = "<${type.typeArguments.map((t) => toTsType(t)).join(',')}>";
      } else {
        ta = '';
      }

      return "${ta}(${args.join(',')})=>${toTsType(type.returnType)}";
    }

    if (getAnnotation(type?.element?.metadata ?? [], isJS) != null) {
      // check if we got a package annotation
      TSPath path = _collectJSPath(type.element);
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
    if (type.element != null &&
        type.element.library != _current &&
        !isNativeType(type)) {
      p = "${namespace(type.element.library)}.";
    } else {
      p = "";
    }

    String actualName;
    if (isListType(type)) {
      actualName = "Array";
    } else if (type == currentContext.typeProvider.numType ||
        type == currentContext.typeProvider.intType) {
      actualName = 'number';
    } else if (type == currentContext.typeProvider.stringType) {
      actualName = 'string';
    } else if (type == currentContext.typeProvider.boolType) {
      actualName = 'boolean';
    } else if (type == getType(currentContext, 'dart:core', 'RegExp')) {
      actualName = 'RegExpPattern';
    } else {
      actualName = type.name;
    }

    if (nativeTypes().contains(type) && inTypeOf) {
      actualName = '"${actualName}"';
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

