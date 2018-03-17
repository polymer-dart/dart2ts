import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:build/src/builder/build_step.dart';
import 'package:build_runner/build_runner.dart';
import 'package:logging/logging.dart';
import 'package:package_config/packages_file.dart' as packages;
import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';

Logger _logger = new Logger('dart2ts.lib.deps_installer');

class Pubspec {
  int depth;
  var content;
  String packagePath;

  List<Pubspec> children = [];

  Pubspec({this.packagePath, this.content, this.depth});

  String get name => content['name'];

  Map get dependencies => content['dependencies'] ?? {};

  String get version => content['version'] ?? '0.0.0';

  String get description => content['description'] ?? 'Package ${name}';

  String get author => content['author'] ?? 'unknown';

  toString() => "Package ${name} ${version} [${depth}]";
}

class Dart2TsPackageBuildAction extends PackageBuilder {
  @override
  Future build(BuildStep buildStep) {}

  @override
  Iterable<String> get outputs => ['dart2ts.gen.dart'];
}

class Dart2TsInstallCommand extends Command<bool> {
  @override
  String get description => "install dependencies";

  @override
  String get name => 'install';

  Dart2TsInstallCommand() {
    this.argParser
      ..addOption('dir', defaultsTo: '.', abbr: 'd', help: 'the base path of the package to process')
      ..addOption('out', defaultsTo: 'deps', abbr: 'o', help: 'install folder path');
  }

  @override
  run() {
    String rootPath = argResults['dir'];
    String destPath = argResults['out'];

    // Load packages
    _installAllDeps(rootPath, destPath);
  }
}

void _installAllDeps(String rootPath, String destPath) {
  // Load packages
  File packagesFile = new File(path.join(rootPath, '.packages'));

  if (!packagesFile.existsSync()) {
    throw "`.packages` file is missing, please run `pub get`";
  }

  // Read packages file
  Map<String, Uri> pkgs = packages.parse(packagesFile.readAsBytesSync(), path.toUri(rootPath));

  // Recursively collect all the NOT DEV DEPS

  Map<String, Pubspec> deps = new Map();

  Pubspec collectDeps(String fromPath, [int depth = 0]) {
    var content = loadYaml(new File(path.join(fromPath, 'pubspec.yaml')).readAsStringSync());
    Pubspec pubspec = new Pubspec(packagePath: fromPath, content: content, depth: depth);
    if (!deps.containsKey(pubspec.name)) {
      deps[pubspec.name] = pubspec;
      (pubspec.dependencies ?? {}).keys.forEach((String k) {
        pubspec.children.add(collectDeps(path.dirname(pkgs[k].toFilePath()), depth + 1));
      });
    }

    return pubspec;
  }

  Pubspec rootSpec = collectDeps(rootPath);

  List sorted_deps = new List<Pubspec>.from(deps.values.where((p) => p.packagePath != rootPath))
    ..sort((p1, p2) => p1.depth.compareTo(p2.depth));

  _logger.fine("Collected deps : ${sorted_deps}");

  // All but root depth first
  Iterable<Pubspec> depthFirst(Pubspec root) sync* {
    for (Pubspec child in root.children) {
      yield* depthFirst(child);
    }
    if (root != rootSpec) yield root;
  }

  depthFirst(rootSpec).forEach((p) {
    _logger.fine("Installing ${p.name} into ${destPath}");
    _install(p, destPath);
  });
}

void _install(Pubspec pubspec, String dest) {
  String packageDest = path.join(dest, pubspec.name);
  _copy(pubspec.packagePath, packageDest);

  // generate "package.json"

  _generatePackageJson(pubspec, dest, path.join(packageDest, 'package.json'));
  _generateTsConfig(pubspec, dest, path.join(packageDest, 'tsconfig.json'));
}

void _copy(String from, String to) {
  Directory src = new Directory(from);
  src.listSync(recursive: true).where((f) => f is File).forEach((e) {
    File f = e;
    String dest = path.join(to, path.relative(f.path, from: from));
    new Directory(path.dirname(dest)).createSync(recursive: true);
    f.copySync(dest);
  });
}

void _generatePackageJson(Pubspec pubspec, String pkgRoot, String filePath) {
  File f = new File(filePath);
  if (!f.existsSync()) {
    // Create a new file
    f.writeAsStringSync(JSON.encode({
      "name": pubspec.name,
      "version": pubspec.version,
      "description": pubspec.description,
      "scripts": {"build": "tsc"},
      "files": ["lib/**/*.js", "lib/**/*.d.ts", "package.json"],
      "author": pubspec.author,
      "license": "ISC",
      "dependencies": new Map.fromIterable(pubspec.children,
          key: (p) => p.name, value: (p) => path.relative(path.join(pkgRoot, p.name, 'dist'), from: f.parent.path)),
      "devDependencies": {"typescript": "^2.5.2"}
    }));
  }

  // copy it into dist too
  Directory dist = new Directory(path.join(f.parent.path, 'dist'));
  dist.createSync(recursive: true);

  f.copySync(path.join(dist.path, path.basename(f.path)));
}

void _generateTsConfig(Pubspec pubspec, String pkgRoot, String filePath) {
  File f = new File(filePath);
  if (!f.existsSync()) {
    // Create a new file
    f.writeAsStringSync(JSON.encode({
      "compilerOptions": {
        "module": "es6",
        "target": "es6",
        "sourceMap": true,
        "declaration": true,
        "rootDir": "./lib/",
        "outDir": "dist",
        "baseUrl": "./",
        "experimentalDecorators": true,
        "lib": ["dom", "es6", "esnext.asynciterable"]
      },
      "exclude": ["node_modules", "dist"],
      "include": ["lib/**/*.ts"],
    }));
  }
}
