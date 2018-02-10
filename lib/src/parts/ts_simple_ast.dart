part of '../code_generator2.dart';

/**
 * TS Generator
 * (to be moved in another lib)
 */

abstract class TSNode extends PrinterWriter {
  void writeCode(IndentingPrinter printer);
}

class TSLibrary extends TSNode {
  String _name;
  List<TSFile> _children = [];

  Iterable<TSImport> imports;

  TSGlobalContext globalContext;

  TSLibrary(this._name) {}

  @override
  void writeCode(IndentingPrinter printer) {
    printer.writeln("/** Library ${_name} */");

    imports.forEach((i) => printer.accept(i));
    printer.writeln();

    if (globalContext != null) {
      printer.accept(globalContext);
    }

    List<String> exported = [];
    List<TSNode> topLevelGetterAndSetters = [];
    _children.forEach((f) {
      f._declarations.forEach((d) {
        if ((d is TSFunction && (d.isGetter || d.isSetter)) || d is TSVariableDeclarations) {
          topLevelGetterAndSetters.add(d);
        } else {
          printer.accept(d);
          if (d is TSStatement && d.needsSeparator) {
            printer.write(';');
          }
          printer.writeln();
        }
        if (d is TSFunction) {
          exported.add(d.name);
        } else if (d is TSClass && !d.isInterface) {
          exported.add(d.name);
        }
      });
    });

    printer.writeln('export class Module {');
    printer.indented((p) {
      topLevelGetterAndSetters.forEach((n) {
        printer.accept(n);
        printer.writeln();
      });
    });
    printer.writeln('}');
    printer.writeln('export var module : Module = new Module();');
  }

  void addChild(TSFile child) {
    _children.add(child);
  }
}

abstract class TSDeclareContext extends TSNode {
  List<TSNode> _children = [];

  Map<String, TSDeclareContext> _subContexts = {};

  void addChild(TSNode n) {
    _children.add(n);
  }

  TSDeclareContext resolveSubcontext(String name) => _subContexts.putIfAbsent(name, () => new TSNamespaceContext(name));

  void writeChildren(IndentingPrinter printer) {
    _subContexts.values.forEach((s) => printer.accept(s));
    _children.forEach((n) => printer.accept(n));
  }
}

class TSGlobalContext extends TSDeclareContext {
  @override
  void writeCode(IndentingPrinter printer) {
    printer.writeln('declare global {');
    printer.indented(writeChildren);
    printer.writeln('}');
  }
}

class TSNamespaceContext extends TSDeclareContext {
  String _name;

  TSNamespaceContext(this._name);

  @override
  void writeCode(IndentingPrinter printer) {
    printer.writeln('namespace ${_name} {');
    printer.indented(writeChildren);
    printer.writeln('}');
  }
}

class TSClass extends TSNode {
  String name;
  List<TSNode> members = [];
  TSType superClass;
  bool topLevel;
  bool isInterface;
  Iterable<TSTypeExpr> implemented;
  String library;
  bool declared;
  List<TSType> typeParameters;

  TSClass(
      {this.topLevel: true,
      this.isInterface: false,
      this.implemented,
      this.library,
      this.declared: false,
      this.typeParameters});

  @override
  void writeCode(IndentingPrinter printer) {
    if (library != null && !isInterface) {
      printer.writeln('@bare.DartMetadata({library:\'${this.library}\'})');
    }

    if (topLevel) {
      printer.write('export ');
    }

    if (isInterface) {
      printer.write('interface');
    } else {
      printer.write('class');
    }
    printer.write(' ${name}');

    if (typeParameters != null && typeParameters.isNotEmpty) {
      printer.write('<');
      printer.join(typeParameters);
      printer.write('> ');
    }

    if (superClass != null) {
      printer.write(' extends ');
      printer.accept(superClass);
    }
    if (implemented != null && implemented.isNotEmpty) {
      printer.write(' implements ');
      printer.join(implemented);
    }
    printer.writeln(' {');
    if (members != null)
      printer.indented((p) {
        members.forEach((m) {
          p.accept(m);
          if (declared) {
            p.write(';');
          }
          p.writeln();
        });
      });
    printer.writeln('}');
  }
}

abstract class TSType extends TSNode {
  bool _isObject;

  bool get isObject => _isObject;

  TSType(this._isObject);
}

class TSSimpleType extends TSType {
  String _name;

