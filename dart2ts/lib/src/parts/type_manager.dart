part of '../code_generator.dart';

const String SDK_LIBRARY = 'typescript_dart';

class TSImport extends TSNode {
  String prefix;
  String path;
  LibraryElement library;
  List<String> names;

  TSImport({this.prefix, this.path, this.library, this.names}) {

  }

  @override
  void writeCode(IndentingPrinter printer) {
    printer.write('import ');
    if (names == null || names.isEmpty) {
      printer.write('* as ${prefix}');
    } else {
      printer.write('{');
      printer.joinConsumers(names.map((name) => (p) => p.write(name)));
      printer.write('}');
    }
    printer.writeln(' from "${path}";');
  }
}

class TSPath {
  bool isJSAnnotated = false;
  List<String> modulePathElements = [];
  List<String> namespacePathElements = [];

  String get moduleUri => modulePathElements.isEmpty ? null : "module:${modulePath}";

  String get modulePath => modulePathElements.join('/');

  String get name => namespacePathElements.join('.');

  void fixWindowAtFirst() {
    if (namespacePathElements.isNotEmpty && namespacePathElements.first == 'window') {
      namespacePathElements.removeAt(0);
    }
  }
}

class TypeManager {
  LibraryElement _current;
  Overrides _overrides;
  Set<String> exports = new Set();

  String modulePrefix;
  String moduleSuffix;

  String resolvePath(String pp) {
    if (!pp.startsWith('./')) {
      pp = path.normalize(path.join(modulePrefix, pp));
    }
    return "${pp}${moduleSuffix}";
  }

  TypeManager(this._current, this._overrides, {this.moduleSuffix = '../node_modules/', this.modulePrefix = '.js'}) {
    registerModule(String uri,String prefix, String modulePath) {
      TSImport import = new TSImport(prefix: prefix, path: resolvePath(modulePath));
      _importedPaths[modulePath] = import;
      _prefixes = {uri: import};
    }

    registerSdkModule(String name) {
      registerModule("dart:${name}",name, "${SDK_LIBRARY}/${name}");
    }

    registerSdkModule('_common');
    registerSdkModule('core');
    registerSdkModule('async');
  }

  Map<String, TSImport> _prefixes;

  String _nextPrefix() => "lib${_prefixes.length}";

  AssetId _toAssetId(String uri) {
    if (uri.startsWith('asset:')) {
      List<String> parts = path.split(uri.substring(6));
      return new AssetId(parts.first, path.joinAll(parts.sublist(1)));
    }
    throw "Cannot convert to assetId : ${uri}";
  }

  String namespace(LibraryElement lib) => namespaceFor(lib: lib);

  TSExpression checkMethod(DartType type, String methodName, TSExpression tsTarget, {TSExpression orElse()}) =>
      _overrides.checkMethod(this, type, methodName, tsTarget, orElse: orElse);

  String checkProperty(DartType type, String name) => _overrides.checkProperty(this, type, name);

  TSImport _getSdkPath(String _name, {LibraryElement lib, List<String> names}) {
    String name = _name.substring(5);

    String p = "${SDK_LIBRARY}/${name}";

    // Check if we are in dart_sdk and need relative paths for dart: imports
    DartObject anno = getAnnotation(_current.metadata, isTargetLib);
    if (anno != null) {
      String module = anno.getField('package').toStringValue();
      String modPath = anno.getField('path').toStringValue();
      if (module.startsWith('dart:')) {
        String my_path = path.join('/', modPath);
        p = path.relative(path.join('/', name), from: my_path);
      }
    }
    if (names != null) {
      return new TSImport(prefix: name, path: resolvePath(p), library: lib, names: names);
    } else {
      String modulePath = p;

      return _importedPaths.putIfAbsent(p, () {
        return new TSImport(prefix: name, path: resolvePath(p), library: lib);
      });
    }
  }

  Map<String, TSImport> _importedPaths = {};

