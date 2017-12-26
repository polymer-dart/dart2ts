part of '../code_generator2.dart';

abstract class Context {
  TypeManager get typeManager;
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

  TSType returnType;

  Iterable<TSTypeParameter> typeParameters;

  FunctionExpressionContext(Context parent, this._functionExpression) {
    parentContext = parent;
  }

  TSFunction generateTypescript() {
    return new TSFunction(
      topLevel: true,
      returnType: returnType,
      typeParameters: typeParameters,
    );
  }
}

class TopLevelFunctionContext extends TopLevelDeclarationContext {
  FunctionDeclaration _functionDeclaration;
  FunctionExpressionContext _functionExpressionContext;

  TSType returnType;

  TopLevelFunctionContext(FileContext fileContext, this._functionDeclaration)
      : super(fileContext) {
    _functionExpressionContext = new FunctionExpressionContext(
        this, _functionDeclaration.functionExpression)
      ..returnType = parentContext.typeManager
          .toTsType(_functionDeclaration?.returnType?.type);
  }

  @override
  void generateTypescript(TSLibrary tsLibrary) {
    tsLibrary.addChild(_functionExpressionContext.generateTypescript()
      ..name = _functionDeclaration.name.name);
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
