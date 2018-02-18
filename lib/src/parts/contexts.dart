part of '../code_generator2.dart';

class Overrides {
  var _yaml;
  var _overrides;

  Overrides(this._yaml) {
    this._overrides = _yaml['overrides'] ?? {};
  }

  static Future<Overrides> forCurrentContext() async {
    res.Resource resource = new res.Resource('package:dart2ts/src/overrides.yml');
    String str = await resource.readAsString();

    return new Overrides(loadYaml(str));
  }

  String resolvePrefix(TypeManager m, String module, [String origPrefix = null]) {
    if (module == 'global') {
      return "";
    } else if (module != null) {
      if (module.startsWith('module:')) {
        return m.namespaceFor(uri: module, modulePath: module.substring(7));
      } else if (module.startsWith('dart:') || module.startsWith('package:')) {
        return m.namespace(getLibrary(currentContext, module));
      }
    } else {
      return origPrefix;
    }
  }

  TSExpression checkMethod(TypeManager typeManager, DartType type, String methodName, TSExpression tsTarget,
      {TSExpression orElse()}) {
    var classOverrides = _findClassOverride(type);

    if (classOverrides == null) {
      return orElse();
    }

    String methodOverrides = (classOverrides['methods'] ?? {})[methodName];

    if (methodOverrides == null) {
      return orElse();
    }

    String module = classOverrides['to']['from'];

    String prefix = resolvePrefix(typeManager, module);

    // Square or dot ?

    if (methodOverrides.startsWith('[')) {
      String sym = methodOverrides.substring(1, methodOverrides.length - 1);
      sym = sym.replaceAllMapped(new RegExp(r"\${([^}]*)}"), (Match m) {
        String n = m.group(1);
        if (n == "prefix") {
          return prefix;
        }

        return "\${${n}}";
      });
      return new TSIndexExpression(tsTarget, new TSSimpleExpression(sym));
    } else {
      return new TSDotExpression(tsTarget, methodOverrides);
    }
  }

  String checkProperty(TypeManager typeManager, DartType type, String name) {
    var classOverrides = _findClassOverride(type);

    if (classOverrides == null) {
      return name;
    }

    String propsOverrides = (classOverrides['properties'] ?? {})[name];

    if (propsOverrides == null) {
      return name;
    }

    return propsOverrides;
  }

  _findClassOverride(DartType type) {
    LibraryElement from = type?.element?.library;
    Uri fromUri = from?.source?.uri;

    _logger.fine("Checking type for {${fromUri}}${type?.name}");
    if (type == null || fromUri == null) {
      return null;
    }

    var libOverrides = _overrides[fromUri.toString()];
    if (libOverrides == null) {
      return null;
    }

    return (libOverrides['classes'] ?? {})[type.name];
  }

  TSType checkType(TypeManager typeManager, String origPrefix, DartType type, bool noTypeArgs, {TSType orElse()}) {
    var classOverrides = _findClassOverride(type);

    if (classOverrides == null || classOverrides['to'] == null || (classOverrides['to'] as YamlMap)['class'] == null) {
      return orElse();
    }

    String module = classOverrides['to']['from'];

    String p = resolvePrefix(typeManager, module, origPrefix);
    if (p != null && p.isNotEmpty) {
      p = "${p}.";
    }

    String actualName = classOverrides['to']['class'];

    if (!noTypeArgs && type is ParameterizedType && type.typeArguments.isNotEmpty) {
      return new TSGenericType("${p}${actualName}", type.typeArguments.map((t) => typeManager.toTsType(t)));
    } else {
      return new TSSimpleType("${p}${actualName}", !TypeManager.isNativeType(type));
    }
  }

  TSExpression checkOperator(
      Context<TSNode> context, String op, Expression target, Expression index, TSExpression orElse()) {
    var classOverrides = _findClassOverride(target.bestType);

    if (classOverrides == null) return orElse();

    var operators = classOverrides['operators'];

    if (context.isAssigning) {
      op = "${op}=";
    }

    if (operators == null || operators[op] == null) {
      return orElse();
    }

    // replace with method invocation
    String methodName = operators[op];

    if (context.isAssigning) {
      Context noAssign = context.exitAssignament();
      return new TSInvoke(new TSDotExpression(noAssign.processExpression(target), methodName), [
        noAssign.processExpression(index),
        context.assigningValue,
      ]);
    } else {
      return new TSInvoke(
          new TSDotExpression(context.processExpression(target), methodName), [context.processExpression(index)]);
    }
  }

  TSExpression checkConstructor(Context<TSNode> context, DartType targetType, ConstructorElement ctor,
      ArgumentListCollector collector, TSExpression orElse()) {
    var classOverrides = _findClassOverride(targetType);
    if (classOverrides == null || classOverrides['constructors'] == null) {
      return orElse();
    }

    var constructor = classOverrides['constructors'][ctor.name ?? "\$default"];
    if (constructor == null) {
      return orElse();
    }

    String newName;
    bool isFactory;
    if (constructor is String) {
      newName = constructor;
      isFactory = false;
    } else {
      newName = constructor['name'];
      isFactory = constructor['factory'];
    }

    TSType tsType = context.typeManager.toTsType(targetType);

    return new TSInvoke(new TSStaticRef(tsType, newName), collector.arguments, collector.namedArguments)
      ..asNew = !isFactory;
  }
}

abstract class Context<T extends TSNode> {
  TypeManager get typeManager;

  bool get topLevel;

  bool get isAssigning;

  bool get isCascading;

  TSExpression get cascadingTarget;

  TSExpression get assigningValue;

  ClassContext get currentClass;

  Expression get cascadingExpression;

  void translate();

  E processExpression<E extends TSExpression>(Expression expression) {
    if (expression == null) {
      return null;
    }
    return expression.accept(new ExpressionVisitor(this)) as E;
  }

  TSFunction processFunctionExpression(FunctionExpression functionExpression) {
    return processExpression<TSFunction>(functionExpression);
  }

  TSBody processBody(FunctionBody body, {bool withBrackets: false, bool withReturn: true}) {
    return body.accept(new BodyVisitor(
      this,
      withBrackets: withBrackets,
      withReturn: withReturn,
    ));
  }

  Iterable<TSStatement> processBlock(Block block) {
    StatementVisitor visitor = new StatementVisitor(this);
    return new List.from(
        block.statements.map((s) => processStatement(s, withVisitor: visitor)).where((s) => s != null));
  }

  TSStatement processStatement(Statement statement, {StatementVisitor withVisitor}) {
    withVisitor ??= new StatementVisitor(this);
    return statement.accept(withVisitor);
  }

  AssigningContext enterAssigning(TSExpression value) => new AssigningContext(this, value);

