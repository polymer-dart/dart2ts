/** Library asset:sample_project/lib/index.dart */
import {is,isNot,equals} from "@dart2ts/dart/_common";
import {defaultConstructor,namedConstructor,namedFactory,defaultFactory,DartClass,Implements,op,Op,OperatorMethods,DartClassAnnotation,DartMethodAnnotation,DartPropertyAnnotation,Abstract,AbstractProperty} from "@dart2ts/dart/utils";
import * as _common from "@dart2ts/dart/_common";
import * as core from "@dart2ts/dart/core";
import * as async from "@dart2ts/dart/async";
import * as lib3 from "./sample1";

export var index : () => void = () : void =>  {
    lib3.main(new core.DartList.literal('ciao','ciao','bambina'));
};
export class _Properties {
}
export const properties : _Properties = new _Properties();
// On module load

index();
