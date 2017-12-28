part of '../code_generator2.dart';

abstract class Context {
  TypeManager get typeManager;

  E processExpression<E extends TSExpression>(Expression expression) {
    if (expression == null) {
      return null;
    }
    return expression.accept(new ExpressionVisitor(this)) as E;
  }

  TSFunction processFunctionExpression(FunctionExpression functionExpression) {
    return processExpression<TSFunction>(functionExpression);
  }

  TSBody processBody(FunctionBody body, {bool withBrackets: false}) {
    return body.accept(new BodyVisitor(this, withBrackets: withBrackets));
  }

  Iterable<TSStatement> processBlock(Block block) {
    StatementVisitor visitor = new StatementVisitor(this);
    return block.statements
        .map((s) => processStatement(s, withVisitor: visitor))
        .where((s) => s != null);
  }

  TSStatement processStatement(Statement statement,
      {StatementVisitor withVisitor}) {
    withVisitor ??= new StatementVisitor(this);
    return statement.accept(withVisitor);
  }
}

class BodyVisitor extends GeneralizingAstVisitor<TSBody> {
  Context _context;
  bool withBrackets;

  BodyVisitor(this._context, {this.withBrackets: false});

  @override
  TSBody visitBlockFunctionBody(BlockFunctionBody node) {
    return new TSBody(
        statements: _context.processBlock(node.block),
        withBrackets: withBrackets);
  }

  @override
  TSBody visitExpressionFunctionBody(ExpressionFunctionBody node) {
    return new TSBody(statements: [
      new TSReturnStatement(_context.processExpression(node.expression))
    ], withBrackets: withBrackets);
  }
}

class StatementVisitor extends GeneralizingAstVisitor<TSStatement> {
  Context _context;
  StatementVisitor(this._context);

  @override
  TSStatement visitReturnStatement(ReturnStatement node) {
    return new TSReturnStatement(_context.processExpression(node.expression));
  }

  @override
  TSStatement visitStatement(Statement node) {
    return new TSUnknownStatement(node);
  }
}

class ExpressionVisitor extends GeneralizingAstVisitor<TSExpression> {
  Context _context;

  ExpressionVisitor(this._context);

  @override
  TSExpression visitIntegerLiteral(IntegerLiteral node) {
    return new TSSimpleExpression(node.value.toString());
  }

  @override
  TSExpression visitExpression(Expression node) {
    return new TSUnknownExpression(node);
  }

  @override
  TSExpression visitFunctionExpression(FunctionExpression node) {
    return new FunctionExpressionContext(_context, node).generateTypescript();
  }

  @override
  TSExpression visitSimpleStringLiteral(SimpleStringLiteral node) {
    return new TSSimpleExpression(node.toSource()); // Preserve the same quotes
  }

  @override
  TSExpression visitNullLiteral(NullLiteral node) {
    return new TSSimpleExpression('null');
  }


}

class TopLevelContext {
  TypeManager typeManager;
}

class ChildContext {
  Context parentContext;
  TypeManager get typeManager => parentContext.typeManager;
}

/**
 * Generation Context
 */

class LibraryContext extends Context with TopLevelContext {
  LibraryElement _libraryElement;
  List<FileContext> _fileContexts;

  LibraryContext(this._libraryElement) {
    typeManager = new TypeManager(_libraryElement);
    _fileContexts = _libraryElement.units
        .map((cu) => cu.computeNode())
        .map((cu) => new FileContext(this, cu))
        .toList();
  }

  TSLibrary generateTypescript() {
    TSLibrary tsLibrary = new TSLibrary(_libraryElement.source.uri.toString());
    _fileContexts.forEach((fc) => fc.generateTypescript(tsLibrary));

    return tsLibrary;
  }
}

class FileContext extends Context with ChildContext {
  LibraryContext get _libraryContext => parentContext;
  CompilationUnit _compilationUnit;
  List<TopLevelDeclarationContext> _topLevelContexts;

  FileContext(LibraryContext parent, this._compilationUnit) {
    this.parentContext = parent;

    TopLevelDeclarationVisitor visitor = new TopLevelDeclarationVisitor(this);
    _topLevelContexts = new List();
    _topLevelContexts.addAll(_compilationUnit.declarations
        .map((f) => f.accept(visitor))
        .where((x) => x != null));
  }