  String namespaceFor({String uri, String modulePath, LibraryElement lib}) {
    if (modulePath != null && _importedPaths.containsKey(modulePath)) {
      return _importedPaths[modulePath].prefix;
    }
    if (lib != null && lib == _current) {
      return null;
    }

    uri ??= lib.source.uri.toString();

    if (uri == 'module:global') {
      return null;
    }

    return _prefixes.putIfAbsent(uri, () {
      if (lib == null) {
        return _importedPaths.putIfAbsent(
            modulePath, () => new TSImport(prefix: _nextPrefix(), path: resolvePath(modulePath)));
      }
      if (lib.isInSdk) {
        // Replace with ts_sdk

        return _getSdkPath(lib.name, lib: lib);
      }

      // If same package produce a relative path
      AssetId currentId = _toAssetId(_current.source.uri.toString());
      AssetId id = _toAssetId(uri);

      String libPath;

      if (id.package == currentId.package) {
        libPath =
            path.joinAll(['.', path.withoutExtension(path.relative(id.path, from: path.dirname(currentId.path)))]);
      } else {
        libPath = path.join("${id.package}", "${path.withoutExtension(id.path)}");
      }

      // Fix import for libs in subfolders for windows (this should not be necessary anymore as
      // path is now unix path everywhere ... but can't test it so I leave the "fix"
      libPath = libPath.replaceAll(path.separator, "/");

      // Extract package name and path and produce a nodemodule path

      return _importedPaths.putIfAbsent(
          libPath, () => new TSImport(prefix: _nextPrefix(), path: resolvePath(libPath), library: lib));
    }).prefix;
  }

  static final RegExp NAME_PATTERN = new RegExp('(([^#]+)#)?(.*)');

  Iterable<Element> _elementsFromLibrary(Element e) sync* {
    if (e == null) {
      return;
    }

    if (e is! LibraryElement) {
      yield* _elementsFromLibrary(e.enclosingElement);
    }

    if (e is! CompilationUnitElement) {
      yield e;
    }
  }

  TSPath _collectJSPath(Element start) => _elementsFromLibrary(start).fold(new TSPath(), (p, e) {
        DartObject anno = getAnnotation(e.metadata, isJS);
        //if (anno == null) return p;
        p.isJSAnnotated = p.isJSAnnotated || (e is! LibraryElement && anno != null);

        // Collect if metadata
        String name = anno?.getField('name')?.toStringValue();

        if (name != null && name.isNotEmpty) {
          Match m = NAME_PATTERN.matchAsPrefix(name);
          if ((m != null && m[2] != null)) {
            p.modulePathElements.add(m[2]);
            if ((m[3] ?? '').isNotEmpty) p.namespacePathElements.addAll(m[3].split('.'));
          } else {
            p.namespacePathElements.addAll(name.split('.'));
          }
        } else if (e == start) {
          // Add name if it's the first
          p.namespacePathElements.add(_name(e));
        }

        // Process module path
        var moduleAnnotation = getAnnotation(e.metadata, isModule);
        String module = moduleAnnotation?.getField('path')?.toStringValue();
        if (module != null) {
          p.modulePathElements.add(module);
          if (moduleAnnotation.getField('export')?.toBoolValue() ?? false) {
            exports.add(module);
          }
        }

        return p;
      });

  static Set<DartType> nativeTypes() => ((TypeProvider x) => new Set<DartType>.from([
        x.boolType,
        x.stringType,
        x.intType,
        x.numType,
        x.doubleType,
        x.functionType,
      ]))(currentContext.typeProvider);

  static Set<String> nativeClasses = new Set.from(['List', 'Map', 'Iterable', 'Iterator']);

  static bool isNativeType(DartType t) =>
      nativeTypes().contains(t) ||
      (t.element?.library?.isDartCore ?? false) && (nativeClasses.contains(t.element?.name));

  static String _name(Element e) => (e is PropertyAccessorElement) ? e.variable.name : e.name;

  String toTsName(Element element, {bool nopath: false}) {
    if (element == null) {
      return null;
    }

    TSPath jspath = _collectJSPath(element); // note: we should check if var is top, but ... whatever.

    // For top level elements (properties and methods) use namespace path and module path
    if (isTopLevel(element)) {
      String name;
      // In case of explicit namespaces use it
      if (jspath.isJSAnnotated) {
        if (jspath.modulePathElements.isNotEmpty) {
          name = namespaceFor(uri: jspath.moduleUri, modulePath: jspath.modulePath) + "." + jspath.name;
        } else {
          name = jspath.name;
        }
      } else {
        // Use normal prefix + name otherwise , use also module for toplevel properties
        String m = (element is PropertyAccessorElement) ? "module." : "";
        String prefix = namespace(element.library);
        prefix = (prefix == null) ? "" : "${prefix}.";

        name = "${prefix}${m}${_name(element)}";
      }

      return name;
    }

    // For class members use the name or js name only
    String name;
    // In case of explicit namespaces use it
    if (jspath.namespacePathElements.isNotEmpty) {
      name = jspath.namespacePathElements.last;
    } else {
      // Use normal prefix + name otherwise , use also module for toplevel properties
      name = _name(element);
    }

    return name;
  }

