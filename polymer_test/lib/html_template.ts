/** Library asset:polymer_test/lib/html_template.dart */
import * as bare from "dart_sdk/bare";
import * as lib1 from "./polymer";
import * as lib2 from "./mini_html";

export var html = (lits,...vals) => {
    var html : (template : string,_namedArguments? : {literals? : Array<string>,values? : Array<any>}) => HTMLTemplateElement = (template : string,_namedArguments? : {literals? : Array<string>,values? : Array<any>}) : HTMLTemplateElement =>  {
        _namedArguments = _namedArguments || {};
        let literals : Array<string> = _namedArguments.literals;
        let values : Array<any> = _namedArguments.values;
        return lib1.html(literals,...values);
    };
    return html(null,{literals:lits,values:vals});
};
export class Module {
}
export var module : Module = new Module();
