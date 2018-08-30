export function extend(type, other) {
    copyProps(other.prototype, type.prototype);
    copyProps(other, type);
    return type;
}

export function copyProps(from, into) {
    for (let p in Object.getOwnPropertyNames(from)) {
        // skip constructor
        if (p === 'constructor') {
            continue;
        }
        Object.defineProperty(into, p, Object.getOwnPropertyDescriptor(from, p));
    }

    for (let p in Object.getOwnPropertySymbols(from)) {
        Object.defineProperty(into, p, Object.getOwnPropertyDescriptor(from, p));
    }
}