  TSSimpleType(this._name, bool isObject) : super(isObject);

  @override
  void writeCode(IndentingPrinter printer) {
    printer.write(_name);
  }
}

class TSTypeExpr extends TSExpression {
  TSType _type;
  bool _asDeclaration;
  bool _noTypeParams = false;

  TSTypeExpr(this._type, [this._asDeclaration = true]);

  TSTypeExpr.noTypeParams(this._type) {
    _noTypeParams = true;
  }

  @override
  void writeCode(IndentingPrinter printer) {
    if (_noTypeParams) {
      if (_type is TSSimpleType) {
        printer.write((_type as TSSimpleType)._name);
        return;
      }
    }
    if (_asDeclaration || _type.isObject) {
      printer.accept(_type);
    } else {
      printer.write('"');
      printer.accept(_type);
      printer.write('"');
    }
  }
}

class TSInstanceOf extends TSExpression {
  TSExpression _expr;
  TSTypeExpr _type;

  TSInstanceOf(this._expr, this._type);

  @override
  void writeCode(IndentingPrinter printer) {
    printer.write('bare.is(');
    printer.accept(_expr);
    printer.write(', ');
    printer.accept(_type);
    printer.write(')');
  }
}

class TSThrow extends TSExpression {
  TSExpression _what;

  TSThrow(this._what);

  @override
  void writeCode(IndentingPrinter printer) {
    printer.write('throw ');
    printer.accept(_what);
  }
}

class TSFunctionType extends TSType {
  TSType _returnType;
  List<TSType> _typeArguments;
  List<TSType> _argumentsType;

  TSFunctionType(this._returnType, this._argumentsType, [this._typeArguments]) : super(true);

  @override
  void writeCode(IndentingPrinter printer) {
    if (_typeArguments?.isNotEmpty ?? false) {
      printer.write('<');
      printer.join(_typeArguments);
      printer.write('>');
    }
    printer.write('(');
    printer.join(_argumentsType);
    printer.write(') => ');
    printer.accept(_returnType);
  }
}

class TSInterfaceType extends TSType {
  Map<String, TSType> fields;

  TSInterfaceType({this.fields}) : super(true) {
    fields ??= {};
  }

  @override
  void writeCode(IndentingPrinter printer) {
    printer.write('{');
    printer.joinConsumers(fields.keys.map((k) => (IndentingPrinter p) {
          p.write("${k}? : ");
          p.accept(fields[k]);
        }));
    printer.write('}');
  }
}

class TSGenericType extends TSSimpleType {
  Iterable<TSType> _typeArguments;

  TSGenericType(String name, this._typeArguments) : super(name, true);

  @override
  void writeCode(IndentingPrinter printer) {
    super.writeCode(printer);
    if (_typeArguments?.isNotEmpty ?? false) {
      printer.write('<');
      printer.join(_typeArguments);
      printer.write('>');
    }
  }
}

class TSOptionalType extends TSType {
  TSType _type;

  TSOptionalType(this._type) : super(_type.isObject);

  @override
  void writeCode(IndentingPrinter printer) {
    printer.accept(_type);
    printer.write('?');
  }
}

class TSTypeParameter extends TSNode {
  String name;
  TSType bound;

  TSTypeParameter(this.name, this.bound);

  @override
  void writeCode(IndentingPrinter printer) {
    printer.write(name);
    if (bound != null) {
      printer.write(" extends ");
      printer.accept(bound);
    }
  }
}

class TSStringInterpolation extends TSExpression {
  List<TSNode> _elements;

  TSStringInterpolation(this._elements);

  @override
  void writeCode(IndentingPrinter printer) {
    printer.write('`');
    printer.join(_elements, delim: '');
    printer.write('`');
  }
}

class TSInterpolationExpression extends TSNode {
  TSExpression _expression;

  TSInterpolationExpression(this._expression);

  @override
  void writeCode(IndentingPrinter printer) {
    printer.write('\${');
    printer.accept(_expression);
    printer.write('}');
  }
}

class TSAnnotation extends TSNode {
  TSInvoke _invoke;

  TSAnnotation(this._invoke);

  @override
  void writeCode(IndentingPrinter printer) {
    printer.write('@');
    printer.accept(_invoke);
  }
}

