const {expect} = require('chai');
const puppeteer = require('puppeteer');
const connect = require('connect');
const serveStatic = require('serve-static');
const http = require('http');

/*
(async () => {
    const browser = await puppeteer.launch();
    const page = await browser.newPage();
    await page.goto('https://example.com');
    await page.screenshot({path: 'example.png'});

    await browser.close();
})();
*/

describe('First tests with puppeteer:', function () {
    // Define global variables
    let browser;
    let page;
    let app;

    before(async function () {

        // Simple server for serving static files
        app = connect().use(serveStatic('e2e_test/'));
        http.createServer(app).listen(9000, () => {
            console.log('Listening...');
        });

        browser = await puppeteer.launch();
    });

    beforeEach(async function () {
        page = await browser.newPage();
        await page.goto('http://localhost:9000');
    });

    afterEach(async function () {
        await page.close();
    });

    after(async function () {
        await browser.close();
    });

    it('should add item to the list', async function () {
        await page.screenshot({path: 'test/screens/item.png'});
    });
});