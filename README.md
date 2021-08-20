*This project is currently in **Beta**. Please open up an issue [here](https://github.com/mxenabled/mx-platform-node/issues) to report issues using the MX Platform API Node Library.*

## MX Platform Node

A Node.js library for the [MX Platform API](https://www.mx.com/products/platform-api).

### Documentation

See the [documentation](https://docs.mx.com/api).

### Install

To build and compile the typescript sources to javascript use:

```shell
$ npm install mx-platform-node
```

### Getting Started

The [openapi-generator](https://github.com/OpenAPITools/openapi-generator) creates TypeScript/JavaScript client that utilizes [axios](https://github.com/axios/axios). The generated Node module can be used in the following environments:

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

In order to make requests, you will need to [sign up](https://dashboard.mx.com/sign_up) for the MX Platform API and get a `Client ID` and `API Key`.

```javascript
import { Configuration, MxPlatformApi } from 'mx-platform-node'

const configuration = new Configuration({
  basePath: 'https://int-api.mx.com',
  username: 'Client ID',
  password: 'API Key',
  baseOptions: {
    headers: {
      Accept: 'application/vnd.mx.api.v1+json'
    }
  }
});

const client = new MxPlatformApi(configuration);

const userGuid = 'USR-123';

const response = await client.readUser(userGuid);

console.log(response.data);
```

## Contributing

Bug reports and pull requests are welcome on [GitHub](https://github.com/mxenabled/mx-platform-node).
