import 'package:analyzer/dart/element/type.dart';

bool isListType(DartType type) => isTypeInstanceOf(type.element.context.typeProvider.listType, type);

bool isIterableType(DartType type) => isTypeInstanceOf(type.element.context.typeProvider.iterableType, type);

bool isTypeInstanceOf(ParameterizedType base, DartType type) =>
    type != null &&
    (type is ParameterizedType) &&
    type.typeArguments.length == 1 &&
    type.isSubtypeOf(base.instantiate([type.typeArguments.single]));
