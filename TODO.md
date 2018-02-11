-  ~~handle function expression inside method correclty~~
     -  ~~now there's a problem with this, should use JS closures~~
-  ~~test async stream~~
-  complete collections
-  object literals
-  mixin
-  abstract class
-  ~~Promise<T> ? Why ? (see sample4.dart)~~
-  ~~toString~~
-  extending an overridden ( => replaced by `overrides.yml`) method : example extending `map` method of a list should actually extend `$map`
-  operator inheritance
-  consistently handle hashCode and equals : this is hard .. 
-  ~~repeatable iterables~~
-  named and factory constructor for dynamic : call something similar to `invokeMethod`
-  ~~force async and async* return type~~
-  ~~implement `sync*` and `async*` wrapping to `DartIterator` and `DartStream`.~~
-  decoration for `.ts`  native => add metadata to dartiterable and stream in
   order to be used correctly with `invokeMethod` and `readProperty`, ecc.
-  generate type descriptor when required
     - ~~refactory with normale class~~
     - ~~generate descriptor for get set~~
     - generate descr for constructor
-  ~~fix get set top level generation (and check normal too)~~   
-  add support for external typelib import
-  add extra annotation in `overrides.yml`: annotation can be added to external dart
   code using the `overrides.yml` file 
-  using `overrides.yml` read from base dir
    - an "overrides.yml" files in the top level will be merged with the default
      this can be used to add annotation to external types. For example this can be
      used to add "@TS(generate:true)" to all the `polymer_element` wrappers.   
-  ~~use destructuring for named args~~ (this cannot be done because of optional not allowed for destructured arg)
-  method as generators
-  ~~support for string interpolation~~
-  ~~support for far args mapping (@varargs)~~
     - ~~in external calls just use "..." operator when calling :~~ 
         -  `pippo([a,b,c])` => `pippo(...[a,b,c])`
     