//import 'dart:async';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/src/generated/engine.dart';
import 'package:dart2ts/src/utils.dart';

abstract class Translator {
  bool checkOp(MethodElement operator);
  bool checkMethod(MethodElement method, Expression targetExpression);
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
  bool checkMethod(MethodElement method, Expression targetExpression) => true;

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
      List<String> arguments) {
    if (method?.enclosingElement == null) {
      return "bare.callGenericMethod(${target},'${methodName}',${_args(arguments)})";
    }
    return "${_target(target)}${methodName}${_args(arguments)}";
  }

  @override
  String newInstance(ConstructorElement constructor, String className,
      List<String> arguments) {
    if ((constructor.name ?? '').isEmpty) {
      if (constructor.isFactory)
        return "${className}.new${_args(arguments)}";
      else
        return "new ${className}${_args(arguments)}";
    } else if (constructor.isFactory) {
      return "${className}.${tsMethodName(constructor.name)}${_args(arguments)}";
    } else {
      return "new ${className}.${tsMethodName(constructor.name)}${_args(arguments)}";
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
  bool checkMethod(MethodElement method, Expression targetExpression) => false;

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

  static final Set<String> _overriddenMethodNames = new Set.from(const [
    'add',
    'remove',
    'from',
    'take',
    'removeLast',
    'where',
    'firstWhere',
    'lastWhere'
  ]);

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
  bool checkMethod(MethodElement method, Expression targetExpression) {
    return method != null &&
        (isListType(method.enclosingElement.type)) &&
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
    return "bare.ListHelpers.${propertyName}.get(${target})";
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

  static final Set<String> _overriddenMethodNames = new Set.from(const [
    'add',
    'remove',
    'from',
    'take',
    'removeLast',
    'map',
    'where',
    'firstWhere',
    'join',
    'lastWhere'
  ]);

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
  bool checkMethod(MethodElement method, Expression targetExpression) {
    return method != null &&
        (isIterableType(method.enclosingElement.type)) &&
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
    return "bare.IterableHelpers.${propertyName}.get(${target})";
  }
}

class NumberTranslator extends TranslatorBase {
  const NumberTranslator();

  static final Set<String> _overriddenMethodNames =
      new Set.from(const ['parse']);

  @override
  bool checkMethod(MethodElement method, Expression targetExpression) {
    return (targetExpression?.staticType ==
            currentContext.typeProvider.numType) &&
        _overriddenMethodNames.contains(method.name);
  }

  @override
  String invokeMethod(MethodElement method, String target, String methodName,
      List<String> arguments) {
    if (method.isStatic) {
      return "bare.NumberHelpers.methods.${methodName}(${arguments.join(',')})";
    }
    return "bare.NumberHelpers.methods.${methodName}(${target},${arguments.join(',')})";
  }
}

class IntTranslator extends TranslatorBase {
  const IntTranslator();

  static final Set<String> _overriddenMethodNames =
      new Set.from(const ['parse']);

  @override
  bool checkMethod(MethodElement method, Expression targetExpression) {
    return (targetExpression?.staticType ==
            currentContext.typeProvider.intType) &&
        _overriddenMethodNames.contains(method.name);
  }

  @override
  String invokeMethod(MethodElement method, String target, String methodName,
      List<String> arguments) {
    if (method.isStatic) {
      return "bare.IntHelpers.methods.${methodName}(${arguments.join(',')})";
    }
    return "bare.IntHelpers.methods.${methodName}(${target},${arguments.join(',')})";
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
        targetType != null &&
        targetType.element != null &&
        targetType == targetType.element.context.typeProvider.stringType &&
        _overriddenAccessors.contains(accessor.name);
  }

  static final Set<String> _overriddenAccessors =
      new Set.from(const ['codeUnits', 'isEmpty', 'isNotEmpty']);

  static final Set<String> _overriddenMethodNames = new Set.from(
      const ['codeUnitAt', 'replaceAll', 'take', 'contains', 'allMatches']);

  @override
  bool checkMethod(MethodElement method, Expression targetExpression) {
    return method != null &&
        (targetExpression?.staticType ==
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
    return "bare.StringHelpers.${propertyName}.get(${target})";
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
    AnalysisContext c = targetType.element.context ?? currentContext;

    return targetType.element == getType(c, 'dart:core', 'Expando');
  }
}

typedef bool CHECK_TRANSLATOR_FUNCTION(Translator t);

class TranslatorRegistry {
  static const List<Translator> _translators = const [
    const ListTranslator(),
    const IterableTranslator(),
    const StringTranslator(),
    const ExpandoTranslator(),
    const IntTranslator(),
    const NumberTranslator(),
    defaultTranslator,
  ];
  const TranslatorRegistry();

  Translator _find(CHECK_TRANSLATOR_FUNCTION check) {
    return _translators.firstWhere((t) => check(t));
  }

  String binaryOp(
          MethodElement operator, String op, String left, String right) =>
      _find((t) => t.checkOp(operator)).binaryOp(operator, op, left, right);

  String newInstance(ConstructorElement constructor, String className,
          List<String> arguments) =>
      _find((t) => t.checkNewInstance(constructor))
          .newInstance(constructor, className, arguments);

  String invokeMethod(MethodElement method, Expression targetExpression,
          String target, String methodName, List<String> arguments) =>
      _find((t) => t.checkMethod(method, targetExpression))
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
