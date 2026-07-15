# CircuitSage

A PowerShell module for interacting with [CircuitDao](https://circuitdao.com) through the [Sage Wallet](https://github.com/xch-dev/sage) RPC API. Manage lending vaults, borrow/lend CAT tokens, and participate in liquidation auctions — all from the comfort of your PowerShell terminal.

## Table of Contents

- [CircuitSage](#circuitsage)
  - [Table of Contents](#table-of-contents)
  - [Prerequisites](#prerequisites)
  - [Installation](#installation)
  - [Quick Start](#quick-start)
  - [Vault Management](#vault-management)
    - [Check Your Vault](#check-your-vault)
    - [View a Specific Vault](#view-a-specific-vault)
    - [Monitor Vault Health](#monitor-vault-health)
  - [Vault Operations](#vault-operations)
    - [Deposit Collateral](#deposit-collateral)
    - [Borrow CAT Tokens](#borrow-cat-tokens)
    - [Repay Debt](#repay-debt)
    - [Withdraw Collateral](#withdraw-collateral)
  - [Surplus Auctions](#surplus-auctions)
    - [View Active Surplus Auctions](#view-active-surplus-auctions)
    - [Settle Surplus](#settle-surplus)
    - [Bid on Surplus Auctions](#bid-on-surplus-auctions)
  - [Vault Bidding](#vault-bidding)
  - [Command Reference](#command-reference)
    - [Query Commands](#query-commands)
    - [Action Commands](#action-commands)
  - [Notes](#notes)

---

## Prerequisites

- **PowerShell 7.4+** — [Download](https://learn.microsoft.com/powershell/scripting/install/installing-powershell)
- **Sage Wallet** — [Download](https://github.com/xch-dev/sage/releases) (must be running and logged in)
- **Required PowerShell Modules:**
  - `PowerSage` — Sage Wallet RPC integration
  - `PwshSpectreConsole` — Terminal UI components

Install the prerequisites:

```powershell
Install-Module -Name PowerSage, PwshSpectreConsole -Scope CurrentUser
```

## Installation

Install CircuitSage from the PowerShell Gallery:

```powershell
Install-Module -Name CircuitSage -Scope CurrentUser
```

Import the module:

```powershell
Import-Module CircuitSage
```

> **Tip:** Add `Import-Module CircuitSage` to your `$PROFILE` to load it automatically each session.

---

## Quick Start

```powershell
# Check your vault status
Get-CDMyVault

# See vaults nearing liquidation
Get-CDVaults -status NearingLiquidation

# Deposit 10 XCH into your vault
Invoke-CDVaultAction -operation deposit -amount (10 | ConvertTo-XchMojo) -submit

# Borrow 500 BYC
Invoke-CDVaultAction -operation borrow -amount 500000 -submit
```

---

## Vault Management

### Check Your Vault

View details for the vault associated with your current Sage Wallet login:

```powershell
Get-CDMyVault
```

**Sample output:**

```
name                        : f51972063332446ede1f44167b88708021c5090801586f7d2edeb1834bad80
inner_puzzle_hash           : 
synthetic_pk                :                               
collateral                  : 1715000000000000
principal                   : 1890984
debt                        : 1892268
collateral_ratio            : 2.148
liquidation_price           : 183
nearing_liquidation         : False
in_liquidation              : False
```

**Key fields:**

| Field | Description |
|---|---|
| `collateral` | Amount of XCH locked as collateral (in mojo) |
| `principal` | Original borrowed amount |
| `debt` | Total debt owed (principal + stability fees) |
| `collateral_ratio` | Current collateralization ratio |
| `liquidation_price` | Price at which the vault becomes liquidatable |
| `nearing_liquidation` | Boolean — true if the vault is approaching the liquidation threshold |

### View a Specific Vault

Look up any vault by its identifier (32-byte hex hash):

```powershell
# By raw ID
Get-CDVault -vault "47f2055a01ef8db5c874df595aba262145c8b0134a982911f93fda558c19b33d"

# By piped input from a vault list
$vaults = Get-CDVaults -status NearingLiquidation
Get-CDVault -vault $vaults[0].name
```

### Monitor Vault Health

```powershell
# All vaults nearing liquidation
Get-CDVaults -status NearingLiquidation

# Vaults in active liquidation
Get-CDVaults -status InLiquidation

# Vaults with bad debt
Get-CDVaults -status BadDebt

# Full protocol state (all vault collections)
Get-CDVaults -status Any
```

---

## Vault Operations

All vault operations accept amounts in **mojo** (the smallest unit of CAT tokens). Use the helper functions to convert human-readable amounts:

| Converter | Example | Result |
|---|---|---|
| `ConvertTo-XchMojo` | `(10 \| ConvertTo-XchMojo)` | `10000000000000` |
| `ConvertTo-CatMojo` | `(200.02 \| ConvertTo-CatMojo)` | `200020` |

### Deposit Collateral

Deposit XCH into your vault as collateral:

```powershell
# Estimate only (review before committing)
Invoke-CDVaultAction -operation deposit -amount (65 | ConvertTo-XchMojo)

# Deposit and submit
Invoke-CDVaultAction -operation deposit -amount (65 | ConvertTo-XchMojo) -submit
```

### Borrow CAT Tokens

Borrow CAT tokens against your collateral:

```powershell
# Borrow 200 BYC
Invoke-CDVaultAction -operation borrow -amount 200000 -submit
```

### Repay Debt

Repay borrowed CAT tokens (plus any stability fees):

```powershell
# Repay 200.02 BYC
Invoke-CDVaultAction -operation repay -amount (200.02 | ConvertTo-CatMojo) -submit

# Repay maximum debt
Invoke-CDVaultAction -operation repay -amount $vault.max_repay -submit
```

### Withdraw Collateral

Withdraw XCH collateral from your vault:

```powershell
# Withdraw 65 XCH
Invoke-CDVaultAction -operation withdraw -amount (65 | ConvertTo-XchMojo) -submit

# Withdraw maximum available
Invoke-CDVaultAction -operation withdraw -amount $vault.max_withdraw -submit
```

---

## Surplus Auctions

CircuitDao holds surplus coin auctions where excess collateral can be claimed or bid on.

### View Active Surplus Auctions

```powershell
Get-CDSurplusAuctions
```

### Settle Surplus

Settle (claim) a surplus coin from an active auction, converting the auctioned collateral into a claimable asset.

```
# First, list active auctions to find the coin identifier
Get-CDSurplusAuctions
```

```powershell
# Settle without submitting (estimate only)
Invoke-CDSurplusAuctionSettle -auction_coin "<coin_id>"

# Settle and submit to the network
Invoke-CDSurplusAuctionSettle -auction_coin "<coin_id>" -submit
```

**Parameters:**

| Parameter | Description |
|---|---|
| `auction_coin` | The coin identifier of the surplus auction to settle |
| `submit` | Auto-sign and submit the transaction via Sage Wallet |

### Bid on Surplus Auctions

```powershell
# Estimate only
Invoke-CDSurplusAuctionBid -bid_amount 100000 -auction_coin "abc123..."

# Submit bid
Invoke-CDSurplusAuctionBid -bid_amount 100000 -auction_coin "abc123..." -submit
```

---

## Vault Bidding

Bid on vaults in liquidation auctions:

```powershell
# View bid details without submitting
New-CDVaultBid -vault "47f2055a01ef8db5c874df595aba262145c8b0134a982911f93fda558c19b33d" `
    -amount 100000 -max_bid_price 50000 -info

# Place a bid (estimate and submit)
New-CDVaultBid -vault "47f2055a01ef8db5c874df595aba262145c8b0134a982911f93fda558c19b33d" `
    -amount 100000 -max_bid_price 50000 -submit
```

**Parameters:**

| Parameter | Description |
|---|---|
| `vault` | Vault identifier (32-byte hex name) |
| `amount` | Bid quantity in mojo |
| `max_bid_price` | Maximum price you're willing to pay in mojo |
| `info` | Show bid details without submitting |

---

## Command Reference

### Query Commands

| Command | Description |
|---|---|
| `Get-CDMyVault` | View your current vault |
| `Get-CDMySavingsVault` | View your savings vault |
| `Get-CDMyTransactions` | View vault transaction history |
| `Get-CDVaults -status <status>` | List vaults by status (Any, NearingLiquidation, PendingLiquidation, InLiquidation, BadDebt) |
| `Get-CDVault -vault <hash>` | Get details for a specific vault |
| `Get-CDSurplusAuctions` | List active surplus auctions |
| `Get-CDProtocolState` | Get full protocol state |

### Action Commands

| Command | Description |
|---|---|
| `Invoke-CDVaultAction -operation <op> -amount <n> [-submit]` | Deposit, borrow, repay, or withdraw |
| `New-CDVaultBid -vault <v> -amount <n> -max_bid_price <n> [-info] [-submit]` | Bid on a liquidating vault |
| `Start-CDVaultAuction -vault <hash>` | Initiate a vault auction |
| `Invoke-CDSurplusAuctionBid -auction_coin <c> -bid_amount <n> [-submit]` | Bid on a surplus auction coin |
| `Invoke-CDSurplusAuctionSettle -auction_coin <c> [-submit]` | Settle a surplus auction coin |

**Vault operation values:** `deposit`, `borrow`, `repay`, `withdraw`

---

## Notes

- All amounts are in **mojo** unless converted by helper functions.
  - `1 XCH = 1,000,000,000,000 mojo`
  - `1 CAT` = depends on token decimal precision
- The `-submit` flag auto-signs and submits the transaction via your Sage Wallet.
- Without `-submit`, operations only return the estimated spend bundle for review.
- The Sage Wallet must be running and logged in for all operations.
- Use `Get-Help <CommandName>` for detailed help on any command.