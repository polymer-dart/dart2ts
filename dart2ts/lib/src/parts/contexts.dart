part of '../code_generator.dart';

abstract class Context<T extends TSNode> {
  TypeManager get typeManager;

  bool get topLevel;

  ClassContext get currentClass;

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

  FormalParameterCollector collectParameters(FormalParameterList params) {
    FormalParameterCollector res = new FormalParameterCollector(this);
    (params?.parameters ?? []).forEach((p) {
      p.accept(res);
    });
    return res;
  }

  List<TSTypeParameter> methodTypeParameters(ClassMember _methodDeclaration) {
    List<TSTypeParameter> typeParameters;

    List<TypeParameter> params;

    params = new ExecutableClassMember.fromClassMember(_methodDeclaration)?.typeParameters?.typeParameters;

    if (params != null) {
      typeParameters =
          new List.from(params.map((t) => new TSTypeParameter(t.name.name, typeManager.toTsType(t.bound?.type))));
    } else {
      typeParameters = null;
    }
    return typeParameters;
  }
}

abstract class ExecutableClassMember {
  bool get isStatic;

  TypeParameterList get typeParameters;

  factory ExecutableClassMember.fromClassMember(ClassMember member) =>
      member.accept(new _ExecutableClassMemberFactory());
}

class MethodExecutableClassMember implements ExecutableClassMember {
  MethodDeclaration _method;

  MethodExecutableClassMember(this._method);

  bool get isStatic => _method.isStatic;

  TypeParameterList get typeParameters => _method.typeParameters;
}

class ConstructorExecutableClassMember implements ExecutableClassMember {
  ConstructorDeclaration _constructor;

  ConstructorExecutableClassMember(this._constructor);

  bool get isStatic => _constructor.factoryKeyword != null;

  TypeParameterList get typeParameters => (_constructor.parent as ClassDeclaration).typeParameters;
}

class _ExecutableClassMemberFactory extends GeneralizingAstVisitor<ExecutableClassMember> {
  @override
  ExecutableClassMember visitMethodDeclaration(MethodDeclaration node) {
    return new MethodExecutableClassMember(node);
  }

