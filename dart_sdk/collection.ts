function extendPrototype(type, other) {
    let object = other.prototype;
    Object.getOwnPropertyNames(object).forEach(function (n: string) {
        if (n === 'constructor') {
            return;
        }
        let des: PropertyDescriptor = Object.getOwnPropertyDescriptor(object, n);
        Object.defineProperty(type.prototype, n, des);
    });
    Object.getOwnPropertySymbols(object).forEach(function (n: symbol) {
        let des: PropertyDescriptor = Object.getOwnPropertyDescriptor(object, n);
        Object.defineProperty(type.prototype, n, des);
    });
}


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

extendPrototype(Array, class<T> extends Array<T> implements DartIterable<T> {
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
        return toDartIterable(function* () {
            for (let t of this) {
                yield f(t);
            }
        }());
    }
});

export interface DartIterable<T> extends Iterable<T> {
    readonly $first: T;
    readonly $last: T;
    $join(separator:string):string;
}

function toDartIterable<X>(x: Iterable<X>) {
    return new class implements DartIterable<X> {
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
    }
}