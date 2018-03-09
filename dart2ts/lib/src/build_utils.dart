import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:build_runner/build_runner.dart' as builder;

import 'package:dart2ts/src/code_generator.dart';

import 'package:path/path.dart' as p;

final p.Context path = p.url;

npm([List<String> args = const ['run', 'build']]) async {
  Process npm = await Process.start('npm', args);
  stdout.addStream(npm.stdout);
  stderr.addStream(npm.stderr);
  int exitCode = await npm.exitCode;
  if (exitCode != 0) {
    throw "Build error";
  }
}

tsc({String basePath: '.'}) async {
  Process npm = await Process.start('tsc', [], workingDirectory: basePath);
  stdout.addStream(npm.stdout);
  stderr.addStream(npm.stderr);
  int exitCode = await npm.exitCode;
  if (exitCode != 0) {
    throw "Build error";
  }
}

enum Mode { APPLICATION, LIBRARY }

class BuildException {
  builder.BuildResult _result;

  BuildException(this._result);

  builder.BuildResult get result => _result;

  toString() => "Build Exception ${_result.exception}";
}

Future<builder.BuildResult> tsbuild({String basePath: '.', bool clean: true, Mode mode: Mode.LIBRARY}) async {
  if (clean) {
    Directory dir = new Directory(path.join(basePath, '.dart_tool'));
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  }

  builder.PackageGraph packageGraph = new builder.PackageGraph.forPath(basePath);

  Config cfg;

  switch (mode) {
    case Mode.LIBRARY:
      cfg = new Config(modulePrefix: 'node_modules');
      break;
    case Mode.APPLICATION:
      cfg = new Config();
      break;
  }

  builder.BuildResult res = await builder.build([
    new builder.BuildAction(new Dart2TsBuilder(cfg), packageGraph.root.name, inputs: ['lib/**.dart']),
  ], deleteFilesByDefault: true, packageGraph: packageGraph);

  if (res.status != builder.BuildStatus.success) {
    throw new BuildException(res);
  }

  await tsc(basePath: basePath);

  switch (mode) {
    case Mode.LIBRARY:
      await finishLibrary(basePath: basePath, packageName: packageGraph.root.name);
      break;
    case Mode.APPLICATION:
      break;
  }

  return res;
}

Future fixDependencyPath(String dist, String packageName) async {
  // Replace "node_modules" with relative url

  RegExp re = new RegExp("import([^\"']*)[\"']([^\"']*)[\"']");
  await for (FileSystemEntity f in new Directory(dist).list(recursive: true)) {
    if (f is File) {
      List<String> lines = await f.readAsLines();
      IOSink sink = f.openWrite();
      lines.map((l) {
        Match m = re.matchAsPrefix(l);
        if (m != null && (!path.isAbsolute(m[2]) && !m[2].startsWith('.'))) {
          String origPath = m[2];
          String virtualAbsolutePath =
              path.joinAll(["node_modules", packageName]..addAll(path.split(path.relative(f.path, from: dist))));
          String virtualRelativePath = path.relative(m[2], from: virtualAbsolutePath);
          // Compute relative path from "virtual" directory "node_modules/<package>/current_path"

          l = "import${m[1]}'${virtualRelativePath}';";
        }

        return l;
      }).forEach((l) => sink.writeln(l));

      await sink.close();
    }
  }
}

Future copyAssets(String dist, {String basePath: '.'}) async {
  // Copy assets
  String srcPath = path.join(basePath, 'lib');

  await for (FileSystemEntity f in new Directory(srcPath).list(recursive: true)) {
    if (f is File && !f.path.endsWith('.dart') && !f.path.endsWith('.ts')) {
      File d = new File(path.join(dist, path.relative(f.path, from: srcPath)));
      if (!d.parent.existsSync()) {
        await d.parent.create(recursive: true);
      }
      await f.copy(d.path);
    }
  }
}

Future finishLibrary({String basePath: '.', String packageName}) async {
  File tsconfigFile = new File(path.join(basePath, 'tsconfig.json'));
  var tsconfig = JSON.decode(tsconfigFile.readAsStringSync());
  String dist = path.joinAll([basePath, tsconfig['compilerOptions']['outDir'], 'lib']);
  await fixDependencyPath(dist, packageName);
  await copyAssets(dist);
}