/**
 * TSFunction
 *
 * This is one of the most complex case. A function can be a top level function,
 * a function declared inside a method, a function expression, a method, a property accessor.
 * They can be generator and async or both.
 * For many of this combination there's a different style.
 *
 * Dart scope for `this` is different from that of JS when using the `function` keyword, and is the same of
 * the "arrow function" expression. Thus we're using "arrow function" expression style everywhere we can to
 * preserve the same semantic.
 *
 * This cannot be done for generator (sync and async). Also we need, for those special cases to wrap the js generator
 * to a proper wrapper object (`DartIterable`, `DartStream`). So we need to use a more complex strategy in order to:
 *  - preserve the `this` scope
 *  - wrap the result
 *
 * The result is an ugly method full of if/then/else that probably will need to be rewritten.
 */

class TSFunction extends TSExpression implements TSStatement {
  String name;
  bool topLevel;
  TSType returnType;
  Iterable<TSTypeParameter> typeParameters;
  List<TSParameter> parameters;
  Map<String, TSType> namedParameters;
  Map<String, TSExpression> defaults;
  Map<String, TSExpression> namedDefaults;
  TSBody body;
  bool asMethod = false;
  bool isGetter = false;
  bool isSetter = false;
  bool isStatic = false;
  bool asDefaultConstructor = false;
  bool callSuper = false;
  bool isAsync;
  bool isOperator;
  bool isGenerator;
  List<TSAnnotation> annotations;
  List<TSStatement> initializers;
  bool isExpression;
  TypeManager tm;
  String prefix;
  bool declared;

  TSFunction(
    this.tm, {
    this.name,
    this.topLevel: false,
    this.isAsync: false,
    this.isGenerator: false,
    this.returnType,
    this.typeParameters,
    this.parameters,
    this.namedParameters,
    this.defaults,
    this.namedDefaults,
    this.body,
    this.asMethod: false,
    this.isGetter: false,
    this.asDefaultConstructor: false,
    this.isSetter: false,
    this.isStatic: false,
    this.callSuper: false,
    this.initializers,
    this.isExpression: false,
    this.annotations: const [],
    FormalParameterCollector withParameterCollector,
    this.declared: false,
  }) {
    if (isGenerator) {
      if (isAsync) {
        prefix = tm.namespace(getLibrary(currentContext, 'dart:async'));
      } else {
        prefix = tm.namespaceFor(uri: 'module:dart_sdk/collection', modulePath: 'dart_sdk/collection');
      }
    }
    if (withParameterCollector != null) {
      parameters = new List.from(withParameterCollector.tsParameters);
      namedParameters = withParameterCollector.namedType?.fields;
      defaults = withParameterCollector.defaults;
      namedDefaults = withParameterCollector.namedDefaults;
      initializers ??= [];
      initializers.addAll(withParameterCollector.fields?.map((f) => new TSExpressionStatement(
          new TSAssignamentExpression(
              new TSDotExpression(new TSSimpleExpression('this'), f), new TSSimpleExpression(f)))));
    }
  }

