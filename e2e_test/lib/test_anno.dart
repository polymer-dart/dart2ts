import 'package:js/js.dart';
import 'package:dart2ts/annotations.dart';

class MyAnnotation {
  final String _value;

  const MyAnnotation(this._value);
}

@MyAnnotation('Yeah!')
class MyAnnotatedClass {
  @MyAnnotation('onprop')
  String myProp;
}

@JS("Map")
class JSMap<K, V> {
  @JS('get')
  V GET(K str);
}

@JS()
@anonymous
@Module('dart_sdk/decorations')
class IAnnotationKey {
  String library;
  String type;

  IAnnotationKey({this.library, this.type});
}

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
  JSMap<String, JSMap<String, List<dynamic>>> propertyAnnotations;
}

@JS('getDartMetadata')
@Module('dart_sdk/decorations')
external IDartMetadata getMetadata(var tp);

IDartMetadata testMetadata() => getMetadata(MyAnnotatedClass);

List propAnno() => getMetadata(MyAnnotatedClass)
    .propertyAnnotations
    .GET('myProp')
    .GET('{asset:sample_project/lib/test_anno.dart}#{MyAnnotation}');
