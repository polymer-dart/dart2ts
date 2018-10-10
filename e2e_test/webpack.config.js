const path = require('path');

const HtmlWebpackPlugin = require('html-webpack-plugin');
const CleanWebpackPlugin = require('clean-webpack-plugin');
const CopyWebpackPlugin = require('copy-webpack-plugin');
const webpack = require('webpack');

module.exports = {
    entry: {
        app: [
            'webpack-dev-server/client?http://localhost:9000',
            './lib/index'
        ],
	test: [
            'webpack-dev-server/client?http://localhost:9000',
	   './lib/exports'
	]
	
    },
    devtool: 'inline-source-map',
    devServer: {
        contentBase: path.resolve(__dirname, 'dist'),
        hot: true,
        port: 9000
    },
    output: {
        filename: '[name].js',
        chunkFilename: '[name].bundle.js',
        
        path: path.resolve(__dirname,  'dist')
    },
    optimization: {
        splitChunks: {
            chunks: 'all'
        }
    },
    module: {
        rules: [
            {
                test: /\.(html)$/,
                use: {
                    loader: 'html-loader'
                }
            },
            {
                test: /\.ts?$/,
                use: 'ts-loader',
                exclude: /node_modules/
            }/* to use marked as an exposed lib,
            {
                test: require.resolve('marked'),
                use: [{
                    loader: 'expose-loader',
                    options: 'marked'
                }]
            }*/
        ]
    },
    resolve: {
        extensions: ['.ts', '.js']
    },
    plugins: [
        new CleanWebpackPlugin(['dist'], { verbose: false, root: path.resolve(__dirname) }),
        new HtmlWebpackPlugin({
            template: './lib/tests.html',
	    filename: "tests.html",
            chunks: ['test','vendors~app~test'],
            inject: "body"
        }),
        new HtmlWebpackPlugin({
            template: './lib/index.html',
            chunks: ['app','vendors~app~test'],
            inject: "body"
        }),
        new webpack.IgnorePlugin(/vertx/),
        new webpack.HotModuleReplacementPlugin(),
    ]
};
