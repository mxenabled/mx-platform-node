# MX Platform Node.js SDK

This repository contains the Node.js SDK for the [MX Platform API](https://www.mx.com/products/platform-api). The SDK supports multiple API versions, published as independent major versions of the same npm package.

## Which API Version Do You Need?

| API Version | npm Package | Documentation |
|---|---|---|
| **v20111101** | `mx-platform-node@^2` | [v20111101 SDK README](./v20111101/README.md) |
| **v20250224** | `mx-platform-node@^3` | [v20250224 SDK README](./v20250224/README.md) |

## Installation

```bash
# For v20111101 API
npm install mx-platform-node@^2

# For v20250224 API
npm install mx-platform-node@^3
```

## API Migration

If you're upgrading from v20111101 to v20250224, see the [MX Platform API Migration Guide](https://docs.mx.com/api-reference/platform-api/overview/migration).

## Repository Structure

This repository uses [OpenAPI Generator](https://openapi-generator.tech) to automatically generate TypeScript SDKs from OpenAPI specifications.

```
v20111101/              # Generated SDK for v20111101 API
v20250224/              # Generated SDK for v20250224 API
openapi/                # SDK generation configuration and templates
.github/workflows/      # Automation for generation, publishing, and releasing
docs/                   # Repository documentation and contribution guidelines
```

## For Contributors

For detailed information about:
- How the SDK generation process works
- How to contribute to this repository
- Publishing and release workflows
- Architecture and design decisions

Please see the [docs/](./docs/) directory.

## Support

- **SDK Issues**: [Open an issue](https://github.com/mxenabled/mx-platform-node/issues)
- **API Documentation**: [MX Platform API Docs](https://docs.mx.com)
- **API Changelog**: [MX Platform Changelog](https://docs.mx.com/resources/changelog/platform)

