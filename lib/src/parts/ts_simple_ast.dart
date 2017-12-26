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

class TSType extends TSNode {
  String _name;

  @override
  void writeCode(IndentingPrinter printer) {
    printer.write(_name);
  }
}

class TSGenericType extends TSType {
  List<TSType> _typeArguments;

  @override
  void writeCode(IndentingPrinter printer) {
    super.writeCode(printer);
    printer.write('<');
    printer.join(_typeArguments);
    printer.write('>');
  }


}

class TSFunction extends TSNode {
  String _name;
  bool topLevel;

  TSFunction(
      this._name, {
        this.topLevel: false,
      });

  @override
  void writeCode(IndentingPrinter printer) {
    if (topLevel) {
      printer.write('export ');
    }

    printer.write('function ${_name} () {');
    printer.indent();
    printer.writeln('/* body */');
    printer.indent(-1);
    printer.writeln("}");
  }
}
