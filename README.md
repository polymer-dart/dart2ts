# Dart2Ts : a better TS interface

``HIC SUNT DRACONES``

**Dart2Ts** is an highly experimental dart to typescript compiler.

## Why ?

Because I'm tired of the current limits of `dartdevc`. Also translating dart to TS allows 
us to leverage the `tsc` to produce code that works on every browser and optimizing, ecc.

## Targets

 - obviously : semantic equivalence 
 - Produce "natural" and readable TS code, just like how you would have written that same code in TS.
 - Make it simple to use that code from TS and vice versa, like:
   - Allow extending a dart2ts class from ts and vice versa.
 
### Anti-targets
 
  - main target is to make it work on web, so:
    - initially don't want to port any "platform specific" library, try to use only `@JS`
    - I don't care about `Isolate` and stuff like that
 
## What works

At the moment only translating `e2e_test` project, that means:
 - basic function definition
 - invocation
 - import of other modules (only core and current package for now)
 - string interpolation
 - named constructors
 - class extension
 - calling named constructors
 - basic class definition 
 - basic instance creation
 - named parameters
 - optional parameters
 - cascading
 - `(cond)?true:false` conditional expressions
 - this implicit reference for method invocation
 - calling `.first` psuedo accessor on a `List` (it's replaced by an extension method)
 - property
 - property accessor
 - top level variable
 - redir constructors
 - field initializers 
 - field parameters
 - properties initializers
  
 - support for `@JS` annotation
   - **DART2TS** extension
   
**note** 'e2e_test' project is now able to write on the HTML page !!!

**UPDATE** : now even `package:html5` is compiling. Next step is to create a demo project using `package:html5` and demo it.
   
### Dart2TS extensions

#### Estension to @JS annotation

`@JS` can now be used to specify from which module the symbol should be loaded. Module path and name should be separated by the `'#'` character.
Alternatively one can use the `@Module('modulepath')` to specify the module path and the `@JS('name')` annotation for the namespace only.
When both (`'#'` char and `@Module` annotation) are used the latter wins.
The final name is defined concatanating both module path and namespace path information from each enclosing element. For example

```dart
@JS('module#myjslib')
libary mylib;

@JS('submod#Thing')
class That {
  
}

```

or

```dart
@JS('myjslib')
@Module('module')
libary mylib;

@JS('Thing')
@Module('submod')
class That {
  
}

```

Will cause any reference to `That` to be translated as a reference to `myjslib.Thing` in module `module/submod`. 

To declare only the module and not a namespace use `@JS('module#')`. For example the following will associate the `$` top level variable
to the `$` symbol exported by module `jquery`:

```dart
@JS('jquery#')
library mylib;

@JS()
Function $;

```

or 

```dart
@JS()
@Module('jquery')
library mylib;

@JS()
Function $;

```

`@JS` annotation can also be used to change the name of the corresponding native method or properties, thus allowing to resolve any name conflict between dart and TS
(Notably the `is` static method inside a class used by polymer).

## Roadmap

 - ~~using other libraries (easy)~~
   - declare dep on both `pubspec.yaml` and `package.json`
   - build the dep and produce typelibs and js 
   - when main project is built the already compiled is used for runtime and the dart as analysis
     - dart could be replaced by summaries or by generated "dart type lib" : a version of the original lib with only external declarations.
 - dart "typelibs" (libs with only declaration and all method declared external) (boring)
 - make class definition work (easy)
  
  
 - flow control statemets (easy)
   - for in
   - ~~for (x;y;z)~~
   - ~~yield~~
   - ~~return~~
   - while
   - ~~do~~
   - ecc.
 - exports (medium ? easy ?)
 - nullable expression (`??` operator `?=` operator) (super easy)
 - literals
   - array
   - map
 - symbol (map to symbol)
 - complete expression (boring)
    - whats missing ?
 - factory constructors (super easy)
 - `async`, `async*` (should be easy as TS supports 'em all)
   - ~~map Future to Promise (difficulty level ?!?)~~
 - ~~manage scope reference to "this." things (boring)~~
 - mixin (with polymer approach) (should be easy but no named constructor should be allowed)
 - `implements` (subtle , typescript implement of classes is the same of dart?)
 - ~~deal with "rewriting" some method calls, like : (tricky)~~ 
   - List -> Array
   - Map<String,?> -> {}
 - ~~deal with "@JS" things (easy)~~
 
 - (*light*) dart_sdk port
    - collections (maybe tricky, expecially to maintain semantical compatibility)
    - package:html (easy)
    - what else ? (boh)
 
 ## Notes
 
 `Dart2TS` generated classes do not requires a top common class so it will be easy
 to implement native js classes extensions. DDC infact requires a `new` initializers
 on super classes otherwise it will complain in some circumstances (that's why
 we had to patch id in polymerize).
 
 ## Caveat
 
 When executed a second time it can throw. Probably a bug in `builder` package. 
 A workaround is to remove the `.dart_tool` hidden folder inside the package folder you are building (it will
 be recreated in the next build).
 
 When launching `dart2ts` with the watch flag (`-w`) there's no problem.