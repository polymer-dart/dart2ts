part of '../code_generator2.dart';

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