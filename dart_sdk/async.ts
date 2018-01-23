// export * from "./lib/async";

import * as core from './core';
import {Duration} from "./lib/core";
import {extendPrototype} from "./utils";


declare global {


    interface PromiseConstructor {
        delayed<T>(d: Duration): Promise<T>;
    }
}


interface DartStream<T> extends AsyncIterable<T> {
    $map<U>(mapper: (t: T) => U): DartStream<U>;
}

function toStream<X>(source: AsyncIterable<X>): DartStream<X> {

    return new (class implements DartStream<X> {

        [Symbol.asyncIterator](): AsyncIterator<X> {
            return source[Symbol.asyncIterator]();
        }

        $map<U>(mapper: (t: X) => U): DartStream<U> {
            let it: AsyncIterable<X> = this;
            return toStream((async function* () {
                for await (let x of it) {
                    yield mapper(x);
                }
            })());
        }
    });
}

interface DartFuture<T> extends Promise<T> {
    readonly stream$: DartStream<T>;
}


let inited: boolean = false;


export function initCollections() {
    if (inited) {
        return;
    }


    extendPrototype(Promise, class<X> extends Promise<X> implements DartFuture<X> {
        get stream$(): DartStream<X> {
            let p = this;
            return toStream((async function* () {
                let res: X = await p;
                yield res;
            })());
        }
    });

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

}


export abstract class Future<X> extends Promise<X> {

    static wait(x: Array<Future<any>>): Future<Array<any>> {
        let c: Completer<Array<any>> = new Completer();
        Promise.all(x).then((r) => c.complete(r));
        return c.future;
    }

    static delayed(d: core.Duration): Future<any> {
        return new _Future((resolve, reject) => {
            setTimeout(() => resolve(null), d.inMilliseconds);
        });
    }
}

/**
 * A simple completer implementation based on
 * ES6 Promise
 */
export class Completer<X> {
    private _future: Future<X>;
    private _resolve: (x: X) => void;
    private _reject: (error: any) => void;

    isCompleted: boolean = false;

    get future(): Future<X> {
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
        this._future = new _Future<X>((resolve, reject) => {
            this._resolve = resolve;
            this._reject = reject;
        });
    }
}

/**
 * A Future implementation that extends Promise.
 */
class _Future<X> extends Promise<X> implements Future<X> {
    constructor(executor: (resolve: (x: X) => void
        , reject: (error: any) => void) => void) {
        super(executor);
    }

}

export abstract class Stream<X> {

}

/**
 * An iterator
 */
export class StreamController<X> {
    private _stream: _Stream<X>;

    get stream(): Stream<X> {
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


class _Stream<X> implements Stream<X> {

    private _closed: boolean = false;

    /**
     *  Implementing the iterable protocols allows
     * to easily implement "await for" constructs.
     */
    get [Symbol.iterator]() {
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
