# Dart2Ts : a better TS interface

Dart2Ts is an higly experimental dart to typescript compiler.

## Why ?

Because I'm tired of the current limits of `dartdevc`. Also translating dart to TS allows 
us to leverage the `tsc` to produce code that works on every browser and optimizing, ecc.

## What works

Only translating `e2e_test` project, that means:
 - basic function definition
 - invocation
 - import of other modules (only core and current package for now)
 - string interpolation
 - named constructors
 - class extension
 - calling named constructors
 - basic class definition
  
 - basic instance creation
 
## Roadmap

 - TODO
     - named parameters
     - optional parameters
 - make class definition work
 - complete expression
 - named constructors, factory constructors
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