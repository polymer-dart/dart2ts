// export * from "./lib/async";

import * as core from './core.js';
import {Duration} from "./lib/core.js";
import {extendPrototype} from "./utils.js";


declare global {
    interface PromiseConstructor {
        delayed<T>(d: Duration): Promise<T>;

        wait(promises: Array<Promise<any>>): Promise<Array<any>>;
    }
}


export interface DartStream<T> extends AsyncIterable<T> {
    $map<U>(mapper: (t: T) => U): DartStream<U>;
}

export function toStream<X>(source: AsyncIterable<X>): DartStream<X> {

    return new (class implements DartStream<X> {

        [Symbol.asyncIterator](): AsyncIterator<X> {
            return source[Symbol.asyncIterator]();
        }

        $map<U>(mapper: (t: X) => U): DartStream<U> {
            let it: AsyncIterable<X> = this;
            return toStream({
                [Symbol.asyncIterator]: async function* () {
                    for await (let x of it) {
                        yield mapper(x);
                    }
                }
            });
        }
    });
}

export function stream<X>(generator: () => AsyncIterator<X>): DartStream<X> {
    return toStream({
        [Symbol.asyncIterator]: generator
    });
}

class DartFuture<T> extends Promise<T> {
    get stream$(): DartStream<T> {
        let p = this;
        return toStream({
            [Symbol.asyncIterator]: async function* () {
                let res: T = await p;
                yield res;
            }
        });
    }
}


let inited: boolean = false;


export function initAsync() {
    if (inited) {
        return;
    }


    extendPrototype(Promise, DartFuture);

    Object.defineProperty(Promise, 'delayed', {
        "get": function () {
            return function (d: Duration): Promise<any> {
                return new Promise<any>((resolve, reject) => {
                    setTimeout(() => {
                        resolve();
                    }, d.inMilliseconds);
                });
            }
        }
    });

    Object.defineProperty(Promise, 'wait', {
        "get": function () {
            return async function (promises: Array<Promise<any>>): Promise<Array<any>> {
                return await Promise.all(promises);
            }
        }
    });

}


/**
 * A simple completer implementation based on
 * ES6 Promise
 */
export class Completer<X> {
    private _future: Promise<X>;
    private _resolve: (x: X) => void;
    private _reject: (error: any) => void;

    isCompleted: boolean = false;

    static $create<X>(): Completer<X> {
        return new Completer();
    }

    get future(): Promise<X> {
        return this._future;
    }

    complete(x?: X): void {
        this.isCompleted = true;
        this._resolve(x);
    }

    completeError(error: any): void {
        this._reject(error);
    }

    constructor() {
        this._future = new Promise<X>((resolve, reject) => {
            this._resolve = resolve;
            this._reject = reject;
        });
    }
}


/**
 * An iterator
 */
export class StreamController<X> {
    private _stream: _Stream<X>;

    get stream(): DartStream<X> {
        return this._stream;
    }

    constructor() {
        this._stream = new _Stream<X>();
    }

    // Factory constructor
    static broadcast<Y>(arg?: { onListen?: () => any, onCancel?: () => any, sync?: boolean }): StreamController<Y> {
        return new StreamController<Y>();
    }

    add(x: X): void {
        this._stream.add(x);
    }

}

export interface StreamSink<X> {

}

export interface StreamSubscription<X> {
    cancel(): void;
}


class _Stream<X> implements DartStream<X> {
    $map<U>(mapper: (t: X) => U): DartStream<U> {
        return undefined;
    }

    private _closed: boolean = false;

    /**
     *  Implementing the iterable protocols allows
     * to easily implement "await for" constructs.
     */
    get [Symbol.asyncIterator]() {
        return async function* () {
            while (!this._closed) {
                let next: Promise<X> = new Promise((resolve, reject) => {
                    let sub = this.listen((x) => {
                        sub.cancel();
                        resolve(x);
                    });
                });

                yield next;
            }
        }
    }


    private _listeners: Array<(X) => any> = [];

    add(x: X): void {
        this._listeners.forEach((l) => {
            try {
                l(x);
            } catch (e) {
                console.error(e);
            }
        });
    }

    listen(handler: (X) => any): StreamSubscription<X> {
        this._listeners.push(handler);
        return <StreamSubscription<X>>{
            cancel: () => this._listeners.splice(this._listeners.indexOf(handler), 1)
        };
    }
}