  @override
  ExecutableClassMember visitConstructorDeclaration(ConstructorDeclaration node) {
    return new ConstructorExecutableClassMember(node);
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
  TSStatement visitLabeledStatement(LabeledStatement node) {
    return new TSLabeledStatement(node.labels.map((l) => l.label.name).toList(), node.statement.accept(this));
  }

  @override
  TSStatement visitContinueStatement(ContinueStatement node) {
    return new TSExpressionStatement(new TSSimpleExpression('continue'));
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

bool isAssigningLeftSide(AstNode node) => (node.parent is AssignmentExpression) && (node != assigningValue(node));

Expression assigningValue(AstNode node) => (node.parent as AssignmentExpression).rightHandSide;

abstract class ExpressionVisitor implements AstVisitor<TSExpression> {
  factory ExpressionVisitor(Context context) => new CachingExpressionVisitor(context);
}

class CachingExpressionVisitor extends GeneralizingAstVisitor<TSExpression> implements ExpressionVisitor {
  final _ExpressionVisitor _actualVisitor;
  static final Map<AstNode, TSExpression> _cache = new Map();

  CachingExpressionVisitor(Context context) : _actualVisitor = new _ExpressionVisitor(context);

  @override
  TSExpression visitNode(AstNode node) {
    return _cache.putIfAbsent(node, () => node.accept(_actualVisitor));
  }
}

class _ExpressionVisitor extends GeneralizingAstVisitor<TSExpression> {
  Context _context;

  _ExpressionVisitor(this._context);

  @override
  TSExpression visitIntegerLiteral(IntegerLiteral node) {
    return new TSSimpleExpression(node.value.toString());
  }

  @override
  TSExpression visitDoubleLiteral(DoubleLiteral node) {
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
    return new TSInstanceOf(node.expression.accept(this),
        new TSTypeExpr(_context.typeManager.toTsType(node.type.type), false), node.notOperator == null);
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

    return new TSInvoke(new TSStaticRef(_context.typeManager.toTsType(dartMap), 'literal'), [
      new TSList(node.entries.map((entry) {
        return new TSList([_context.processExpression(entry.key), _context.processExpression(entry.value)]);
      }).toList())
    ])
      ..asNew = true;
  }

  @override
  TSExpression visitListLiteral(ListLiteral node) {
    //new TSGenericType(name, _typeArguments)_context.typeManager.toTsType(getType(currentContext,'dart:core','List'))

    DartType listElementType = node.typeArguments?.arguments?.first?.type;
    return new TSInvoke(
        new TSStaticRef(_context.typeManager.toTsType(getType(currentContext, 'dart:core', 'List')), 'literal'),
        new List.from(node.elements.map((e) => _context.processExpression(e))))
      ..typeParameters = listElementType != null ? [_context.typeManager.toTsType(listElementType)] : null
      ..asNew = true;
    //return new TSList(),
    //   _context.typeManager.toTsType(node?.bestType));
  }

  @override
  TSExpression visitPrefixExpression(PrefixExpression node) {
    if (TypeManager.isNativeType(node.operand.bestType)) {
      return new TSPrefixOperandExpression(node.operator.lexeme, _context.processExpression(node.operand));
    }
    return makeOperatorExpression(node.operator.type, [_context.processExpression(node.operand)]);
    //return handlePrefixSuffixExpression(node.operand, node.operator, OperatorType.PREFIX);
  }

  TSExpression makeOperatorExpression(TokenType operator, List<TSExpression> operands) {
    return new TSInvoke(new TSSimpleExpression('op'),
        [new TSSimpleExpression(operatorSymbol(operator, operands.length == 1))]..addAll(operands));
  }

  /*TSExpression handlePrefixSuffixExpression(Expression operand, Token operator, OperatorType opType) {
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
  }*/

  @override
  TSExpression visitPostfixExpression(PostfixExpression node) {
    if (TypeManager.isNativeType(node.operand.bestType)) {
      return new TSPostfixOperandExpression(node.operator.lexeme, _context.processExpression(node.operand));
    }
    return makeOperatorExpression(node.operator.type, [_context.processExpression(node.operand)]);
    //return handlePrefixSuffixExpression(node.operand, node.operator, OperatorType.SUFFIX);
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
      String op;
      if (node.operator.type == TokenType.QUESTION_QUESTION) {
        op = '||';
      } else {
        op = node.operator.lexeme.toString();
      }

      return new TSBinaryExpression(leftExpression, op, rightExpression);
    }

    if (node.leftOperand.bestType is InterfaceType && !TypeManager.isNativeType(node.leftOperand.bestType)) {
      InterfaceType cls = node.leftOperand.bestType as InterfaceType;
      MethodElement method = findMethod(cls, node.operator.lexeme);
      assert(method != null, 'Operator ${node.operator} can be used only if defined in ${cls.name}');

      return makeOperatorExpression(node.operator.type, [leftExpression, rightExpression]);
      /*
      return new TSInvoke(
          new TSDotExpression(leftExpression, _operatorName(method, node.operator, OperatorType.BINARY)),
          [rightExpression]);*/
    }

    return makeOperatorExpression(node.operator.type, [leftExpression, rightExpression]);
    /*return new TSInvoke(new TSSimpleExpression('bare.invokeBinaryOperand'),
        [new TSSimpleExpression('"${node.operator.lexeme}"'), leftExpression, rightExpression]);*/
  }

/*
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
  }*/

  @override
  TSExpression visitCascadeExpression(CascadeExpression node) {
    TSExpression target = new TSSimpleExpression.cascadingTarget();
    TSBody body = new TSBody(statements: () sync* {
      yield* node.cascadeSections.map((e) => _context.processExpression(e)).map((e) => new TSExpressionStatement(e));
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
    return TSSimpleExpression.THIS;
  }

  @override
  TSExpression visitSuperExpression(SuperExpression node) {
    return TSSimpleExpression.SUPER;
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
    // If not js indexable use default operator

    return _context.typeManager.checkIndexedOperator(_context, node.target, node.index, () {
      TSExpression target;
      Expression tgt;
      if (node.target == null && node.isCascaded) {
        target = new TSSimpleExpression.cascadingTarget();
        tgt = findCascadeExpression(node);
      } else {
        target = _context.processExpression(node.target);
        tgt = node.target;
      }
      if (tgt != null) {
        if ((tgt?.bestType is InterfaceType &&
                ((tgt?.bestType as InterfaceType)?.interfaces?.any((i) => i.name == 'JSIndexable') ?? false)) ||
            isListType(tgt?.bestType) ||
            TypeManager.isNativeType(tgt?.bestType)) {
          // Use normal operator
          return _mayWrapInAssignament(node, new TSIndexExpression(target, _context.processExpression(node.index)));
        }
      }

      // Use generic op
      TokenType tk;
      List<TSExpression> operands = [target, _context.processExpression(node.index)];
      if (isAssigningLeftSide(node)) {
        tk = TokenType.INDEX_EQ;
        operands.add(_context.processExpression(assigningValue(node)));
      } else {
        tk = TokenType.INDEX;
      }

      return makeOperatorExpression(tk, operands);
    });
  }

  @override
  TSExpression visitSimpleIdentifier(SimpleIdentifier node) {
    // Check for implicit this

    String name = _context.typeManager.toTsName(node.bestElement) ?? node.name;

    DartType currentClassType = _context.currentClass?._classDeclaration?.element?.type;
    if (node.bestElement is PropertyAccessorElement) {
      PropertyInducingElement el = (node.bestElement as PropertyAccessorElement).variable;

      if (el.enclosingElement is ClassElement) {
        name = _context.typeManager.checkProperty((el.enclosingElement as ClassElement).type, node.name);
      }

      // check if current class has it
      if (_context.currentClass != null && findField(currentClassType, node.name) == el) {
        TSExpression tgt;
        if (el.isStatic) {
          tgt = new TSTypeExpr.noTypeParams(_context.typeManager.toTsType(currentClassType));
        } else {
          tgt = TSSimpleExpression.THIS;
        }
        return _mayWrapInAssignament(node, new TSDotExpression(tgt, name));
      }
    } else if (node.bestElement is MethodElement) {
      MethodElement el = node.bestElement;

      bool hasTarget = false;
      TSExpression tgt;
      if (node.parent is MethodInvocation) {
        MethodInvocation inv = node.parent as MethodInvocation;
        if (inv.methodName == node && inv.target != null) {
          hasTarget = true;
          tgt = _context.processExpression(inv.target);
        }
      }

      if (_context.currentClass != null && findMethod(currentClassType, node.name) == el && !hasTarget) {
        if (el.isStatic) {
          tgt = new TSTypeExpr.noTypeParams(_context.typeManager.toTsType(currentClassType));
        } else {
          tgt = TSSimpleExpression.THIS;
        }

        TSExpression expr = _context.typeManager.checkMethod(
            el.enclosingElement.type, node.name, TSSimpleExpression.THIS,
            orElse: () => new TSDotExpression(tgt, node.name));

        // When using a method without invoking it => bind it to this
        if (!isAssigningLeftSide(node) && (node.parent is! MethodInvocation)) {
          return new TSInvoke(new TSDotExpression(expr, 'bind'), [TSSimpleExpression.THIS]);
        }

        return _mayWrapInAssignament(node, expr);
      }

      // When using a method without invoking it => bind it to this
      if (!isAssigningLeftSide(node) && (node.parent is! MethodInvocation)) {
        return new TSInvoke(new TSDotExpression(new TSSimpleExpression(name), 'bind'), [tgt]);
      }
    } else if (node.bestElement is ClassElement) {
      if (node.parent is MethodInvocation || node.parent is PropertyAccess || node.parent is PrefixedIdentifier) {
        return new TSTypeExpr.noTypeParams(_context.typeManager.toTsType((node.bestElement as ClassElement).type));
      } else {
        return new TSTypeExpr(_context.typeManager.toTsType((node.bestElement as ClassElement).type));
      }
    } else if (node.bestElement is ExecutableElement) {
      // need resolve prefix
      name = _context.typeManager.toTsName(node.bestElement);
    }

    // Resolve names otherwisely ( <- I know this term doesn't exist, but I like it)

    return _mayWrapInAssignament(node, new TSSimpleExpression(name));
  }

  @override
  TSExpression visitAssignmentExpression(AssignmentExpression node) {
    return node.leftHandSide.accept(this);
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
    TSExpression tsTarget;

    DartType targetType;
    if (node.isCascaded) {
      tsTarget = new TSSimpleExpression.cascadingTarget();
      targetType = findCascadeExpression(node)?.bestType;
    } else {
      tsTarget = _context.processExpression(node.target);
      targetType = node.target?.bestType;
    }

    return asFieldAccess(_maybeWrapNativeCall(targetType, tsTarget), node.propertyName);
  }

  CascadeExpression findCascadeExpression(AstNode node) {
    while (node is! CascadeExpression && node != null) {
      node = node.parent;
    }

    return node;
  }

  Expression findCascadeTarget(AstNode node) => findCascadeExpression(node)?.target;

  @override
  TSExpression visitPrefixedIdentifier(PrefixedIdentifier node) {
    if (node.prefix.staticElement is PrefixElement) {
      PrefixElement prefix = node.prefix.staticElement;

      // Lookup library
      String prefixStr = _context.typeManager.namespaceForPrefix(prefix);

      // Handle references to top level external variables or getters and setters
      if (node.identifier.bestElement is PropertyAccessorElement) {
        prefixStr = "${prefixStr}.${MODULE_PROPERTIES}";
      }

      return _mayWrapInAssignament(node, new TSDotExpression(new TSSimpleExpression(prefixStr), node.identifier.name));
    }
    return asFieldAccess(
        _maybeWrapNativeCall(node.prefix?.bestType, _context.processExpression(node.prefix)), node.identifier);
  }

  TSExpression _mayWrapInAssignament(AstNode node, TSExpression expre) {
    if (isAssigningLeftSide(node)) {
      return new TSAssignamentExpression(expre, _context.processExpression(assigningValue(node)));
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

      // Handler method name ref
      if (identifier.bestElement is MethodElement) {
        return new TSInvoke(new TSDotExpression(new TSDotExpression(expression, name), 'bind'), [expression]);
      } else {
        return _mayWrapInAssignament(identifier.parent, new TSDotExpression(expression, name));
      }
    } else {
      String name = identifier.name;
      return _mayWrapInAssignament(identifier.parent, new TSDotExpression(expression, name));
      // Use the property accessor helper
      /*
      if (isAssigningLeftSide(identifier.parent)) {
        return new TSInvoke(new TSSimpleExpression('bare.writeProperty'), [
          expression,
          new TSSimpleExpression('"${identifier.name}"'),
          _context.processExpression(assigningValue(identifier.parent))
        ]);
      } else {
        return new TSInvoke(
            new TSSimpleExpression('bare.readProperty'), [expression, new TSSimpleExpression('"${identifier.name}"')]);
      }*/
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

  bool isAnonymousJS(ClassElement ce) {
    if (ce == null) return false;
    return hasAnnotation(ce.metadata, isJS) && hasAnnotation(ce.metadata, isAnonymous);
  }

  TSExpression _newObjectWithConstructor(
      ConstructorElement ctor, InstanceCreationExpression node, ArgumentListCollector collector) {
    return _context.typeManager.checkConstructor(_context, node.bestType, ctor, collector, () {
      TSType myType = _context.typeManager.toTsType(node.bestType);
      TSExpression target;

      // Check if it's an anonymous @JS constructor
      if (isAnonymousJS(ctor?.enclosingElement)) {
        return new TSAsExpression(new TSObjectLiteral(collector.namedArguments ?? {}),
            _context.typeManager.toTsType(ctor.enclosingElement.type));
      }

      bool asNew = true /*(!ctor.isFactory || ctor.isExternal)*/;

      if ((ctor.name?.isEmpty ?? true)) {
        target = new TSTypeRef(myType);
      } else {
        target = new TSStaticRef(myType, ctor.name);
      }

      return new TSInvoke(target, collector.arguments, collector.namedArguments)..asNew = asNew;
    });
  }

  TSExpression _maybeWrapNativeCall(DartType targetType, TSExpression tsTarget) {
    String wrapper;
    if (currentContext.typeProvider.numType == targetType) {
      wrapper = "core.DartNumber";
    } else if (currentContext.typeProvider.intType == targetType) {
      wrapper = "core.DartInt";
    } else if (currentContext.typeProvider.doubleType == targetType) {
      wrapper = 'core.DartDouble';
    } else if (currentContext.typeProvider.stringType == targetType) {
      wrapper = 'core.DartString';
    } else {
      return tsTarget;
    }

    return new TSInvoke(new TSSimpleExpression(wrapper), [tsTarget])..asNew = true;
  }

  @override
  TSExpression visitMethodInvocation(MethodInvocation node) {
    // Handle special case for string JS
    if (node.methodName.name == 'JS' &&
        node.argumentList.arguments.length > 1 &&
        node.argumentList.arguments[1] is StringLiteral) {
      return _handleJSTemplate(node);
    }

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
    Element elem = node.methodName.bestElement;

    if (elem != null) {
      TSExpression method;
      if (node.isCascaded) {
        TSExpression target;
        target = new TSSimpleExpression.cascadingTarget();
        Expression cascadeTarget = findCascadeTarget(node);
        method = _context.typeManager.checkMethod(cascadeTarget.bestType, node.methodName.name, target,
            orElse: () => new TSDotExpression(
                _maybeWrapNativeCall(cascadeTarget.bestType, target), _context.typeManager.toTsName(elem)));
      } else if (!TypeManager.isTopLevel(elem) && (elem.enclosingElement is ClassElement)) {
        TSExpression target;
        DartType targetType = node.target?.bestType ?? (elem.enclosingElement as ClassElement).type;
        target = _context.processExpression(node.target) ??
            ((elem as ExecutableElement).isStatic
                ? new TSTypeExpr(_context.typeManager.toTsType(targetType))
                : TSSimpleExpression.THIS);

        // Check for method substitution
        method = _context.typeManager.checkMethod(targetType, node.methodName.name, target, orElse: () {
          TSExpression res = _context.processExpression(node.methodName);
          if (node.target != null) {
            res = new TSDotExpression.expr(_maybeWrapNativeCall(node.target?.bestType, target), res);
          }
          return res;
        });
      } else {
        method = _context.processExpression(node.methodName);
      }

      // Invoke normal method / function
      return new TSInvoke(method, collector.arguments, collector.namedArguments);
    } else {
      TSExpression target;
      Expression targetExpression = node.target;
      if (node.isCascaded) {
        targetExpression = findCascadeExpression(node);
        target = new TSSimpleExpression.cascadingTarget();
      } else if (targetExpression != null &&
          !(targetExpression is SimpleIdentifier && targetExpression.bestElement is PrefixElement)) {
        target = _context.processExpression(node.target);
      } else {
        target = new TSSimpleExpression('null /*topLevl*/');
      }

      TSExpression res = _context.processExpression(node.methodName);
      if (node.target != null) {
        res = new TSDotExpression.expr(_maybeWrapNativeCall(targetExpression.bestType, target), res);
      }

      //return new TSInvoke(method,)
      return new TSInvoke(res, collector.arguments, collector.namedArguments);
      /*
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
        */
    }
  }

  TSExpression _handleJSTemplate(MethodInvocation node) {
    String pattern = (node.argumentList.arguments[1] as StringLiteral).stringValue;
    List<String> pieces = pattern.split('#');
    List<TSExpression> expr = [];
    for (int i = 2; i < node.argumentList.arguments.length; i++) {
      expr.add(_context.processExpression(node.argumentList.arguments[i]));
    }
    return new TSNativeJs(node.toString(), pieces, expr);
  }
}

class TSNativeJs extends TSExpression {
  String orig;
  List<String> pieces;
  List<TSExpression> expr;

  TSNativeJs(this.orig, this.pieces, this.expr);

  @override
  void writeCode(IndentingPrinter printer) {
    int i;
    for (i = 0; i < pieces.length; i++) {
      printer.write(pieces[i]);
      if (i < expr.length) {
        printer.accept(expr[i]);
      }
    }

    printer.write("/* ${orig} */");
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

class InvokingContext<A extends TSNode, B extends Context<A>> extends ChildContext<A, B, A> {
  bool get isInvoking => true;

  InvokingContext(B parent) : super(parent);

  @override
  void translate() => parentContext.translate();
}

MethodElement findMethod(InterfaceType tp, String methodName) {
  MethodElement m = tp.getMethod(methodName);
  if (m != null) {
    if (m is MethodMember) {
      return m.baseElement;
    }
    return m;
  }

  if (tp.superclass != null) {
    MethodElement me = findMethod(tp.superclass, methodName);
    if (me != null) {
      return me;
    }
  }

  if (tp.interfaces != null) {
    return tp.interfaces.map((i) => findMethod(i, methodName)).firstWhere((m) => m != null, orElse: () => null);
  }

  return null;
}

FieldElement findField(InterfaceType tp, String fieldName) {
  PropertyAccessorElement pe = tp.getGetter(fieldName) ?? tp.getSetter(fieldName);
  if (pe != null) {
    FieldElement m = pe.variable as FieldElement;
    if (m is FieldMember) {
      return m.baseElement;
    }
    return m;
  }

  if (tp.superclass != null) {
    FieldElement fe = findField(tp.superclass, fieldName);
    if (fe != null) {
      return fe;
    }
  }

  if (tp.interfaces != null) {
    return tp.interfaces.map((i) => findField(i, fieldName)).firstWhere((m) => m != null, orElse: () => null);
  }

  return null;
}

abstract class TopLevelContext<E extends TSNode> extends Context<E> {
  TypeManager typeManager;

  bool get topLevel => true;

  ClassContext get currentClass => null;
}

abstract class ChildContext<A extends TSNode, P extends Context<A>, E extends TSNode> extends Context<E> {
  P parentContext;

  ChildContext(this.parentContext);

  TypeManager get typeManager => parentContext.typeManager;

  bool get topLevel => false;

  ClassContext get currentClass => parentContext.currentClass;
}

class Config {
  String modulePrefix;
  String moduleSuffix;
  String sdkPrefix;
  IOverrides overrides;

  Config(
      {this.modulePrefix = '@dart2ts.packages',
      this.moduleSuffix = '',
      this.overrides,
      this.sdkPrefix = '@dart2ts/dart'});
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
        modulePrefix: _config.modulePrefix, moduleSuffix: _config.moduleSuffix, sdkPrefix: _config.sdkPrefix);

    tsLibrary = new TSLibrary(_libraryElement.source.uri.toString());

    _libraryElement.units.forEach((cu) => new FileContext(this, cu.computeNode()).translate());

    tsLibrary.imports = new List.from(typeManager.allImports)
      ..insert(
          0,
          typeManager._getSdkPath('****:utils', names: [
            'defaultConstructor',
            'namedConstructor',
            'namedFactory',
            'defaultFactory',
            'DartClass',
            'Implements',
            'op',
            'Op',
            "OperatorMethods",
            "DartClassAnnotation",
            "DartMethodAnnotation",
            "DartPropertyAnnotation",
            "Abstract",
            "AbstractProperty",
            "int",
            "bool",
            "double",
          ]))
      ..insert(
          0,
          typeManager._getSdkPath('****:_common', names: [
            'is',
            'isNot',
            'equals',
          ]));
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

  Map<String, TSType> get asFormalArguments {
    Map<String, TSType> res = new Map()
      ..addAll(new Map.fromIterable(parameters, key: (p) => p.name, value: (p) => p.type));
    if (namedType != null) {
      res['_namedArguments?'] = namedType;
    }
    return res;
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

TSAnnotation Function(Annotation anno) annotationMapper(
    Context context,
    TSAnnotation Function(
            Uri library, String type, List<TSExpression> arguments, Map<String, TSExpression> namedArguments)
        annoFactory) {
  return (Annotation anno) {
    // Ignore unknown anno
    if (anno.constructorName?.bestElement == null && anno.name.bestElement == null) {
      return null;
    }

    ArgumentListCollector collector;
    String name;
    if (anno.name.bestElement is PropertyAccessorElement) {
      ConstVariableElement constVar =
          ((anno.name.bestElement as PropertyAccessorElement).variable) as ConstVariableElement;

      InstanceCreationExpression creationExpression = (constVar.computeNode() as VariableDeclaration).initializer;

      ConstructorElement cons = creationExpression.staticElement;

      collector = new ArgumentListCollector(context, cons);
      if (anno.arguments != null) collector.processArgumentList(creationExpression.argumentList);
      name = cons.name;

      //ArgumentListCollector collector = new ArgumentListCollector(context, cons);
      //collector.processArgumentList(inv.arguments);
    } else {
      ConstructorElement cons = anno.constructorName?.bestElement ??
          (anno.name.bestElement as ClassElement).constructors.firstWhere((e) => e.name == null || e.name.isEmpty);

      collector = new ArgumentListCollector(context, cons);
      if (anno.arguments != null) collector.processArgumentList(anno.arguments);
      name = cons.name;
    }

    if (name == null || name.isEmpty) {
      name = anno.name.bestElement.name;
    } else {
      name = "${anno.name.bestElement.name}.${name}";
    }
    return annoFactory(anno.name.bestElement.library.source.uri, name, collector.arguments, collector.namedArguments);
  };
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
    _tsClass = new TSClass(library: _classDeclaration.element.librarySource.uri.toString());
    _tsClass.isAbstract = _classDeclaration.isAbstract;
    ClassMemberVisitor visitor = new ClassMemberVisitor(this, _tsClass, _declarationMode);
    _tsClass.name = _classDeclaration.name.name;

    // Add annotations
    _tsClass.annotations = new List()
      ..addAll(_classDeclaration.metadata
          .map(annotationMapper(
              this,
              (uri, name, arguments, namedArguments) =>
                  new TSAnnotation.classAnnotation(uri, name, arguments, namedArguments)))
          .where(notNull));

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

    /*
    visitor.namedConstructors.values.forEach((ConstructorDeclaration decl) {
      FormalParameterCollector parameterCollector = collectParameters(decl.parameters);

      parentContext.addDeclaration(new TSClass(isInterface: true)
        ..name = '${_classDeclaration.name.name}_${decl.name.name}'
        ..typeParameters = tsClass.typeParameters
        ..members = [
          new TSFunction(
            typeManager,
            asMethod: true,
            name: 'new',
            withParameterCollector: parameterCollector,
            returnType: typeManager.toTsType(_classDeclaration.element.type),
          )
        ]);
    });*/

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

  String variableName(VariableDeclaration v) {
    if (hasAnnotation(v.element.metadata, isJS)) {
      return getAnnotation(v.element.metadata, isJS).getField('name').toStringValue();
    } else {
      return v.name.name;
    }
  }

  @override
  visitFieldDeclaration(FieldDeclaration node) {
    List<TSAnnotation> dartAnno = node.metadata
        .map(annotationMapper(
            _context,
            (uri, name, arguments, namedArguments) =>
                new TSAnnotation.propertyAnnotation(uri, name, arguments, namedArguments)))
        .where(notNull)
        .toList();
    _context.tsClass.members.add(new TSVariableDeclarations(
      new List.from(node.fields.variables.map((v) => new TSVariableDeclaration(variableName(v),
          _context.processExpression(v.initializer), _context.typeManager.toTsType(node.fields.type?.type)))),
      isField: true,
      isStatic: node.isStatic,
      annotations: dartAnno,
      //isConst: node.fields.isConst || node.fields.isFinal,
    ));
  }

  @override
  visitConstructorDeclaration(ConstructorDeclaration node) {
    if (node.factoryKeyword != null) {
      // Return a static method declaration

      FormalParameterCollector collector = new FormalParameterCollector(_context);
      node.parameters.accept(collector);

      TSBody body;
      if (node.redirectedConstructor != null) {
        body = _redirectingConstructorBody(node, collector);
      } else {
        body = _context.processBody(node.body, withBrackets: false, withReturn: true);
      }

      InitializerCollector initializerCollector = new InitializerCollector(_context);
      List<TSStatement> initializers = initializerCollector.processInitializers(node.initializers);

      ConstructorType constructorType =
          (node.name?.name?.length ?? 0) > 0 ? ConstructorType.NAMED_FACTORY : ConstructorType.DEFAULT_FACTORY;

      String actualName = constructorType == ConstructorType.NAMED_FACTORY
          ? "${node.name.name}"
          : '${node.element.enclosingElement.name}';

      List<TSTypeParameter> typeParams;
      if (node.element.enclosingElement.typeParameters != null) {
        typeParams = node.element.enclosingElement.typeParameters
            .map(
                (tp) => new TSTypeParameter(tp.name, tp.bound != null ? _context.typeManager.toTsType(tp.bound) : null))
            .toList();

/*
      ctorType = new TSGenericType(
          ctorTypeName,
          new List.generate(
              (node.parent as ClassDeclaration).typeParameters.typeParameters.length, (i) => new TSSimpleType('any', false)));*/
      } else {
        typeParams = null;
      }

      TSType returnType = _context.typeManager.toTsType(node.element.enclosingElement.type);

      _context.tsClass.members.add(new TSFunction(
        _context.typeManager,
        name: "_${actualName}",
        asMethod: true,
        isStatic: true,
        withParameterCollector: collector,
        body: body,
        callSuper: (_context._classDeclaration.element.type).superclass != currentContext.typeProvider.objectType,
        constructorType: constructorType,
        typeParameters: typeParams,
        initializers: initializers,
        returnType: returnType,
      ));

      if (constructorType == ConstructorType.NAMED_FACTORY) {
        TSType ctorType = new TSFunctionType(returnType, collector.asFormalArguments, typeParams, true);

        // Add constructor declaration
        _context.tsClass.members.add(new TSVariableDeclarations(
          [new TSVariableDeclaration(actualName, null, ctorType)],
          isStatic: true,
          isField: true,
        ));
      }
    } else if (node.name != null) {
      namedConstructors[node.name.name] = node;

      // Create the static
      _createNamedConstructor(node);
    } else {
      // Create a default constructor

      FormalParameterCollector collector = new FormalParameterCollector(_context);
      node.parameters.accept(collector);

      TSBody body = _context.processBody(node.body, withBrackets: false, withReturn: false);

      InitializerCollector initializerCollector = new InitializerCollector(_context);
      List<TSStatement> initializers = initializerCollector.processInitializers(node.initializers);

      _context.tsClass.members.add(new TSFunction(_context.typeManager,
          asMethod: true,
          initializers: initializers,
          constructorType: ConstructorType.DEFAULT,
          asDefaultConstructor: true,
          callSuper: (_context._classDeclaration.element.type).superclass != currentContext.typeProvider.objectType,
          nativeSuper: getAnnotation(_context._classDeclaration.element.type.superclass.element.metadata, isJS) != null,
          withParameterCollector: collector,
          body: body,
          name: tsClass.name));
    }
  }

  TSBody _redirectingConstructorBody(ConstructorDeclaration node, FormalParameterCollector collector) {
    TSBody body;
    TSExpression target;

    if (node.redirectedConstructor.staticElement.isFactory) {
      String name;
      if (node.redirectedConstructor.name == null || node.redirectedConstructor.name.name.isEmpty) {
        name = "\$create";
      } else {
        name = node.redirectedConstructor.name.name;
      }
      target = new TSStaticRef(_context.typeManager.toTsType(node.redirectedConstructor.type.type), name);
    } else {
      if (node.redirectedConstructor.name == null || node.redirectedConstructor.name.name.isEmpty) {
        target = new TSTypeExpr(_context.typeManager.toTsType(node.redirectedConstructor.type.type));
      } else {
        String name;
        name = node.redirectedConstructor.name.name;
        target = new TSStaticRef(_context.typeManager.toTsType(node.redirectedConstructor.type.type), name);
      }
    }

    // Create arguments
    List<TSExpression> normalArgs = new List.from(collector.parameters.map((p) => new TSSimpleExpression(p.name)));
    Map<String, TSExpression> namedArgs;
    if (collector.namedType != null) {
      namedArgs =
          new Map.fromIterable(collector.namedType.fields.keys, key: (k) => k, value: (k) => new TSSimpleExpression(k));
    } else {
      namedArgs = null;
    }

    body = new TSBody(statements: [
      new TSReturnStatement(new TSInvoke(
        target,
        normalArgs,
        namedArgs,
      )..asNew = true)
    ], withBrackets: false);
    return body;
  }

  void _createNamedConstructor(ConstructorDeclaration node) {
    TSType ctorType;
    FormalParameterCollector parameterCollector = _context.collectParameters(node.parameters);
    List<TSTypeParameter> typeParams;
    if (node.element.enclosingElement.typeParameters != null) {
      typeParams = node.element.enclosingElement.typeParameters
          .map((tp) => new TSTypeParameter(tp.name, tp.bound != null ? _context.typeManager.toTsType(tp.bound) : null))
          .toList();

/*
      ctorType = new TSGenericType(
          ctorTypeName,
          new List.generate(
              (node.parent as ClassDeclaration).typeParameters.typeParameters.length, (i) => new TSSimpleType('any', false)));*/
    } else {
      typeParams = null;
    }

    TSType returnType = _context.typeManager.toTsType(node.element.enclosingElement.type);

    ctorType = new TSFunctionType(returnType, parameterCollector.asFormalArguments, typeParams, true);

    TSBody body = _context.processBody(node.body, withBrackets: false, withReturn: false);

    InitializerCollector initializerCollector = new InitializerCollector(_context);
    List<TSStatement> initializers = initializerCollector.processInitializers(node.initializers);

    String metName = '${node.name.name}';

    List<TSNode> nodes = [
      // actual constructor
      new TSFunction(
        _context.typeManager,
        name: metName,
        withParameterCollector: parameterCollector,
        body: body,
        asMethod: true,
        initializers: initializers,
        namedConstructor: true,
        constructorType: ConstructorType.NAMED,
      ),
      // getter
      new TSVariableDeclarations(
        [new TSVariableDeclaration(node.name.name, null, ctorType)],
        isStatic: true,
        isField: true,
      ),
    ];

    _context.tsClass.members.addAll(nodes);
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
      TSType superType = _context.typeManager.toTsType(node.staticElement.enclosingElement.type);
      target = new TSSimpleExpression('super.${superType.name}');
    } else {
      target = new TSSimpleExpression('super.${node.constructorName.name}');
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
      target = new TSSimpleExpression('this.${node.staticElement.enclosingElement.name}');
    } else {
      if ((node.constructorName.bestElement as ConstructorElement).isFactory) {
        target = new TSSimpleExpression('this._${node.constructorName.name}');
      } else {
        target = new TSSimpleExpression('this.${node.constructorName.name}');
      }
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

    List<TSTypeParameter> typeParameters = methodTypeParameters(_methodDeclaration);

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
      bool unary = _methodDeclaration.parameters.parameters.isEmpty;
      name = "[${operatorMethodSymbol(tk, unary)}]";
    }

    // Dart Annotations
    annotations.addAll(_methodDeclaration.metadata
        .map(annotationMapper(
            this,
            (uri, name, arguments, namedArguments) =>
                new TSAnnotation.methodAnnotation(uri, name, arguments, namedArguments)))
        .where(notNull));

    parentContext.tsClass.members.add(new TSFunction(
      typeManager,
      name: name,
      returnType: typeManager.toTsType(_methodDeclaration.returnType?.type),
      isAsync: _methodDeclaration.body.isAsynchronous,
      topLevel: topLevel,
      typeParameters: typeParameters,
      asMethod: true,
      isGenerator: _methodDeclaration.body.isGenerator,
      isAbstract: _methodDeclaration.isAbstract,
      isStatic: _methodDeclaration.isStatic,
      isGetter: _methodDeclaration.isGetter,
      isSetter: _methodDeclaration.isSetter,
      body: _methodDeclaration.isAbstract ? null : body,
      annotations: annotations,
      withParameterCollector: parameterCollector,
      declared: _declarationMode,
    ));
  }
}

String operatorSymbol(TokenType tk, bool unary) {
  if (unary) {
    return <TokenType, String>{
      TokenType.MINUS: 'Op.NEG',
      TokenType.TILDE: 'Op.BITNEG',
    }[tk];
  } else {
    return <TokenType, String>{
      TokenType.PLUS: 'Op.PLUS',
      TokenType.MINUS: 'Op.MINUS',
      TokenType.STAR: 'Op.TIMES',
      TokenType.SLASH: 'Op.DIVIDE',
      TokenType.TILDE_SLASH: 'Op.QUOTIENT',
      TokenType.EQ_EQ: 'Op.EQUALS',
      TokenType.INDEX: 'Op.INDEX',
      TokenType.INDEX_EQ: 'Op.INDEX_ASSIGN',
      TokenType.LT: 'Op.LT',
      TokenType.GT: 'Op.GT',
      TokenType.LT_EQ: 'Op.LEQ',
      TokenType.GT_EQ: 'Op.GEQ',
      TokenType.CARET: 'Op.XOR',
      TokenType.BAR: 'Op.BITOR',
      TokenType.AMPERSAND: 'Op.BITAND',
      TokenType.GT_GT: 'Op.SHIFTRIGHT',
      TokenType.LT_LT: 'Op.SHIFTLEFT',
      TokenType.PERCENT: 'Op.MODULE',
    }[tk];
  }
}

String operatorMethodSymbol(TokenType tk, bool unary) {
  if (unary) {
    return <TokenType, String>{
      TokenType.MINUS: 'OperatorMethods.NEGATE',
      TokenType.TILDE: 'OperatorMethods.COMPLEMENT',
    }[tk];
  } else {
    return <TokenType, String>{
      TokenType.PLUS: 'OperatorMethods.PLUS',
      TokenType.MINUS: 'OperatorMethods.MINUS',
      TokenType.STAR: 'OperatorMethods.MULTIPLY',
      TokenType.SLASH: 'OperatorMethods.DIVIDE',
      TokenType.TILDE_SLASH: 'OperatorMethods.QUOTIENT',
      TokenType.EQ_EQ: 'OperatorMethods.EQUALS',
      TokenType.INDEX: 'OperatorMethods.INDEX',
      TokenType.INDEX_EQ: 'OperatorMethods.INDEX_EQ',
      TokenType.LT: 'OperatorMethods.LT',
      TokenType.GT: 'OperatorMethods.GT',
      TokenType.LT_EQ: 'OperatorMethods.LEQ',
      TokenType.GT_EQ: 'OperatorMethods.GEQ',
      TokenType.CARET: 'OperatorMethods.XOR',
      TokenType.BAR: 'OperatorMethods.BINARY_OR',
      TokenType.AMPERSAND: 'OperatorMethods.BINARY_AND',
      TokenType.GT_GT: 'OperatorMethods.SHIFTRIGHT',
      TokenType.LT_LT: 'OperatorMethods.SHIFTLEFT',
      TokenType.PERCENT: 'OperatorMethods.MODULE',
    }[tk];
  }
}

TSExpression toOperatorSymbolExpression(TokenType tk, bool unary) => new TSStringLiteral(operatorSymbol(tk, unary));
