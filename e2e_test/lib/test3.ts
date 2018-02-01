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