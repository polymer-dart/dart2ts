export {Duration, Duration__microseconds} from './lib/core.js';
export {Exception, FormatException, _Exception, IntegerDivisionByZeroException} from './lib/exceptions.js';


export class Expando<X> {
    private _sym: symbol;

    constructor(name?: string) {
        this._sym = Symbol(name);
    }

    $get(obj: any): X {
        return obj[this._sym];
    }

    $set(obj: any, val: X) {
        obj[this._sym] = val;
    }
}


export function print(message: String): void {
    console.log(message);
}