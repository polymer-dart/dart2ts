import 'package:analyzer/analyzer.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:dart2ts/utils.dart';

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
          String target, String propertyName) =>
      "${target}.${propertyName}";

  @override
  String invokeMethod(MethodElement method, String target, String methodName,
          List<String> arguments) =>
      "${_target(target)}${methodName}${_args(arguments)}";

  @override
  String newInstance(ConstructorElement constructor, String className,
      List<String> arguments) {
    if (constructor.isDefaultConstructor) {
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
}

class ListTranslator extends TranslatorBase {
  const ListTranslator();

  @override
  bool checkAccessor(DartType targetType, PropertyAccessorElement accessor) {
    Element enclosing = accessor.enclosingElement;
    return enclosing is ClassElement &&
        isListType(targetType) &&
        accessor.name == "first";
  }

  @override
  String getProperty(DartType targetType, PropertyAccessorElement getter,
      String target, String propertyName) {
    return "bare.List.${propertyName}.get.call(this,${target})";
  }
}

class TranslatorRegistry {
  static const List<Translator> _translators = const [
    const ListTranslator(),
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
}

TranslatorRegistry translatorRegistry = const TranslatorRegistry();
