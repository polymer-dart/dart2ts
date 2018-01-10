export class SampleClass {

    get doc() {
        return module.document;
    }
}


export class OtherClass extends SampleClass {

}

export class Module {
    get document() {
        return "ciao";
    }

}


export var module = new Module();