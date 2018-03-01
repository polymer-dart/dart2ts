import 'dart:async';
import 'package:dart2ts/dart2ts.dart';

Future main() async {
  await tsbuild(clean: true);
}
