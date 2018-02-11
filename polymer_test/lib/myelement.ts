/** Library asset:polymer_test/lib/myelement.dart */
import * as bare from "dart_sdk/bare";
import * as lib1 from "./polymer";
import * as lib2 from "./html_template";
import * as core from "dart_sdk/core";

@bare.DartMetadata({library:'asset:polymer_test/lib/myelement.dart'})
export class MyElement extends lib1.Element {
    name : string;
    static get template() {
        return lib2.html`<div>\n This is my [[name]] app.\n</div>\n`;
    }

    constructor(...args)
    constructor() {
        super();
        arguments[0] != bare.init && this[bare.init]();
    }
    [bare.init]() {
        this.name = "Pino" + " Daniele " + "Lives!";
    }
}

export var main : () => void = () : void =>  {
    customElements.define('my-tag',MyElement);
    core.print("hello");
};
export class Module {
}
export var module : Module = new Module();
