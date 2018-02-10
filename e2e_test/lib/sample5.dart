@JS('NativeNamespace')
library myNativeNamespace;

import 'package:js/js.dart';
import 'package:dart2ts/annotations.dart';

@JS('NativeClass')
@TS(generate:true)
class NativeClass {
  external String doSomething();
}
