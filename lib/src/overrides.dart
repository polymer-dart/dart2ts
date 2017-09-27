import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/src/generated/engine.dart';
import 'package:dart2ts/src/utils.dart';

abstract class Translator {
  bool checkOp(MethodElement operator);
  bool checkMethod(MethodElement method);
  bool checkAccessor(DartType targetType, PropertyAccessorElement accessor);
  bool checkNewInstance(ConstructorElement cons);
  bool checkField(FieldElement field);

  String binaryOp(MethodElement operator, String op, String left, String right);
  String newInstance(
      ConstructorElement constructor, String className, List<String> arguments);
  String invokeMethod(MethodElement method, String target, String methodName,
      List<String> arguments);
  String getProperty(DartType targetType, PropertyAccessorElement getter,
      String target, String propertyName);
  String setProperty(DartType targetType, PropertyAccessorElement setter,
      String target, String propertyName, String value);

  String getField(FieldElement field, String target, String propertyName);
  String setField(
      FieldElement field, String target, String propertyName, String value);

  String indexGet(DartType targetType, String target, String index);

  bool checkIndexed(DartType targetType);

  String indexSet(
      DartType targetType, String target, String index, String value);
}

class DefaultTranslator implements Translator {
  const DefaultTranslator();

  static _args(List<String> arguments) => "(${arguments.join(',')})";

  static _target(String target) =>
      target != null && target.isNotEmpty ? "${target}." : "";

  @override
  bool checkAccessor(DartType targetType, PropertyAccessorElement accessor) =>
      true;

  @override
  bool checkField(FieldElement field) => true;

  @override
  bool checkMethod(MethodElement method) => true;

  @override
  bool checkNewInstance(ConstructorElement cons) => true;

  @override
  bool checkOp(MethodElement operator) => true;

  @override
  String binaryOp(
          MethodElement operator, String op, String left, String right) =>
      "${left} ${op} ${right}";

  @override
  String getField(FieldElement field, String target, String propertyName) =>
      "${target}.${propertyName}";

  @override
  String getProperty(DartType targetType, PropertyAccessorElement getter,
      String target, String propertyName) {
    if (getter?.enclosingElement is CompilationUnitElement) {
      return "${target}.${propertyName}()";
    } else {
      return "${target}.${propertyName}";
    }
  }

  @override
  String invokeMethod(MethodElement method, String target, String methodName,
          List<String> arguments) =>
      "${_target(target)}${methodName}${_args(arguments)}";

  @override
  String newInstance(ConstructorElement constructor, String className,
      List<String> arguments) {
    if ((constructor.name ?? '').isEmpty) {
      if (constructor.isFactory)
        return "${className}.new${_args(arguments)}";
      else
        return "new ${className}${_args(arguments)}";
    } else if (constructor.isFactory) {
      return "${className}.${constructor.name}${_args(arguments)}";
    } else {
      return "new ${className}.${constructor.name}${_args(arguments)}";
    }
  }

  @override
  String setField(FieldElement field, String target, String propertyName,
          String value) =>
      "${_target(target)}${propertyName}=${value}";

  @override
  String setProperty(DartType targetType, PropertyAccessorElement setter,
          String target, String propertyName, String value) =>
      "${_target(target)}${propertyName}=${value}";
  @override
  bool checkIndexed(DartType targetType) => true;

  @override
  String indexGet(DartType targetType, String target, String index) =>
      "${target}[${index}]";
  @override
  String indexSet(
      DartType targetType, String target, String index, String value) {
    return "${indexGet(targetType,target,index)} = ${value}";
  }
}

const DefaultTranslator defaultTranslator = const DefaultTranslator();

class TranslatorBase implements Translator {
  const TranslatorBase();

  @override
  String binaryOp(
          MethodElement operator, String op, String left, String right) =>
      throw "Not Implemented";

  @override
  bool checkAccessor(DartType targetType, PropertyAccessorElement accessor) =>
      false;

  @override
  bool checkField(FieldElement field) => false;

  @override
  bool checkMethod(MethodElement method) => false;

  @override
  bool checkNewInstance(ConstructorElement cons) => false;

  @override
  bool checkOp(MethodElement operator) => false;

