part of '../code_generator.dart';

abstract class IOverrides {
  IOverrides();

  factory IOverrides.parse(String overrideYaml) => new Overrides.parse(overrideYaml);
}

Map<K, V> _recursiveMerge<K, V>(Map<K, V> map1, Map<K, V> map2) {
  Set<K> allKeys = new Set<K>()..addAll(map1.keys)..addAll(map2.keys);

  return new Map.fromIterable(allKeys, value: (k) {
    if (map1[k] is Map || map2[k] is Map) {
      return _recursiveMerge(map1[k] ?? {}, map2[k] ?? {}) as V;
    }

    return map1[k] ?? map2[k];
  });
}

class Overrides extends IOverrides {
  Map _overrides;

  Map _libraryOverrides(String uri) => _overrides[uri] as Map;

  Overrides(YamlDocument _yaml) {
    Map _d = (_yaml?.contents is Map) ? _yaml.contents : {};
    this._overrides = _d['overrides'] ?? {};
  }

  factory Overrides.parse(String overrideYaml) {
    return new Overrides(loadYamlDocument(overrideYaml));
  }

  static Future<Overrides> forCurrentContext() async {
    res.Resource resource = new res.Resource('package:dart2ts/src/overrides.yml');
    String str = await resource.readAsString();

    return new Overrides(loadYamlDocument(str));
  }

  String resolvePrefix(TypeManager m, String module, [String origPrefix = null]) {
    if (module == 'global') {
      return "";
    } else if (module != null) {
      if (module.startsWith('module:')) {
        return m.namespaceFor(uri: module, modulePath: module.substring(7));
      } else if (module.startsWith('sdk:')) {
        return m.namespaceFor(uri: module, modulePath: module.substring(4),isSdk: true);
      }
      if (module.startsWith('dart:') || module.startsWith('package:')) {
        return m.namespace(getLibrary(currentContext, module));
      }
    } else {
      return origPrefix;
    }
  }

  /**
   * Check for method overrides.
   * The target can be a method name or a square expression. Inside square expression one can use `${prefix}` to replace
   * with the current prefix for the destination module, in order to access static fields in the native class.
   */
  TSExpression checkMethod(TypeManager typeManager, DartType type, String methodName, TSExpression tsTarget,
      {TSExpression orElse()}) {
    var classOverrides = _findClassOverride(type);

    if (classOverrides == null) {
      return orElse();
    }

    String methodOverrides = (classOverrides['methods'] ?? {})[methodName];

    if (methodOverrides == null) {
      return orElse();
    }

    String module = classOverrides['to']['from'];

    String prefix = resolvePrefix(typeManager, module);

    // Square or dot ?

    if (methodOverrides.startsWith('[')) {
      String sym = methodOverrides.substring(1, methodOverrides.length - 1);
      sym = sym.replaceAllMapped(new RegExp(r"\${([^}]*)}"), (Match m) {
        String n = m.group(1);
        if (n == "prefix") {
          return prefix;
        }

        return "\${${n}}";
      });
      return new TSIndexExpression(tsTarget, new TSSimpleExpression(sym));
    } else {
      return new TSDotExpression(tsTarget, methodOverrides);
    }
  }

  String checkProperty(TypeManager typeManager, DartType type, String name) {
    var classOverrides = _findClassOverride(type);

    if (classOverrides == null) {
      return name;
    }

    String propsOverrides = (classOverrides['properties'] ?? {})[name];

    if (propsOverrides == null) {
      return name;
    }

    return propsOverrides;
  }

  Iterable<DartType> _visitTypeHierarchy(DartType type, {bool recursive: true}) sync* {
    if (type == null) return;

    yield type;

    if (type == currentContext.typeProvider.objectType) return;

    if (!recursive) {
      return;
    }

    if (type.element is ClassElement) {
      yield* _visitTypeHierarchy((type.element as ClassElement).supertype, recursive: true);

      for (DartType intf in (type.element as ClassElement).interfaces) {
        yield* _visitTypeHierarchy(intf, recursive: true);
      }
    }
  }