  CascadingContext enterCascade(Expression dartTarget, TSExpression target) =>
      new CascadingContext(this, target, dartTarget);

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
  bool withReturn;

  BodyVisitor(this._context, {this.withBrackets: false, this.withReturn: true});

  @override
  TSBody visitBlockFunctionBody(BlockFunctionBody node) {
    return new TSBody(statements: _context.processBlock(node.block), withBrackets: withBrackets);
  }

  @override
  TSBody visitExpressionFunctionBody(ExpressionFunctionBody node) {
    TSExpression expr = _context.processExpression(node.expression);
    return new TSBody(
        statements: [withReturn ? new TSReturnStatement(expr) : new TSExpressionStatement(expr)],
        withBrackets: withBrackets);
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
  TSStatement visitYieldStatement(YieldStatement node) {
    return new TSYieldStatement(_context.processExpression(node.expression), many: node.star != null);
  }

  @override
  TSStatement visitTryStatement(TryStatement node) {
    return new TSTryStatement(node.body.accept(this), new List.from(node.catchClauses.map((c) => c.accept(this))),
        node.finallyBlock?.accept(this));
  }

  @override
  TSStatement visitCatchClause(CatchClause node) {
    return new TSCatchStatement(
        node.exceptionParameter.name, _context.typeManager.toTsType(node.exceptionType?.type), node.body.accept(this));
  }

  @override
  TSStatement visitStatement(Statement node) {
    return new TSUnknownStatement(node);
  }

  @override
  TSStatement visitBreakStatement(BreakStatement node) {
    return new TSExpressionStatement(new TSSimpleExpression('break'));
  }

  @override
  TSStatement visitFunctionDeclarationStatement(FunctionDeclarationStatement node) {
    FunctionDeclarationContext functionDeclarationContext =
        new FunctionDeclarationContext(_context, node.functionDeclaration, topLevel: false);
    return (functionDeclarationContext..translate()).tsFunction;
  }

  @override
  TSStatement visitIfStatement(IfStatement node) {
    return new TSIfStatement(
        _context.processExpression(node.condition), node.thenStatement.accept(this), node.elseStatement?.accept(this));
  }

  @override
  TSStatement visitForStatement(ForStatement node) {
    TSNode initExpr;
    if (node.variables != null) {
      initExpr = new TSVariableDeclarations(
          new List.from(node.variables.variables.map((v) => new TSVariableDeclaration(v.name.name,
              _context.processExpression(v.initializer), _context.typeManager.toTsType(node.variables.type?.type)))),
          isField: false);
    } else {
      initExpr = null;
    }

    return new TSForStatement(
        initExpr,
        _context.processExpression(node.initialization),
        _context.processExpression(node.condition),
        node.updaters.map((e) => _context.processExpression(e)).toList(),
        node.body.accept(this));
  }

  @override
  TSStatement visitForEachStatement(ForEachStatement node) {
    return new TSForEachStatement(toDeclaredIdentifier(node.loopVariable, loopVariable: true),
        _context.processExpression(node.iterable), node.body.accept(this),
        isAsync: node.awaitKeyword != null);
  }

  @override
  TSStatement visitWhileStatement(WhileStatement node) {
    return new TSWhileStatement(_context.processExpression(node.condition), node.body.accept(this));
  }

  @override
  TSStatement visitDoStatement(DoStatement node) {
    return new TSDoWhileStatement(_context.processExpression(node.condition), node.body.accept(this));
  }

  @override
  TSDeclaredIdentifier toDeclaredIdentifier(DeclaredIdentifier node, {bool loopVariable: false}) {
    return new TSDeclaredIdentifier(
        node.identifier.name, loopVariable ? null : _context.typeManager.toTsType(node.type.type));
  }

  @override
  TSStatement visitBlock(Block node) {
    return new TSBody(statements: _context.processBlock(node), newLine: false);
  }

  @override
  TSStatement visitExpressionStatement(ExpressionStatement node) {
    return new TSExpressionStatement(_context.processExpression(node.expression));
  }

  @override
  TSStatement visitSwitchStatement(SwitchStatement node) {
    return new TSSwitchStatement(
        _context.processExpression(node.expression), new List.from(node.members.map((m) => m.accept(this))));
  }

  @override
  TSStatement visitSwitchCase(SwitchCase node) {
    return new TSCase(
        _context.processExpression(node.expression), new List.from(node.statements.map((s) => s.accept(this))));
  }

  @override
  TSStatement visitSwitchDefault(SwitchDefault node) {
    return new TSCase.defaultCase(new List.from(node.statements.map((s) => s.accept(this))));
  }

  @override
  TSStatement visitVariableDeclarationStatement(VariableDeclarationStatement node) {
    return new TSVariableDeclarations(new List.from(node.variables.variables.map((v) => new TSVariableDeclaration(
        v.name.name,
        _context.processExpression(v.initializer),
        _context.typeManager.toTsType(node.variables.type?.type)))));
  }
}

enum OperatorType { BINARY, PREFIX, SUFFIX }

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
    return (new FunctionExpressionContext(_context, node)..translate()).tsFunction;
  }

  @override
  TSExpression visitSimpleStringLiteral(SimpleStringLiteral node) {
    return new TSStringLiteral(node.value.replaceAll('\n', '\\n'), node.isSingleQuoted);
  }

  @override
  TSExpression visitAdjacentStrings(AdjacentStrings node) {
    return node.strings.map((x) => x.accept(this)).reduce((a, b) => new TSBinaryExpression(a, '+', b));
  }

  @override
  TSExpression visitBooleanLiteral(BooleanLiteral node) {
    return new TSSimpleExpression(node.value ? 'true' : 'false');
  }

  @override
  TSExpression visitIsExpression(IsExpression node) {
    return new TSInstanceOf(
        node.expression.accept(this), new TSTypeExpr(_context.typeManager.toTsType(node.type.type), false));
  }

  @override
  TSExpression visitThrowExpression(ThrowExpression node) {
    return new TSThrow(node.expression.accept(this));
  }

  @override
  TSExpression visitAwaitExpression(AwaitExpression node) {
    return new TSAwaitExpression(node.expression.accept(this));
  }

  @override
  TSExpression visitNullLiteral(NullLiteral node) {
    return new TSSimpleExpression('null');
  }

  @override
  TSExpression visitMapLiteral(MapLiteral node) {
    DartType dartMap = getType(currentContext, 'dart:core', 'Map');

    dartMap = currentContext.typeSystem.instantiateType(dartMap, (node.bestType as ParameterizedType).typeArguments);

    return new TSInvoke(new TSTypeExpr(_context.typeManager.toTsType(dartMap)), [
      new TSList(node.entries.map((entry) {
        return new TSList([_context.processExpression(entry.key), _context.processExpression(entry.value)]);
      }).toList())
    ])
      ..asNew = true;
  }

  @override
  TSExpression visitListLiteral(ListLiteral node) {
    return new TSList(new List.from(node.elements.map((e) => _context.processExpression(e))));
  }

  @override
  TSExpression visitPrefixExpression(PrefixExpression node) {
    return handlePrefixSuffixExpression(node.operand, node.operator, OperatorType.PREFIX);
  }

  TSExpression handlePrefixSuffixExpression(Expression operand, Token operator, OperatorType opType) {
    TSExpression expr = _context.processExpression(operand);

    if (TypeManager.isNativeType(operand.bestType) || !operator.isUserDefinableOperator) {
      if (opType == OperatorType.PREFIX)
        return new TSPrefixOperandExpression(operator.lexeme, expr);
      else
        return new TSPostfixOperandExpression(operator.lexeme, expr);
    }

    if (operand.bestType is InterfaceType && !TypeManager.isNativeType(operand.bestType)) {
      InterfaceType cls = operand.bestType as InterfaceType;
      MethodElement method = findMethod(cls, operator.lexeme);
      assert(method != null, 'Operator ${operator.lexeme} can be used only if defined in ${operand.bestType.name}');
      return new TSInvoke(new TSDotExpression(expr, _operatorName(method, operator, opType)), []);
    }

    return new TSInvoke(new TSSimpleExpression('bare.invokeUnaryOperand'), [
      new TSSimpleExpression('"${operator.lexeme}"'),
      new TSSimpleExpression(opType == OperatorType.PREFIX ? 'bare.OperatorType.PREFIX' : 'bare.OperatorType.SUFFIX'),
      expr
    ]);
  }

  @override
  TSExpression visitPostfixExpression(PostfixExpression node) {
    return handlePrefixSuffixExpression(node.operand, node.operator, OperatorType.SUFFIX);
  }

  @override
  TSExpression visitBinaryExpression(BinaryExpression node) {
    // Here we should check if
    // 1. we know what type is the left op =>
    //   1.1 if it's a natural type => use natural TS operator
    //   1.2 if it's another type and there's an user defined operator => use it
    // 2. use the dynamic runtime call to operator that does the above checks at runtime

    TSExpression leftExpression = _context.processExpression(node.leftOperand);
    TSExpression rightExpression = _context.processExpression(node.rightOperand);

    if (node.operator.type != TokenType.TILDE_SLASH &&
        (node.operator.type != TokenType.STAR || node.leftOperand.bestType != currentContext.typeProvider.stringType) &&
        (TypeManager.isNativeType(node.leftOperand.bestType) || !node.operator.isUserDefinableOperator)) {
      return new TSBinaryExpression(leftExpression, node.operator.lexeme.toString(), rightExpression);
    }

    if (node.leftOperand.bestType is InterfaceType && !TypeManager.isNativeType(node.leftOperand.bestType)) {
      InterfaceType cls = node.leftOperand.bestType as InterfaceType;
      MethodElement method = findMethod(cls, node.operator.lexeme);
      assert(method != null, 'Operator ${node.operator} can be used only if defined in ${cls.name}');
      return new TSInvoke(
          new TSDotExpression(leftExpression, _operatorName(method, node.operator, OperatorType.BINARY)),
          [rightExpression]);
    }

    return new TSInvoke(new TSSimpleExpression('bare.invokeBinaryOperand'),
        [new TSSimpleExpression('"${node.operator.lexeme}"'), leftExpression, rightExpression]);
  }

  String _operatorName(MethodElement method, Token op, OperatorType type) {
    String name;
    switch (type) {
      case OperatorType.PREFIX:
        name = "OPERATOR_PREFIX_${op.type.name}";
        break;
      case OperatorType.SUFFIX:
        name = "OPERATOR_SUFFIX_${op.type.name}";
        break;
      case OperatorType.BINARY:
        name = 'OPERATOR_${op.type.name}';
        break;
    }
    return name;
  }

  @override
  TSExpression visitCascadeExpression(CascadeExpression node) {
    TSExpression target = new TSSimpleExpression('_');
    CascadingContext cascadingContext = _context.enterCascade(node.target, target);
    //CascadingVisitor cascadingVisitor = new CascadingVisitor(_context, target);
    TSBody body = new TSBody(statements: () sync* {
      yield* node.cascadeSections
          .map((e) => cascadingContext.processExpression(e))
          .map((e) => new TSExpressionStatement(e));
      yield new TSReturnStatement(target);
    }());
    return new TSInvoke(
        new TSBracketExpression(new TSFunction(_context.typeManager,
            parameters: [new TSParameter(name: '_')],
            body: body,
            isExpression: true,
            returnType: _context.typeManager.toTsType(node.target.bestType))),
        [_context.processExpression(node.target)]);
  }

  @override
  TSExpression visitThisExpression(ThisExpression node) {
    return new TSSimpleExpression('this');
  }

  @override
  TSExpression visitFunctionExpressionInvocation(FunctionExpressionInvocation node) {
    ArgumentListCollector collector = new ArgumentListCollector(_context, node.bestElement);
    collector.processArgumentList(node.argumentList);
    TSExpression target = new TSBracketExpression(_context.processExpression(node.function));

    return new TSInvoke(target, collector.arguments, collector.namedArguments);
  }

  @override
  TSExpression visitConditionalExpression(ConditionalExpression node) {
    return new TSConditionalExpression(_context.processExpression(node.condition),
        _context.processExpression(node.thenExpression), _context.processExpression(node.elseExpression));
  }

  @override
  TSExpression visitIndexExpression(IndexExpression node) {
    // TODO: handle overridden operator
    return _context.typeManager.checkOperator(
        _context,
        '[]',
        node.target,
        node.index,
        () => _mayWrapInAssignament(new TSIndexExpression(_context.exitAssignament().processExpression(node.target),
            _context.exitAssignament().processExpression(node.index))));
  }

  @override
  TSExpression visitSimpleIdentifier(SimpleIdentifier node) {
    // Check for implicit this

    String name = node.name;

    DartType currentClassType = _context.currentClass?._classDeclaration?.element?.type;
    if (node.staticElement is PropertyAccessorElement) {
      PropertyInducingElement el = (node.staticElement as PropertyAccessorElement).variable;

      if (el.enclosingElement is ClassElement) {
        name = _context.typeManager.checkProperty((el.enclosingElement as ClassElement).type, node.name);
      }

      // check if current class has it
      if (_context.currentClass != null &&
          findField(_context.currentClass._classDeclaration.element, node.name) == el) {
        TSExpression tgt;
        if (el.isStatic) {
          tgt = new TSTypeExpr(_context.typeManager.toTsType(currentClassType), false);
        } else {
          tgt = new TSSimpleExpression('this');
        }
        return _mayWrapInAssignament(new TSDotExpression(tgt, name));
      }
    } else if (node.staticElement is MethodElement) {
      MethodElement el = node.staticElement;

      if (_context.currentClass != null && findMethod(currentClassType, node.name) == el) {
        TSExpression tgt;
        if (el.isStatic) {
          tgt = new TSTypeExpr(_context.typeManager.toTsType(currentClassType), false);
        } else {
          tgt = new TSSimpleExpression('this');
        }

        TSExpression expr = _context.typeManager.checkMethod(
            el.enclosingElement.type, node.name, new TSSimpleExpression('this'),
            orElse: () => new TSDotExpression(tgt, node.name));

        return _mayWrapInAssignament(expr);
      }
    }

    // Resolve names otherwisely ( <- I know this term doesn't exist, but I like it)

    if (node.bestElement is ExecutableElement) {
      // need resolve prefix
      name = _context.typeManager.toTsName(node.bestElement);
    }

    return _mayWrapInAssignament(new TSSimpleExpression(name));
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
    return new TSAsExpression(
        _context.processExpression(node.expression), _context.typeManager.toTsType(node.type.type));
  }

  @override
  TSExpression visitPropertyAccess(PropertyAccess node) {
    TSExpression target =
        node.isCascaded ? _context.cascadingTarget : _context.exitAssignament().processExpression(node.target);
    return asFieldAccess(target, node.propertyName);
  }

  @override
  TSExpression visitPrefixedIdentifier(PrefixedIdentifier node) {
    if (node.prefix.staticElement is PrefixElement) {
      PrefixElement prefix = node.prefix.staticElement;

      // Lookup library
      String prefixStr = _context.typeManager.namespaceForPrefix(prefix);

      // Handle references to top level external variables or getters and setters
      if (node.identifier.bestElement is PropertyAccessorElement) {
        prefixStr = "${prefixStr}.module";
      }

      return _mayWrapInAssignament(new TSDotExpression(new TSSimpleExpression(prefixStr), node.identifier.name));
    }
    return asFieldAccess(_context.exitAssignament().processExpression(node.prefix), node.identifier);
  }

  TSExpression _mayWrapInAssignament(TSExpression expre) {
    if (_context.isAssigning) {
      return new TSAssignamentExpression(expre, _context.assigningValue);
    } else {
      return expre;
    }
  }

  TSExpression asFieldAccess(TSExpression expression, SimpleIdentifier identifier) {
    // If it's actually a property
    if (identifier.bestElement != null) {
      // Check if we can apply an override

      String name = identifier.name;

      name = _context.typeManager.checkProperty((identifier.bestElement.enclosingElement as ClassElement).type, name);

      return _mayWrapInAssignament(new TSDotExpression(expression, name));
    } else {
      // Use the property accessor helper
      if (_context.isAssigning) {
        return new TSInvoke(new TSSimpleExpression('bare.writeProperty'),
            [expression, new TSSimpleExpression('"${identifier.name}"'), _context.assigningValue]);
      } else {
        return new TSInvoke(
            new TSSimpleExpression('bare.readProperty'), [expression, new TSSimpleExpression('"${identifier.name}"')]);
      }
    }
  }

  @override
  TSExpression visitStringInterpolation(StringInterpolation node) {
    InterpolationElementVisitor visitor = new InterpolationElementVisitor(_context);
    return new TSStringInterpolation(new List.from(node.elements.map((m) => m.accept(visitor))));
  }

  @override
  TSExpression visitInstanceCreationExpression(InstanceCreationExpression node) {
    /**
     * If we know the constructor just callit
     * otherwise use the helper function
     */
    ArgumentListCollector collector = new ArgumentListCollector(_context, null);
    node.argumentList.accept(collector);
    ConstructorElement elem = node.constructorName.staticElement;
    if (elem != null) {
      return _newObjectWithConstructor(elem, node, collector);
    } else {
      assert(node.bestType != null, 'We should know at least the type to call "new" here ?');
      TSType myType = _context.typeManager.toTsType(node.bestType);

      return new TSInvoke(
          new TSSimpleExpression('bare.createInstance'),
          new List()
            ..addAll([
              new TSTypeRef(myType),
              new TSSimpleExpression(
                  node.constructorName?.name?.name != null ? '"${node.constructorName?.name?.name}"' : 'null'),
            ])
            ..addAll(collector.arguments),
          collector.namedArguments)
        ..asNew = true;
    }
  }

  TSExpression _newObjectWithConstructor(
      ConstructorElement ctor, InstanceCreationExpression node, ArgumentListCollector collector) {
    return _context.typeManager.checkConstructor(_context, node.bestType, ctor, collector, () {
      TSType myType = _context.typeManager.toTsType(node.bestType);
      TSExpression target;

      bool asNew = (!ctor.isFactory || ctor.isExternal);

      if ((ctor.name?.isEmpty ?? true) && asNew) {
        target = new TSTypeRef(myType);
      } else {
        String factoryName = ctor.name ?? "";
        if (factoryName.isEmpty) {
          factoryName = r"$create";
        }
        target = new TSStaticRef(myType, factoryName);
      }

      return new TSInvoke(target, collector.arguments, collector.namedArguments)..asNew = asNew;
    });
  }

  @override
  TSExpression visitMethodInvocation(MethodInvocation node) {
    // Handle special case for string interpolators

    DartObject tsMeta = getAnnotation(node.methodName?.bestElement?.metadata, isTS);
    bool interpolate = tsMeta?.getField('stringInterpolation')?.toBoolValue() ?? false;
    if (interpolate) {
      TSNode arg = node.argumentList.arguments.single.accept(this);
      TSStringInterpolation stringInterpolation;
      if (arg is TSStringInterpolation) {
        stringInterpolation = arg;
      } else if (arg is TSStringLiteral) {
        stringInterpolation = new TSStringInterpolation([new TSSimpleExpression(arg.stringValue)]);
      }
      stringInterpolation.tag = _context.typeManager.toTsName(node.methodName.bestElement);
      return stringInterpolation;
    }

    // Same as with constructor
    /**
     * If we know the constructor just callit
     * otherwise use the helper function
     */
    ArgumentListCollector collector = new ArgumentListCollector(_context, node.methodName.bestElement);
    node.argumentList.accept(collector);
    Element elem = node.methodName.staticElement;
    TSExpression target;
    TSExpression method;
    if (_context.isCascading) {
      target = _context.cascadingTarget;
      method = _context.typeManager.checkMethod(_context.cascadingExpression.bestType, node.methodName.name, target,
          orElse: () => new TSDotExpression(target, node.methodName.name));
    } else if (node.target != null) {
      if (node.target is SimpleIdentifier && (node.target as SimpleIdentifier).bestElement is PrefixElement) {
        Element el = (node.target as SimpleIdentifier).bestElement;
        target = new TSSimpleExpression('null');

        String name = node.methodName.name;

        // use "module." for top level module getter (if they aren't external)
        if (node.methodName.bestElement is PropertyAccessorElement &&
            getAnnotation(node.methodName.bestElement.metadata, isJS) == null) {
          name = "module.${name}";
        }

        method = new TSDotExpression(new TSSimpleExpression(_context.typeManager.namespaceForPrefix(el)), name);
      } else {
        target = _context.processExpression(node.target);

        // Check for method substitution
        method = _context.typeManager.checkMethod(node.target.bestType, node.methodName.name, target,
            orElse: () => new TSDotExpression(target, node.methodName.name));
      }
    } else {
      target = new TSSimpleExpression('null');
      method = _context.processExpression(node.methodName);
    }

    if (elem != null) {
      // Invoke normal method / function
      return new TSInvoke(method, collector.arguments, collector.namedArguments);
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
        ..asNew = false;
    }
  }
}