  @override
  void writeCode(IndentingPrinter printer) {
    annotations.forEach((anno) {
      printer.accept(anno);
      printer.writeln();
    });

    if (topLevel && !isGetter && !isSetter) {
      printer.write('export ');
    }
    // If not expression or is a topleve getter and setter (that should be treated as normal get set of module)

    bool treatAsExpression = isExpression && (!topLevel || (!isGetter && !isSetter));

    if (!treatAsExpression) {
      if (asDefaultConstructor) {
        printer.writeln('constructor(...args)');
        printer.write('constructor(');
        printer.join(parameters);
        printer.writeln(') {');
        printer.indented((p) {
          if (callSuper) {
            p.writeln('super(bare.init);');
          }
          // Call bare init
          p.write('arguments[0] != bare.init && this[bare.init](');
          p.joinConsumers(parameters.map((par) => (p) {
                p.write(par.name);
              }));
          p.writeln(');');
        });
        printer.writeln('}');

        printer.write(('[bare.init]'));
      } else {
        if (isStatic) printer.write('static ');
        if (isAsync) {
          printer.write("async ");
        }
        if (!asMethod && !isGetter && !isSetter) printer.write('function ');
        if (isGetter) printer.write('get ');
        if (isSetter) printer.write('set ');
      }

      if (name != null) {
        printer.write(name);
      }
    } else {
      if (name != null) {
        printer.write('var ${name} = ');
      }

      if (isAsync && !isGenerator) {
        printer.write('async ');
      }
    }

    if (typeParameters != null) {
      printer.write('<');
      printer.join(typeParameters);
      printer.write('>');
    }

    printer.write('(');
    if (parameters != null) printer.join(parameters);
    printer.write(')');

    if (returnType != null && !isSetter) {
      printer.write(" : ");
      printer.accept(returnType);
    }

    if (treatAsExpression) {
      printer.write(' => ');
    }

    if (isGenerator) {
      TSType t;
      if (returnType != null && returnType is TSGenericType) {
        t = (returnType as TSGenericType)._typeArguments.first;
      } else {
        t = new TSSimpleType('any', false);
      }
      if (isAsync) {
        printer.write('${prefix}.stream');

        printer.write('<');
        printer.accept(t);
        printer.write('>');
        printer.write('(()=>(async function*() ');
      } else {
        printer.write('${prefix}.iter');
        printer.write('<');
        printer.accept(t);
        printer.write('>');
        printer.write('(()=>(function*() ');
      }
    }

    if (body != null) {
      printer.writeln(' {');
      printer.indented((printer) {
        //printer.writeln('/* init */');

        // Init all values

        defaults?.keys?.forEach((def) {
          printer.write("${def} = ${def} || ");
          printer.accept(defaults[def]);
          printer.writeln(";");
        });

        if (namedDefaults?.isNotEmpty ?? false) {
          printer.writeln('${NAMED_ARGUMENTS} = Object.assign({');

          printer.indented((printer) {
            printer.joinConsumers(
                namedDefaults.keys.map((k) => (p) {
                      p.write('"${k}" : ');
                      p.accept(namedDefaults[k]);
                    }),
                newLine: true);
          });

          printer.writeln('}, ${NAMED_ARGUMENTS} || {});');
        } else if (namedParameters?.isNotEmpty ?? false) {
          printer.writeln('${NAMED_ARGUMENTS} = ${NAMED_ARGUMENTS} || {};');
        }

        // Explode named args
        namedParameters?.keys?.forEach((k) {
          printer.write('let ${k} : ');
          printer.accept(namedParameters[k]);
          printer.writeln(' = ${NAMED_ARGUMENTS}.${k};');
        });

        // Initializers
        if (initializers != null) {
          initializers.forEach((st) {
            printer.accept(st);
            printer.writeln(";");
          });
        }

        //printer.writeln('/* body */');
        printer.accept(body);
      });
      printer.write("}");
    }

    if (isGenerator) {
      printer.write(').call(this))');
    }
  }

  @override
  bool get needsSeparator => true;
}

class TSPostfixOperandExpression extends TSExpression {
  String _op;
  TSExpression _expr;

  TSPostfixOperandExpression(this._op, this._expr);

  @override
  void writeCode(IndentingPrinter printer) {
    printer.accept(_expr);
    printer.write(_op);
  }
}

class TSPrefixOperandExpression extends TSExpression {
  String _op;
  TSExpression _expr;

  TSPrefixOperandExpression(this._op, this._expr);

  @override
  void writeCode(IndentingPrinter printer) {
    printer.write(_op);
    printer.accept(_expr);
  }
}

class TSConditionalExpression extends TSExpression {
  TSExpression _cond;
  TSExpression _true;
  TSExpression _false;

  TSConditionalExpression(this._cond, this._true, this._false);

  @override
  void writeCode(IndentingPrinter printer) {
    printer.accept(_cond);
    printer.write(' ? ');
    printer.accept(_true);
    printer.write(' : ');
    printer.accept(_false);
  }
}

class TSIndexExpression extends TSExpression {
  TSExpression _target;
  TSExpression _index;

  TSIndexExpression(this._target, this._index);

  @override
  void writeCode(IndentingPrinter printer) {
    printer.accept(_target);
    printer.write('[');
    printer.accept(_index);
    printer.write(']');
  }
}

class TSList extends TSExpression {
  List<TSExpression> _elements;

  TSList(this._elements);

  @override
  void writeCode(IndentingPrinter printer) {
    printer.write('[');
    printer.join(_elements);
    printer.write(']');
  }
}

abstract class TSStatement extends TSNode {
  bool get needsSeparator => true;
}

class TSReturnStatement extends TSStatement {
  TSExpression value;

  TSReturnStatement([this.value]);

