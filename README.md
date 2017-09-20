# Dart2Ts : a better TS interface

Dart2Ts is an higly experimental dart to typescript compiler.

## Why ?

Because I'm tired of the current limits of `dartdevc`. Also translating dart to TS allows 
us to leverage the `tsc` to produce code that works on every browser and optimizing, ecc.

## Targets

 - Produce "natural" and readable TS code, just like how you would have written that same code in TS.
 - Make it simple to use that code from TS and vice versa, like:
   - Allow extending a dart2ts class from ts and vice versa.
 
 
 
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
 
## Roadmap

 - using other libraries
 - dart "typelibs" (libs with only declaration and all method declared external)
 - make class definition work
 - complete expression
 - factory constructors
 - deal with more complicated constructs like cascade operator, etc.
 - async
 - manage scope reference to "this." things
 - type name scope
 - mixin (with polymer approach)
 - interfaces
 - deal with "rewriting" some method calls, like : 
   - List -> Array
   - Map<String,?> -> {}
 - deal with "@JS" things
 
 ## Notes
 
 `Dart2TS` generated classes do not requires a top common class so it will be easy
 to implement native js classes extensions. DDC infact requires a `new` initializers
 on super classes otherwise it will complain in some circumstances (that's why
 we had to patch id in polymerize).