class ArgumentListCollector extends GeneralizingAstVisitor {
  Context _context;

  //ExecutableElement _method;
  Iterable<ParameterElement> _parameters;
  ParameterElement _currentParam;

  ArgumentListCollector(this._context, Element meth) {
    if (meth is ExecutableElement) {
      _parameters = meth.parameters;
    } else if (meth is VariableElement) {
      DartType t = meth.type;
      if (t is FunctionType) {
        _parameters = t.parameters;
      }
    }
  }

  List<TSExpression> arguments = [];
  Map<String, TSExpression> namedArguments;

  void processArgumentList(ArgumentList arg) {
    arg.accept(this);
  }

  @override
  visitArgumentList(ArgumentList node) {
    // Normal args
    Iterator<ParameterElement> pars = _parameters?.iterator;

    node.arguments.forEach((n) {
      bool hasNext = pars?.moveNext() ?? false;
      _currentParam = pars?.current;
      if (!hasNext) {
        pars = null;
      }
      n.accept(this);
    });
  }

  @override
  visitNamedExpression(NamedExpression node) {
    namedArguments ??= {};
    namedArguments[node.name.label.name] = _context.processExpression(node.expression);
  }

  @override
  visitExpression(Expression node) {
    TSExpression expr = _context.processExpression(node);
    if (getAnnotation(_currentParam?.metadata, isVarargs) != null) {
      expr = new TSSpread(expr);
    }
    arguments.add(expr);
  }
}

