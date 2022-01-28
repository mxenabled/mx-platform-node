*This project is currently in **Beta**. Please open up an issue [here](https://github.com/mxenabled/mx-platform-node/issues) to report issues using the MX Platform Node.js library.*

# MX Platform Node.js

The [MX Platform API](https://www.mx.com/products/platform-api) is a powerful, fully-featured API designed to make aggregating and enhancing financial data easy and reliable. It can seamlessly connect your app or website to tens of thousands of financial institutions.

## Documentation

Examples for the API endpoints can be found [here.](https://docs.mx.com/api)

## Requirements

The generated Node module can be used in the following environments:

Environment
* Node.js
* Webpack
* Browserify

Language level
* ES5 - you must have a Promises/A+ library installed
* ES6

Module system
* CommonJS
* ES6 module system

## Installation

To build and compile the TypeScript sources to JavaScript use:

```shell
npm install mx-platform-node
```

## Getting Started

In order to make requests, you will need to [sign up](https://dashboard.mx.com/sign_up) for the MX Platform API and get a `Client ID` and `API Key`.

Please follow the [installation](#installation) procedure and then run the following code to create your first User:

```javascript
import { Configuration, MxPlatformApi } from 'mx-platform-node';

const configuration = new Configuration({
  // Configure with your Client ID/API Key from https://dashboard.mx.com
  username: 'Your Client ID',
  password: 'Your API Key',

  // Configure environment. https://int-api.mx.com for development, https://api.mx.com for production
  basePath: 'https://int-api.mx.com',

  baseOptions: {
    headers: {
      Accept: 'application/vnd.mx.api.v1+json'
    }
  }
});

const client = new MxPlatformApi(configuration);

const requestBody = {
  user: {
    metadata: 'Creating a user!'
  }
};

const response = await client.createUser(requestBody);

console.log(response.data);
```

## Development

This project was generated by the [OpenAPI Generator](https://openapi-generator.tech). To generate this library, verify you have the latest version of the `openapi-generator-cli` found [here.](https://github.com/OpenAPITools/openapi-generator#17---npm)

Running the following command in this repo's directory will generate this library using the [MX Platform API OpenAPI spec](https://github.com/mxenabled/openapi/blob/master/openapi/mx_platform_api_beta.yml) with our [configuration and templates.](https://github.com/mxenabled/mx-platform-ruby/tree/master/openapi)
```shell
openapi-generator-cli generate \
-i https://raw.githubusercontent.com/mxenabled/openapi/master/openapi/mx_platform_api_beta.yml \
-g typescript-axios \
-c ./openapi/config.yml \
-t ./openapi/templates
```

## Contributing

Please [open an issue](https://github.com/mxenabled/mx-platform-node/issues) or [submit a pull request.](https://github.com/mxenabled/mx-platform-node/pulls)
