import 'package:analyzer/dart/element/type.dart';
import 'dart:io';
import 'package:analyzer/analyzer.dart';
import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';

bool isListType(DartType type) =>
    isTypeInstanceOf(type?.element?.context?.typeProvider?.listType, type);

bool isIterableType(DartType type) =>
    isTypeInstanceOf(type?.element?.context?.typeProvider?.iterableType, type);

bool isTypeInstanceOf(ParameterizedType base, DartType type) =>
    type != null &&
    (type is ParameterizedType) &&
    type.typeArguments.length == 1 &&
    type.isSubtypeOf(base.instantiate([type.typeArguments.single]));

final Uri _DART2TS_URI = Uri.parse('package:dart2ts/annotations.dart');
final Uri _DART2TS_ASSET_URI = Uri.parse('asset:dart2ts/lib/annotations.dart');

final Uri _POLYMER_REGISTER_URI =
    Uri.parse('package:polymer_element/annotations.dart');
final Uri _POLYMER_REGISTER_ASSET_URI =
    Uri.parse('asset:polymer_element/lib/annotations.dart');
final Uri _JS_URI = Uri.parse('package:js/js.dart');
final Uri _JS_ASSET_URI = Uri.parse('asset:js/lib/js.dart');

final Uri _POLYMER_INIT_URI = Uri.parse('package:polymerize_common/init.dart');
final Uri _POLYMER_INIT_ASSET_URI =
    Uri.parse('asset:polymerize_common/lib/init.dart');

final Uri _POLYMER_MAP_URI = Uri.parse('package:polymerize_common/map.dart');
final Uri _POLYMER_MAP_ASSET_URI =
    Uri.parse('asset:polymerize_common/lib/map.dart');

final Uri _POLYMER_HTML_IMPORT_URI =
    Uri.parse('package:polymerize_common/html_import.dart');
final Uri _POLYMER_HTML_IMPORT_ASSET_URI =
    Uri.parse('asset:polymerize_common/lib/html_import.dart');

bool isDart2TsUri(Uri u) => u == _DART2TS_URI || u == _DART2TS_ASSET_URI;

bool isJsUri(Uri u) => u == _JS_ASSET_URI || u == _JS_URI;

bool isPolymerElementUri(Uri u) =>
    u == _POLYMER_REGISTER_ASSET_URI || u == _POLYMER_REGISTER_URI;

bool isPolymerMapUri(Uri u) =>
    u == _POLYMER_MAP_URI || u == _POLYMER_MAP_ASSET_URI;

bool isPolymerElementInitUri(Uri u) =>
    u == _POLYMER_INIT_URI || u == _POLYMER_INIT_ASSET_URI;

bool isPolymerElementHtmlImportUri(Uri u) =>
    u == _POLYMER_HTML_IMPORT_URI || u == _POLYMER_HTML_IMPORT_ASSET_URI;

bool isJS(DartObject o) =>
    (isJsUri(o.type.element.librarySource.uri)) && (o.type.name == 'JS');

bool isModule(DartObject o) =>
    (isDart2TsUri(o.type.element.librarySource.uri)) && (o.type.name == 'Module');


bool isBowerImport(DartObject o) =>
    o != null &&
    (isPolymerElementUri(o.type.element.librarySource.uri)) &&
    (o.type.name == 'BowerImport');

bool isJsMap(DartObject o) =>
    o != null &&
    (isPolymerMapUri(o.type.element.librarySource.uri)) &&
    (o.type.name == 'JsMap');

bool isDefine(DartObject o) =>
    (isPolymerElementUri(o.type.element.librarySource.uri)) &&
    (o.type.name == 'Define');

bool isObserve(DartObject o) =>
    (isPolymerElementUri(o.type.element.librarySource.uri)) &&
    (o.type.name == 'Observe');

bool isReduxActionFactory(DartObject o) =>
    (isPolymerElementUri(o.type.element.librarySource.uri)) &&
    (o.type.name == 'ReduxActionFactory');

bool isProperty(DartObject o) =>
    (isPolymerElementUri(o.type.element.librarySource.uri)) &&
    (o.type.name == 'Property');

bool isNotify(DartObject o) =>
    (isPolymerElementUri(o.type.element.librarySource.uri)) &&
    (o.type.name == 'Notify');

bool isPolymerRegister(DartObject o) =>
    o != null &&
    (isPolymerElementUri(o.type.element.librarySource.uri)) &&
    (o.type.name == 'PolymerRegister');

bool isPolymerBehavior(DartObject o) =>
    (isPolymerElementUri(o.type.element.librarySource.uri)) &&
    (o.type.name == 'PolymerBehavior');

bool isStoreDef(DartObject o) =>
    (isPolymerElementUri(o.type.element.librarySource.uri)) &&
    (o.type.name == 'StoreDef');

bool isInit(DartObject o) =>
    o != null &&
    (isPolymerElementInitUri(o.type.element.librarySource.uri)) &&
    (o.type.name == 'Init');

bool isEntryPoint(DartObject o) =>
    o != null &&
    (isPolymerElementInitUri(o.type.element.librarySource.uri)) &&
    (o.type.name == 'EntryPoint');