class InterpolationElementVisitor extends GeneralizingAstVisitor<TSNode> {
  Context _context;

  InterpolationElementVisitor(this._context);

  @override
  TSNode visitInterpolationExpression(InterpolationExpression node) {
    return new TSInterpolationExpression(_context.processExpression(node.expression));
  }

  @override
  TSNode visitInterpolationString(InterpolationString node) {
    return new TSSimpleExpression(node.value.replaceAll('\n', '\\n'));
  }
}

class AssigningContext<A extends TSNode, B extends Context<A>> extends ChildContext<A, B, A> {
  TSExpression _value;

  TSExpression get assigningValue => _value;

  bool get isAssigning => true;

  AssigningContext(B parent, this._value) : super(parent);

  @override
  void translate() => parentContext.translate();

  exitAssignament() => parentContext.exitAssignament();
}

class CascadingContext<A extends TSNode, B extends Context<A>> extends ChildContext<A, B, A> {
  TSExpression _cascadingTarget;
  Expression _target;

  CascadingContext(B parent, this._cascadingTarget, this._target) : super(parent);

  @override
  void translate() => parentContext.translate();

  @override
  bool get isCascading => true;

  @override
  TSExpression get cascadingTarget => _cascadingTarget;

  @override
  Expression get cascadingExpression => _target;
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