  @override
  String getField(FieldElement field, String target, String propertyName) =>
      throw "Not Implemented";

  @override
  String getProperty(DartType targetType, PropertyAccessorElement getter,
          String target, String propertyName) =>
      throw "Not Implemented";

  @override
  String invokeMethod(MethodElement method, String target, String methodName,
          List<String> arguments) =>
      throw "Not Implemented";

  @override
  String newInstance(ConstructorElement constructor, String className,
          List<String> arguments) =>
      throw "Not Implemented";

  @override
  String setField(FieldElement field, String target, String propertyName,
          String value) =>
      throw "Not Implemented";

  @override
  String setProperty(DartType targetType, PropertyAccessorElement setter,
          String target, String propertyName, String value) =>
      throw "Not Implemented";
  @override
  bool checkIndexed(DartType targetType) => false;

  @override
  String indexGet(DartType targetType, String target, String index) =>
      throw "Not Implemented";
  @override
  String indexSet(
          DartType targetType, String target, String index, String value) =>
      throw "Not Implemented";
}

class ListTranslator extends TranslatorBase {
  const ListTranslator();

  @override
  bool checkAccessor(DartType targetType, PropertyAccessorElement accessor) {
    if (accessor == null) {
      return false;
    }
    Element enclosing = accessor.enclosingElement;
    return enclosing is ClassElement &&
        isListType(targetType) &&
        _overriddenAccessors.contains(accessor.name);
  }

  static final Set<String> _overriddenAccessors =
      new Set.from(const ['first', 'last', 'isEmpty', 'isNotEmpty']);

  static final Set<String> _overriddenMethodNames =
      new Set.from(const ['add', 'remove', 'from', 'take', 'removeLast','where','firstWhere','lastWhere']);

  @override
  bool checkNewInstance(ConstructorElement cons) {
    return (cons.isFactory && isListType(cons.enclosingElement.type));
  }

  @override
  String newInstance(ConstructorElement constructor, String className,
      List<String> arguments) {
    return "bare.ListHelpers.methods.${constructor.name}(${arguments.join(',')})";
  }

  @override
  bool checkMethod(MethodElement method) {
    return (isListType(method.enclosingElement.type)) &&
        _overriddenMethodNames.contains(method.name);
  }

  @override
  String invokeMethod(MethodElement method, String target, String methodName,
      List<String> arguments) {
    return "bare.ListHelpers.methods.${methodName}(${target},${arguments.join(',')})";
  }

  @override
  String getProperty(DartType targetType, PropertyAccessorElement getter,
      String target, String propertyName) {
    return "bare.ListHelpers.${propertyName}.get.call(this,${target})";
  }
}

class IterableTranslator extends TranslatorBase {
  const IterableTranslator();

  @override
  bool checkAccessor(DartType targetType, PropertyAccessorElement accessor) {
    if (accessor == null) {
      return false;
    }
    Element enclosing = accessor.enclosingElement;
    return enclosing is ClassElement &&
        isIterableType(targetType) &&
        _overriddenAccessors.contains(accessor.name);
  }

  static final Set<String> _overriddenAccessors =
      new Set.from(const ['first', 'last', 'isEmpty', 'isNotEmpty']);

  static final Set<String> _overriddenMethodNames =
      new Set.from(const ['add', 'remove', 'from', 'take', 'removeLast','map','where','firstWhere']);

  @override
  bool checkNewInstance(ConstructorElement cons) {
    return (cons.isFactory && isIterableType(cons.enclosingElement.type));
  }

  @override
  String newInstance(ConstructorElement constructor, String className,
      List<String> arguments) {
    return "bare.IterableHelpers.methods.${constructor.name}(${arguments.join(',')})";
  }

  @override
  bool checkMethod(MethodElement method) {
    return (isIterableType(method.enclosingElement.type)) &&
        _overriddenMethodNames.contains(method.name);
  }

  @override
  String invokeMethod(MethodElement method, String target, String methodName,
      List<String> arguments) {
    return "bare.IterableHelpers.methods.${methodName}(${target},${arguments.join(',')})";
  }