  @override
  void writeCode(IndentingPrinter printer) {
    printer.write('return');
    if (value != null) {
      printer.write(' ');
      printer.accept(value);
    }
  }
}

class TSFile extends TSNode {
  CompilationUnit _cu;
  Iterable<TSNode> _declarations;

  TSFile(this._cu, this._declarations);

  @override
  void writeCode(IndentingPrinter printer) {
    printer.writeln('/** from ${_cu.element.source.fullName} */');
    _declarations.forEach((n) {
      printer.accept(n);
      if (n is TSStatement && n.needsSeparator) {
        printer.write(';');
      }
      printer.writeln();
    });
    printer.writeln();
  }
}

class TSUnknownStatement extends TSStatement {
  Statement _unknown;

  TSUnknownStatement(this._unknown);

  @override
  void writeCode(IndentingPrinter printer) {
    printer.write("/* TODO (${_unknown.runtimeType}) : ${_unknown} */");
  }
}

class TSBody extends TSStatement {
  bool withBrackets;
  Iterable<TSStatement> statements;

  bool newLine;

  @override
  bool get needsSeparator => false;

  TSBody({this.statements, this.withBrackets: true, this.newLine: true});

  @override
  void writeCode(IndentingPrinter printer) {
    if (withBrackets) {
      printer.writeln('{');
      printer.indented((p) {
        statements.forEach((s) {
          p.accept(s);
          if (s.needsSeparator)
            p.writeln(';');
          else
            p.writeln();
        });
      });
      printer.write('}');
      if (newLine) {
        printer.writeln();
      }
    } else {
      statements.forEach((s) {
        printer.accept(s);
        if (s.needsSeparator)
          printer.writeln(';');
        else
          printer.writeln();
      });
    }
  }
}

class TSAsExpression extends TSExpression {
  TSExpression _expression;
  TSType _type;

  TSAsExpression(this._expression, this._type);

  @override
  void writeCode(IndentingPrinter printer) {
    printer.accept(_expression);
    printer.write(" as ");
    printer.accept(_type);
  }
}

class TSStaticRef extends TSExpression {
  TSType _type;
  String _name;

  TSStaticRef(this._type, this._name);

  @override
  void writeCode(IndentingPrinter printer) {
    printer.accept(new TSTypeExpr.noTypeParams(_type));
    printer.write('.${_name}');
  }
}

class TSTypeRef extends TSExpression {
  TSType _type;

  TSTypeRef(this._type);

  @override
  void writeCode(IndentingPrinter printer) {
    printer.accept(_type);
  }
}

class TSAwaitExpression extends TSExpression {
  TSExpression _expr;

  TSAwaitExpression(this._expr);

  @override
  void writeCode(IndentingPrinter printer) {
    printer.write("await ");
    printer.accept(_expr);
  }
}

class TSDeclaredIdentifier extends TSNode {
  String _name;
  TSType _type;

  TSDeclaredIdentifier(this._name, this._type);

  @override
  void writeCode(IndentingPrinter printer) {
    printer.write('let ${_name}');
    if (_type != null) {
      printer.write(' : ');
      printer.accept(_type);
    }
  }
}

class TSWhileStatement extends TSStatement {
  TSExpression _cond;
  TSStatement _body;

  TSWhileStatement(this._cond, this._body);

  @override
  void writeCode(IndentingPrinter printer) {
    printer.write('while (');
    printer.accept(_cond);
    printer.write(')');
    printer.accept(_body);
  }

  @override
  bool get needsSeparator => _body.needsSeparator;
}

class TSDoWhileStatement extends TSStatement {
  TSExpression _cond;
  TSStatement _body;

  TSDoWhileStatement(this._cond, this._body);

  @override
  void writeCode(IndentingPrinter printer) {
    printer.write('do');
    printer.accept(_body);
    printer.write(' while (');
    printer.accept(_cond);
    printer.write(')');
  }
}

class TSForEachStatement extends TSStatement {
  TSDeclaredIdentifier _ident;
  TSExpression _iterable;
  TSStatement _body;
  bool isAsync;

  TSForEachStatement(this._ident, this._iterable, this._body, {this.isAsync});

  @override
  void writeCode(IndentingPrinter printer) {
    printer.write('for${isAsync ? ' await' : ''}(');
    printer.accept(_ident);
    printer.write(' of ');
    printer.accept(_iterable);
    printer.write(') ');
    printer.accept(_body);
  }