  void generateTypescript(TSLibrary tsLibrary) {
    _topLevelContexts.forEach((t) => t.generateTypescript(tsLibrary));
  }
}

class TopLevelDeclarationVisitor
    extends GeneralizingAstVisitor<TopLevelDeclarationContext> {
  FileContext _fileContext;

  TopLevelDeclarationVisitor(this._fileContext);

  @override
  TopLevelDeclarationContext visitFunctionDeclaration(
      FunctionDeclaration node) {
    return new TopLevelFunctionContext(_fileContext, node);
  }
}

abstract class TopLevelDeclarationContext extends Context with ChildContext {
  FileContext get _fileContext => parentContext;

  TopLevelDeclarationContext(FileContext parent) {
    this.parentContext = parent;
  }

  void generateTypescript(TSLibrary tsLibrary);
}

class FunctionExpressionContext extends Context with ChildContext {
  FunctionExpression _functionExpression;

  FunctionExpressionContext(Context parent, this._functionExpression) {
    parentContext = parent;
  }

  TSFunction generateTypescript() {
    List<TSTypeParameter> typeParameters;

    if (_functionExpression.typeParameters != null) {
      typeParameters = new List.from(_functionExpression
          .typeParameters.typeParameters
          .map((t) => new TSTypeParameter(
              t.name.name, typeManager.toTsType(t.bound?.type))));
    } else {
      typeParameters = null;
    }

    // arguments
    FormalParameterCollector parameterCollector =
        new FormalParameterCollector(this);
    (_functionExpression.parameters?.parameters ?? []).forEach((p) {
      p.accept(parameterCollector);
    });

    // body
    TSBody body = processBody(_functionExpression.body, withBrackets: false);

    return new TSFunction(
        topLevel: true,
        typeParameters: typeParameters,
        parameters: new List.from(parameterCollector.tsParameters),
        defaults: parameterCollector.defaults,
        namedDefaults: parameterCollector.namedDefaults,
        body: body);
  }
}

const String NAMED_ARGUMENTS = '_namedArguments';

class FormalParameterCollector extends GeneralizingAstVisitor {
  Context _context;

  FormalParameterCollector(this._context);

  Map<String, TSExpression> defaults = {};
  Map<String, TSExpression> namedDefaults = {};
  List<TSParameter> parameters = [];
  TSInterfaceType namedType;

  Iterable<TSParameter> get tsParameters sync* {
    yield* parameters;
    if (namedType != null) {
      yield new TSParameter(
          name: NAMED_ARGUMENTS, type: namedType, optional: true);
    }
  }

  @override
  visitDefaultFormalParameter(DefaultFormalParameter node) {
    super.visitDefaultFormalParameter(node);
    if (node.defaultValue == null) {
      return;
    }
    if (node.kind == ParameterKind.NAMED) {
      namedDefaults[node.identifier.name] =
          _context.processExpression(node.defaultValue);
    } else {
      defaults[node.identifier.name] =
          _context.processExpression(node.defaultValue);
    }
  }

  @override
  visitFormalParameter(FormalParameter node) {
    if (node.kind == ParameterKind.NAMED) {
      namedType ??= new TSInterfaceType();
      namedType.fields[node.identifier.name] =
          _context.typeManager.toTsType(node.element.type);
    } else {
      parameters.add(new TSParameter(
          name: node.identifier.name,
          type: _context.typeManager.toTsType(node.element.type),
          optional: node.kind.isOptional));
    }
  }
}

class TopLevelFunctionContext extends TopLevelDeclarationContext {
  FunctionDeclaration _functionDeclaration;

  TSType returnType;

  TopLevelFunctionContext(FileContext fileContext, this._functionDeclaration)
      : super(fileContext) {}

  @override
  void generateTypescript(TSLibrary tsLibrary) {
    tsLibrary.addChild(
        processFunctionExpression(_functionDeclaration.functionExpression)
          ..name = _functionDeclaration.name.name
          ..returnType = parentContext.typeManager
              .toTsType(_functionDeclaration?.returnType?.type));
  }
}

class ClassContext extends TopLevelDeclarationContext {
  ClassContext(FileContext fileContext) : super(fileContext);
  @override
  void generateTypescript(TSLibrary tsLibrary) {
    // TODO: implement generateTypescript
  }
}

class MethodContext extends Context with ChildContext {
  ClassContext _classContext;
}
