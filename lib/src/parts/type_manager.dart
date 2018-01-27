part of '../code_generator2.dart';

class TSImport extends TSNode {
  String prefix;
  String path;
  LibraryElement library;

  TSImport({this.prefix, this.path, this.library});

  @override
  void writeCode(IndentingPrinter printer) {
    printer.writeln('import * as ${prefix} from "${path}";');
  }
}

class TSPath {
  List<String> modulePathElements = [];
  List<String> namespacePathElements = [];

  String get moduleUri => modulePathElements.isEmpty ? null : "module:${modulePath}";

  String get modulePath => modulePathElements.join('/');

  String get name => namespacePathElements.join('.');
}

class TypeManager {
  LibraryElement _current;
  Overrides _overrides;

  TypeManager(this._current, this._overrides) {
    _prefixes = {'#NOURI#': _getSdkPath('dart:bare')};
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

  TSImport _getSdkPath(String name, {LibraryElement lib}) {
    name = name.substring(5);

    String p = "dart_sdk/${name}";

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

    return new TSImport(prefix: name, path: p, library: lib);
  }

  String namespaceFor({String uri, String modulePath, LibraryElement lib}) {
    if (lib != null && lib == _current) {
      return null;
    }
    uri ??= lib.source.uri.toString();

    if (uri == 'module:global') {
      return null;
    }

    return _prefixes.putIfAbsent(uri, () {
      if (lib == null) {
        return new TSImport(prefix: _nextPrefix(), path: modulePath);
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

      // Fix import for libs in subfolders for windows
      libPath = libPath.replaceAll(path.separator, "/");

      // Extract package name and path and produce a nodemodule path
      return new TSImport(prefix: _nextPrefix(), path: libPath, library: lib);
    }).prefix;
  }

  static final RegExp NAME_PATTERN = new RegExp('(([^#]+)#)?(.*)');

  TSPath _collectJSPath(Element start) {
    var collector = (Element e, TSPath p, var c) {
      DartObject anno = getAnnotation(e.metadata, isJS);
      if (anno == null) return;

      if (e is! LibraryElement) {
        c(e.enclosingElement, p, c);
      }

      // Collect if metadata
      String name = anno.getField('name')?.toStringValue();
      if (name != null && name.isNotEmpty) {
        Match m = NAME_PATTERN.matchAsPrefix(name);
        String module = getAnnotation(e.metadata, isModule)?.getField('path')?.toStringValue();
        if (m != null && (m[2] != null || module != null)) {
          p.modulePathElements.add(module ?? m[2]);
          if ((m[3] ?? '').isNotEmpty) p.namespacePathElements.add(m[3]);
        } else {
          p.namespacePathElements.add(name);
        }
      } else if (e == start) {
        // Add name if it's the first
        p.namespacePathElements.add(e.name);
      }
    };

    TSPath p = new TSPath();
    collector(start, p, collector);
    return p;
  }

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
      nativeTypes().contains(t) || (t.element?.library?.isDartCore ?? false) && (nativeClasses.contains(t.element?.name));

  static String _name(Element e) => (e is PropertyAccessorElement) ? e.variable.name : e.name;

  String toTsName(Element element, {bool nopath: false}) {
    TSPath jspath = _collectJSPath(element); // note: we should check if var is top, but ... whatever.
    String name;
    if (nopath) {
      return jspath.namespacePathElements.last;
    }
    if (jspath.namespacePathElements.isNotEmpty) {
      if (jspath.modulePathElements.isNotEmpty) {
        name = namespaceFor(uri: jspath.moduleUri, modulePath: jspath.modulePath) + "." + jspath.name;
      } else {
        name = jspath.name;
      }
    } else {
      String prefix = namespace(element.library);
      if ((element is PropertyAccessorElement) && isTopLevel(element)) {
        prefix = prefix == null ? "module" : "${prefix}.module";
      }
      if (prefix != null && isTopLevel(element)) {
        name = "${prefix}.${_name(element)}";
      } else
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
      return new TSSimpleType(type.element.name,! TypeManager.isNativeType(type));
    }

    if (type is FunctionType) {
      Iterable<TSType> args = () sync* {
        for (var p in type.normalParameterTypes) {
          yield toTsType(p);
        }
        for (var p in type.optionalParameterTypes) {
          yield new TSOptionalType(toTsType(p));
        }

        if (type.namedParameterTypes.isNotEmpty) {
          yield new TSInterfaceType(
              fields: new Map.fromIterable(type.namedParameterTypes.keys,
                  value: (k) => new TSOptionalType(toTsType(type.namedParameterTypes[k]))));
        }
      }();

      Iterable<TSType> typeArguments = type.typeArguments?.map((t) => toTsType(t));

      return new TSFunctionType(toTsType(type.returnType), args, typeArguments);
    }

    if (getAnnotation(type?.element?.metadata ?? [], isJS) != null) {
      // check if we got a package annotation
      TSPath path = _collectJSPath(type.element);
      // Lookup for prefix
      String moduleUri = path.moduleUri;

      String prefix;
      if (moduleUri != null) {
        prefix = namespaceFor(uri: path.moduleUri, modulePath: path.modulePath) + '.';
      } else {
        prefix = "";
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
      if (isListType(type)) {
        actualName = "Array";
      } else if (type == currentContext.typeProvider.numType || type == currentContext.typeProvider.intType) {
        actualName = 'number';
      } else if (type == currentContext.typeProvider.stringType) {
        actualName = 'string';
      } else if (type == currentContext.typeProvider.boolType) {
        actualName = 'boolean';
      } else if (type == getType(currentContext, 'dart:core', 'RegExp')) {
        actualName = 'RegExpPattern';
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
}
