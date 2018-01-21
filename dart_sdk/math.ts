export class Point<T> {
    x: T;
    y: T;

    constructor(x: T, y: T) {
        this.x = x;
        this.y = y;
    }
}

export function max(x: number, y: number): number {
    return x > y ? x : y;
}

export class Module {
    get E(): number {
        return Math.E;
    }
}

export let module: Module = new Module();