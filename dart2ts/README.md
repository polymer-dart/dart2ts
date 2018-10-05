# TLDR

*Dart2TS* is a dart1.x to typescript compiler.

# Usage

Install the tool : 

    pub global activate dart2ts

Launch it:

    dart2ts build <path_to_your_dart_package>

# Package Requirements

The package to translate should be in strong mode with all the dependencies resolved. 

The stronger it is the better dart2ts can understand it and translate it.

# Details

*Dart2TS* is a new approach of developing with Dart. You can write actual dart code and have it translated
to effective typescript code. From there you can continue writing in dart or switch to typescript.

The main advantages of using dart2ts instead of the traditional `dart2js` or `dartdevc` compilers is a
better integration with the javascript / typescript / nodejs ecosystem.

You can end up writing nodejs packages or webpack application using dart.

# What is working

Pretty much every constructs from dart1.x:

 - named constructors
 - factory constructors
 - async await
 - generators
 - named parameters

# Help

If you want to help you're welcome. These are some of the things that needs some helps:

 - improve code coverage
 - test
 - improve incremental building
 - port to dart2.0

# Dart core libraries

Dart core libraries (`dart:core`, `dart:async`) are been ported to typescript and are
available [here](https://npm.dart-polymer.com/#/detail/@dart2ts/dart).

In order to access dart2ts node packages you'll have add the following registers to your configuration:

    npm config set @dart2ts.packages:registry=https://npm.dart-polymer.com
    npm config set @dart2ts:registry=https://npm.dart-polymer.com


