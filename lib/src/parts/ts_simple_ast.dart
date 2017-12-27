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

class TSFunction extends TSExpression {
  String name;
  bool topLevel;
  TSType returnType;
  Iterable<TSTypeParameter> typeParameters;
  Iterable<TSParameter> parameters;
  Map<String, TSExpression> defaults;
  Map<String, TSExpression> namedDefaults;

  TSFunction({
    this.name,
    this.topLevel: false,
    this.returnType,
    this.typeParameters,
    this.parameters,
    this.defaults,
    this.namedDefaults,
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
    printer.writeln(' {');
    printer.indent();
    printer.writeln('/* init */');

    // Init all values
    defaults.keys.forEach((def) {
      printer.write("${def} = ${def} || ");
      printer.accept(defaults[def]);
      printer.writeln(";");
    });

    if (namedDefaults?.isNotEmpty ?? false) {
      printer.writeln('${NAMED_ARGUMENTS} = Object.assign({');
      printer.indent(1);
      printer.joinConsumers(namedDefaults.keys.map((k) => (p) {
            p.write('"${k}" : ');
            p.accept(namedDefaults[k]);
          }),newLine: true);
      printer.indent(-1);
      printer.writeln('}, ${NAMED_ARGUMENTS});');
    }

    printer.writeln('/* body */');

    printer.indent(-1);
    printer.writeln("}");
  }
}

class TSParameter extends TSNode {
  String name;
  TSType type;
  bool optional;

  TSParameter({this.name, this.type,this.optional=false});

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

class TSExpression extends TSNode {
  @override
  void writeCode(IndentingPrinter printer) {
    // TODO: implement writeCode
    printer.write("/* TODO : EXPRESSION */");
  }
}
