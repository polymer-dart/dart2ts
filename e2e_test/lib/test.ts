export class SampleClass {

    get doc() {
        return _library.document;
    }
}


export class OtherClass extends SampleClass {

}

export class Library {
    SampleClass= SampleClass;
    OtherClass= OtherClass;

    get document() {
        return "ciao";
    }

}

var _library:Library = new Library();


export default _library;