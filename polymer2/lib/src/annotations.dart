class PolymerRegister {
  final String tagName;
  final String template;
  final bool native;
  final List<Type> uses;

  const PolymerRegister(this.tagName, {this.template, this.native: false, this.uses});
}

class BowerImport {
  final String ref;
  final String path;
  final String name;

  const BowerImport({this.ref, this.path, this.name});
}

/**
 * Optional property annotation in order to add metadata info.
 */
class Property {
  final bool notify;

  /// TODO: not yet implemented
  final String computed;
  final String statePath;

  /// TODO: not yet implemented
  final Function statePathSelector;

  /// TODO: not yet implemented
  final Map extra;

  const Property({this.notify: false, this.computed, this.statePath, this.extra, this.statePathSelector});
}

/***
 * Mark a class to become a polymer mixin.
 * Classes marked with this annotation becomes a js-mixin (a la polymer)
 * and can be used in `implements` clause like any other polymer mixin.
 * This functionality replaces the dart mixin feature in a way that is more
 * js interoperable.
 */
class PolymerBehavior {
  final String name;

  const PolymerBehavior(this.name);
}

class Observe {
  final String observed;

  const Observe(this.observed);
}

class Notify {
  const Notify();
}

const Notify notify = const Notify();