  Expression get cascadingExpression => null;

  ClassContext get currentClass => null;
}

abstract class ChildContext<A extends TSNode, P extends Context<A>, E extends TSNode> extends Context<E> {
  P parentContext;

  ChildContext(this.parentContext);

  TypeManager get typeManager => parentContext.typeManager;

  bool get topLevel => false;

  bool get isAssigning => parentContext.isAssigning;

  bool get isCascading => parentContext.isCascading;

  TSExpression get assigningValue => parentContext.assigningValue;

  TSExpression get cascadingTarget => parentContext.cascadingTarget;

  Expression get cascadingExpression => parentContext.cascadingExpression;

  ClassContext get currentClass => parentContext.currentClass;
}

class Config {
  String modulePrefix;
  String moduleSuffix;

  Config({this.modulePrefix = '../node_modules/', this.moduleSuffix = '.js'});
}

/**
 * Generation Context
 */

class LibraryContext extends TopLevelContext<TSLibrary> {
  LibraryElement _libraryElement;

  //List<FileContext> _fileContexts;
  Overrides _overrides;
  TSLibrary tsLibrary;
  Config _config;

  LibraryContext(this._libraryElement, this._overrides, this._config) {}

  void translate() {
    typeManager = new TypeManager(_libraryElement, _overrides,
        modulePrefix: _config.modulePrefix, moduleSuffix: _config.moduleSuffix);
    tsLibrary = new TSLibrary(_libraryElement.source.uri.toString());

    _libraryElement.units.forEach((cu) => new FileContext(this, cu.computeNode()).translate());

    tsLibrary.imports = new List.from(typeManager.allImports);
    tsLibrary.globalContext = _globalContext;

    tsLibrary.exports.addAll(typeManager.exports);
  }

  TSGlobalContext _globalContext;

  TSDeclareContext resolveDeclarationContext(List<String> namespace) {
    if (_globalContext == null) {
      _globalContext = new TSGlobalContext();
    }

    return namespace.fold(_globalContext, (prev, name) => prev.resolveSubcontext(name));
  }

  void addExport(String export) {
    tsLibrary.addExport(export);
  }

  void addOnModuleLoad(TSStatement statement) => tsLibrary.onModuleLoad.add(statement);
}

class FileContext extends ChildContext<TSLibrary, LibraryContext, TSFile> {
  CompilationUnit _compilationUnit;
  List<Context> _topLevelContexts;
  List<TSNode> globals;

  FileContext(LibraryContext parent, this._compilationUnit) : super(parent) {
    globals = [];
  }

  List<TSNode> _tsDeclarations;

