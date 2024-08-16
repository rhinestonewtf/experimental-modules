# Experimental Modules

**Rhinestone experimental modules for smart accounts**

> These modules are experimental and are not yet ready for production use.

Modules:

- **AggregatedValidator**: Implementing a validator as an ERC-4337 aggregator
- **PermissionsHook**: A hook to enforce granular module permissions

## Using the modules

To use the modules in an application, head to our [sdk documentation](https://docs.rhinestone.wtf/module-sdk) for more information. Since these modules are experimental, they are not integrated into the SDK but you can use them as external modules. You will also need to deploy them on the chain required unless we have already done so (see our [address book](https://docs.rhinestone.wtf/overview/address-book)).

## Using this repo

To install the dependencies, run:

```bash
pnpm install
```

To build the project, run:

```bash
forge build
```

To run the tests, run:

```bash
forge test
```

## Contributing

For feature or change requests, feel free to open a PR, start a discussion or get in touch with us.
