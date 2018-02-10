class Module {
  final String path;

  const Module(this.path);
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

  const TS({this.generate: false, this.typelib,this.stringInterpolation:false});
}
