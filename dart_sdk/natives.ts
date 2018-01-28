import {extendPrototype} from "./utils";

declare global {

    interface Number extends Comparable<Number> {
        round(): number;

        remainder(n: number): number;

        readonly hashCode: number;

        abs(): number;
    }
}

export interface Comparable<T> {
    compareTo(t: T): number;
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

    get hashCode(): number {
        return this.valueOf();
    }

    abs(): number {
        return Math.abs(this.valueOf());
    }

}

export function initNatives() {
    extendPrototype(Number, NumberExtension);
}