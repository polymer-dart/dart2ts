class Module {
  final String path;
  final bool export;

  const Module(this.path, {this.export: false});
}

class TargetLib {
  final String package;
  final String path;

  const TargetLib({this.package, this.path});
}

class TS {
  final bool generate;
  final String typelib;
  final bool stringInterpolation;
  final String export;

  const TS({this.generate: false, this.typelib, this.stringInterpolation: false, this.export});
}

class VarArgs {
  const VarArgs();
}

const VarArgs varargs = const VarArgs();
