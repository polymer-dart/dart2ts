import 'dart:async';
import 'package:dart2ts/code_generator.dart';
import 'package:logging/logging.dart';



Future main(List<String> args) {
  Logger.root.onRecord.listen((record)=>print('${record.time} ${record.level} ::: ${record.loggerName}, ${record.message}'));
  return new Dart2TsCommandRunner().run(args);
}