import 'dart:async';
import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:build_runner/build_runner.dart';
import 'package:dart_style/dart_style.dart';
import 'package:glob/glob.dart';
import 'package:code_builder/code_builder.dart' as code_builder;
import 'package:polymerize/utils.dart';

Future generateInitCode(PackageGraph graph) async {
  await build([new PackageBuildAction(new InitCodePackageBuilder(new Glob("lib/myelement.dart")), graph.root.name)],
      packageGraph: graph);
}

class InitCodePackageBuilder extends PackageBuilder {
  final Glob _entryPointGlob;

  InitCodePackageBuilder(this._entryPointGlob);

  @override
  Future build(BuildStep buildStep) async {
    code_builder.FileBuilder fileBuilder = new code_builder.FileBuilder();
    code_builder.BlockBuilder blockBuilder = new code_builder.BlockBuilder();
    code_builder.MethodBuilder methodBuilder = new code_builder.MethodBuilder()
      ..name = '_registerAllComponents'
      ..annotations.addAll([
        new code_builder.Annotation((b) =>
        b
          ..code =
              code_builder
                  .refer("onModuleLoad", "package:dart2ts/annotations.dart")
                  .call([code_builder.literalMap({})])
                  .code)
      ]);

    Iterable<LibraryElement> allDeps(LibraryElement le, Set<num> visited) sync* {
      if (visited.contains(le.id)) {
        return;
      }

      visited.add(le.id);

      for (LibraryElement imported in le.importedLibraries) {
        yield* allDeps(imported, visited);
      }

      yield le;
    }

    await for (AssetId id in buildStep.findAssets(_entryPointGlob)) {
      // If it's a lib
      if (!await buildStep.resolver.isLibrary(id)) {
        continue;
      }

      // Collect every component
      LibraryElement libraryElement = await buildStep.resolver.libraryFor(id);

      allDeps(libraryElement, new Set()).forEach((lib) {
        // find all classes annotated with polymer register

        lib.units.forEach((cu) {
          cu.types.forEach((ce) {
            if (getAnnotation(ce.metadata, isPolymerRegister) != null) {
              blockBuilder.addExpression(code_builder.refer("register", "package:polymer2/polymer2.dart").call([]));
            }
          });
        });
      });
    }

    methodBuilder.body = blockBuilder.build();
    fileBuilder.body.add(methodBuilder.build());

    code_builder.File library = fileBuilder.build();


    final emitter = new code_builder.DartEmitter(new code_builder.Allocator.simplePrefixing());
    await buildStep.writeAsString(new AssetId("", 'lib/init.dart'), new DartFormatter().format('${library.accept(emitter)}'));
  }

  @override
  Iterable<String> get outputs => const ['lib/init.dart'];
}
