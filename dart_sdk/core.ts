export function print(message: String): void {
    console.log(message);
}

export class List<T> extends Array<T> {
    dartMap<Y>(f: (x: T) => Y): Array<Y> {
        return this.map((x: T) => f(x));
    }
}


export class Expando<T> {
    sym: symbol;

    constructor() {
        this.sym = Symbol();
    }
}

export namespace ExpandoHelpers {
    export namespace index {
        export function get<T>(t: Expando<T>, index) {
            return index[t.sym];
        }

        export function set<T>(t: Expando<T>, index, value) {
            index[t.sym] = value;
        }
    }

}