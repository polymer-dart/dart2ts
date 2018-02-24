const {expect, assert} = require('chai');
const puppeteer = require('puppeteer');
const express = require('express');


describe('dart2ts', function () {
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
        server = app.listen(9000);

        browser = await puppeteer.launch();
    });

    after(async function () {
        await browser.close();
        await server.close();
        console.log('TEST FINISHED');
    });

    describe('tests', () => {
        before(async () => {
            page = await browser.newPage();
            page.on('console', msg => {
                for (let i = 0; i < msg.args().length; ++i)
                    //console.log(`${i}: ${msg.args()[i]}`);
                    console.log(`TESTS> ${msg.text()}`);
            });
            await page.goto('http://localhost:9000/lib/tests.html');
        });

        after(async () => {
            await page.close();
            page = null;
        });

        it('async await', async function () {
            this.timeout(20000);
            
            const testAwait = await page.evaluate(() => window.tests.testAsync());

            assert.isArray(testAwait);
            expect(testAwait).to.deep.equal([0, 1, 2, 3, 4]);

        });
    });

    describe('index', () => {
        before(async () => {
            page = await browser.newPage();
            page.on('console', msg => {
                for (let i = 0; i < msg.args().length; ++i)
                    //console.log(`${i}: ${msg.args()[i]}`);
                    console.log(`INDEX> ${msg.text()}`);
            });
            await page.goto('http://localhost:9000/lib/index.html');
        });

        after(async () => {
            await page.close();
            page = null;
        });

        it('page should be rendered', async function () {
            this.timeout(20000);

            console.log('waiting for end of work');

            await page.waitForSelector('div.endofwork', {timeout: 20000});


            const createdTask = await page.evaluate(() => document.querySelector('div.endofwork').textContent);

            // Compare actual text with expected input
            console.log('executing task');
            expect(createdTask).to.equal("finished");

            await page.screenshot({path: 'test/screens/item.png', fullscreen: true});

        });

    });


});