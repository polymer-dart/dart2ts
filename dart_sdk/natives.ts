import {extend} from "./utils.js";

declare global {

    interface Number extends Comparable<Number> {
        round(): number;

        remainder(n: number): number;

        readonly $hashCode: number;

        abs(): number;
    }

    interface Object {
        readonly $hashCode: number;
    }

    interface String {
        readonly $hashCode: number;

    }

}

export interface Comparable<T> {
    compareTo(t: T): number;
}

abstract class ObjectExtension extends Object {
    get $hashCode(): number {
        return this.toString().$hashCode;
    }
}

abstract class StringExtension extends String {
    get $hashCode(): number {
        let h = 0, l = this.valueOf().length, i = 0;
        if (l > 0)
            while (i < l)
                h = (h << 5) - h + this.valueOf().charCodeAt(i++) | 0;
        return h;
    }
}

export function sequenceHashCode(things: Iterable<any>) {
    let res: number = 1;
    for (let v of things) {
        res = (res * 31 + v.$hashCode) & 0xffffffff;
    }
    return res;
}

abstract class NumberExtension implements Number {
    abstract toString(radix?: number): string ;

    abstract toFixed(fractionDigits?: number): string;

    abstract toExponential(fractionDigits?: number): string;

    abstract toPrecision(precision?: number): string;

    abstract valueOf(): number ;

    abstract toLocaleString(locales?: string | string[], options?: Intl.NumberFormatOptions): string ;

    compareTo(t: Number): number {
        return Math.sign(t.valueOf() - (<any>this as Number).valueOf());
    }

    round(): number {
        return Math.round(this.valueOf());
    }


    remainder(n: number): number {
        return this.valueOf() % n;
    }


    abs(): number {
        return Math.abs(this.valueOf());
    }

}

export function initNatives() {
    extend(Number, NumberExtension);
    extend(String, StringExtension);
    extend(Object, ObjectExtension);
}