  String findLibraryOverride(TypeManager tm, LibraryElement lib) {
    if (lib == null) {
      return null;
    }
    Uri fromUri = lib.source?.uri;

    _logger.fine("Checking type for {${fromUri}}");
    if (fromUri == null) {
      return null;
    }

    var libOverrides = _libraryOverrides(fromUri.toString());
    if (libOverrides == null) {
      return null;
    }

    String mod = libOverrides['from'];

    if (mod == null || !mod.startsWith('module:') && !mod.startsWith('sdk:')) {
      return null;
    }

    if (mod.startsWith('sdk:')) {
      return "${tm.sdkPrefix}/${mod.substring(4)}";
    }
    return mod.substring(7);
  }

  _findClassOverride(DartType mainType, {bool recursive: true}) {
    return _visitTypeHierarchy(mainType, recursive: recursive).map((type) {
      LibraryElement from = type?.element?.library;
      Uri fromUri = from?.source?.uri;

      _logger.fine("Checking type for {${fromUri}}${type?.name}");
      if (type == null || fromUri == null) {
        return null;
      }

      var libOverrides = _libraryOverrides(fromUri.toString());
      if (libOverrides == null) {
        return null;
      }

      var classOverrides = (libOverrides['classes'] ?? {})[type.name];
      if (classOverrides == null) {
        return null;
      }

      return new Map()
        ..addAll(classOverrides)
        ..putIfAbsent('library', () => libOverrides);
    }).firstWhere(notNull, orElse: () => null);
  }

  TSType checkType(TypeManager typeManager, String origPrefix, DartType type, bool noTypeArgs, {TSType orElse()}) {
    var classOverrides = _findClassOverride(type, recursive: false);

    if (classOverrides == null || classOverrides['to'] == null || (classOverrides['to'] as Map)['class'] == null) {
      return orElse();
    }

    String module = classOverrides['to']['from'] ?? classOverrides['library']['from'];

    String p = resolvePrefix(typeManager, module, origPrefix);
    if (p != null && p.isNotEmpty) {
      p = "${p}.";
    }

    String actualName = classOverrides['to']['class'];

    if (!noTypeArgs && type is ParameterizedType && type.typeArguments.isNotEmpty) {
      return new TSGenericType("${p}${actualName}", type.typeArguments.map((t) => typeManager.toTsType(t)).toList());
    } else {
      return new TSSimpleType("${p}${actualName}", !TypeManager.isNativeType(type));
    }
  }

  TSExpression checkIndexedOperator(
      Context<TSNode> context, Expression target, Expression index, TSExpression orElse()) {
    var classOverrides = _findClassOverride(target.bestType);

    if (classOverrides == null) return orElse();

    var operators = classOverrides['operators'];

    bool isAssigning = isAssigningLeftSide(target.parent);

    String op;
    if (isAssigning) {
      op = "[]=";
    } else {
      op = "[]";
    }

    if (operators == null || operators[op] == null) {
      return orElse();
    }

    // replace with method invocation
    String methodName = operators[op];

    if (isAssigning) {
      return new TSInvoke(new TSDotExpression(context.processExpression(target), methodName), [
        context.processExpression(index),
        context.processExpression(assigningValue(target.parent)),
      ]);
    } else {
      return new TSInvoke(
          new TSDotExpression(context.processExpression(target), methodName), [context.processExpression(index)]);
    }
  }

  TSExpression checkConstructor(Context<TSNode> context, DartType targetType, ConstructorElement ctor,
      ArgumentListCollector collector, TSExpression orElse()) {
    var classOverrides = _findClassOverride(targetType);
    if (classOverrides == null || classOverrides['constructors'] == null) {
      return orElse();
    }

    var constructor = classOverrides['constructors'][ctor.name ?? "\$default"];
    if (constructor == null) {
      return orElse();
    }

    String newName;
    bool isFactory;
    if (constructor is String) {
      newName = constructor;
      isFactory = false;
    } else {
      newName = constructor['name'];
      isFactory = constructor['factory'];
    }

    TSType tsType = context.typeManager.toTsType(targetType);

    return new TSInvoke(new TSStaticRef(tsType, newName), collector.arguments, collector.namedArguments)
      ..asNew = !isFactory;
  }

  void merge(Overrides newOverrides) {
    _overrides = _recursiveMerge(newOverrides._overrides, _overrides);
  }
}
