part of '../code_generator2.dart';


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
