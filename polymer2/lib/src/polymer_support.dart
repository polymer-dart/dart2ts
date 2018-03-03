@JS()
@Module('polymer2/lib/src/polymer_support_native')
library polymer2.lib.src.polymer_support;

import 'package:js/js.dart';
import 'package:dart2ts/annotations.dart';

@JS()
external register(Type dartClass, String tagName);
