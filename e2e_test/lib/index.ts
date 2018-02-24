/** Library asset:sample_project/lib/index.dart */
import * as bare from "../node_modules/dart_sdk/bare.js";
import * as lib1 from "./sample1.js";

export var index : () => void = () : void =>  {
    lib1.main(['ciao','ciao','bambina']);
};
export class Module {
}
export var module : Module = new Module();
// On module load

index();
