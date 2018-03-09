import 'package:dart2ts/annotations.dart' as _1;
import 'package:polymer2/polymer2.dart' as _2;
import 'package:polymer2_test/myelement.dart' as _3;

@_1.onModuleLoad
_registerAllComponents() {
  _2.register(_3.MyElement);
}
