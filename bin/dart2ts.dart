import 'dart:async';
import 'package:dart2ts/src/commands.dart' as cmd;
import 'package:logging/logging.dart';

const String BOLD = '\x1b[1m';
const String DIM = '\x1b[2m';
const String UNDERLINED = '\x1b[4m';
const String BLINK = '\x1b[5m';
const String REVERSE = '\x1b[7m';
const String NORMAL = '\x1b[0m';

Future main(List<String> args) => cmd.main(args);
