# Migration Guide

## Upgrading to v2.0.0 from v1.10.0 or earlier

### Breaking Change: API Class Restructure

**Important:** Starting with version 2.0.0 (originally introduced in v1.10.1, now properly versioned), the unified `MxPlatformApi` class has been replaced with domain-specific API classes. If you're upgrading from v1.10.0 or earlier, you'll need to update your imports and API instantiation.

**Note:** Versions v1.10.1 through v1.12.1 are deprecated. If you're on any of these versions, please upgrade to v2.0.0 (functionally identical to v1.12.1, just properly versioned).

### What Changed

The library now provides granular API classes organized by domain (Users, Members, Accounts, Transactions, etc.) instead of a single `MxPlatformApi` class. This aligns with the OpenAPI specification structure and provides better code organization.

### How to Migrate

**Before (v1.10.0 and earlier):**
```javascript
import { Configuration, MxPlatformApi } from 'mx-platform-node';

const client = new MxPlatformApi(configuration);
await client.createUser(requestBody);
await client.listMembers(userGuid);
await client.listAccounts(userGuid);
```

**After (v2.0.0+):**
```javascript
import { Configuration, UsersApi, MembersApi, AccountsApi } from 'mx-platform-node';

const usersApi = new UsersApi(configuration);
const membersApi = new MembersApi(configuration);
const accountsApi = new AccountsApi(configuration);

await usersApi.createUser(requestBody);
await membersApi.listMembers(userGuid);
await accountsApi.listAccounts(userGuid);
```

### Available API Classes

The new structure includes the following API classes:

- `AccountsApi` - Account operations
- `AuthorizationApi` - Authorization operations
- `BudgetsApi` - Budget operations
- `CategoriesApi` - Category operations
- `GoalsApi` - Goal operations
- `InsightsApi` - Insight operations
- `InstitutionsApi` - Institution operations
- `InvestmentHoldingsApi` - Investment holding operations
- `ManagedDataApi` - Managed data operations
- `MembersApi` - Member operations
- `MerchantsApi` - Merchant operations
- `MicrodepositsApi` - Microdeposit operations
- `MonthlyCashFlowProfileApi` - Monthly cash flow profile operations
- `NotificationsApi` - Notification operations
- `ProcessorTokenApi` - Processor token operations
- `RewardsApi` - Rewards operations
- `SpendingPlanApi` - Spending plan operations
- `StatementsApi` - Statement operations
- `TaggingsApi` - Tagging operations
- `TagsApi` - Tag operations
- `TransactionRulesApi` - Transaction rule operations
- `TransactionsApi` - Transaction operations
- `UsersApi` - User operations
- `VerifiableCredentialsApi` - Verifiable credential operations
- `WidgetsApi` - Widget operations

For the complete list of available methods, please refer to the [API documentation](https://docs.mx.com/api).

### Migration Checklist

1. **Update your imports**: Replace `MxPlatformApi` with the specific API classes you need
2. **Update instantiation**: Create separate instances for each API class instead of a single client
3. **Update method calls**: Call methods on the appropriate API class instance
4. **Test thoroughly**: Verify all API calls work as expected with the new structure
5. **Update documentation**: If you have internal docs referencing the old API, update them

### Need Help?

If you encounter any issues during migration, please [open an issue](https://github.com/mxenabled/mx-platform-node/issues) on GitHub.
