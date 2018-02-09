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
  final bool generateTypelib;
  final String typelib;

  const TS({this.generateTypelib: false, this.typelib});
}