  void translate() {
    _tsDeclarations = new List<TSNode>();
    TSFile tsFile = new TSFile(_compilationUnit, _tsDeclarations);

    TopLevelDeclarationVisitor visitor = new TopLevelDeclarationVisitor(this);
    _topLevelContexts = new List();
    _topLevelContexts.addAll(_compilationUnit.declarations.map((f) => f.accept(visitor)).where((x) => x != null));

    _topLevelContexts.forEach((c) => c.translate());

    parentContext.tsLibrary._children.add(tsFile);
  }

  void addDeclaration(TSNode n) => _tsDeclarations.add(n);

  TSDeclareContext resolveDeclarationContext(List<String> namespace) =>
      parentContext.resolveDeclarationContext(namespace);

  void addOnModuleLoad(TSStatement statement) => parentContext.addOnModuleLoad(statement);
}

class TopLevelDeclarationVisitor extends GeneralizingAstVisitor<Context> {
  FileContext _fileContext;

  TopLevelDeclarationVisitor(this._fileContext);

  @override
  Context visitFunctionDeclaration(FunctionDeclaration node) {
    if (getAnnotation(node.element.metadata, isJS) != null) {
      if (shouldGenerate(node.element.metadata)) {
        return new TopLevelFunctionContext.declare(_fileContext, node);
      }
      return null;
    }

    return new TopLevelFunctionContext(_fileContext, node);
  }

  bool shouldGenerate(List<ElementAnnotation> metadata) {
    DartObject m = getAnnotation(metadata, isTS);

    return m != null && (m.getField('generate')?.toBoolValue() ?? false);
  }

  @override
  Context visitClassDeclaration(ClassDeclaration node) {
    if (getAnnotation(node.element.metadata, isJS) != null) {
      String export = getAnnotation(node.element.metadata, isTS)?.getField('export')?.toStringValue();
      if (export != null) {
        _fileContext.parentContext.addExport(_fileContext.typeManager.resolvePath(export));
      }

      if (shouldGenerate(node.element.metadata)) {
        return new ClassContext(_fileContext, node, true);
      }
      return null;
    }
    return new ClassContext(_fileContext, node, false);
  }

  @override
  Context visitTopLevelVariableDeclaration(TopLevelVariableDeclaration node) {
    return new TopLevelVariableContext(_fileContext, node);
  }
}

class TopLevelFunctionContext extends FunctionDeclarationContext {
  TopLevelFunctionContext(Context<TSNode> parentContext, FunctionDeclaration functionDeclaration)
      : super(parentContext, functionDeclaration);

  TopLevelFunctionContext.declare(Context<TSNode> parentContext, FunctionDeclaration functionDeclaration)
      : super(parentContext, functionDeclaration, declare: true);

  void translate() {
    super.translate();
    (parentContext as FileContext).addDeclaration(tsFunction);

    if (hasAnnotation(_functionDeclaration.element.metadata, isOnModuleLoad)) {
      (parentContext as FileContext).addOnModuleLoad(new TSExpressionStatement(
          new TSInvoke(new TSSimpleExpression(typeManager.toTsName(_functionDeclaration.element)), null)));
    }
  }
}

class TopLevelVariableContext extends ChildContext<TSFile, FileContext, TSVariableDeclarations> {
  TopLevelVariableDeclaration _vars;

  TopLevelVariableContext(Context<TSFile> parentContext, this._vars) : super(parentContext);

  TSVariableDeclarations tsVariableDeclarations;

  @override
  void translate() {
    tsVariableDeclarations = new TSVariableDeclarations(
      new List.from(_vars.variables.variables.map((v) => new TSVariableDeclaration(
          v.name.name, processExpression(v.initializer), typeManager.toTsType(_vars.variables.type?.type)))),
      isTopLevel: true,
      isField: true,
    );

    parentContext.addDeclaration(tsVariableDeclarations);
  }
}

class FunctionExpressionContext extends ChildContext<TSNode, Context<TSNode>, TSFunction> {
  FunctionExpression _functionExpression;

  FunctionExpressionContext(Context parent, this._functionExpression) : super(parent);

  TSFunction tsFunction;