  @override
  String getProperty(DartType targetType, PropertyAccessorElement getter,
      String target, String propertyName) {
    return "bare.IterableHelpers.${propertyName}.get.call(this,${target})";
  }
}

class StringTranslator extends TranslatorBase {
  const StringTranslator();

  @override
  bool checkAccessor(DartType targetType, PropertyAccessorElement accessor) {
    if (accessor == null) {
      return false;
    }
    Element enclosing = accessor.enclosingElement;
    return enclosing is ClassElement &&
        targetType == targetType.element.context.typeProvider.stringType &&
        _overriddenAccessors.contains(accessor.name);
  }

  static final Set<String> _overriddenAccessors =
      new Set.from(const ['codeUnits', 'isEmpty', 'isNotEmpty']);

  static final Set<String> _overriddenMethodNames =
      new Set.from(const ['codeUnitAt', 'replaceAll', 'take']);

  @override
  bool checkMethod(MethodElement method) {
    return (method.enclosingElement.type ==
            method.context.typeProvider.stringType) &&
        _overriddenMethodNames.contains(method.name);
  }

  @override
  String invokeMethod(MethodElement method, String target, String methodName,
      List<String> arguments) {
    return "bare.StringHelpers.methods.${methodName}(${target},${arguments.join(',')})";
  }

  @override
  String getProperty(DartType targetType, PropertyAccessorElement getter,
      String target, String propertyName) {
    return "bare.StringHelpers.${propertyName}.get.call(this,${target})";
  }
}

class ExpandoTranslator extends TranslatorBase {
  const ExpandoTranslator();

  @override
  String indexGet(DartType targetType, String target, String index) {
    return "core.ExpandoHelpers.index.get(${target},${index})";
  }

  @override
  String indexSet(
      DartType targetType, String target, String index, String value) {
    return "core.ExpandoHelpers.index.set(${target},${index},${value})";
  }

  @override
  bool checkIndexed(DartType targetType) {
    AnalysisContext c = targetType.element.context;

    LibraryElement lib =
        c.computeLibraryElement(c.sourceFactory.forUri('dart:core'));
    ClassElement expandoClass = lib.getType('Expando');
    return targetType.element == expandoClass;
  }
}

class TranslatorRegistry {
  static const List<Translator> _translators = const [
    const ListTranslator(),
    const IterableTranslator(),
    const StringTranslator(),
    const ExpandoTranslator(),
    defaultTranslator,
  ];
  const TranslatorRegistry();

  Translator _find(bool Function(Translator t) check) {
    return _translators.firstWhere((t) => check(t));
  }

  String binaryOp(
          MethodElement operator, String op, String left, String right) =>
      _find((t) => t.checkOp(operator)).binaryOp(operator, op, left, right);

  String newInstance(ConstructorElement constructor, String className,
          List<String> arguments) =>
      _find((t) => t.checkNewInstance(constructor))
          .newInstance(constructor, className, arguments);

  String invokeMethod(MethodElement method, String target, String methodName,
          List<String> arguments) =>
      _find((t) => t.checkMethod(method))
          .invokeMethod(method, target, methodName, arguments);
  String getProperty(DartType targetType, PropertyAccessorElement getter,
          String target, String propertyName) =>
      _find((t) => t.checkAccessor(targetType, getter))
          .getProperty(targetType, getter, target, propertyName);

  String setProperty(DartType targetType, PropertyAccessorElement setter,
          String target, String propertyName, String value) =>
      _find((t) => t.checkAccessor(targetType, setter))
          .setProperty(targetType, setter, target, propertyName, value);

  String getField(FieldElement field, String target, String propertyName) =>
      _find((t) => t.checkField(field)).getField(field, target, propertyName);

  String setField(FieldElement field, String target, String propertyName,
          String value) =>
      _find((t) => t.checkField(field))
          .setField(field, target, propertyName, value);

  String indexGet(DartType targetType, String target, String index) =>
      _find((t) => t.checkIndexed(targetType))
          .indexGet(targetType, target, index);

  String indexSet(
          DartType targetType, String target, String index, String value) =>
      _find((t) => t.checkIndexed(targetType))
          .indexSet(targetType, target, index, value);
}

TranslatorRegistry translatorRegistry = const TranslatorRegistry();
