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
  List<TSNode> _children = [];

  TSLibrary(this._name) {}

  @override
  void writeCode(IndentingPrinter printer) {
    printer.writeln("/** Library ${_name} */");
    printer.writeln();
    _children.forEach((n) => n.writeCode(printer));
  }

  void addChild(TSNode child) {
    _children.add(child);
  }
}

class TSClass extends TSNode {
  @override
  void writeCode(IndentingPrinter printer) {
    // TODO: implement writeCode
  }
}

abstract class TSType extends TSNode {}

class TSSimpleType extends TSType {
  String _name;

  TSSimpleType(this._name);

  @override
  void writeCode(IndentingPrinter printer) {
    printer.write(_name);
  }
}

class TSFunctionType extends TSType {
  TSType _returnType;
  List<TSType> _typeArguments;
  List<TSType> _argumentsType;

  TSFunctionType(this._returnType, this._argumentsType, [this._typeArguments]);

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

  TSInterfaceType({this.fields}) {
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

  TSGenericType(String name, this._typeArguments) : super(name);

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

  TSOptionalType(this._type);

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

class TSFunction extends TSExpression implements TSStatement {
  String name;
  bool topLevel;
  TSType returnType;
  Iterable<TSTypeParameter> typeParameters;
  Iterable<TSParameter> parameters;
  Map<String, TSExpression> defaults;
  Map<String, TSExpression> namedDefaults;
  TSBody body;

  TSFunction({
    this.name,
    this.topLevel: false,
    this.returnType,
    this.typeParameters,
    this.parameters,
    this.defaults,
    this.namedDefaults,
    this.body,
  });

  @override
  void writeCode(IndentingPrinter printer) {
    if (topLevel) {
      printer.write('export ');
    }

    printer.write('function');

    if (name != null) {
      printer.write(' ${name}');
    }

    if (typeParameters != null) {
      printer.write('<');
      printer.join(typeParameters);
      printer.write('>');
    }

    printer.write('(');
    printer.join(parameters);
    printer.write(')');

    if (returnType != null) {
      printer.write(" : ");
      printer.accept(returnType);
    }

    if (body != null) {
      printer.writeln(' {');
      printer.indented((printer) {
        printer.writeln('/* init */');

        // Init all values
        defaults.keys.forEach((def) {
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

          printer.writeln('}, ${NAMED_ARGUMENTS});');
        }

        printer.writeln('/* body */');
        printer.accept(body);
      });
      printer.write("}");
    }
  }

  @override
  bool get needsSeparator => false;
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
    printer.join(_declarations, delim: '', newLine: true);
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

class TSBody extends TSNode {
  bool withBrackets;
  Iterable<TSStatement> statements;

  TSBody({this.statements, this.withBrackets: true});

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
      printer.writeln(('}'));
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

abstract class TSInvoking extends TSExpression {
  List<TSExpression> get _arguments;
  Map<String, TSExpression> get _namedArguments;

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

class TSInvokeMethod extends TSInvoking {
  /// True if you want to call the method using square brakets notation
  bool withBrackets = false;
  TSExpression _target;
  String _name;
  List<TSExpression> _arguments;
  Map<String, TSExpression> _namedArguments;
  TSInvokeMethod(this._target, this._name,
      [this._arguments, this._namedArguments]);

  @override
  void writeCode(IndentingPrinter printer) {
    if (withBrackets) {
      printer.accept(_target);
      printer.write('[${_name}]');
    } else {
      printer.accept(_target);
      printer.write('.');
      printer.write(_name);
    }
    writeArguments(printer);
  }
}

class TSInvokeFunction extends TSInvoking {
  String _name;
  List<TSExpression> _arguments;
  Map<String, TSExpression> _namedArguments;
  TSInvokeFunction(this._name, [this._arguments, this._namedArguments]);

  @override
  void writeCode(IndentingPrinter printer) {
    printer.write(_name);
    writeArguments(printer);
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

  bool get needsSeparator => _initializer is! TSFunction;
}

class TSVariableDeclarations extends TSStatement {
  Iterable<TSVariableDeclaration> _declarations;
  TSVariableDeclarations(this._declarations);
  @override
  void writeCode(IndentingPrinter printer) {
    printer.write('let ');
    printer.join(_declarations);
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
  bool get needsSeparator => _expression is! TSFunction;
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