  @override
  bool get needsSeparator => _body.needsSeparator;
}

class TSInvoke extends TSExpression {
  /// True if you want to call the method using square brakets notation
  TSExpression _target;
  List<TSExpression> _arguments;
  Map<String, TSExpression> _namedArguments;
  bool asNew = false;

  TSInvoke(this._target, [this._arguments, this._namedArguments]);

  @override
  void writeCode(IndentingPrinter printer) {
    if (asNew) {
      printer.write("new ");
    }
    printer.accept(_target);
    writeArguments(printer);
  }

  void writeArguments(IndentingPrinter printer) {
    printer.write('(');
    printer.joinConsumers(() sync* {
      if (_arguments != null) {
        yield* _arguments.map((a) => (p) => p.accept(a));
      }

      if (_namedArguments != null) {
        yield (p) {
          p.accept(new TSObjectLiteral(_namedArguments));
        };
      }
    }());
    printer.write(')');
  }
}

class TSDotExpression extends TSExpression {
  TSExpression _expression;
  String _name;

  TSDotExpression(this._expression, this._name);

  @override
  void writeCode(IndentingPrinter printer) {
    printer.accept(_expression);
    printer.write('.${_name}');
  }
}

class TSSquareExpression extends TSExpression {
  TSExpression _expression;
  TSExpression _index;

  TSSquareExpression(this._expression, this._index);

  @override
  void writeCode(IndentingPrinter printer) {
    printer.accept(_expression);
    printer.write('[');
    printer.accept(_index);
    printer.write(']');
  }
}

class TSBracketExpression extends TSExpression {
  TSExpression _expression;

  TSBracketExpression(this._expression);

  @override
  void writeCode(IndentingPrinter printer) {
    printer.write('(');
    printer.accept(_expression);
    printer.write(')');
  }
}

class TSAssignamentExpression extends TSExpression {
  TSExpression _target;
  TSExpression _value;

  TSAssignamentExpression(this._target, this._value);

  @override
  void writeCode(IndentingPrinter printer) {
    printer.accept(_target);
    printer.write(' = ');
    printer.accept(_value);
  }
}

class TSObjectLiteral extends TSExpression {
  Map<String, TSExpression> _fields;

  TSObjectLiteral(this._fields);

  @override
  void writeCode(IndentingPrinter printer) {
    printer.writeln('{');
    printer.indented((p) {
      p.joinConsumers(_fields.keys.map((k) => (p) {
            p.write(k);
            p.write(' : ');
            p.accept(_fields[k]);
          }));
    });
    printer.write(('}'));
  }
}

class TSBinaryExpression extends TSExpression {
  TSExpression _left;
  TSExpression _right;
  String _operand;

  TSBinaryExpression(this._left, this._operand, this._right);

  @override
  void writeCode(IndentingPrinter printer) {
    printer.accept(_left);
    printer.write(' ${_operand} ');
    printer.accept(_right);
  }
}

class TSVariableDeclaration extends TSNode {
  String _name;
  TSExpression _initializer;
  TSType _type;

  TSVariableDeclaration(this._name, this._initializer, this._type);

  @override
  void writeCode(IndentingPrinter printer) {
    printer.write(_name);
    if (_type != null) {
      printer.write(" : ");
      printer.accept(_type);
    }
    if (_initializer != null) {
      printer.write(' = ');
      printer.accept(_initializer);
    }
  }

// bool get needsSeparator => _initializer is! TSFunction;
}

class TSNodes extends TSNode {
  List<TSNode> _nodes;

  TSNodes(this._nodes);

  @override
  void writeCode(IndentingPrinter printer) {
    _nodes.forEach((n) {
      printer.accept(n);
      printer.writeln();
    });
  }
}

class TSYieldStatement extends TSStatement {
  TSExpression _espr;
  bool many;

  TSYieldStatement(this._espr, {this.many: false});

  @override
  void writeCode(IndentingPrinter printer) {
    if (many) {
      printer.write('yield* ');
    } else {
      printer.write('yield ');
    }

    printer.accept(_espr);
  }
}

class TSCase extends TSStatement {
  TSExpression _expr;
  List<TSStatement> _statements;
  bool _isDefault;

  TSCase(this._expr, this._statements) {
    _isDefault = false;
  }

