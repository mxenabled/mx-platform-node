# MX Platform Node.js (v20111101 API)

**SDK version:** 2.1.0  
**API version:** v20111101

You are using the **v20111101** API version of `mx-platform-node`. For other API versions, see [Available API Versions](#available-api-versions) below.

### Checking Your Installed Version

To verify which API version you have installed:

**In package.json:**
```json
{
  "dependencies": {
    "mx-platform-node": "^2.1.0"
  }
}
```

**Programmatically in your code:**
```javascript
const pkg = require('mx-platform-node/package.json');
console.log(pkg.apiVersion); // v20111101
```

**Via npm:**
```shell
npm view mx-platform-node@2.1.0
```

## Available API Versions

- **mx-platform-node@2.x.x** - [v20111101 API](https://docs.mx.com/api-reference/platform-api/v20111101/reference/mx-platform-api/)
- **mx-platform-node@3.x.x** - [v20250224 API](https://docs.mx.com/api-reference/platform-api/reference/mx-platform-api/)

---

## Overview

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
import { Configuration, UsersApi } from 'mx-platform-node';

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

const usersApi = new UsersApi(configuration);

const requestBody = {
  user: {
    metadata: 'Creating a user!'
  }
};

const response = await usersApi.createUser(requestBody);

console.log(response.data);
```

## Upgrading from v1.x?

> **⚠️ Breaking Changes in v2.0.0:** If you're upgrading from v1.10.0 or earlier, the API structure has changed significantly. See the [Migration Guide](MIGRATION.md) for detailed instructions on updating your code.

## Contributing

Please [open an issue](https://github.com/mxenabled/mx-platform-node/issues) or [submit a pull request.](https://github.com/mxenabled/mx-platform-node/pulls)
