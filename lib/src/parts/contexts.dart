part of '../code_generator2.dart';

abstract class Context<T extends TSNode> {
  TypeManager get typeManager;

  bool get topLevel;

  bool get isAssigning;
  bool get isCascading;

  TSExpression get cascadingTarget;
  TSExpression get assigningValue;

  ClassContext get currentClass;

  T translate();

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
    return new List.from(block.statements
        .map((s) => processStatement(s, withVisitor: visitor))
        .where((s) => s != null));
  }

  TSStatement processStatement(Statement statement,
      {StatementVisitor withVisitor}) {
    withVisitor ??= new StatementVisitor(this);
    return statement.accept(withVisitor);
  }

  AssigningContext enterAssigning(TSExpression value) =>
      new AssigningContext(this, value);

  CascadingContext enterCascade(TSExpression target) =>
      new CascadingContext(this, target);

  exitAssignament() => this;

  FormalParameterCollector collectParameters(FormalParameterList params) {
    FormalParameterCollector res = new FormalParameterCollector(this);
    (params?.parameters ?? []).forEach((p) {
      p.accept(res);
    });
    return res;
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

  @override
  TSBody visitEmptyFunctionBody(EmptyFunctionBody node) {
    return new TSBody(statements: [], withBrackets: withBrackets);
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

  @override
  TSStatement visitFunctionDeclarationStatement(
      FunctionDeclarationStatement node) {
    FunctionDeclarationContext functionDeclarationContext =
        new FunctionDeclarationContext(_context, node.functionDeclaration,
            topLevel: false);
    return functionDeclarationContext.translate();
  }

  @override
  TSStatement visitExpressionStatement(ExpressionStatement node) {
    return new TSExpressionStatement(
        _context.processExpression(node.expression));
  }

  @override
  TSStatement visitVariableDeclarationStatement(
      VariableDeclarationStatement node) {
    return new TSVariableDeclarations(new List.from(node.variables.variables
        .map((v) => new TSVariableDeclaration(
            v.name.name,
            _context.processExpression(v.initializer),
            _context.typeManager.toTsType(node.variables.type?.type)))));
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
    return new FunctionExpressionContext(_context, node).translate();
  }

  @override
  TSExpression visitSimpleStringLiteral(SimpleStringLiteral node) {
    return new TSSimpleExpression(node.toSource()); // Preserve the same quotes
  }

  @override
  TSExpression visitNullLiteral(NullLiteral node) {
    return new TSSimpleExpression('null');
  }


  @override
  TSExpression visitListLiteral(ListLiteral node) {
    return new TSList(new List.from(node.elements.map((e)=>_context.processExpression(e))));
  }

  @override
  TSExpression visitBinaryExpression(BinaryExpression node) {
    // Here we should check if
    // 1. we know what type is the left op =>
    //   1.1 if it's a natural type => use natural TS operator
    //   1.2 if it's another type and there's an user defined operator => use it
    // 2. use the dynamic runtime call to operator that does the above checks at runtime

    TSExpression leftExpression = _context.processExpression(node.leftOperand);
    TSExpression rightExpression =
        _context.processExpression(node.rightOperand);

    if (TypeManager.isNativeType(node.leftOperand.bestType) ||
        !node.operator.isUserDefinableOperator) {
      return new TSBinaryExpression(
          leftExpression, node.operator.lexeme.toString(), rightExpression);
    }

    if (node.leftOperand.bestType is InterfaceType) {
      InterfaceType cls = node.leftOperand.bestType as InterfaceType;
      MethodElement method = findMethod(cls, node.operator.lexeme);
      assert(method != null,
          'Operator ${node.operator} can be used only if defined in ${cls.name}');
      return new TSInvoke(
          new TSSquareExpression(
              leftExpression, _operatorName(method, node.operator)),
          [rightExpression]);
    }

    return new TSInvoke(new TSSimpleExpression('bare.invokeBinaryOperand'), [
      new TSSimpleExpression('"${node.operator.lexeme}"'),
      leftExpression,
      rightExpression
    ]);
  }

  TSExpression _operatorName(MethodElement method, Token op) {
    return new TSDotExpression(
        new TSSimpleExpression(method.enclosingElement.name),
        "OPERATOR_${op.type.name}");
  }

  @override
  TSExpression visitCascadeExpression(CascadeExpression node) {
    TSExpression target = new TSSimpleExpression('_');
    CascadingContext cascadingContext = _context.enterCascade(target);
    //CascadingVisitor cascadingVisitor = new CascadingVisitor(_context, target);
    TSBody body = new TSBody(statements: () sync* {
      yield* node.cascadeSections
          .map((e) => cascadingContext.processExpression(e))
          .map((e) => new TSExpressionStatement(e));
      yield new TSReturnStatement(target);
    }());
    return new TSInvoke(
        new TSBracketExpression(new TSFunction(
            parameters: [new TSParameter(name: '_')],
            body: body,
            returnType: _context.typeManager.toTsType(node.target.bestType))),
        [_context.processExpression(node.target)]);
  }

  @override
  TSExpression visitSimpleIdentifier(SimpleIdentifier node) {
    // Check for implicit this

    if (node.staticElement is PropertyAccessorElement) {
      PropertyInducingElement el =
          (node.staticElement as PropertyAccessorElement).variable;
      // check if current class has it
      if (_context.currentClass != null &&
          findField(
                  _context.currentClass._classDeclaration.element, node.name) ==
              el) {
        return _mayWrapInAssignament(
            new TSDotExpression(new TSSimpleExpression('this'), node.name));
      }
    }

    return _mayWrapInAssignament(new TSSimpleExpression(node.name));
  }

  @override
  TSExpression visitAssignmentExpression(AssignmentExpression node) {
    TSExpression value = _context.processExpression(node.rightHandSide);
    AssigningContext assigningContext = _context.enterAssigning(value);
    return assigningContext.processExpression(node.leftHandSide);
  }

  @override
  TSExpression visitParenthesizedExpression(ParenthesizedExpression node) {
    return new TSBracketExpression(_context.processExpression(node.expression));
  }

  @override
  TSExpression visitAsExpression(AsExpression node) {
    return new TSAsExpression(_context.processExpression(node.expression),
        _context.typeManager.toTsType(node.type.type));
  }

  @override
  TSExpression visitPropertyAccess(PropertyAccess node) {
    TSExpression target = node.isCascaded
        ? _context.cascadingTarget
        : _context.exitAssignament().processExpression(node.target);
    return asFieldAccess(target, node.propertyName);
  }

  @override
  TSExpression visitPrefixedIdentifier(PrefixedIdentifier node) {
    if (node.prefix.staticElement is PrefixElement) {
      PrefixElement prefix = node.prefix.staticElement;

      // Lookup library
      return new TSDotExpression(
          new TSSimpleExpression(
              _context.typeManager.namespaceForPrefix(prefix)),
          node.identifier.name);
    }
    return asFieldAccess(
        _context.processExpression(node.prefix), node.identifier);
  }

  TSExpression _mayWrapInAssignament(TSExpression expre) {
    if (_context.isAssigning) {
      return new TSAssignamentExpression(expre, _context.assigningValue);
    } else {
      return expre;
    }
  }

  TSExpression asFieldAccess(
      TSExpression expression, SimpleIdentifier identifier) {
    // If it's actually a property
    if (identifier.bestElement != null) {
      // Check if we can apply an override

      return _mayWrapInAssignament(
          new TSDotExpression(expression, identifier.name));
    } else {
      // Use the property accessor helper
      if (_context.isAssigning) {
        return new TSInvoke(new TSSimpleExpression('bare.writeProperty'), [
          expression,
          new TSSimpleExpression('"${identifier.name}"'),
          _context.assigningValue
        ]);
      } else {
        return new TSInvoke(new TSSimpleExpression('bare.readProperty'),
            [expression, new TSSimpleExpression('"${identifier.name}"')]);
      }
    }
  }

  @override
  TSExpression visitStringInterpolation(StringInterpolation node) {
    InterpolationElementVisitor visitor =
        new InterpolationElementVisitor(_context);
    return new TSStringInterpolation(
        new List.from(node.elements.map((m) => m.accept(visitor))));
  }

  @override
  TSExpression visitInstanceCreationExpression(
      InstanceCreationExpression node) {
    /**
     * If we know the constructor just callit
     * otherwise use the helper function
     */
    ArgumentListCollector collector = new ArgumentListCollector(_context);
    node.argumentList.accept(collector);
    ConstructorElement elem = node.constructorName.staticElement;
    if (elem != null) {
      return _newObjectWithConstructor(elem, node, collector);
    } else {
      assert(node.bestType != null,
          'We should know at least the type to call "new" here ?');
      TSType myType = _context.typeManager.toTsType(node.bestType);

      return new TSInvoke(
          new TSSimpleExpression('bare.createInstance'),
          new List()
            ..addAll([
              new TSTypeRef(myType),
              new TSSimpleExpression(node.constructorName?.name?.name != null
                  ? '"${node.constructorName?.name?.name}"'
                  : 'null'),
            ])
            ..addAll(collector.arguments),
          collector.namedArguments)
        ..asNew = true;
    }
  }

  TSExpression _newObjectWithConstructor(ConstructorElement ctor,
      InstanceCreationExpression node, ArgumentListCollector collector) {
    TSType myType = _context.typeManager.toTsType(ctor.enclosingElement.type);
    if (ctor.isFactory) {
      // Invoke as normal static method
      return new TSInvoke(new TSStaticRef(myType, ctor.name),
          collector.arguments, collector.namedArguments);
    } else if ((ctor.name?.length ?? 0) > 0) {
      // Invoke named constructor
      return new TSInvoke(new TSStaticRef(myType, ctor.name),
          collector.arguments, collector.namedArguments)
        ..asNew = true;
    } else {
      // Invoke normal constructor
      return new TSInvoke(
          new TSTypeRef(myType), collector.arguments, collector.namedArguments)
        ..asNew = true;
    }
  }

  @override
  TSExpression visitMethodInvocation(MethodInvocation node) {
    // Same as with constructor
    /**
     * If we know the constructor just callit
     * otherwise use the helper function
     */
    ArgumentListCollector collector = new ArgumentListCollector(_context);
    node.argumentList.accept(collector);
    ExecutableElement elem = node.methodName.staticElement;
    TSExpression target;
    if (node.target != null) {
      target = new TSDotExpression(
          _context.processExpression(node.target), node.methodName.name);
    } else {
      target = _context.processExpression(node.methodName);
    }

    if (elem != null) {
      // Invoke normal method
      return new TSInvoke(
          target, collector.arguments, collector.namedArguments);
    } else {
      return new TSInvoke(
          new TSSimpleExpression('bare.invokeMethod'),
          new List()
            ..addAll([
              target,
              new TSSimpleExpression('"${node.methodName.name}"'),
            ])
            ..addAll(collector.arguments),
          collector.namedArguments)
        ..asNew = true;
    }
  }
}

class ArgumentListCollector extends GeneralizingAstVisitor {
  Context _context;
  ArgumentListCollector(this._context);
  List<TSExpression> arguments = [];
  Map<String, TSExpression> namedArguments;

  void processArgumentList(ArgumentList arg) {
    arg.accept(this);
  }

  @override
  visitArgumentList(ArgumentList node) {
    node.arguments.forEach((n) {
      n.accept(this);
    });
  }

  @override
  visitNamedExpression(NamedExpression node) {
    namedArguments ??= {};
    namedArguments[node.name.label.name] =
        _context.processExpression(node.expression);
  }

  @override
  visitExpression(Expression node) {
    arguments.add(_context.processExpression(node));
  }
}

class InterpolationElementVisitor extends GeneralizingAstVisitor<TSNode> {
  Context _context;
  InterpolationElementVisitor(this._context);

  @override
  TSNode visitInterpolationExpression(InterpolationExpression node) {
    return new TSInterpolationExpression(
        _context.processExpression(node.expression));
  }

  @override
  TSNode visitInterpolationString(InterpolationString node) {
    return new TSSimpleExpression(node.value);
  }
}

class AssigningContext<A extends TSNode, B extends Context<A>>
    extends ChildContext<A, B, A> {
  TSExpression _value;

  TSExpression get assigningValue => _value;
  bool get isAssigning => true;

  AssigningContext(B parent, this._value) : super(parent);

  @override
  A translate() => parentContext.translate();

  exitAssignament() => parentContext.exitAssignament();
}

class CascadingContext<A extends TSNode, B extends Context<A>>
    extends ChildContext<A, B, A> {
  TSExpression _cascadingTarget;

  CascadingContext(B parent, this._cascadingTarget) : super(parent);

  @override
  A translate() => parentContext.translate();

  @override
  bool get isCascading => true;

  @override
  TSExpression get cascadingTarget => _cascadingTarget;
}

MethodElement findMethod(InterfaceType tp, String methodName) {
  MethodElement m = tp.getMethod(methodName);
  if (m != null) {
    return m;
  }

  if (tp.superclass != null) {
    return findMethod(tp.superclass, methodName);
  }

  return null;
}

FieldElement findField(ClassElement tp, String fieldName) {
  FieldElement m = tp.getField(fieldName);
  if (m != null) {
    return m;
  }

  if (tp.type.superclass?.element != null) {
    return findField(tp.type.superclass?.element, fieldName);
  }

  return null;
}

abstract class TopLevelContext<E extends TSNode> extends Context<E> {
  TypeManager typeManager;

  bool get topLevel => true;

  bool get isAssigning => false;
  bool get isCascading => false;
  TSExpression get assigningValue => null;
  TSExpression get cascadingTarget => null;
  ClassContext get currentClass => null;
}

abstract class ChildContext<A extends TSNode, P extends Context<A>,
    E extends TSNode> extends Context<E> {
  P parentContext;

  ChildContext(this.parentContext);

  TypeManager get typeManager => parentContext.typeManager;

  bool get topLevel => false;
  bool get isAssigning => parentContext.isAssigning;
  bool get isCascading => parentContext.isCascading;
  TSExpression get assigningValue => parentContext.assigningValue;
  TSExpression get cascadingTarget => parentContext.cascadingTarget;
  ClassContext get currentClass => parentContext.currentClass;
}

/**
 * Generation Context
 */

class LibraryContext extends TopLevelContext<TSLibrary> {
  LibraryElement _libraryElement;
  List<FileContext> _fileContexts;

  LibraryContext(this._libraryElement) {
    typeManager = new TypeManager(_libraryElement);
    _fileContexts = _libraryElement.units
        .map((cu) => cu.computeNode())
        .map((cu) => new FileContext(this, cu))
        .toList();
  }

  TSLibrary translate() {
    TSLibrary tsLibrary = new TSLibrary(_libraryElement.source.uri.toString());
    tsLibrary._children.addAll(_fileContexts.map((fc) => fc.translate()));

    tsLibrary.imports = new List.from(typeManager.allImports);
    return tsLibrary;
  }
}

class FileContext extends ChildContext<TSLibrary, LibraryContext, TSFile> {
  CompilationUnit _compilationUnit;
  List<Context> _topLevelContexts;

  FileContext(LibraryContext parent, this._compilationUnit) : super(parent) {
    TopLevelDeclarationVisitor visitor = new TopLevelDeclarationVisitor(this);
    _topLevelContexts = new List();
    _topLevelContexts.addAll(_compilationUnit.declarations
        .map((f) => f.accept(visitor))
        .where((x) => x != null));
  }

  List<TSNode> tsDeclarations;

  TSFile translate() {
    tsDeclarations = new List<TSNode>();
    List<TSNode> declarations =
        new List.from(_topLevelContexts.map((tlc) => tlc.translate()));
    tsDeclarations.addAll(declarations);
    return new TSFile(_compilationUnit, tsDeclarations);
  }
}

class TopLevelDeclarationVisitor extends GeneralizingAstVisitor<Context> {
  FileContext _fileContext;

  TopLevelDeclarationVisitor(this._fileContext);

  @override
  Context visitFunctionDeclaration(FunctionDeclaration node) {
    return new FunctionDeclarationContext(_fileContext, node);
  }

  @override
  Context visitClassDeclaration(ClassDeclaration node) {
    return new ClassContext(_fileContext, node);
  }
}

class FunctionExpressionContext
    extends ChildContext<TSNode, Context<TSNode>, TSFunction> {
  FunctionExpression _functionExpression;

  FunctionExpressionContext(Context parent, this._functionExpression)
      : super(parent);

  TSFunction translate() {
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
        topLevel: topLevel,
        typeParameters: typeParameters,
        withParameterCollector: parameterCollector,
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

class FunctionDeclarationContext
    extends ChildContext<TSNode, Context, TSFunction> {
  FunctionDeclaration _functionDeclaration;
  bool topLevel;

  TSType returnType;

  FunctionDeclarationContext(Context parentContext, this._functionDeclaration,
      {this.topLevel = true})
      : super(parentContext);

  @override
  TSFunction translate() {
    return processFunctionExpression(_functionDeclaration.functionExpression)
      ..name = _functionDeclaration.name.name
      ..topLevel = topLevel
      ..returnType = parentContext.typeManager
          .toTsType(_functionDeclaration?.returnType?.type);
  }
}

class ClassContext extends ChildContext<TSFile, FileContext, TSClass> {
  ClassDeclaration _classDeclaration;
  ClassContext get currentClass => this;
  ClassContext(Context parent, this._classDeclaration) : super(parent);

  TSClass _tsClass;

  TSClass get tsClass => _tsClass;

  @override
  TSClass translate() {
    _tsClass = new TSClass();
    ClassMemberVisitor visitor = new ClassMemberVisitor(this, _tsClass);
    _tsClass.name = _classDeclaration.name.name;

    if (_classDeclaration.extendsClause != null) {
      tsClass.superClass =
          typeManager.toTsType(_classDeclaration.extendsClause.superclass.type);
    }

    _tsClass.members = new List.from(_classDeclaration.members
        .map((m) => m.accept(visitor))
        .where((m) => m != null));

    // Create constructor interfaces
    visitor.namedConstructors.values.forEach((ConstructorDeclaration decl) {
      FormalParameterCollector parameterCollector =
          collectParameters(decl.parameters);

      parentContext.tsDeclarations.add(new TSClass(isInterface: true)
        ..name = '${_classDeclaration.name.name}_${decl.name.name}'
        ..members = [
          new TSFunction(
              asMethod: true,
              name: 'new',
              withParameterCollector: parameterCollector,
              returnType: new TSSimpleType(_classDeclaration.name.name)),
        ]);
    });

    return _tsClass;
  }
}

class ClassMemberVisitor extends GeneralizingAstVisitor<TSNode> {
  ClassContext _context;
  TSClass tsClass;
  ClassMemberVisitor(this._context, this.tsClass);
  Map<String, ConstructorDeclaration> namedConstructors = {};

  @override
  TSNode visitMethodDeclaration(MethodDeclaration node) {
    MethodContext methodContext = new MethodContext(_context, node);
    return methodContext.translate();
  }

  @override
  TSNode visitFieldDeclaration(FieldDeclaration node) {
    return new TSVariableDeclarations(
      new List.from(node.fields.variables.map((v) => new TSVariableDeclaration(
          v.name.name,
          _context.processExpression(v.initializer),
          _context.typeManager.toTsType(node.fields.type?.type)))),
      isField: true,
      isStatic: node.isStatic,
    );
  }

  @override
  TSNode visitConstructorDeclaration(ConstructorDeclaration node) {
    if (node.factoryKeyword != null) {
      // Return a static method declaration

      FormalParameterCollector collector =
          new FormalParameterCollector(_context);
      node.parameters.accept(collector);

      TSBody body = _context.processBody(node.body, withBrackets: false);
      InitializerCollector initializerCollector =
          new InitializerCollector(_context);
      List<TSStatement> initializers =
          initializerCollector.processInitializers(node.initializers);

      return new TSFunction(
        name: (node.name?.name?.length ?? 0) > 0 ? node.name.name : 'create',
        asMethod: true,
        isStatic: true,
        withParameterCollector: collector,
        body: body,
        initializers: initializers,
        returnType:
            _context.typeManager.toTsType(node.element.enclosingElement.type),
      );
    } else if (node.name != null) {
      namedConstructors[node.name.name] = node;

      // Create the static
      return _createNamedConstructor(node);
    } else {
      // Create a default constructor

      FormalParameterCollector collector =
          new FormalParameterCollector(_context);
      node.parameters.accept(collector);

      TSBody body = _context.processBody(node.body, withBrackets: false);

      InitializerCollector initializerCollector =
          new InitializerCollector(_context);
      List<TSStatement> initializers =
          initializerCollector.processInitializers(node.initializers);

      return new TSFunction(
        asMethod: true,
        initializers: initializers,
        asDefaultConstructor: true,
        callSuper: (_context._classDeclaration.element.type).superclass !=
            currentContext.typeProvider.objectType,
        withParameterCollector: collector,
        body: body,
      );
    }
  }

  TSNode _createNamedConstructor(ConstructorDeclaration node) {
    TSType ctorType = new TSSimpleType(
        '${_context._classDeclaration.name.name}_${node.name.name}');

    FormalParameterCollector parameterCollector =
        _context.collectParameters(node.parameters);

    TSBody body = _context.processBody(node.body, withBrackets: false);

    InitializerCollector initializerCollector =
        new InitializerCollector(_context);
    List<TSStatement> initializers =
        initializerCollector.processInitializers(node.initializers);

    String metName = '_${node.name.name}';

    TSExpression init = new TSInvoke(
        new TSBracketExpression(new TSFunction(
            body: new TSBody(statements: [
          new TSVariableDeclarations([
            new TSVariableDeclaration(
                'ctor',
                new TSDotExpression(
                    new TSStaticRef(
                        _context.typeManager
                            .toTsType(_context._classDeclaration.element.type),
                        'prototype'),
                    metName),
                null)
          ]),
          new TSExpressionStatement(new TSAssignamentExpression(
              new TSDotExpression(new TSSimpleExpression('ctor'), 'prototype'),
              new TSDotExpression(
                  new TSSimpleExpression(_context._classDeclaration.name.name),
                  'prototype'))),
          new TSReturnStatement(new TSAsExpression(
              new TSSimpleExpression('ctor'), new TSSimpleType('any'))),
        ], withBrackets: false))),
        []);

    List<TSNode> nodes = [
      // actual constructor
      new TSFunction(
        name: metName,
        withParameterCollector: parameterCollector,
        body: body,
        asMethod: true,
        initializers: initializers,
      ),
      // getter
      new TSVariableDeclarations(
        [new TSVariableDeclaration(node.name.name, init, ctorType)],
        isStatic: true,
        isField: true,
      ),
    ];

    return new TSNodes(nodes);
  }
}

class InitializerCollector extends GeneralizingAstVisitor<TSStatement> {
  Context _context;
  InitializerCollector(this._context);

  List<TSStatement> processInitializers(
      List<ConstructorInitializer> initializers) {
    if (initializers == null) {
      return null;
    }

    return new List.from(initializers.map((init) => init.accept(this)));
  }

  @override
  TSStatement visitSuperConstructorInvocation(SuperConstructorInvocation node) {
    TSExpression target;
    if (node.constructorName == null) {
      target = new TSSimpleExpression('super[bare.init]');
    } else {
      target = new TSSimpleExpression('super._${node.constructorName.name}');
    }

    ArgumentListCollector argumentListCollector =
        new ArgumentListCollector(_context)
          ..processArgumentList(node.argumentList);

    return new TSExpressionStatement(new TSInvoke(target,
        argumentListCollector.arguments, argumentListCollector.namedArguments));
  }

  @override
  TSStatement visitRedirectingConstructorInvocation(
      RedirectingConstructorInvocation node) {
    TSExpression target;
    if (node.constructorName == null) {
      target = new TSSimpleExpression('this[bare.init]');
    } else {
      target = new TSSimpleExpression('this._${node.constructorName.name}');
    }

    ArgumentListCollector argumentListCollector =
        new ArgumentListCollector(_context)
          ..processArgumentList(node.argumentList);

    return new TSExpressionStatement(new TSInvoke(target,
        argumentListCollector.arguments, argumentListCollector.namedArguments));
  }

  @override
  TSStatement visitConstructorFieldInitializer(
      ConstructorFieldInitializer node) {
    return new TSExpressionStatement(new TSAssignamentExpression(
        new TSSimpleExpression('this.${node.fieldName.name}'),
        _context.processExpression(node.expression)));
  }
}

class MethodContext extends ChildContext<TSClass, ClassContext, TSNode> {
  MethodDeclaration _methodDeclaration;

  MethodContext(ClassContext parent, this._methodDeclaration) : super(parent);

  @override
  TSNode translate() {
    List<TSTypeParameter> typeParameters;
    List<TSNode> result = [];

    if (_methodDeclaration.typeParameters != null) {
      typeParameters = new List.from(_methodDeclaration
          .typeParameters.typeParameters
          .map((t) => new TSTypeParameter(
              t.name.name, typeManager.toTsType(t.bound?.type))));
    } else {
      typeParameters = null;
    }

    // arguments
    FormalParameterCollector parameterCollector =
        new FormalParameterCollector(this);
    (_methodDeclaration.parameters?.parameters ?? []).forEach((p) {
      p.accept(parameterCollector);
    });

    // body
    TSBody body = processBody(_methodDeclaration.body, withBrackets: false);

    String name = _methodDeclaration.name.name;

    if (_methodDeclaration.isOperator) {
      TokenType tk = TokenType.all
          .firstWhere((tt) => tt.lexeme == _methodDeclaration.name.name);
      name = 'OPERATOR_${tk.name}';
      result.add(new TSVariableDeclarations([
        new TSVariableDeclaration(
            name,
            new TSSimpleExpression('Symbol("${_methodDeclaration.name}")'),
            new TSSimpleType('symbol'))
      ], isField: true, isStatic: true));
      name = "[${parentContext._classDeclaration.name}.${name}]";
    }

    result.add(new TSFunction(
      name: name,
      topLevel: topLevel,
      typeParameters: typeParameters,
      asMethod: true,
      isGetter: _methodDeclaration.isGetter,
      isSetter: _methodDeclaration.isSetter,
      body: body,
      withParameterCollector: parameterCollector,
    ));

    return new TSNodes(result);
  }
}
