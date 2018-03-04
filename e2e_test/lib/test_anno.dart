import 'package:js/js.dart';
import 'package:dart2ts/annotations.dart';

class MyAnnotation {
  final String _value;

  const MyAnnotation(this._value);
}

@MyAnnotation('Yeah!')
class MyAnnotatedClass {}

@JS()
@Module('dart_sdk/decorations')
class IAnnotation {
  String library;
  String type;
  var value;
}

@JS()
@Module('dart_sdk/decorations')
class IDartMetadata {
  String library;
  List<TSAnno> annotations;
}

@JS('getDartMetadata')
@Module('dart_sdk/decorations')
external IDartMetadata getMetadata(var tp);

IDartMetadata testMetadata() => getMetadata(MyAnnotatedClass);
