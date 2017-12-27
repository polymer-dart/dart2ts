part of '../code_generator2.dart';

abstract class Context {
  TypeManager get typeManager;

  TSExpression generateExpression(Expression defaultValue) {
    // TODO
    return new TSExpression();
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

    return new TSFunction(
      topLevel: true,
      typeParameters: typeParameters,
      parameters: new List.from(parameterCollector.tsParameters),
      defaults: parameterCollector.defaults,
      namedDefaults: parameterCollector.namedDefaults,
    );
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
    if (node.kind == ParameterKind.NAMED) {
      namedDefaults[node.identifier.name] =
          _context.generateExpression(node.defaultValue);
    } else {
      defaults[node.identifier.name] =
          _context.generateExpression(node.defaultValue);
    }
  }

  @override
  visitFormalParameter(FormalParameter node) {
    //super.visitFormalParameter(node);
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
  FunctionExpressionContext _functionExpressionContext;

  TSType returnType;

  TopLevelFunctionContext(FileContext fileContext, this._functionDeclaration)
      : super(fileContext) {
    _functionExpressionContext = new FunctionExpressionContext(
        this, _functionDeclaration.functionExpression);
  }

  @override
  void generateTypescript(TSLibrary tsLibrary) {
    tsLibrary.addChild(_functionExpressionContext.generateTypescript()
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
