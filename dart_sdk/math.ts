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