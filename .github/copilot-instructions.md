# CircuitSage — Copilot Instructions

## Project Overview
PowerShell 7.4+ module for interacting with [CircuitDao](https://circuitdao.com) via the [Sage Wallet](https://github.com/xch-dev/sage) RPC API. Manages lending vaults, CAT token borrowing/lending, and liquidation auctions on the Chia blockchain.

## Structure
- `CircuitSage.psd1` — Module manifest. `FunctionsToExport` lists every exported function; keep it in sync when adding/changing functions. `RequiredModules = @('PowerSage', 'PwshSpectreConsole')`.
- `CircuitSage.psm1` — All module logic in a single file. No sub-modules or nested modules.
- `PSKeeper.ps1` — Standalone utility bot functions (pushover alerts, stability fee automation). Not part of the module; loaded separately by the developer.

## Architecture

### Two-tier function pattern
1. **RPC layer** (`Invoke-CDRPC`): Raw HTTP POST to `https://api.circuitdao.com/<endpoint>`. Accepts a string or hashtable → JSON (depth 20). Retry 3x with 2s interval. All domain functions call through here.
2. **Domain functions**: Query (read-only) or Action (mutating) functions that compose RPC calls.

### Authentication
Every request body must include `synthetic_pks`, fetched via `Get-CDSyntheticPKs` which calls `PowerSage\Get-SageDerivations`. The wallet must be running with RPC enabled and logged in.

### Dry-run vs Execute
All mutating operations follow the same pattern:
- Without `-submit`: returns the estimated spend bundle for review
- With `-submit`: calls `Invoke-SageRPC -endpoint sign_coin_spends` with `auto_submit = $true`
This pattern appears in: `Invoke-CDVaultAction`, `Move-CDVaultStabilityFee`, `Complete-CDSurplusAuction`, `Submit-CDSurplusAuctionBid`

### UI Feedback
User-facing functions wrap their RPC calls with `Invoke-SpectreCommandWithStatus -Spinner Aesthetic -Title "..."` for in-terminal status display. Not every function uses this (e.g., `Get-CDMyVault`, `Get-CDAllVaults`, `Get-CDTreasury`), but new domain functions should follow it.

## Conventions

### Amounts are in mojo
- `1 XCH = 1,000,000,000,000 mojo`
- CAT amounts depend on token decimal precision
- Never accept human-readable amounts directly in RPC calls; use helper converters `ConvertTo-XchMojo` / `ConvertTo-CatMojo`

### Function naming
- Query functions: `Get-CD*` (e.g., `Get-CDMyVault`, `Get-CDAllVaults`, `Get-CDSurplusAuctions`)
- Action functions: `Invoke-CD*` or `Start-CD*` or `New-CD*` or `Complete-CD*`
- Utility bots (PSKeeper): `Watch-*`, `Start-*`

### Parameter conventions
- All functions use `[CmdletBinding()]`
- Use `[ValidateSet()]` for known enums (e.g., `borrow`, `deposit`, `repay`, `withdraw`)
- Boolean switches: `-submit`, `-wait`, `-info` — always check with `.IsPresent`
- `$fee_per_cost = 0` is the standard across all transactions
- Pipeline input: use `ValueFromPipeline` + `process {}` block for functions accepting arrays

### Error handling
- `Invoke-CDRPC` has built-in retry and detailed error extraction from `$_.ErrorDetails.Message` and response streams
- Functions should `throw` on failure; callers handle via try/catch or the built-in error from `Invoke-CDRPC`

### Code style
- PowerShell 7.4+ syntax (no legacy PS5.1 compatibility)
- Consistent indentation (4 spaces)
- Avoid `Write-Host` in library functions (use `Write-Output`/`Write-Information`); `PSKeeper.ps1` bot functions are exempt
- No tests exist — validate changes by importing the module and running commands against the live API

## Dependencies
- **PowerSage** — Sage Wallet RPC integration (`Get-SageDerivations`, `Get-SageCoins`, `Get-SagePendingTransactions`, `Invoke-SageRPC`, etc.)
- **PwshSpectreConsole** — `Invoke-SpectreCommandWithStatus` for spinner/status UI

## Publishing
Published to PowerShell Gallery. Bump `ModuleVersion` in `CircuitSage.psd1` before release.
