export class My {
    xx: number;

    * generatorMethod() {
        yield this.xx++;
        yield this.xx++;
        yield this.xx++;
    }


    executeMe() {
        this.xx = 10;
        var x = () => {
            return (function* () {
                while (this.xx < 20) {
                    yield this.xx++;
                }
            }).call(this);
        };

        for (let n of x()) {
            console.log(`val : ${n}`);
        }
    }
}


function makeIndexAwareProxy<X extends object>(claxx: X) {
    return new Proxy(claxx, {
        construct(target, args) {
            return new Proxy(new (target as any)(...args), {

            });
        }
    });
}
