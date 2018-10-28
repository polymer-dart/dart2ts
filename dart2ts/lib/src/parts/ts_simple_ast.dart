part of '../code_generator.dart';

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

  List<TSStatement> onModuleLoad = [];

  Set<String> exports = new Set();

  int Function(TSNode n1, TSNode n2) order;

  TSLibrary(this._name, {this.order}) {}

  @override
  void writeCode(IndentingPrinter printer) {
    printer.writeln("/** Library ${_name} */");

    //printer.writeln(
    //   "import {defaultConstructor,namedConstructor,namedFactory,defaultFactory,DartClass,Implements} from '${SDK_LIBRARY}/utils';");
    imports.forEach((i) => printer.accept(i));
    printer.writeln();
    exports.forEach((i) {
      printer.writeln('export * from "${i}";');
    });

    if (globalContext != null) {
      printer.accept(globalContext);
    }

    List<String> exported = [];
    List<TSNode> topLevelGetterAndSetters = [];

    new List.from(_children.expand((f) => f._declarations))
      ..sort(order)
      ..forEach((d) {
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

    printer.writeln('export class ${MODULE_PROPERTIES} {');
    printer.indented((p) {
      topLevelGetterAndSetters.forEach((n) {
        if (n is TSFunction) {
          n.isStatic = true;
        }
        printer.accept(n);
        printer.writeln();
      });
    });
    printer.writeln('}');
    // printer.writeln('export const ${MODULE_PROPERTIES} : _Properties = new _Properties();');

    if (onModuleLoad.isNotEmpty) {
      printer.writeln('// On module load');
      printer.writeln();
      onModuleLoad.forEach((s) {
        printer.accept(s);
        if (s.needsSeparator) {
          printer.write(';');
        }
        printer.writeln();
      });
    }
  }

  void addChild(TSFile child) {
    _children.add(child);
  }

  void addExport(String export) {
    exports.add(export);
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
  List<TSTypeExpr> implemented = [];
  String library;
  bool declared;
  List<TSType> typeParameters;
  List<TSAnnotation> annotations;

  bool isAbstract = false;

  List<TSTypeExpr> mixins = [];

  bool isNative=false;

  TSClass(
      {this.topLevel: true,
      this.isInterface: false,
      implemented,
      this.library,
      this.declared: false,
      this.typeParameters})
      : implemented = implemented ?? [];

  List<TSStatement> extractAllInitializerExpressions([bool statics = false]) {
    return new List.from(members
        .where((m) => m is TSVariableDeclarations && m.isStatic == statics)
        .expand((vd) => (vd as TSVariableDeclarations)._declarations)
        .where((v) => v._initializer != null)
        .map((v) => new TSAssignamentExpression(
            statics
                ? new TSStaticRef(new TSSimpleType(name, true), v._name)
                : new TSDotExpression(TSSimpleExpression.THIS, v._name),
            v._initializer,
            "=")));
  }

  static bool isConstructor(TSNode n) =>
      (n is TSFunction && (n.constructorType == ConstructorType.DEFAULT || n.constructorType == ConstructorType.NAMED));

  void _writeTypeParameters(IndentingPrinter printer) {
    if (typeParameters != null && typeParameters.isNotEmpty) {
      printer.write("<");
      printer.join(typeParameters);
      printer.write(">");
    }
  }

  void writeInterfaceCode(IndentingPrinter printer) {
    if (isNative) {
      return;
    }
    printer.writeln("export namespace ${name} {");
    printer.indented((_) {
      // Constructors

      List<TSFunction> constructors = new List.from(members.where(isConstructor));

      printer.write("export type Constructors = ");
      if (superClass != null) {
        printer.accept(new TSTypeExpr.noTypeParams(superClass));
        printer.write(".Constructors | ");
      }
      printer.joinConsumers(constructors.map((c) => (p) => p.write("'${c.name}'")), delim: ' | ');
      if (constructors.isEmpty) {
        printer.write("never");
        //printer.write("'${name}'");
      }
      printer.writeln(';');

      // Interface
      printer.write("export type Interface");
      _writeTypeParameters(printer);
      printer.write(" = Omit<");
      printer.write(name);
      _writeTypeParameters(printer);
      printer.writeln(", Constructors>;");
    });

    printer.writeln("}");
  }

  @override
  void writeCode(IndentingPrinter printer) {
    writeInterfaceCode(printer);

    if (library != null && !isInterface) {
      printer.writeln('@DartClass');
    }
    if (implemented != null && implemented.isNotEmpty) {
      printer.write('@Implements(');
      printer.joinConsumers(implemented.map((intf) => (p) => new TSTypeExpr.noTypeParams(intf._type).writeCode(p)));
      printer.writeln(')');
    }

    if (mixins != null && mixins.isNotEmpty) {
      printer.write('@With(');
      printer.joinConsumers(mixins.map((intf) => (p) => new TSTypeExpr.noTypeParams(intf._type).writeCode(p)));
      printer.writeln(')');
    }

    annotations?.forEach((a) {
      printer.accept(a);
      printer.writeln();
    });

    if (topLevel) {
      printer.write('export ');
    }

    if (declared) {
      printer.write('declare ');
    }

    if (isAbstract) {
      // No more abstact things
      // printer.write('abstract ');
    }

    if (isInterface) {
      printer.write('interface');
    } else {
      printer.write('class');
    }
    printer.write(' ${name}');

    _writeTypeParameters(printer);

    if (superClass != null) {
      printer.write(' extends ');
      printer.accept(superClass);
    }
    if (implemented.isNotEmpty /* || mixins.isNotEmpty*/) {
      printer.write(' implements ');
      printer.join(new List.from([implemented /*, mixins*/].expand((i) => i)));
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

    // Add all static initializers
    // NO MORE NEEDED IF WE USE LAZY :
    /*
    extractAllInitializerExpressions(true).forEach((staticInit) {
      printer.accept(staticInit);
      printer.writeln(";");
    });*/
  }
}

abstract class TSType extends TSNode {
  bool _isObject;

  bool get isObject => _isObject;

  String get name;

  TSType(this._isObject);
}

class TSSimpleType extends TSType {
  static final RegExp _MYREGEXP = new RegExp(r"([^.]+\.)?(.*)");

  String _name;

  String get name => _MYREGEXP.matchAsPrefix(_name).group(2);

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
  bool negate;

  TSInstanceOf(this._expr, this._type, this.negate);

  @override
  void writeCode(IndentingPrinter printer) {
    if (negate) {
      printer.write('isNot(');
    } else {
      printer.write('is(');
    }
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
  List<TSTypeParameter> _typeArguments;
  Map<String, TSType> _arguments;
  bool _isCtor;

  String get name => "<Function>";

  TSFunctionType(this._returnType, this._arguments, [this._typeArguments, this._isCtor = false]) : super(true);

  @override
  void writeCode(IndentingPrinter printer) {
    if (this._isCtor) {
      printer.write('new');
    }
    if (_typeArguments?.isNotEmpty ?? false) {
      printer.write('<');
      printer.join(_typeArguments);
      printer.write('>');
    }
    printer.write('(');

    printer.joinConsumers(_arguments.keys.map((n) => (p) {
          p.write(n);
          p.write(' : ');
          p.accept(_arguments[n]);
        }));
    printer.write(') => ');
    printer.accept(_returnType);
  }
}

class TSInterfaceType extends TSType {
  Map<String, TSType> fields;

  TSInterfaceType({this.fields}) : super(true) {
    fields ??= {};
  }

  String get name => "<anon>";

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

  String get name => _type.name;

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
  String tag;

  TSStringInterpolation(this._elements);

  @override
  void writeCode(IndentingPrinter printer) {
    if (tag != null) {
      printer.write(tag);
    }
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

  TSAnnotation.classAnnotation(
      Uri libUri, String name, List<TSExpression> arguments, Map<String, TSExpression> namedArguments)
      : this(createClassAnnotationInvoke('DartClassAnnotation', libUri, name, arguments, namedArguments));

  TSAnnotation.methodAnnotation(
      Uri libUri, String name, List<TSExpression> arguments, Map<String, TSExpression> namedArguments)
      : this(createClassAnnotationInvoke('DartMethodAnnotation', libUri, name, arguments, namedArguments));

  TSAnnotation.propertyAnnotation(
      Uri libUri, String name, List<TSExpression> arguments, Map<String, TSExpression> namedArguments)
      : this(createClassAnnotationInvoke('DartPropertyAnnotation', libUri, name, arguments, namedArguments));

  @override
  void writeCode(IndentingPrinter printer) {
    printer.write('@');
    printer.accept(_invoke);
  }

  static TSInvoke createClassAnnotationInvoke(
      String cons, Uri libUri, String name, List<TSExpression> arguments, Map<String, TSExpression> namedArguments) {
    return new TSInvoke(new TSSimpleExpression(cons), [
      new TSObjectLiteral({
        'library': new TSSimpleExpression("'${libUri}'"),
        'type': new TSStringLiteral(name),
        'value': new TSObjectLiteral({
          'arguments': new TSList(arguments),
          'namedArguments': new TSObjectLiteral(namedArguments ?? {}),
        })
      })
    ]);
  }
}

class TSSpread extends TSExpression {
  TSExpression _expr;

  TSSpread(this._expr);

  @override
  void writeCode(IndentingPrinter printer) {
    printer.write('...');
    printer.accept(_expr);
  }
}

class TSStringLiteral extends TSExpression {
  String stringValue;
  bool isSingleQuoted;

  TSStringLiteral(this.stringValue, [this.isSingleQuoted = true]);

  @override
  void writeCode(IndentingPrinter printer) {
    String q = isSingleQuoted ? "'" : '"';
    String v = isSingleQuoted ? stringValue.replaceAll('\'', '\\\'') : stringValue.replaceAll('"', '\\"');
    printer.write(q);
    printer.write(v);
    printer.write(q);
  }
}

enum ConstructorType { DEFAULT, NAMED, DEFAULT_FACTORY, NAMED_FACTORY }

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
  List<TSTypeParameter> typeParameters;
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
  bool nativeSuper = false;
  bool isInterpolator = false;
  bool isAsync;
  bool isOperator;
  bool isGenerator;
  List<TSAnnotation> annotations;
  List<TSStatement> initializers;
  bool isExpression;
  TypeManager tm;
  String prefix;
  bool declared;
  TSType namedParameterType;
  bool isAbstract;
  bool namedConstructor;
  ConstructorType constructorType;

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
    this.isAbstract: false,
    this.callSuper: false,
    this.nativeSuper: false,
    this.initializers,
    this.isExpression: false,
    this.namedConstructor: false,
    this.constructorType,
    this.annotations: const [],
    FormalParameterCollector withParameterCollector,
    this.declared: false,
  }) {
    if (isGenerator) {
      if (isAsync) {
        prefix = tm.namespace(getLibrary(currentContext, 'dart:async'));
      } else {
        prefix = tm.namespace(getLibrary(currentContext, 'dart:core'));
      }
    }
    if (withParameterCollector != null) {
      parameters = new List.from(withParameterCollector.tsParameters);
      namedParameters = withParameterCollector.namedType?.fields;
      defaults = withParameterCollector.defaults;
      namedDefaults = withParameterCollector.namedDefaults;
      initializers ??= [];
      namedParameterType = withParameterCollector.namedType;
      initializers.addAll(withParameterCollector.fields?.map((f) => new TSExpressionStatement(
          new TSAssignamentExpression(
              new TSDotExpression(new TSSimpleExpression('this'), f), new TSSimpleExpression(f), "="))));
    }
  }

  @override
  void writeCode(IndentingPrinter printer) {
    // Generate interpolator

    if (isInterpolator) {
      printer.writeln('export var ${name} = (lits,...vals) => {');
      printer.indented((p) {
        _writeCodeNoInterpolator(p);
        printer.writeln(';');
        printer.writeln("return ${name}(null,{literals:lits,values:vals as any});");
      });
      printer.write('}');
    } else {
      _writeCodeNoInterpolator(printer);
    }
  }

  void _writeCodeNoInterpolator(IndentingPrinter printer) {
    annotations.forEach((anno) {
      printer.accept(anno);
      printer.writeln();
    });

    if (topLevel && !isGetter && !isSetter && !isInterpolator) {
      printer.write('export ');
      if (declared) {
        printer.write('declare ');
      }
    }
    // If not expression or is a topleve getter and setter (that should be treated as normal get set of module)

    bool treatAsExpression = isExpression && (!topLevel || (!isGetter && !isSetter));

    // Utility function to write the initial signature
    writePrehamble(bool minimal) {
      if (minimal) {
        printer.write("()");
      } else {
        if (typeParameters != null && typeParameters.isNotEmpty) {
          printer.write('<');
          printer.join(typeParameters);
          printer.write('>');
        }

        printer.write('(');
        if (parameters != null) printer.join(parameters);
        printer.write(')');
      }
    }

    if (!treatAsExpression) {
      if (constructorType == ConstructorType.NAMED) {
        printer.writeln('@namedConstructor');
      }
      if (constructorType == ConstructorType.DEFAULT) {
        //printer.writeln('constructor()');

        printer.write('constructor(');
        printer.join(parameters);
        printer.write(')');

        printer.writeln(' {');
        printer.indented((p) {
          if (callSuper) {
            //if (nativeSuper) {
            p.writeln('// @ts-ignore'); // ignore signature stuff here we don't care because it won't be called actually
            p.writeln('super();');
            //} else {
            //  p.writeln('// TODO : WE NEED SIGNATURE HERE, using default for now');
            //  p.writeln('super();');
            //}
          }
        });
        // Call bare init
        printer.writeln('}');

        printer.writeln('@defaultConstructor');
      } else {
        if (constructorType == ConstructorType.DEFAULT_FACTORY) {
          //printer.writeln('constructor()');

          printer.write('constructor(');
          printer.join(parameters);
          printer.write(')');

          printer.writeln(' {');
          printer.indented((p) {
            if (callSuper) {
              //if (nativeSuper) {
              p.writeln(
                  '// @ts-ignore'); // ignore signature stuff here we don't care because it won't be called actually
              p.writeln('super();');
              //} else {
              //  p.writeln('// TODO : WE NEED SIGNATURE HERE, using default for now');
              //  p.writeln('super();');
              //}
            }
          });
          // Call bare init
          printer.writeln('}');

          printer.writeln('@defaultFactory');
        } else if (constructorType == ConstructorType.NAMED_FACTORY) {
          printer.writeln('@namedFactory');
        }

        if (isAbstract) {
          if (isGetter) {
            printer.writeln('@AbstractProperty');
          } else if (!isSetter) {
            printer.writeln('@Abstract');
          }
        }
        if (isStatic) printer.write('static ');
        //if (isAbstract) printer.write('abstract ');

        if (!asMethod && !isGetter && !isSetter) printer.write('function ');
        if (isGetter) printer.write('get ');
        if (isSetter) printer.write('set ');
      }

      if (name != null) {
        printer.write(name);
      }
    } else {
      if (name != null) {
        printer.write('var ${name} : ');

        if (typeParameters != null && typeParameters.isNotEmpty) {
          printer.write('<');
          printer.join(typeParameters);
          printer.write('>');
        }

        printer.write('(');
        if (parameters != null) printer.join(parameters);
        printer.write(')');

        printer.write(" => ");
        if (returnType != null) {
          printer.accept(returnType);
        } else {
          printer.write('any');
        }

        if (!declared) {
          printer.write(' = ');
        }
      }

      if (isAsync && !isGenerator) {
        String async = tm.namespace(getLibrary(currentContext, 'dart:async'));
        writePrehamble(false);
        printer.write(' => new ${async}.Future.fromPromise(( async ');
      }

      if (declared) {
        return;
      }

      // move this above
      /*
      if (isAsync && !isGenerator) {
        printer.write('async ');
      }*/
    }

    // Extract the first parameter type if there is any or use any
    // This is needed for future => promise thing
    TSType t = new TSSimpleType('any', false);
    if (returnType != null && returnType is TSGenericType) {
      t = (returnType as TSGenericType)._typeArguments?.first;
    }

    writePrehamble(treatAsExpression && isAsync && !isGenerator);

    if (returnType != null && !isSetter) {
      printer.write(" : ");

      // Replace Future with promise in this case
      if (treatAsExpression && isAsync && !isGenerator) {
        printer.write("Promise<");
        printer.accept(t);
        printer.write(">");
      } else {
        printer.accept(returnType);
      }
    } else if (returnType == null) {
      if (treatAsExpression && isAsync && !isGenerator) {
        printer.write(" : Promise<");
        printer.accept(t);
        printer.write(">");
      } else {
        if (isAsync) {
          printer.write(" : ");
          if (isGenerator) {
            printer.write('async.DartStream<');
            printer.accept(t);
            printer.write('>');
          } else {
            printer.write('async.Future<');
            printer.accept(t);
            printer.write('>');
          }
        } else if (isGenerator) {
          printer.write(' : core.DartIterable<');
          printer.accept(t);
          printer.write('>');
        }
      }
    }

    if (treatAsExpression) {
      printer.write(' => ');
    } else {
      if (isAsync) {
        String async = tm.namespace(getLibrary(currentContext, 'dart:async'));
        if (isGenerator) {
          printer.writeln(' { ');
          printer.indent();
          printer.write('return ');
        } else {
          printer.writeln(' { ');
          printer.indent();
          printer.write('return new ${async}.Future.fromPromise(( async () => ');
        }
      } else if (isGenerator) {
        printer.writeln(' { ');
        printer.indent();
        printer.write('return ');
      }
    }

    if (isGenerator) {
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
      printer.indented((IndentingPrinter printer) {
        //printer.writeln('/* init */');

        // Init all values

        defaults?.keys?.forEach((def) {
          printer.write("${def} = ${def} || ");
          printer.accept(defaults[def]);
          printer.writeln(";");
        });

        // Explode named args

        if (namedParameters?.isNotEmpty ?? false) {
          printer.write('let {');
          printer.joinConsumers(namedParameters.keys.map((k) => (p) => p.write(k)));
          printer.write('} = ');

          printer.writeln('Object.assign({');
          printer.indented((printer) {
            printer.joinConsumers(
                namedDefaults.keys.map((k) => (p) {
                      p.write('"${k}" : ');
                      p.accept(namedDefaults[k]);
                    }),
                newLine: true);
          });
          printer.writeln('}, ${NAMED_ARGUMENTS} );');
        }

        //} else if (namedParameters?.isNotEmpty ?? false) {
        //  printer.write('${NAMED_ARGUMENTS} || {}');
        //}
/*
        if (namedParameters?.isNotEmpty ?? false) {
          printer.write(' as ');
          printer.accept(namedParameterType);
          printer.writeln(';');
        }
*/
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
    } else if (isAbstract) {
      printer.write("{ throw 'abstract'}");
    }

    if (isGenerator) {
      printer.write(').call(this))');
    }

    if (treatAsExpression) {
      if (isAsync && !isGenerator) {
        //String async = tm.namespace(getLibrary(currentContext, 'dart:async'));
        printer.write(')())');
      }
    } else {
      if (isAsync) {
        String async = tm.namespace(getLibrary(currentContext, 'dart:async'));
        if (isGenerator) {
          printer.writeln(';');
          printer.deindent();
          printer.writeln('}');
        } else {
          printer.writeln(' )());');
          printer.deindent();
          printer.writeln('}');
        }
      } else if (isGenerator) {
        printer.writeln(';');
        printer.deindent();
        printer.writeln('}');
      }
    }
  }

  @override
  bool get needsSeparator => true;
  @override
  TSStatement inject(TSStatement statement) {
    throw "not implemented";
  }
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
  final List<TSExpression> _elements;
  final TSType _tsType;
  bool indent = false;

  TSList(this._elements, [this._tsType]);

  @override
  void writeCode(IndentingPrinter printer) {
    if (_tsType != null) {
      printer.write('<');
      printer.accept(_tsType);
      printer.write('>');
    }
    printer.write('[');
    if (indent) {
      printer.writeln();
      printer.indented((IndentingPrinter p) => p.join(_elements, newLine: true));
    } else {
      printer.join(_elements);
    }
    printer.write(']');
  }
}

abstract class TSStatement extends TSNode {
  bool get needsSeparator => true;

  TSStatement inject(TSStatement statement) {
    return new TSBody(statements: [statement, this], withBrackets: true);
  }
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
  List<TSStatement> statements;

  bool newLine;

  @override
  bool get needsSeparator => false;

  TSBody({Iterable<TSStatement> statements, this.withBrackets: true, this.newLine: true})
      : statements = new List.from(statements);

  @override
  TSStatement inject(TSStatement statement) {
    return new TSBody(
        statements: new List.from(statements)..insert(0, statement),
        withBrackets: this.withBrackets,
        newLine: this.newLine);
  }

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

class TSCatchStatement extends TSStatement {
  String _exceptionName;
  TSType _exceptionType;
  TSStatement _body;
  String stack;

  TSCatchStatement(this._exceptionName, this._exceptionType, this._body, {this.stack: null});

  @override
  void writeCode(IndentingPrinter printer) {
    printer.writeln();
    if (_exceptionType != null) {
      printer.write('if (is(__error__,');
      printer.accept(_exceptionType);
      printer.write('))');
    }
    TSStatement actualBody = _body;

    if (_exceptionName != null) {
      actualBody = _body.inject(new TSVariableDeclarations(
          [new TSVariableDeclaration(_exceptionName, new TSSimpleExpression('__error__'), _exceptionType)]));
    }
    if (this.stack != null) {
      actualBody = actualBody.inject(new TSVariableDeclarations([
        new TSVariableDeclaration(
            stack,
            new TSInvoke(new TSStaticRef(new TSSimpleType("core.DartStackTrace", true), "fromError"),
                [new TSSimpleExpression('__error__')])
              ..asNew = true,
            new TSSimpleType("core.DartStackTrace", true))
      ]));
    }
    printer.accept(actualBody);
    printer.writeln();
  }
}

class TSEnumDeclaration extends TSStatement {
  List<String> constants = [];
  String name;

  TSEnumDeclaration(this.name);

  @override
  bool get needsSeparator => false;

  @override
  void writeCode(IndentingPrinter printer) {
    printer.writeln("export enum ${name} {");
    printer.indented((IndentingPrinter p) {
      p.joinConsumers(constants.map((c) => (pw) => pw.write(c)), newLine: true);
    });
    printer.writeln();
    printer.writeln("}");
  }

  void addConstant(String name) {
    constants.add(name);
  }
}

class TSTryStatement extends TSStatement {
  TSStatement _body;
  List<TSStatement> _catches;
  TSStatement _finallyBlock;

  TSTryStatement(this._body, this._catches, this._finallyBlock);

  @override
  void writeCode(IndentingPrinter printer) {
    printer.write('try ');
    printer.accept(_body);

    if (_catches != null && _catches.isNotEmpty) {
      printer.writeln(' catch (__error__) {');

      printer.indented((IndentingPrinter p) => p.join(_catches, delim: '', newLine: true));
      printer.write('}');
    }

    if (_finallyBlock != null) {
      printer.write((' finally '));
      printer.accept(_finallyBlock);
    }
  }

  @override
  bool get needsSeparator => false;
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
  List<TSType> typeParameters;
  TSExpression methodTarget;
  bool safeAccess;
  TSExpression safeTarget;

  TSInvoke(this._target,
      [this._arguments, this._namedArguments, this.methodTarget = null, this.safeAccess = false, this.safeTarget]);

  @override
  void writeCode(IndentingPrinter printer) {
    if (safeAccess) {
      printer.write('((');
      printer.accept(safeTarget);
      printer.write(')=>');
      printer.write('(!!');
      printer.accept(safeTarget);
      printer.write(")?");
      printer.accept(_target);
      if (typeParameters != null && typeParameters.length > 0) {
        printer.write('<');
        printer.join(typeParameters);
        printer.write('>');
      }
      writeArguments(printer);
      printer.write(":null)(");
      printer.accept(methodTarget);
      printer.write(")");
    } else {
      if (asNew) {
        printer.write("new ");
      }
      printer.accept(_target);
      if (typeParameters != null && typeParameters.length > 0) {
        printer.write('<');
        printer.join(typeParameters);
        printer.write('>');
      }
      writeArguments(printer);
    }
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
  TSExpression _name;
  bool safeAccess = false;

  TSDotExpression(TSExpression expression, String name, {safeAccess: false})
      : this.expr(expression, new TSSimpleExpression(name), safeAccess: safeAccess);

  TSDotExpression.expr(this._expression, this._name, {this.safeAccess: false});

  @override
  void writeCode(IndentingPrinter printer) {
    if (safeAccess) {
      printer.write('((t)=>(!!t)?t.');
      printer.accept(_name);
      printer.write(':null)(');
      printer.accept(_expression);
      printer.write(')');
    } else {
      printer.accept(_expression);
      printer.write('.');
      printer.accept(_name);
    }
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
  String operator;

  TSAssignamentExpression(this._target, this._value, this.operator);

  @override
  void writeCode(IndentingPrinter printer) {
    if (operator == '??=') {
      printer.accept(_target);
      printer.write(' = ( ');
      printer.accept(_target);
      printer.write(' ) || ( ');
      printer.accept(_value);
      printer.write(' )');
      return;
    }

    printer.accept(_target);
    printer.write(' ${operator} ');
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
  bool isField;
  bool isConst;

  TSVariableDeclaration(this._name, this._initializer, this._type, {this.isField: false, this.isConst: false});

  @override
  void writeCode(IndentingPrinter printer) {
    printer.write(_name);
    if (_type != null) {
      printer.write(" : ");
      printer.accept(_type);
    }
    // Field initializers are handler differently (see extractFieldInitializers in TSClass)
    if (_initializer != null && !isField) {
      printer.write(' = ');
      printer.accept(_initializer);
    }
  }

  TSLazyVariableDeclaration asLazy({bool isStatic: true}) => new TSLazyVariableDeclaration(this, isStatic, isConst);

// bool get needsSeparator => _initializer is! TSFunction;
}

class TSLazyVariableDeclaration extends TSNode {
  static const PREFIX = r'__$';
  bool isStatic;
  bool isReadonly;
  TSVariableDeclaration _decl;
  TSLazyVariableDeclaration(this._decl, [this.isStatic = true, this.isReadonly = false]);

  @override
  void writeCode(IndentingPrinter printer) {
    String st = isStatic ? "static " : "";
    // First declare the internal property
    printer.write("private ${st}${PREFIX}${_decl._name}");
    if (_decl._type != null) {
      printer.write(" : ");
      printer.accept(_decl._type);
    }
    printer.writeln(";");

    // Then the getter and setter
    printer.write("${st}get ${_decl._name}()");
    if (_decl._type != null) {
      printer.write(" : ");
      printer.accept(_decl._type);
    }

    printer.writeln(" { ");
    printer.indented((printer) {
      if (_decl._initializer != null) {
        printer.writeln("if (this.${PREFIX}${_decl._name}===undefined) {");
        printer.indented((printer) {
          printer.write("this.${PREFIX}${_decl._name} = ");
          printer.accept(_decl._initializer);
          printer.writeln(";");
        });

        printer.writeln("}");
      }
      printer.writeln("return this.${PREFIX}${_decl._name};");
    });
    printer.writeln("}");

    if (!isReadonly) {
      printer.write("${st}set ${_decl._name}(${PREFIX}value");
      if (_decl._type != null) {
        printer.write(" : ");
        printer.accept(_decl._type);
      } else {
        printer.write(" : any");
      }

      printer.writeln(")  { ");
      printer.indented((printer) {
        printer.writeln("this.${PREFIX}${_decl._name} = ${PREFIX}value;");
      });
      printer.writeln("}");
    }
  }
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
    if (_condition != null) printer.accept(_condition);
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
  bool isConstructor;
  final List<TSAnnotation> annotations;

  TSVariableDeclarations(
    this._declarations, {
    this.isStatic: false,
    this.isField: false,
    this.isTopLevel: false,
    this.isConst: false,
    this.readonly: false,
    this.declared: false,
    this.annotations,
    this.isConstructor: false,
  });

  @override
  void writeCode(IndentingPrinter printer) {
    if (annotations != null) {
      annotations.forEach((a) {
        printer.accept(a);
        printer.writeln();
      });
    }

    bool lazy = !isConstructor && (isTopLevel || (isStatic && isField));

    if (!lazy) {
      if (!isField) {
        printer.write('let ');
      }

      String comma = "";

      for (TSVariableDeclaration e in _declarations) {
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
          printer.write(comma);
          comma = ", ";
        }

        printer.accept(e);

        //printer.join(_declarations, delim: isField ? ';' : ',', newLine: isField);

        if (isField) {
          printer.writeln(';');
        }
      }
    } else {
      printer.join(_declarations.map((v) => v.asLazy()));
    }
  }
}

class TSLabeledStatement extends TSStatement {
  List<String> labels;
  TSStatement statement;

  TSLabeledStatement(this.labels, this.statement);

  @override
  void writeCode(IndentingPrinter printer) {
    labels.forEach((lbl) {
      printer.writeln("${lbl}:");
    });
    printer.indented((p) {
      p.accept(statement);
    });
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
  bool varargs;

  TSParameter({this.name, this.type, this.optional = false, this.varargs: false});

  @override
  void writeCode(IndentingPrinter printer) {
    assert(name != null, "Parameters should have a name");
    if (varargs) {
      printer.write('...');
    }
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
  static final _cascadingTarget = new TSSimpleExpression('_');
  static final THIS = new TSSimpleExpression('this');
  static final SUPER = new TSSimpleExpression('super');

  String _expression;

  TSSimpleExpression(this._expression);

  factory TSSimpleExpression.cascadingTarget() => _cascadingTarget;

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
