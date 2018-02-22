const {expect} = require('chai');
const puppeteer = require('puppeteer');
const express = require('express');

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
    let server;

    before(async function () {

        // Simple server for serving static files
        // Simple server for serving static files
        app = express();
        app.use(express.static('e2e_test'));
        //app.use('/node_modules/dart_sdk',express.static('../dart_sdk'));
        server = app.listen(9000, () => {
            console.log('Listening...');
        });

        browser = await puppeteer.launch();
    });

    beforeEach(async function () {
        page = await browser.newPage();
        page.on('console', msg => {
            for (let i = 0; i < msg.args().length; ++i)
                //console.log(`${i}: ${msg.args()[i]}`);
                console.log(`JS> ${msg.text()}`);
        });
        await page.goto('http://localhost:9000/lib/index.html');
    });

    afterEach(async function () {
        await page.close();
    });

    after(async function () {
        await browser.close();
        await server.close();
        console.log('TEST FINISHED');
    });

    it('page should be rendered', async function () {
        this.timeout(90000);

        console.log('waiting for end of work');

        await page.waitForSelector('div.endofwork', {timeout: 90000});


        const createdTask = await page.evaluate(() => document.querySelector('div.endofwork').textContent)

        // Compare actual text with expected input
        console.log('executing task');
        expect(createdTask).to.equal("finished");

        await page.screenshot({path: 'test/screens/item.png', fullscreen: true});

    });
});