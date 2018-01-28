import {Duration} from "./lib/core";
import {extendPrototype} from "./utils";


export namespace Symbols {
}

declare global {

    interface Array<T> {
        readonly $first: T;
        readonly $last: T;

        $sublist(from: number, to: number): Array<T>;

        $isEmpty: boolean;
        $isNotEmpty: boolean;

        $add(e: T): void;

        $remove(e: T): void;

        $map<X>(f: (t: T) => X): DartIterable<X>;
    }

}


export interface DartIterable<T> extends Iterable<T> {
    readonly $first: T;
    readonly $last: T;

    $join(separator: string): string;

    $map<X>(f: (t: T) => X): DartIterable<X>;
}

export interface DartList<T> extends DartIterable<T> {

}

function toDartIterable<X>(x: Iterable<X>): DartIterable<X> {
    return new (class implements DartIterable<X> {
        $map<T>(f: (t: X) => T): DartIterable<T> {
            let self = this;

            return toDartIterable<T>(function* () {
                for (let t of self) {
                    yield f(t);
                }
            }());
        }

        $join(separator: string): string {
            return Array.from(this).join(separator);
        }

        get $first(): X {
            let first: X;
            for (let x of this) {
                first = x;
                break;
            }
            return first;
        }

        get $last(): X {
            let last: X;
            for (let x of this) {
                last = x;
            }
            return last;
        }

        [Symbol.iterator](): Iterator<X> {
            return x[Symbol.iterator]();
        }
    }) as DartIterable<X>;
}


let inited: boolean = false;


export function initCollections() {
    if (inited) {
        return;
    }

    extendPrototype(Array, class<T> extends Array<T> implements DartList<T> {
        $join(separator: string): string {
            return this.join(separator);
        }

        get $first(): T {
            return this[0];
        }

        get $last(): T {
            return this[this.length - 1];
        }

        $sublist(from: number, to: number): Array<T> {
            return this.slice(from, to);
        }

        $add(e: T): void {
            this.push(e);
        }

        $remove(e: T): void {
            this.splice(this.indexOf(e), 1);
        }

        $map<X>(f: (t: T) => X): DartIterable<X> {
            let self = this;
            return toDartIterable<X>(function* () {
                for (let t of self) {
                    yield f(t);
                }
            }());
        }
    });

}