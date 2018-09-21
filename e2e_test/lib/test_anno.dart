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
  external V GET(K str);
}

@JS()
@anonymous
@Module('typescript_dart/utils')
class IAnnotationKey {
  String library;
  String type;

  IAnnotationKey({this.library, this.type});
}

@JS()
@Module('typescript_dart/utils')
class IAnnotation {
  String library;
  String type;
  var value;
}

@JS('Metadata')
@Module('typescript_dart/utils')
class IDartMetadata {
  List<IAnnotation> annotations;
  JSMap<String, JSMap<String, dynamic>> propertyAnnotations;
}

@JS('getMetadata')
@Module('typescript_dart/utils')
external IDartMetadata getMetadata(var tp);

IDartMetadata testMetadata() => getMetadata(MyAnnotatedClass);

propAnno() => getMetadata(MyAnnotatedClass)
    .propertyAnnotations
    .GET('myProp')
    .GET('{asset:sample_project/lib/test_anno.dart}#{MyAnnotation}');
