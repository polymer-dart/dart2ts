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

export class ArgumentError extends Error {
    constructor(msg?: string) {
        super(msg);
    }
}

export abstract class Pattern {

}

export class RegExpPattern extends RegExp implements Pattern {
    constructor(expression: string) {
        super(expression);
    }

    static new(expression: string) {
        return new RegExpPattern(expression);
    }
}

export class Exception {

}

export class Uri {
    url: URL;

    constructor(url: URL) {
        this.url = url;
    }

    static parse(str: string): Uri {
        return new Uri(new URL(str));
    }

    static new(args?: { pathSegments?: Array<string>, path?: string, scheme?: string, host?: string }): Uri {
        let {pathSegments, path, scheme, host}:{ pathSegments?: Array<string>, path: string, scheme: string, host: string } = Object.assign({
            pathSegments: null,
            path: null,
            scheme: null,
            host: null
        }, args);

        let elem: Array<string> = [];

        if (host != null) {
            elem.push(host);
        }

        if (path != null) {
            elem.push(...path.split('/'));
        }

        if (pathSegments != null) {
            elem.push(...pathSegments);
        }

        let url: string = elem.join('/');
        if (scheme != null) {
            url = `${scheme}:${url}`;
        }

        return new Uri(new URL(elem.join('/')));
    }

    get path(): string {
        return this.url.pathname;
    }

    get pathSegments(): Array<string> {
        return this.path.split('/');
    }

    get scheme(): string {
        return this.url.protocol;
    }

    get host(): string {
        return this.url.host;
    }

    toFilePath(): string {
        return this.path;
    }

    static decodeComponent(s: string): string {
        return decodeURIComponent(s);
    }

    static encodeComponent(s: string): string {
        return encodeURIComponent(s);
    }

    static get base(): Uri {
        return new Uri(new URL(document.location.toString()));    //?
    }
}

export function identical(a: any, b: any) {
    return a === b;
}

export class StringBuffer {
    buffer: string = "";

    clear() {
        this.buffer = "";
    }

    write(s: string): void {
        this.buffer = this.buffer + s;
    }

    toString() {
        return this.buffer;
    }
}