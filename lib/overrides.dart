import 'package:analyzer/analyzer.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:dart2ts/utils.dart';

abstract class MethodInterceptor {
  String build(MethodInvocation invocation, String target, String name,
      String arguments);
}

abstract class AccessorInterceptor {
  String buildRead(PropertyAccessorElement invocation, String target, String name);
}

class ExtensionMethodInterceptor implements MethodInterceptor {
  String _extensionMethod;

  ExtensionMethodInterceptor(this._extensionMethod);

  @override
  String build(MethodInvocation invocation, String target, String name,
      String arguments) {
    return "${_extensionMethod}.apply(this,[${target}].push${arguments})";
  }
}

class ExtensionAccessInterceptor implements AccessorInterceptor {
  String _extensionMethod;

  ExtensionAccessInterceptor(this._extensionMethod);

  @override
  String buildRead(PropertyAccessorElement access, String target, String name) {
    return "${_extensionMethod}.call(this,${target})";
  }
}

Map<String, MethodInterceptor> _listInterceptors = {};

Map<String, AccessorInterceptor> _listAccessorInterceptors = {
  "first": new ExtensionAccessInterceptor('bare.List.first')
};

MethodInterceptor lookupInterceptor(MethodInvocation invocation) {
  Element e = invocation.methodName.staticElement?.enclosingElement;
  if (e is ClassElement && isListType(e.type)) {
    return _listInterceptors[invocation.methodName.name];
  }
  return null;
}

AccessorInterceptor lookupAccessorInterceptorFromAccess(PropertyAccess access) => lookupAccessorInterceptor(access.propertyName.staticElement);

AccessorInterceptor lookupAccessorInterceptor(Element property) {
  Element e = property?.enclosingElement;
  if (e is ClassElement && (isListType(e.type)||isIterableType(e.type))) {
    return _listAccessorInterceptors[property.name];
  }
  return null;
}
