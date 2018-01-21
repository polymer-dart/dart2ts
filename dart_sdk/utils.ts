
export function extendPrototype(type, other) {
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