  static bool isTopLevel(Element e) => e.library.units.contains(e.enclosingElement);

  TSType toTsType(DartType type, {bool noTypeArgs: false, bool inTypeOf: false}) {
    if (type == null) {
      return null;
    }

    // Look for @JS annotations
    if (type is TypeParameterType) {
      return new TSSimpleType(type.element.name, !TypeManager.isNativeType(type));
    }

    if (type is FunctionType) {
      Iterable<List> args = () sync* {
        Map<String, DartType> normalPars = new Map.fromIterables(type.normalParameterNames, type.normalParameterTypes);

        for (var p in type.normalParameterNames) {
          yield [p, toTsType(normalPars[p])];
        }

        Map<String, DartType> optionalPars =
            new Map.fromIterables(type.optionalParameterNames, type.optionalParameterTypes);
        for (var p in type.optionalParameterNames) {
          yield [p, new TSOptionalType(toTsType(optionalPars[p]))];
        }

        if (type.namedParameterTypes.isNotEmpty) {
          yield [
            NAMED_ARGUMENTS,
            new TSInterfaceType(
                fields: new Map.fromIterable(type.namedParameterTypes.keys,
                    value: (k) => new TSOptionalType(toTsType(type.namedParameterTypes[k]))))
          ];
        }
      }();

      List<TSTypeParameter> typeArguments =
          new List.from(type.typeParameters?.map((t) => new TSTypeParameter(t.name, toTsType(t.bound))));

      return new TSFunctionType(
          toTsType(type.returnType), new Map.fromIterable(args, key: (p) => p[0], value: (p) => p[1]), typeArguments);
    }

    if (getAnnotation(type?.element?.metadata ?? [], isJS) != null) {
      // check if we got a package annotation
      TSPath path = _collectJSPath(type.element);
      // Lookup for prefix
      String moduleUri = path.moduleUri;
      // ensure lib is always imported
      String libPrefix = namespace(type.element.library);
      String prefix;
      if (moduleUri != null) {
        prefix = namespaceFor(uri: path.moduleUri, modulePath: path.modulePath) + '.';
      } else if ((getAnnotation(type.element.metadata, isTS)?.getField('export')?.toStringValue() ?? "").isNotEmpty) {
        // use lib prefix for this type if the class is exported from another module

        // TODO  we could actually only export this class instead of the whole library ... but this is ok for now.
        prefix = "${libPrefix}.";
      } else {
        prefix = '';
      }

      Iterable<TSType> typeArgs;
      if (!noTypeArgs && type is ParameterizedType && type.typeArguments?.isNotEmpty ?? false) {
        typeArgs = ((type as ParameterizedType).typeArguments).map((t) => toTsType(t));
      } else {
        typeArgs = null;
      }

      return new TSGenericType("${prefix}${path.name}", typeArgs);
    }

    if (type.isDynamic) {
      return new TSSimpleType("any", true);
    }

    String p;
    if (type.element != null && type.element.library != _current && !isNativeType(type)) {
      p = "${namespace(type.element.library)}.";
    } else {
      p = "";
    }

    return _overrides.checkType(this, p, type, noTypeArgs, orElse: () {
      String actualName;
      if (type == currentContext.typeProvider.numType || type == currentContext.typeProvider.intType) {
        actualName = 'number';
      } else if (type == currentContext.typeProvider.stringType) {
        actualName = 'string';
      } else if (type == currentContext.typeProvider.boolType) {
        actualName = 'boolean';
      } else {
        actualName = type.name;
      }

      if (nativeTypes().contains(type) && inTypeOf) {
        actualName = '"${actualName}"';
      }

      if (!noTypeArgs && type is ParameterizedType && type.typeArguments.isNotEmpty) {
        return new TSGenericType("${p}${actualName}", type.typeArguments.map((t) => toTsType(t)));
      } else {
        return new TSSimpleType("${p}${actualName}", !TypeManager.isNativeType(type));
      }
    });
  }

  Iterable<TSImport> get allImports => _prefixes.values;

  String namespaceForPrefix(PrefixElement prefix) {
    return namespace(_current.getImportsWithPrefix(prefix).first.importedLibrary);
  }

  TSExpression checkIndexedOperator(
          Context<TSNode> context, Expression target, Expression index, TSExpression orElse()) =>
      _overrides.checkIndexedOperator(context, target, index, orElse);

  TSExpression checkConstructor(Context<TSNode> context, DartType targetType, ConstructorElement ctor,
          ArgumentListCollector collector, TSExpression orElse()) =>
      _overrides.checkConstructor(context, targetType, ctor, collector, orElse);
}
