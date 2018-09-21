/** Library asset:sample_project/lib/index.dart */
import {is,equals} from "../node_modules/typescript_dart/_common.js";
import {defaultConstructor,namedConstructor,namedFactory,defaultFactory,DartClass,Implements,op,Op,OperatorMethods,DartClassAnnotation,DartMethodAnnotation,DartPropertyAnnotation,Abstract,AbstractProperty} from "../node_modules/typescript_dart/utils.js";
import * as _common from "../node_modules/typescript_dart/_common.js";
import * as core from "../node_modules/typescript_dart/core.js";
import * as async from "../node_modules/typescript_dart/async.js";
import * as lib3 from "./sample1.js";

export var index : () => void = () : void =>  {
    lib3.main(new core.DartList.literal('ciao','ciao','bambina'));
};
export class _Properties {
}
export const properties : _Properties = new _Properties();
// On module load

index();
