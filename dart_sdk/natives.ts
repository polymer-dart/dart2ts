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

export function initNatives() {
    extendPrototype(Number, class {

        compareTo(t: Number): Number {
            return Math.sign(t.valueOf() - (<any>this as Number).valueOf());
        }

        round(): number {
            return Math.round((<any>this as Number).valueOf());
        }


        remainder(n: number): number {
            return (<any>this as Number).valueOf() % n;
        }

        get hashCode(): number {
            return (<any>this as Number).valueOf();
        }

        abs(): number {
            return Math.abs((<any>this as Number).valueOf());
        }

    })
}