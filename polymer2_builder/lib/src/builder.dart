import 'dart:async';

import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:code_builder/code_builder.dart' as code_builder;
import 'package:dart2ts/src/utils.dart';
import 'package:dart_style/dart_style.dart';
/*
Future generateInitCode(PackageGraph graph) async {
  await build([new PackageBuildAction(new InitCodePackageBuilder(new Glob("lib/myelement.dart")), graph.root.name)],
      packageGraph: graph);
}*/

class InitCodePackageBuilder extends Builder {
  InitCodePackageBuilder();

  @override
  Future build(BuildStep buildStep) async {
    code_builder.FileBuilder fileBuilder = new code_builder.FileBuilder();
    code_builder.BlockBuilder blockBuilder = new code_builder.BlockBuilder();
    code_builder.MethodBuilder methodBuilder = new code_builder.MethodBuilder()
      ..name = '_registerAllComponents'
      ..annotations.add(code_builder.refer("onModuleLoad", "package:dart2ts/annotations.dart").annotation());

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

    // If it's a lib
    if (!await buildStep.resolver.isLibrary(buildStep.inputId)) {
      return;
    }

    // Collect every component
    LibraryElement libraryElement = await buildStep.resolver.libraryFor(buildStep.inputId);

    allDeps(libraryElement, new Set()).forEach((lib) {
      // find all classes annotated with polymer register

      lib.units.forEach((cu) {
        cu.types.forEach((ce) {
          if (getAnnotation(ce.metadata, isPolymerRegister2) != null) {
            blockBuilder.addExpression(code_builder
                .refer("register", "package:polymer2/polymer2.dart")
                .call([code_builder.refer(ce.name, toPackageUri(ce.library.source.uri))]));
          }
        });
      });
    });

    methodBuilder.body = blockBuilder.build();
    fileBuilder.body.add(methodBuilder.build());

    code_builder.File library = fileBuilder.build();

    final emitter = new code_builder.DartEmitter(new code_builder.Allocator.simplePrefixing());
    await buildStep.writeAsString(
        buildStep.inputId.changeExtension('.init.dart'), new DartFormatter().format('${library.accept(emitter)}'));
  }

  @override
  Iterable<String> get outputs => const ['lib/init.dart'];

  // TODO: implement buildExtensions
  @override
  Map<String, List<String>> get buildExtensions => const {
        '.dart': const ['.init.dart']
      };
}

String toPackageUri(Uri assetUri) {
  AssetId id = new AssetId.resolve(assetUri.toString());
  return "package:${id.package}/${id.path.split('/').sublist(1).join('/')}";
}
