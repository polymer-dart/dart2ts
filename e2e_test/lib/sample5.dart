@JS('NativeNamespace')
library myNativeNamespace;

import 'package:js/js.dart';
import 'package:dart2ts/annotations.dart';

@JS('NativeClass')
@TS(generate: true)
class NativeClass<T> {
  external String get readOnlyString;

  external String get normal;

  external void set normal(String);

  external String doSomething(String name);

  external T create();
}