  TSCase.defaultCase(this._statements) {
    _isDefault = true;
  }

  @override
  void writeCode(IndentingPrinter printer) {
    if (_isDefault) {
      printer.writeln('default:');
    } else {
      printer.write('case ');
      printer.accept(_expr);
      printer.writeln(':');
    }
    printer.indented((p) {
      p.accept(new TSBody(statements: this._statements, withBrackets: false));
    });
  }
}

class TSSwitchStatement extends TSStatement {
  TSExpression _expr;
  List<TSStatement> _members;

  TSSwitchStatement(this._expr, this._members);

  @override
  void writeCode(IndentingPrinter printer) {
    printer.write('switch (');
    printer.accept(_expr);
    printer.writeln(') {');
    printer.indented((p) {
      _members.forEach((m) => printer.accept(m));
    });
    printer.write('}');
  }

  @override
  bool get needsSeparator => false;
}

class TSForStatement extends TSStatement {
  TSNode _variables;
  TSExpression _init;
  TSExpression _condition;
  List<TSExpression> _updaters;
  TSStatement _body;

  TSForStatement(this._variables, this._init, this._condition, this._updaters, this._body);

  @override
  void writeCode(IndentingPrinter printer) {
    printer.write('for(');
    if (_variables != null) {
      printer.accept(_variables);
    }
    if (_init != null) {
      printer.accept(_init);
    }
    printer.write('; ');
    printer.accept(_condition);
    printer.write('; ');
    printer.join(_updaters);
    printer.write(')');
    printer.accept(_body);
  }

  @override
  bool get needsSeparator => _body.needsSeparator;
}

class TSIfStatement extends TSStatement {
  TSExpression _condition;
  TSStatement _then;
  TSStatement _else;

  TSIfStatement(this._condition, this._then, this._else);

  @override
  void writeCode(IndentingPrinter printer) {
    printer.write('if (');
    printer.accept(_condition);
    printer.write(') ');
    printer.accept(_then);
    if (_then.needsSeparator) {
      printer.write(';');
    }
    if (_else != null) {
      printer.write('else ');
      printer.accept(_else);
      if (_else.needsSeparator) {
        printer.write(';');
      }
    }
  }

  @override
  bool get needsSeparator => false;
}

class TSVariableDeclarations extends TSStatement {
  Iterable<TSVariableDeclaration> _declarations;
  bool isStatic;
  bool isField;
  bool isTopLevel;
  bool isConst;
  bool readonly;
  bool declared;

  TSVariableDeclarations(this._declarations,
      {this.isStatic: false,
      this.isField: false,
      this.isTopLevel: false,
      this.isConst: false,
      this.readonly: false,
      this.declared: false});

  @override
  void writeCode(IndentingPrinter printer) {
    if (isStatic) {
      printer.write('static ');
    }

    if (readonly) {
      printer.write('readonly ');
    }

    if (isConst) {
      printer.write('const ');
    }

    if (!isField) {
      printer.write('let ');
    }
    printer.join(_declarations);
    if (isField) {
      printer.write(';');
    }
  }
}

class TSExpressionStatement extends TSStatement {
  TSExpression _expression;

  TSExpressionStatement(this._expression);

  @override
  void writeCode(IndentingPrinter printer) {
    printer.accept(_expression);
  }

  @override
  bool get needsSeparator => _expression is! TSFunction && _expression is! TSBody;
}

class TSParameter extends TSNode {
  String name;
  TSType type;
  bool optional;

  TSParameter({this.name, this.type, this.optional = false});

  @override
  void writeCode(IndentingPrinter printer) {
    assert(name != null, "Parameters should have a name");
    printer.write(name);
    if (optional) {
      printer.write('?');
    }
    if (type != null) {
      printer.write(" : ");
      printer.accept(type);
    }
  }
}

class TSSimpleExpression extends TSExpression {
  String _expression;

  TSSimpleExpression(this._expression);

  @override
  void writeCode(IndentingPrinter printer) {
    printer.write(_expression);
  }
}

abstract class TSExpression extends TSNode {}

class TSUnknownExpression extends TSExpression {
  Expression _unknown;

  TSUnknownExpression(this._unknown);

  @override
  void writeCode(IndentingPrinter printer) {
    printer.write(('/* TODO (${_unknown.runtimeType}): ${_unknown} */'));
  }
}
