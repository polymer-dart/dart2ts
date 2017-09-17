export function print(message: String): void {
    console.log(message);
}

export class List<T> extends Array<T> {
    dartMap<Y>(f: (x: T) => Y): Array<Y> {
        return this.map((x: T) => f(x));
    }
}