  void translate() {
    List<TSTypeParameter> typeParameters;

    if (_functionExpression.typeParameters != null) {
      typeParameters = new List.from(_functionExpression.typeParameters.typeParameters
          .map((t) => new TSTypeParameter(t.name.name, typeManager.toTsType(t.bound?.type))));
    } else {
      typeParameters = null;
    }

    // arguments
    FormalParameterCollector parameterCollector = new FormalParameterCollector(this);
    (_functionExpression.parameters?.parameters ?? []).forEach((p) {
      p.accept(parameterCollector);
    });

    // body
    TSBody body = processBody(_functionExpression.body, withBrackets: false);

    tsFunction = new TSFunction(
      typeManager,
      isAsync: _functionExpression.body.isAsynchronous,
      isGenerator: _functionExpression.body.star != null,
      topLevel: topLevel,
      typeParameters: typeParameters,
      withParameterCollector: parameterCollector,
      body: body,
      isExpression: true,
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
  List<String> fields = [];

  Iterable<TSParameter> get tsParameters sync* {
    yield* parameters;
    if (namedType != null) {
      yield new TSParameter(name: NAMED_ARGUMENTS, type: namedType, optional: true);
    }
  }

  @override
  visitDefaultFormalParameter(DefaultFormalParameter node) {
    super.visitDefaultFormalParameter(node);
    if (node.parameter is FieldFormalParameter) {
      fields.add(node.identifier.name);
    }
    if (node.defaultValue == null) {
      return;
    }
    if (node.kind == ParameterKind.NAMED) {
      namedDefaults[node.identifier.name] = _context.processExpression(node.defaultValue);
    } else {
      defaults[node.identifier.name] = _context.processExpression(node.defaultValue);
    }
  }

  @override
  visitFormalParameter(FormalParameter node) {
    if (node is FieldFormalParameter) {
      fields.add(node.identifier.name);
    }
    if (node.kind == ParameterKind.NAMED) {
      namedType ??= new TSInterfaceType();
      namedType.fields[node.identifier.name] = _context.typeManager.toTsType(node.element.type);
    } else {
      parameters.add(new TSParameter(
          name: node.identifier.name,
          varargs: getAnnotation(node.element.metadata, isVarargs) != null,
          type: _context.typeManager.toTsType(node.element.type),
          optional: node.kind.isOptional));
    }
  }
}

class FunctionDeclarationContext extends ChildContext<TSNode, Context, TSFunction> {
  FunctionDeclaration _functionDeclaration;
  bool topLevel;
  bool declare;

  TSType returnType;

  FunctionDeclarationContext(Context parentContext, this._functionDeclaration,
      {this.topLevel = true, this.declare: false})
      : super(parentContext);

  TSFunction tsFunction;

  @override
  void translate() {
    String name = _functionDeclaration.name.name;

    if (_functionDeclaration.element is PropertyAccessorElement) {
      name = (_functionDeclaration.element as PropertyAccessorElement).variable.name;
    }

    tsFunction = processFunctionExpression(_functionDeclaration.functionExpression)
      ..name = _functionDeclaration.name.name
      ..declared = declare
      ..topLevel = topLevel
      ..isGetter = _functionDeclaration.isGetter
      ..isSetter = _functionDeclaration.isSetter
      ..isInterpolator =
          getAnnotation(_functionDeclaration.element.metadata, isTS)?.getField('stringInterpolation')?.toBoolValue() ??
              false
      ..returnType = parentContext.typeManager.toTsType(_functionDeclaration?.returnType?.type);
  }
}

class ClassContext extends ChildContext<TSFile, FileContext, TSClass> {
  final ClassDeclaration _classDeclaration;

  ClassContext get currentClass => this;

  final bool _declarationMode;

  ClassContext(Context parent, this._classDeclaration, this._declarationMode) : super(parent);

  TSClass _tsClass;

  TSClass get tsClass => _tsClass;

  List<TSNode> _members;

  @override
  void translate() {
    _tsClass = new TSClass(library: currentClass._classDeclaration.element.librarySource.uri.toString());
    ClassMemberVisitor visitor = new ClassMemberVisitor(this, _tsClass, _declarationMode);
    _tsClass.name = _classDeclaration.name.name;

    if (_classDeclaration.extendsClause != null) {
      tsClass.superClass = typeManager.toTsType(_classDeclaration.extendsClause.superclass.type);
    }

    if (_classDeclaration.implementsClause != null) {
      tsClass.implemented =
          _classDeclaration.implementsClause.interfaces.map((t) => new TSTypeExpr(typeManager.toTsType(t.type)));
    }

    if (_classDeclaration.typeParameters != null) {
      tsClass.typeParameters = new List.from(_classDeclaration.typeParameters.typeParameters
          .map((tp) => new TSTypeParameter(tp.name.name, typeManager.toTsType(tp.bound?.type))));
    }

    _tsClass.members = new List();
    _classDeclaration.members.forEach((m) {
      m.accept(visitor);
    });
    //List<TSNode> _members =
    //   new List.from(_classDeclaration.members.map((m) => m.accept(visitor)).where((m) => m != null));
    //_tsClass.members.addAll(_members);

    // Create constructor interfaces
    visitor.namedConstructors.values.forEach((ConstructorDeclaration decl) {
      FormalParameterCollector parameterCollector = collectParameters(decl.parameters);

      parentContext.addDeclaration(new TSClass(isInterface: true)
        ..name = '${_classDeclaration.name.name}_${decl.name.name}'
        ..members = [
          new TSFunction(typeManager,
              asMethod: true,
              name: 'new',
              withParameterCollector: parameterCollector,
              returnType: new TSSimpleType(_classDeclaration.name.name, true)),
        ]);
    });

    // If exported add as a normal declaration
    String export = getAnnotation(_classDeclaration.element.metadata, isTS)?.getField('export')?.toStringValue();

    if (_declarationMode && export == null) {
      _registerGlobal(_tsClass);
    } else {
      _tsClass.declared = _declarationMode;
      parentContext.addDeclaration(_tsClass);
    }
  }

  void _registerGlobal(TSClass declared) {
    List<String> namespace = new List.from(() sync* {
      DartObject libJS = getAnnotation(parentContext.parentContext._libraryElement.metadata, isJS);
      if (libJS != null) {
        String main = libJS.getField('name').toStringValue();
        if (main != null && main.isNotEmpty) {
          yield* main.split('.');
        }
      }

      libJS = getAnnotation(_classDeclaration.element.metadata, isJS);
      if (libJS != null) {
        String main = libJS.getField('name').toStringValue();
        if (main != null && main.isNotEmpty) {
          yield* (main.split('.')..removeLast());
        }
      }
    }());

    TSDeclareContext ctx = parentContext.resolveDeclarationContext(namespace);
    ctx.addChild(declared);
  }
}

class ClassMemberVisitor extends GeneralizingAstVisitor {
  final ClassContext _context;
  final TSClass tsClass;
  final bool _declarationMode;

  ClassMemberVisitor(this._context, this.tsClass, this._declarationMode);

  Map<String, ConstructorDeclaration> namedConstructors = {};

  @override
  visitMethodDeclaration(MethodDeclaration node) {
    MethodContext methodContext = new MethodContext(_context, node, _declarationMode);
    methodContext.translate();
  }

  @override
  visitFieldDeclaration(FieldDeclaration node) {
    _context.tsClass.members.add(new TSVariableDeclarations(
      new List.from(node.fields.variables.map((v) => new TSVariableDeclaration(v.name.name,
          _context.processExpression(v.initializer), _context.typeManager.toTsType(node.fields.type?.type)))),
      isField: true,
      isStatic: node.isStatic,
      //isConst: node.fields.isConst || node.fields.isFinal,
    ));
  }

  @override
  visitConstructorDeclaration(ConstructorDeclaration node) {
    if (node.factoryKeyword != null) {
      // Return a static method declaration

      FormalParameterCollector collector = new FormalParameterCollector(_context);
      node.parameters.accept(collector);

      TSBody body = _context.processBody(node.body, withBrackets: false, withReturn: true);
      InitializerCollector initializerCollector = new InitializerCollector(_context);
      List<TSStatement> initializers = initializerCollector.processInitializers(node.initializers);

      _context.tsClass.members.add(new TSFunction(
        _context.typeManager,
        name: (node.name?.name?.length ?? 0) > 0 ? node.name.name : 'create',
        asMethod: true,
        isStatic: true,
        withParameterCollector: collector,
        body: body,
        initializers: initializers,
        returnType: _context.typeManager.toTsType(node.element.enclosingElement.type),
      ));
    } else if (node.name != null) {
      namedConstructors[node.name.name] = node;

      // Create the static
      _context.tsClass.members.add(_createNamedConstructor(node));
    } else {
      // Create a default constructor

      FormalParameterCollector collector = new FormalParameterCollector(_context);
      node.parameters.accept(collector);

      TSBody body = _context.processBody(node.body, withBrackets: false, withReturn: false);

      InitializerCollector initializerCollector = new InitializerCollector(_context);
      List<TSStatement> initializers = initializerCollector.processInitializers(node.initializers);

      _context.tsClass.members.add(new TSFunction(
        _context.typeManager,
        asMethod: true,
        initializers: initializers,
        asDefaultConstructor: true,
        callSuper: (_context._classDeclaration.element.type).superclass != currentContext.typeProvider.objectType,
        nativeSuper: getAnnotation(_context._classDeclaration.element.type.superclass.element.metadata, isJS) != null,
        withParameterCollector: collector,
        body: body,
      ));
    }
  }

  TSNode _createNamedConstructor(ConstructorDeclaration node) {
    TSType ctorType = new TSSimpleType('${_context._classDeclaration.name.name}_${node.name.name}', true);

    FormalParameterCollector parameterCollector = _context.collectParameters(node.parameters);

    TSBody body = _context.processBody(node.body, withBrackets: false, withReturn: false);

    InitializerCollector initializerCollector = new InitializerCollector(_context);
    List<TSStatement> initializers = initializerCollector.processInitializers(node.initializers);

    String metName = '_${node.name.name}';

    TSExpression init = new TSInvoke(
        new TSBracketExpression(new TSFunction(_context.typeManager,
            body: new TSBody(statements: [
              new TSVariableDeclarations([
                new TSVariableDeclaration(
                    'ctor',
                    new TSFunction(_context.typeManager,
                        parameters: [new TSParameter(name: '...args')],
                        body: new TSBody(withBrackets: false, statements: [
                          new TSExpressionStatement(new TSInvoke(
                              new TSDotExpression(
                                  new TSDotExpression(
                                      new TSStaticRef(
                                          _context.typeManager.toTsType(_context._classDeclaration.element.type),
                                          'prototype'),
                                      metName),
                                  'apply'),
                              [new TSSimpleExpression('this'), new TSSimpleExpression('args')]))
                        ])),
                    null)
              ]),
              new TSExpressionStatement(new TSAssignamentExpression(
                  new TSDotExpression(new TSSimpleExpression('ctor'), 'prototype'),
                  new TSDotExpression(new TSSimpleExpression(_context._classDeclaration.name.name), 'prototype'))),
              new TSReturnStatement(new TSAsExpression(new TSSimpleExpression('ctor'), new TSSimpleType('any', false))),
            ], withBrackets: false))),
        []);

    List<TSNode> nodes = [
      // actual constructor
      new TSFunction(
        _context.typeManager,
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

  List<TSStatement> processInitializers(List<ConstructorInitializer> initializers) {
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

    ArgumentListCollector argumentListCollector = new ArgumentListCollector(_context, node.staticElement)
      ..processArgumentList(node.argumentList);

    return new TSExpressionStatement(
        new TSInvoke(target, argumentListCollector.arguments, argumentListCollector.namedArguments));
  }

  @override
  TSStatement visitRedirectingConstructorInvocation(RedirectingConstructorInvocation node) {
    TSExpression target;
    if (node.constructorName == null) {
      target = new TSSimpleExpression('this[bare.init]');
    } else {
      target = new TSSimpleExpression('this._${node.constructorName.name}');
    }

    ArgumentListCollector argumentListCollector = new ArgumentListCollector(_context, node.staticElement)
      ..processArgumentList(node.argumentList);

    return new TSExpressionStatement(
        new TSInvoke(target, argumentListCollector.arguments, argumentListCollector.namedArguments));
  }

  @override
  TSStatement visitConstructorFieldInitializer(ConstructorFieldInitializer node) {
    return new TSExpressionStatement(new TSAssignamentExpression(
        new TSSimpleExpression('this.${node.fieldName.name}'), _context.processExpression(node.expression)));
  }
}

class MethodContext extends ChildContext<TSClass, ClassContext, TSNode> {
  final MethodDeclaration _methodDeclaration;
  final bool _declarationMode;

  MethodContext(ClassContext parent, this._methodDeclaration, this._declarationMode) : super(parent);

  @override
  void translate() {
    // Props
    if (_declarationMode && (_methodDeclaration.isGetter || _methodDeclaration.isSetter)) {
      // Actually add a readonly or normal prop

      PropertyAccessorElement prop = _methodDeclaration.element as PropertyAccessorElement;

      bool readonly = prop.variable.setter == null;

      // Ignore setters for rw props (otherwise it will be added twice)
      if (_methodDeclaration.isSetter) {
        return null;
      }

      parentContext._tsClass.members.add(new TSVariableDeclarations(
          [new TSVariableDeclaration(prop.variable.name, null, typeManager.toTsType(prop.variable.type))],
          isField: true, readonly: readonly, declared: _declarationMode));
      return null;
    }

    List<TSTypeParameter> typeParameters;
    //List<TSNode> result = [];

    if (_methodDeclaration.typeParameters != null) {
      typeParameters = new List.from(_methodDeclaration.typeParameters.typeParameters
          .map((t) => new TSTypeParameter(t.name.name, typeManager.toTsType(t.bound?.type))));
    } else {
      typeParameters = null;
    }

    // arguments
    FormalParameterCollector parameterCollector = new FormalParameterCollector(this);
    (_methodDeclaration.parameters?.parameters ?? []).forEach((p) {
      p.accept(parameterCollector);
    });

    // body
    TSBody body;
    if (_declarationMode) {
      body = null;
    } else {
      body = processBody(_methodDeclaration.body, withBrackets: false, withReturn: !_methodDeclaration.isSetter);
    }
    String name = _methodDeclaration.name.name;

    List<TSAnnotation> annotations = new List();

    if (_methodDeclaration.isOperator) {
      TokenType tk = TokenType.all.firstWhere((tt) => tt.lexeme == _methodDeclaration.name.name);
      if (_methodDeclaration.parameters.parameters.isEmpty) {
        name = "OPERATOR_PREFIX_${tk.name}";
      } else {
        name = 'OPERATOR_${tk.name}';
      }
      annotations.add(new TSAnnotation(new TSInvoke(new TSSimpleExpression('bare.DartOperator'), [], {
        'type': _methodDeclaration.parameters.parameters.isEmpty
            ? new TSSimpleExpression('bare.OperatorType.PREFIX')
            : new TSSimpleExpression('bare.OperatorType.BINARY'),
        'op': new TSSimpleExpression('"${tk.lexeme}"')
      })));
    }

    parentContext.tsClass.members.add(new TSFunction(
      typeManager,
      name: name,
      returnType: typeManager.toTsType(_methodDeclaration.returnType?.type),
      isAsync: _methodDeclaration.body.isAsynchronous,
      topLevel: topLevel,
      typeParameters: typeParameters,
      asMethod: true,
      isStatic: _methodDeclaration.isStatic,
      isGetter: _methodDeclaration.isGetter,
      isSetter: _methodDeclaration.isSetter,
      body: body,
      annotations: annotations,
      withParameterCollector: parameterCollector,
      declared: _declarationMode,
    ));
  }
}
