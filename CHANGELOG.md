# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [2.0.0] - TBD

### Changed
- **Versioning Correction:** Re-released as v2.0.0 to properly indicate breaking changes that were inadvertently introduced in v1.10.1
- No code changes from v1.12.1 - this is a versioning correction to follow semantic versioning
- Versions v1.10.1 through v1.12.1 are now deprecated on npm in favor of this properly versioned v2.0.0 release

### ⚠️ BREAKING CHANGES (from v1.10.0)

**API Class Restructure:** The unified `MxPlatformApi` class has been replaced with granular, domain-specific API classes to better align with the OpenAPI specification structure. This change improves code organization and maintainability but requires migration of existing code.

**Note:** This breaking change was originally introduced in v1.10.1 but should have been released as v2.0.0. If you are currently using v1.10.1 through v1.12.1, the code is functionally identical to v2.0.0.

#### Migration Required

**Before (v1.10.0 and earlier):**
```javascript
import { Configuration, MxPlatformApi } from 'mx-platform-node';

const client = new MxPlatformApi(configuration);
await client.listMembers(userGuid);
await client.listAccounts(userGuid);
await client.listTransactions(userGuid, accountGuid);
```

**After (v1.10.1+):**
```javascript
import { 
  Configuration, 
  MembersApi, 
  AccountsApi, 
  TransactionsApi 
} from 'mx-platform-node';

const membersApi = new MembersApi(configuration);
const accountsApi = new AccountsApi(configuration);
const transactionsApi = new TransactionsApi(configuration);

await membersApi.listMembers(userGuid);
await accountsApi.listAccounts(userGuid);
await transactionsApi.listTransactions(userGuid, accountGuid);
```

#### Available API Classes

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

### Changed
- Restructured API classes from single `MxPlatformApi` to domain-specific classes

## [1.12.1] and earlier (1.10.1 - 1.12.1) - Various dates

### ⚠️ DEPRECATED
These versions (v1.10.1 through v1.12.1) contain the breaking API restructure but were incorrectly published as minor/patch releases instead of a major version. They have been deprecated on npm in favor of v2.0.0.

**If you are on any of these versions:** Please upgrade to v2.0.0 (code is identical to v1.12.1, just properly versioned).

## [1.10.0] - Various dates

### Note
- Last stable version with unified `MxPlatformApi` class
- Upgrade from this version to v2.0.0 requires code changes (see migration guide above)

---

**Note:** This CHANGELOG was created retroactively. For detailed version history prior to v2.0.0, please refer to the [commit history](https://github.com/mxenabled/mx-platform-node/commits/master) and [releases page](https://github.com/mxenabled/mx-platform-node/releases).
