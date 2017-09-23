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
 - support for `@JS` annotation
   - **DART2TS** extension
   
**note** 'e2e_test' project is now able to write on the HTML page !!!
   
### Dart2TS extensions

#### Estension to @JS annotation

'@JS' can be unsed to specify with module should be loaded. Module path and name should be separated by the `'#'` character.
The final name is defined concatanating both module path and namespace path information. For example

```dart
@JS('module#myjslib')
libary mylib;

@JS('submod#Thing')
class That {
  
}

```
Will cause any reference to `That` will be translated as a reference to `myjslib.Thing` in module `module/submod`. 

To declare only the module and not a namespace use `@JS('module#')`. For example the following will associate the `$` top level variable
to the `$` simbol exported by module `jquery`:

```dart
@JS('jquery#')
library mylib;

@JS()
Function $;

```

## Roadmap

 - using other libraries (easy)
   - declare dep on both `pubspec.yaml` and `package.json`
   - build the dep and produce typelibs and js 
   - when main project is built the already compiled is used for runtime and the dart as analysis
     - dart could be replaced by summaries or by generated "dart type lib" : a version of the original lib with only external declarations.
 - dart "typelibs" (libs with only declaration and all method declared external) (boring)
 - make class definition work (easy)
  - redir constructors
  - field initializers 
  - field parameters
  - properties initializers
  
  
 - flow control statemets (easy)
   - for
   - while
   - switch
   - do
   - break
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
 - `async`, `async*`, `sync*` (should be easy as TS supports 'em all)
   - map Future to Promise (difficulty level ?!?)
 - manage scope reference to "this." things (boring)
 - mixin (with polymer approach) (should be easy but no named constructor should be allowed)
 - `implements` (subtle , typescript implement of classes is the same of dart?)
 - deal with "rewriting" some method calls, like : (tricky) 
   - List -> Array
   - Map<String,?> -> {}
 - deal with "@JS" things (easy)
 
 - dart_sdk port
    - collections (maybe tricky, expecially to maintain semantical compatibility)
    - package:html (easy)
    - what else ? (boh)
 
 ## Notes
 
 `Dart2TS` generated classes do not requires a top common class so it will be easy
 to implement native js classes extensions. DDC infact requires a `new` initializers
 on super classes otherwise it will complain in some circumstances (that's why
 we had to patch id in polymerize).