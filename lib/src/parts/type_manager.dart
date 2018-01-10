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

  String get moduleUri =>
      modulePathElements.isEmpty ? null : "module:${modulePath}";

  String get modulePath => modulePathElements.join('/');

  String get name => namespacePathElements.join('.');
}

class TypeManager {
  LibraryElement _current;

  TypeManager(this._current);

  Map<String, TSImport> _prefixes = {
    '#NOURI#': new TSImport(prefix: 'bare', path: 'dart_sdk/bare')
  };

  String _nextPrefix() => "lib${_prefixes.length}";

  AssetId _toAssetId(String uri) {
    if (uri.startsWith('asset:')) {
      List<String> parts = path.split(uri.substring(6));
      return new AssetId(parts.first, path.joinAll(parts.sublist(1)));
    }
    throw "Cannot convert to assetId : ${uri}";
  }

  String namespace(LibraryElement lib) => namespaceFor(lib: lib);

  String namespaceFor({String uri, String modulePath, LibraryElement lib}) {
    if (lib != null && lib == _current) {
      return null;
    }
    uri ??= lib.source.uri.toString();

    return _prefixes.putIfAbsent(uri, () {
      if (lib == null) {
        return new TSImport(prefix: _nextPrefix(), path: modulePath);
      }
      if (lib.isInSdk) {
        // Replace with ts_sdk

        String name = lib.name.substring(5);

        return new TSImport(
            prefix: name, path: "dart_sdk/${name}", library: lib);
      }

      // If same package produce a relative path
      AssetId currentId = _toAssetId(_current.source.uri.toString());
      AssetId id = _toAssetId(uri);

      String libPath;

      if (id.package == currentId.package) {
        libPath = path.joinAll([
          '.',
          path.withoutExtension(
              path.relative(id.path, from: path.dirname(currentId.path)))
        ]);
      } else {
        libPath =
            path.join("${id.package}", "${path.withoutExtension(id.path)}");
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
        String module = getAnnotation(e.metadata, isModule)
            ?.getField('path')
            ?.toStringValue();
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

  static Set<DartType> nativeTypes() =>
      ((TypeProvider x) => new Set<DartType>.from([
            x.boolType,
            x.stringType,
            x.intType,
            x.numType,
            x.doubleType,
            x.functionType,
          ]))(currentContext.typeProvider);

  static Set<String> nativeClasses =
      new Set.from(['List', 'Map', 'Iterable', 'Iterator']);

  static bool isNativeType(DartType t) =>
      nativeTypes().contains(t) ||
      (t.element.library?.isDartCore ?? false) &&
          (nativeClasses.contains(t.element.name));

  String toTsName(Element element, {bool nopath: false}) {
    TSPath jspath = _collectJSPath(
        element); // note: we should check if var is top, but ... whatever.
    String name;
    if (nopath) {
      return jspath.namespacePathElements.last;
    }
    if (jspath.namespacePathElements.isNotEmpty) {
      if (jspath.modulePathElements.isNotEmpty) {
        name =
            namespaceFor(uri: jspath.moduleUri, modulePath: jspath.modulePath) +
                "." +
                jspath.name;
      } else {
        name = jspath.name;
      }
    } else {
      String prefix = namespace(element.library);
      String mod = ""; // TODO: add "module." for topLevel getters and setters.
      if (prefix != null && isTopLevel(element)) {
        name = "${prefix}.${element.name}";
      } else
        name = element.name;
    }

    return name;
  }

  static bool isTopLevel(Element e) => e.library.units.contains(e.enclosingElement);

  TSType toTsType(DartType type,
      {bool noTypeArgs: false, bool inTypeOf: false}) {
    if (type == null) {
      return null;
    }

    // Look for @JS annotations
    if (type is TypeParameterType) {
      return new TSSimpleType(type.element.name);
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
                  value: (k) => new TSOptionalType(
                      toTsType(type.namedParameterTypes[k]))));
        }
      }();

      Iterable<TSType> typeArguments =
          type.typeArguments?.map((t) => toTsType(t));

      return new TSFunctionType(toTsType(type.returnType), args, typeArguments);
    }

    if (getAnnotation(type?.element?.metadata ?? [], isJS) != null) {
      // check if we got a package annotation
      TSPath path = _collectJSPath(type.element);
      // Lookup for prefix
      String moduleUri = path.moduleUri;

      String prefix;
      if (moduleUri != null) {
        prefix =
            namespaceFor(uri: path.moduleUri, modulePath: path.modulePath) +
                '.';
      } else {
        prefix = "";
      }

      Iterable<TSType> typeArgs;
      if (!noTypeArgs &&
              type is ParameterizedType &&
              type.typeArguments?.isNotEmpty ??
          false) {
        typeArgs =
            ((type as ParameterizedType).typeArguments).map((t) => toTsType(t));
      } else {
        typeArgs = null;
      }

      return new TSGenericType("${prefix}${path.name}", typeArgs);
    }

    if (type.isDynamic) {
      return new TSSimpleType("any");
    }

    String p;
    if (type.element != null &&
        type.element.library != _current &&
        !isNativeType(type)) {
      p = "${namespace(type.element.library)}.";
    } else {
      p = "";
    }

    String actualName;
    if (isListType(type)) {
      actualName = "Array";
    } else if (type == currentContext.typeProvider.numType ||
        type == currentContext.typeProvider.intType) {
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

    if (!noTypeArgs &&
        type is ParameterizedType &&
        type.typeArguments.isNotEmpty) {
      return new TSGenericType(
          "${p}${actualName}", type.typeArguments.map((t) => toTsType(t)));
    } else {
      return new TSSimpleType("${p}${actualName}");
    }
  }

  Iterable<TSImport> get allImports => _prefixes.values;

  String namespaceForPrefix(PrefixElement prefix) {
    return namespace(
        _current.getImportsWithPrefix(prefix).first.importedLibrary);
  }
}