bool isInitModule(DartObject o) =>
    o != null &&
    (isPolymerElementInitUri(o.type.element.librarySource.uri)) &&
    (o.type.name == 'InitModule');

bool isHtmlImport(DartObject o) =>
    o != null &&
    (isPolymerElementHtmlImportUri(o.type.element.librarySource.uri)) &&
    (o.type.name == 'HtmlImport');

Iterable<DartObject> allFirstLevelAnnotation(
        Iterable<CompilationUnit> cus, bool matches(DartObject x)) =>
    flatten(cus.map((cu) => cu.sortedDirectivesAndDeclarations))
        .map(_element)
        .where(notNull)
        .map((e) => e.metadata)
        .where(notNull)
        .map((anno) => getAnnotation(anno, matches))
        .where(notNull);

typedef bool Matcher(DartObject x);

X _whichMatcher<X>(DartObject annotation, Map<X, Matcher> matchers, X orElse) =>
    matchers.keys
        .firstWhere((k) => matchers[k](annotation), orElse: () => orElse);

Map<X, Iterable<Y>> _collect<X, Y, Z>(Iterable<Z> i,
    {X key(Z z), Y value(Z z)}) {
  Map<X, List<Y>> res = {};
  i.forEach((z) {
    X x = key(z);
    Y y = value(z);
    if (x != null) {
      List<Y> yy = res.putIfAbsent(x, () => []);
      yy.add(y);
    }
  });
  return res;
}

Iterable<X> flatten<X>(Iterable<Iterable<X>> x) => flattenWith(x, (x) => x);

Iterable<X> flattenWith<X, Y>(
    Iterable<Y> x, Iterable<X> Function(Y) extract) sync* {
  for (Y i in x) {
    yield* extract(i);
  }
}

class AnnotationInfo {
  Element element;
  DartObject annotation;

  AnnotationInfo({this.element, this.annotation});
}

Map<X, List<AnnotationInfo>> firstLevelAnnotationMap<X>(
        Iterable<CompilationUnit> cus, Map<X, Matcher> matchers, X orElse) =>
    _collect(
        flatten<AnnotationInfo>(flatten<AstNode>(
                cus.map((cu) => cu.sortedDirectivesAndDeclarations))
            .map(_element)
            .where((e) => e?.metadata != null)
            .map((e) => e.metadata
                .map((a) => a.computeConstantValue())
                .where(notNull)
                .map((o) => new AnnotationInfo(element: e, annotation: o)))),
        key: (AnnotationInfo o) =>
            _whichMatcher(o.annotation, matchers, orElse),
        value: (AnnotationInfo o) => o);

Element _element(AstNode x) =>
    (x is Declaration) ? x.element : ((x is Directive) ? x.element : null);

bool hasAnyFirstLevelAnnotation(
        Iterable<CompilationUnit> cus, bool matches(DartObject x)) =>
    allFirstLevelAnnotation(cus, matches).isNotEmpty;

DartObject getAnnotation(
        Iterable<ElementAnnotation> metadata, //
        bool matches(DartObject x)) =>
    metadata
        .map((an) => an.computeConstantValue())
        .where(notNull)
        .firstWhere(matches, orElse: () => null);

ElementAnnotation getElementAnnotation(
        Iterable<ElementAnnotation> metadata, //
        bool matches(DartObject x)) =>
    metadata.firstWhere((an) => matches(an.computeConstantValue()),
        orElse: () => null);

Directory findDartSDKHome() {
  if (Platform.environment['DART_HOME'] != null) {
    return new Directory(Platform.environment['DART_HOME']);
  }

  //print("res:${Platform.resolvedExecutable} exe:${Platform.executable} root:${Platform.packageRoot} cfg:${Platform.packageConfig} ");
  // Else tries with current executable
  return new File(Platform.resolvedExecutable).parent;
}

typedef bool matcher(DartObject x);

matcher anyOf(List<matcher> matches) =>
    (DartObject o) => matches.any((m) => m(o));

bool notNull(x) => x != null;

bool needsProcessing(LibraryElement le) => hasAnyFirstLevelAnnotation(
    le.units.map((u) => u.unit),
    anyOf([
      isJsMap,
      isBowerImport,
      isPolymerRegister,
      isInit,
      isInitModule,
      isHtmlImport,
      isPolymerBehavior,
      isEntryPoint
    ]));

PropertyInducingElement findField(Element clazz, String name) {
  if (clazz == null) {
    return null;
  }

  if (clazz is ClassElement) {
    return clazz.fields.firstWhere((fe) => fe.name == name,
        orElse: () => flattenWith(
                flattenWith(
                    clazz.interfaces ?? [], (InterfaceType x) => x.accessors),
                (PropertyAccessorElement ac) =>
                    [ac.variable]).firstWhere(
                (PropertyInducingElement ac) => ac.name == name, orElse: () {
              if (clazz.supertype != clazz) {
                return findField(clazz.supertype?.element, name);
              }
              return null;
            }));
  } else {
    return null;
  }
}

bool isAnonymousConstructor(ConstructorElement c) =>
    (c.name ?? "").isEmpty && !c.isFactory;
