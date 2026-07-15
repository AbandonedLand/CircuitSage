<#
.SYNOPSIS
    PowerShell module for interacting with CircuitDao through the Sage RPC API.

.DESCRIPTION
    CircuitSage is a PowerShell module that provides a wrapper for the CircuitDao
    protocol on the Chia Blockchain. It enables vault management, lending operations,
    surplus auctions, and vault bidding through the Sage Wallet RPC interface.

    This module requires the PowerSage and PwshSpectreConsole modules to be installed
    and the Sage Wallet to be running and logged in.

.EXAMPLE
    Import-Module CircuitSage
    Get-CDMyVault

.EXAMPLE
    Get-CDVaults -status NearingLiquidation

.EXAMPLE
    Invoke-CDVaultAction -operation deposit -amount (50 | ConvertTo-XchMojo) -submit

.NOTES
    Module Version: 1.0.0
    Author: MayorAbandoned
    Requires: PowerSage, PwshSpectreConsole modules
    PowerShell Version: 7.4
#>

# RequiresPowerShell 7.4

# ============================================================
# Core RPC Functions
# ============================================================

<#
.SYNOPSIS
    Invokes a CircuitDao RPC API endpoint.

.DESCRIPTION
    Internal helper function that wraps Invoke-RestMethod to communicate with the
    CircuitDao API. Sends a POST request with a JSON body to the specified endpoint.
    The default endpoint is https://api.circuitdao.com.

.PARAMETER endpoint
    The API endpoint path (e.g., "vaults/borrow", "protocol/state", "vault").

.PARAMETER json
    The JSON payload to send with the request. Accepts either a hashtable or an
    object that will be converted to JSON.

.EXAMPLE
    Invoke-CDRPC -endpoint "protocol/state" -json @{ vaults = $true }

.EXAMPLE
    Invoke-CDRPC -endpoint "vault/deposit" -json @{ synthetic_pks = $pks; amount = 100000000000000 }

.INPUTS
    System.String, System.Object

.OUTPUTS
    System.Object. Response from the CircuitDao API.

.NOTES
    This is a core helper function used by all other functions in this module.
    Exported for convenience but primary usage should be through higher-level functions.

.LINK
    Get-CDMyVault
    Invoke-CDVaultAction
    Get-CDVaults
#>
function Invoke-CDRPC{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [string]$endpoint,
        [Parameter(Mandatory=$true, Position=1, ValueFromPipeline)]
        [object]$json
    )
    process {
        $json = $json | ConvertTo-Json -Depth 10

        $uri = "https://api.circuitdao.com/$endpoint"
        #$uri = "https://testnet-api.circuitdao.com/$endpoint"
        try{
            Invoke-RestMethod -Method Post -Uri $uri -Body $json -ContentType "application/json" -AllowInsecureRedirect
        } catch {
            throw "Could not submit request to CircuitDao"
        }
        
    }
}

<#
.SYNOPSIS
    Retrieves oracle data from the CircuitDao protocol.

.DESCRIPTION
    Queries the oracle endpoint to obtain on-chain oracle data used by the protocol
    for price feeds and protocol state.

.EXAMPLE
    Get-CDOracle
    # Returns oracle data from CircuitDao.

.INPUTS
    None.

.OUTPUTS
    System.Object. Oracle data object returned from the API.

.NOTES
    This is a placeholder function. Additional oracle parameters may be added in the future.
#>
function Get-CDOracle{
    [CmdletBinding()]
    param()

    $json = @{}
    Invoke-CDRPC -endpoint "oracle" -json $json
}

<#
.SYNOPSIS
    Retrieves the current protocol state from CircuitDao.

.DESCRIPTION
    Fetches the on-chain protocol state including vault listings in various
    liquidation states. This is the foundational data source used by several
    other cmdlets in the module.

.EXAMPLE
    Get-CDProtocolState
    # Retrieves the full protocol state including all vault collections.

.INPUTS
    None.

.OUTPUTS
    System.Object. Protocol state object containing vault collections.

.NOTES
    The returned object contains properties such as:
    - vaults_nearing_liquidation
    - vaults_pending_liquidation
    - vaults_in_liquidation
    - vaults_bad_debt

.LINK
    Get-CDVaults
    Get-CDMyVault
#>
function Get-CDProtocolState{
    [CmdletBinding()]
    param()

    $json = @{
        vaults = $true
    }
    Invoke-CDRPC -endpoint "protocol/state" -json $json
}

# ============================================================
# Vault Query Functions
# ============================================================

<#
.SYNOPSIS
    Retrieves a list of vaults from CircuitDao filtered by status.

.DESCRIPTION
    Queries the protocol state and returns vaults matching the specified status filter.
    Use this to monitor vaults that may be at risk of liquidation or are already
    in liquidation auctions.

.PARAMETER status
    The status of vaults to retrieve. Valid values are:
    - "Any"             : Returns the full protocol state object with all vault collections
    - "NearingLiquidation" : Vaults approaching their liquidation threshold
    - "PendingLiquidation"   : Vaults that are pending liquidation
    - "InLiquidation"    : Vaults currently in the liquidation process
    - "BadDebt"          : Vaults that have entered bad debt status

.EXAMPLE
    Get-CDVaults -status NearingLiquidation
    # Returns all vaults that are nearing liquidation.

.EXAMPLE
    $badDebtVaults = Get-CDVaults -status BadDebt
    $badDebtVaults | Format-Table
    # Stores and displays all bad debt vaults in a table format.

.EXAMPLE
    $allVaults = Get-CDVaults -status Any
    $allVaults | Get-Member
    # Returns the full protocol state object with all vault collections for further processing.

.INPUTS
    None.

.OUTPUTS
    System.Object[]. Array of vault objects or the full protocol state object when status is "Any".

.NOTES
    Each vault object contains fields such as:
    - name: The vault identifier (32-byte hex hash)
    - collateral: The amount of XCH collateral locked
    - principal: The borrowed amount (in CAT mojo)
    - debt: The total debt owed to the vault
    - collateral_ratio: The current collateralization ratio
    - liquidation_price: The price at which the vault would be liquidated

.LINK
    Get-CDVault
    Get-CDMyVault
#>
function Get-CDVaults{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [ValidateSet("Any","NearingLiquidation","PendingLiquidation","InLiquidation","BadDebt")]
        [string]$status
    )

    $vaults = Get-CDProtocolState

    switch ($status) {

        "NearingLiquidation" { return $vaults.vaults_nearing_liquidation  }
        "PendingLiquidation" { return $vaults.vaults_pending_liquidation }
        "InLiquidation" { return $vaults.vaults_in_liquidation }
        "BadDebt" { return $vaults.vaults_bad_debt}
        "Any" { return $vaults }
    }
}

<#
.SYNOPSIS
    Retrieves detailed information about a specific vault.

.DESCRIPTION
    Queries the CircuitDao API for a single vault by its name (32-byte hex identifier)
    and returns all associated vault data including collateral, debt, and liquidation status.

.PARAMETER vault
    The vault identifier (name), a 32-byte hexadecimal string. This can be obtained from
    the output of Get-CDVaults or by specifying a vault hash directly.

.EXAMPLE
    Get-CDVault -vault "47f2055a01ef8db5c874df595aba262145c8b0134a982911f93fda558c19b33d"
    # Retrieves detailed information about the specified vault.

.EXAMPLE
    $vaults = Get-CDVaults -status NearingLiquidation
    Get-CDVault -vault $vaults[0].name
    # Gets detailed info for the first vault in the list.

.INPUTS
    System.String. You can pipe a vault identifier string to Get-CDVault.

.OUTPUTS
    System.Object. Detailed vault information object.

.NOTES
    The returned vault object contains:
    - collateral: Total XCH collateral locked
    - principal: Original loan principal
    - debt: Current total debt including stability fees
    - collateral_ratio: Current collateralization ratio
    - liquidation_price: Price at which liquidation triggers
    - min_deposit / max_withdraw: Current deposit and withdrawal limits
    - min_repay / max_repay: Current repayment limits
    - auction_state / auction_ttl / auction_price: Auction state if applicable

.LINK
    Get-CDVaults
    Get-CDMyVault
    Invoke-CDVaultAction
#>
function Get-CDVault{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, Position=0, ValueFromPipeline)]
        [string]$vault
    )
    process {
        Invoke-CDRPC -endpoint "vaults/$vault/" -json @{}
    }
}

<#
.SYNOPSIS
    Retrieves the vault associated with the current Sage Wallet login.

.DESCRIPTION
    Queries the CircuitDao API for the vault belonging to the currently logged-in
    Sage Wallet account. Uses the wallet's synthetic public keys to identify
    the associated vault.

.EXAMPLE
    Get-CDMyVault
    # Returns the vault data for the currently logged-in Sage Wallet user.

.INPUTS
    None.

.OUTPUTS
    System.Object. Vault data object for the current user.

.NOTES
    Requires the Sage Wallet to be logged in. Internally calls Get-CDSyntheticPKs
    to resolve the user's synthetic public keys.

.LINK
    Get-CDSyntheticPKs
    Get-CDMySavingsVault
    Invoke-CDVaultAction
#>
function Get-CDMyVault{
    [CmdletBinding()]
    param()

    $synthetic_pks = Get-CDSyntheticPKs
    $json = @{
        synthetic_pks = $synthetic_pks
    }
    Invoke-CDRPC -endpoint "vault" -json $json
}

<#
.SYNOPSIS
    Retrieves the savings vault associated with the current Sage Wallet login.

.DESCRIPTION
    Queries the CircuitDao API for the savings vault belonging to the currently
    logged-in Sage Wallet account. Savings vaults differ from regular lending vaults
    in their deposit and yield mechanics.

.EXAMPLE
    Get-CDMySavingsVault
    # Returns the savings vault data for the currently logged-in Sage Wallet user.

.INPUTS
    None.

.OUTPUTS
    System.Object. Savings vault data object for the current user.

.NOTES
    Requires the Sage Wallet to be logged in. Internally calls Get-CDSyntheticPKs
    to resolve the user's synthetic public keys.

.LINK
    Get-CDMyVault
    Get-CDSyntheticPKs
#>
function Get-CDMySavingsVault{
    [CmdletBinding()]
    param()

    $synthetic_pks = Get-CDSyntheticPKs
    $json = @{
        synthetic_pks = $synthetic_pks
    }
    Invoke-CDRPC -endpoint "savings" -json $json
}

<#
.SYNOPSIS
    Retrieves transaction history for the current user's vault.

.DESCRIPTION
    Queries the CircuitDao API for the transaction history of the vault associated
    with the current Sage Wallet user. Returns up to 20 transactions at a time
    with pagination support.

.PARAMETER start_index
    The starting index for transaction retrieval. Defaults to 0 (most recent transactions).
    Use this parameter for pagination through transaction history.

.EXAMPLE
    Get-CDMyTransactions
    # Returns the first 20 (most recent) transactions.

.EXAMPLE
    Get-CDMyTransactions -start_index 20
    # Returns transactions 21-40.

.EXAMPLE
    Get-CDMyTransactions | Format-Table -AutoSize
    # Retrieves and displays all transactions in a formatted table.

.INPUTS
    None.

.OUTPUTS
    System.Object[]. Array of transaction objects.

.NOTES
    Requires the Sage Wallet to be logged in. The function defaults to returning
    20 transactions per call. Use start_index for pagination.

.LINK
    Get-CDMyVault
    Invoke-CDVaultAction
    Get-CDSyntheticPKs
#>
function Get-CDMyTransactions{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false, Position=0)]
        [int32]$start_index=0
    )
    $synthetic_pks = Get-CDSyntheticPKs

    [int32]$end_index = $start_index + 20

    $json = @{
        synthetic_pks = $synthetic_pks
        fee_per_cost = 0
        only_estimate_fee=$false
    }

    Invoke-CDRPC -endpoint "vault/transactions/?start_index=$start_index&end_index=$end_index" -json $json
}

# ============================================================
# Vault Action Functions
# ============================================================

<#
.SYNOPSIS
    Executes a vault action on CircuitDao (deposit, borrow, repay, or withdraw).

.DESCRIPTION
    The primary command for interacting with your CircuitDao lending vault. Performs
    one of four vault operations: deposit collateral, borrow CAT tokens, repay a loan,
    or withdraw collateral. The action can be estimated only (returns the spend bundle)
    or estimated and submitted (auto-submits to the network via Sage Wallet).

.PARAMETER operation
    The vault operation to perform. Valid values are:
    - "borrow"  : Borrow CAT tokens against collateral
    - "deposit" : Deposit XCH collateral into the vault
    - "repay"   : Repay borrowed CAT tokens
    - "withdraw": Withdraw XCH collateral from the vault

.PARAMETER amount
    The amount in mojo (smallest unit). For XCH, use mojo (1 XCH = 1,000,000,000,000 mojo).
    Use the helper functions to convert human-readable amounts:
    - `(amount | ConvertTo-XchMojo)` for XCH amounts
    - `(amount | ConvertTo-CATMojo)` for CAT token amounts

.PARAMETER submit
    When specified, the estimated transaction is automatically signed and submitted
    to the CircuitDao network via the Sage Wallet. Without this flag, the function
    only returns the estimated spend bundle for manual review.

.EXAMPLE
    # Estimate a deposit (do not submit)
    Invoke-CDVaultAction -operation deposit -amount 65000000000000

.EXAMPLE
    # Deposit 65 XCH and submit to network
    Invoke-CDVaultAction -operation deposit -amount (65 | ConvertTo-XchMojo) -submit

.EXAMPLE
    # Borrow 200 BYC tokens
    Invoke-CDVaultAction -operation borrow -amount 200000 -submit

.EXAMPLE
    # Repay 200.02 BYC tokens using the converter helper
    Invoke-CDVaultAction -operation repay -amount (200.02 | ConvertTo-CatMojo) -submit

.EXAMPLE
    # Withdraw 65 XCH from vault
    Invoke-CDVaultAction -operation withdraw -amount (65 | ConvertTo-XchMojo) -submit

.INPUTS
    None.

.OUTPUTS
    System.Object. Returns the spend bundle response from the RPC call, or the signed
    and submitted transaction if -submit is specified.

.NOTES
    Requires the Sage Wallet to be logged in. The -submit flag requires the Sage
    Wallet to be unlocked and configured. Use this function without -submit first
    to review the estimated spend bundle before committing.

.LINK
    Get-CDMyVault
    Invoke-CDSurplusAuctionBid
#>
function Invoke-CDVaultAction{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [ValidateSet("borrow","deposit","repay","withdraw")]
        [string]$operation,
        [Parameter(Mandatory=$true, Position=1)]
        [UInt64]$amount,
        [switch]$submit
    )


    $synthetic_pks = Get-CDSyntheticPKs


    $json = @{
        synthetic_pks = $synthetic_pks
        fee_per_cost = 0
        only_estimate_fee = $false
        amount = $amount
    }

    $response = Invoke-CDRPC -endpoint "vault/$operation" -json $json
        if($submit.IsPresent){
            $spend = invoke-sagerpc -endpoint sign_coin_spends -json @{
                auto_submit = $true
                partial = $false
                coin_spends = ($response.bundle.coin_spends)
            }
            return $spend
        } else {
            return $response
        }
}

<#
.SYNOPSIS
    Initiates a vault auction on CircuitDao.

.DESCRIPTION
    Starts a liquidation auction for the specified vault. This is used when a
    vault has entered the liquidation process and needs to be bid on or settled.

.PARAMETER vault
    The vault identifier (32-byte hex name) of the vault to start an auction for.

.EXAMPLE
    Start-CDVaultAuction -vault "47f2055a01ef8db5c874df595aba262145c8b0134a982911f93fda558c19b33d"
    # Initiates an auction for the specified vault.

.INPUTS
    System.String. You can pipe a vault identifier string to Start-CDVaultAuction.

.OUTPUTS
    System.Object. Auction initiation response from the RPC call.

.NOTES
    Requires the Sage Wallet to be logged in.

.LINK
    Get-CDVault
    New-CDVaultBid
#>
function Start-CDVaultAuction{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, Position=0, ValueFromPipeline)]
        [string]$vault
    )
    process {
        $synthetic_pks = Get-CDSyntheticPKs
        $initiator_puzzle_hash = Get-CDMyPuzzleHash

        $json = @{
            synthetic_pks = $synthetic_pks
            fee_per_cost = 0
            only_estimate_fee = $false
            vault_name = $vault
            initiator_puzzle_hash = $initiator_puzzle_hash
        }

        Invoke-CDRPC -endpoint "vaults/start_auction" -json $json
    }
}

<#
.SYNOPSIS
    Places a bid on a vault auction in CircuitDao.

.DESCRIPTION
    Submits a bid to participate in a vault liquidation auction. The bid specifies
    the amount and the maximum price you are willing to pay. The function estimates
    the transaction fee and returns a spend bundle that can be reviewed and optionally
    submitted to the network.

.PARAMETER vault
    The vault identifier (32-byte hex name) of the vault being auctioned.

.PARAMETER amount
    The bid amount in mojo. The quantity being bid on for the vault.

.PARAMETER max_bid_price
    The maximum price in mojo you are willing to pay for this vault auction bid.

.PARAMETER info
    When specified, includes additional information in the bid request. Use this
    to inspect bid details before committing.

.EXAMPLE
    New-CDVaultBid -vault "47f2055a01ef8db5c874df595aba262145c8b0134a982911f93fda558c19b33d" -amount 100000 -max_bid_price 50000 -info
    # Returns bid information for the specified vault without submitting.

.INPUTS
    System.String. You can pipe a vault identifier string to New-CDVaultBid.

.OUTPUTS
    System.Object. Bid spend bundle response from the RPC call.

.NOTES
    Requires the Sage Wallet to be logged in. The current user must have a valid
    puzzle hash for the bid to succeed.

.LINK
    Get-CDVault
    Start-CDVaultAuction
    Invoke-CDSurplusAuctionBid
#>
function New-CDVaultBid{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, Position=0, ValueFromPipeline)]
        [string]$vault,
        [Parameter(Mandatory=$true, Position=1)]
        [UInt64]$amount,
        [Parameter(Mandatory=$true, Position=2)]
        [UInt64]$max_bid_price,
        [Parameter(Mandatory=$true)]
        [switch]$info
    )
    process {
        $synthetic_pks = Get-CDSyntheticPKs
        $initiator_puzzle_hash = Get-CDMyPuzzleHash
        if($initiator_puzzle_hash -and $synthetic_pks){
            $json = @{
                synthetic_pks = $synthetic_pks
                fee_per_cost = 0
                only_estimate_fee = $false
                vault_name = $vault
                target_puzzle_hash = $initiator_puzzle_hash
                amount = $amount
                max_bid_price = $max_bid_price
                info = $false
                ignore_coin_names = @()
            }

            if($info.IsPresent){
                $json.info = $true
            }

            Invoke-CDRPC -endpoint "vaults/bid_auction" -json $json
        }
    }
}

# ============================================================
# Surplus Auction Functions
# ============================================================

<#
.SYNOPSIS
    Retrieves a list of active surplus auctions from CircuitDao.

.DESCRIPTION
    Queries the CircuitDao API for all active surplus coin auctions. Surplus
    auctions are liquidation auctions where excess collateral is being offered
    to bid participants.

.EXAMPLE
    Get-CDSurplusAuctions
    # Returns all active surplus auction records.

.INPUTS
    None.

.OUTPUTS
    System.Object[]. Array of surplus auction objects.

.NOTES
    Use the auction_coin value from each result to inspect or bid on individual auctions.

.LINK
    Invoke-CDSurplusAuctionBid
    Invoke-CDSurplusAuctionSettle
#>
function Get-CDSurplusAuctions{
    [CmdletBinding()]
    param()
    Invoke-CDRPC -endpoint "surplus_auctions" -json @{}
}

<#
.SYNOPSIS
    Settles a surplus auction coin in CircuitDao.

.DESCRIPTION
    Executes a settlement operation on a surplus auction coin, which converts
    the auctioned collateral into a claimable asset. The operation can be
    estimated only or estimated and submitted to the network.

.PARAMETER submit
    When specified, the settlement transaction is automatically signed and
    submitted to the CircuitDao network via the Sage Wallet.

.EXAMPLE
    # Estimate the settlement (do not submit)
    Invoke-CDSurplusAuctionSettle

.EXAMPLE
    # Estimate and submit the settlement to the network
    Invoke-CDSurplusAuctionSettle -submit

.INPUTS
    None.

.OUTPUTS
    System.Object. Spend bundle response from the RPC call, or the submitted transaction if -submit.

.NOTES
    Requires the Sage Wallet to be logged in. The -submit flag requires the
    Sage Wallet to be unlocked.

.LINK
    Get-CDSurplusAuctions
    Invoke-CDSurplusAuctionBid
#>
function Invoke-CDSurplusAuctionSettle{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [string]$auction_coin,
        [switch]$submit
    )

    $synthetic_pks = Get-CDSyntheticPKs
    $json = @{
        synthetic_pks = $synthetic_pks
        fee_per_cost = 0
        operation = "settle"
        args = @{}
    }

    $response = Invoke-CDRPC -endpoint "surplus_auctions/$($auction_coin)" -json $json
    if($submit.IsPresent){
        $spend = invoke-sagerpc -endpoint sign_coin_spends -json @{
            auto_submit = $true
            partial = $false
            coin_spends = ($response.bundle.coin_spends)
        }
        return $spend
    } else {
        return $response
    }
}

<#
.SYNOPSIS
    Places a bid on a surplus auction in CircuitDao.

.DESCRIPTION
    Submits a bid to participate in a surplus auction. Surplus auctions allow
    users to bid on excess collateral from liquidated vaults. The bid can be
    estimated only or estimated and submitted to the network.

.PARAMETER bid_amount
    The amount of CAT tokens to bid.

.PARAMETER auction_coin
    The coin identifier of the surplus auction to bid on.

.PARAMETER submit
    When specified, the bid transaction is automatically signed and submitted
    to the CircuitDao network via the Sage Wallet.

.EXAMPLE
    # Estimate a bid (do not submit)
    Invoke-CDSurplusAuctionBid -bid_amount 100000 -auction_coin "abc123..."

.EXAMPLE
    # Place a bid and submit to the network
    Invoke-CDSurplusAuctionBid -bid_amount 100000 -auction_coin "abc123..." -submit

.INPUTS
    None.

.OUTPUTS
    System.Object. Spend bundle response from the RPC call, or the submitted transaction if -submit.

.NOTES
    Requires the Sage Wallet to be logged in. The -submit flag requires the
    Sage Wallet to be unlocked.

.LINK
    Get-CDSurplusAuctions
    Invoke-CDSurplusAuctionSettle
    New-CDVaultBid
#>
function Invoke-CDSurplusAuctionBid{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [int32]$bid_amount,
        [Parameter(Mandatory=$true, Position=1)]
        [string]$auction_coin,
        [switch]$submit
    )

    $my_hash = Get-CDMyPuzzleHash
    $synthetic_pks = Get-CDSyntheticPKs

    $json = @{
        synthetic_pks = $synthetic_pks
        fee_per_cost = 0
        operation = "bid"
        args = @{
            amount = $bid_amount
            target_puzzle_hash = $my_hash
            info = $false
        }
    }

    $response = Invoke-CDRPC -endpoint "surplus_auctions/$($auction_coin)/" -json $json
    if($submit.IsPresent){
        $spend = invoke-sagerpc -endpoint sign_coin_spends -json @{
            auto_submit = $true
            partial = $false
            coin_spends = ($response.coin_spends)
        }
        return $spend
    } else {
        return $response
    }
}

# ============================================================
# Internal Helper Functions
# ============================================================

<#
.SYNOPSIS
    Retrieves the synthetic public keys associated with the current Sage Wallet.

.DESCRIPTION
    Queries the PowerSage module for the wallet's account derivations and extracts
    the public keys. These synthetic public keys are used by CircuitDao to identify
    and look up the caller's vaults and addresses.

.EXAMPLE
    $keys = Get-CDSyntheticPKs
    $keys
    # Returns an array of synthetic public key strings.

.INPUTS
    None.

.OUTPUTS
    System.String[]. Array of synthetic public key strings.

.NOTES
    This function queries up to 100 derivation entries. It is an internal dependency
    used by most other CircuitDao functions to authenticate requests.
    Requires the PowerSage module to be installed and the Sage Wallet to be running.

.LINK
    Get-CDMyVault
    Get-CDMySavingsVault
    Invoke-CDVaultAction
    Start-CDVaultAuction
    Get-CDMyTransactions
#>
function Get-CDSyntheticPKs{
    [CmdletBinding()]
    param()

    $keys = (PowerSage\Get-SageDerivations -limit 100 -offset 0 ).derivations.public_key
    return $keys
}

<#
.SYNOPSIS
    Retrieves the puzzle hash for the current user's wallet address.

.DESCRIPTION
    Internally calls Get-CDAddress to resolve the puzzle hash associated with
    the current Sage Wallet user. This puzzle hash is used as the target for
    bids, settlements, and other wallet operations.

.EXAMPLE
    $hash = Get-CDMyPuzzleHash
    $hash
    # Returns the puzzle hash string or $false if resolution fails.

.INPUTS
    None.

.OUTPUTS
    System.String. The puzzle hash string, or $false on failure.

.NOTES
    This is an internal helper function used by multiple vault action functions.

.LINK
    Get-CDAddress
    Start-CDVaultAuction
    New-CDVaultBid
    Invoke-CDSurplusAuctionBid
#>
function Get-CDMyPuzzleHash{
    [CmdletBinding()]
    param()

    $response = Get-CDAddress
    if($null -ne $response){
        return ($response."0".puzzle_hash)
    }
    return $false
}

<#
.SYNOPSIS
    Retrieves the wallet address and puzzle hash for the current user.

.DESCRIPTION
    Queries the CircuitDao API to resolve the wallet address associated with the
    user's synthetic public keys. Returns the puzzle hash needed for bids and settlements.

.EXAMPLE
    Get-CDAddress
    # Returns the wallet address and puzzle hash for the current user.

.INPUTS
    None.

.OUTPUTS
    System.Object. Wallet address object containing puzzle hash information.

.NOTES
    This is an internal helper function. Most users should use Get-CDMyPuzzleHash instead.

.LINK
    Get-CDMyPuzzleHash
    Get-CDSyntheticPKs
#>
function Get-CDAddress{
    [CmdletBinding()]
    param()

    $synthetic_pks = Get-CDSyntheticPKs

    $json = @{
        synthetic_pks = $synthetic_pks
        fee_per_cost = 0
        derivation_index = 0
        include_puzzle_hashes = $true
    }

    Invoke-CDRPC -endpoint "wallet/addresses" -json $json
}

<#
.SYNOPSIS
    Signs coin spends using the Sage Wallet.

.DESCRIPTION
    Low-level function that passes coin spend data to the Sage Wallet for signing.
    Supports both full and partial signatures. Can optionally auto-submit the signed
    transaction to the network.

.PARAMETER coin_spend
    The coin spend object or spend bundle to sign.

.PARAMETER submit
    When specified, the signed transaction is automatically submitted to the network.

.PARAMETER partial
    When specified, performs a partial signature instead of a full signature.

.EXAMPLE
    Invoke-CDSignCoinSpend -coin_spend $spendBundle -submit
    # Signs and submits the coin spend to the network.

.INPUTS
    System.Object. You can pipe a coin spend object to Invoke-CDSignCoinSpend.

.OUTPUTS
    System.Object. Signed coin spend response from the Sage Wallet.

.NOTES
    This is a lower-level function typically used internally by higher-level vault
    action functions. Most users should use Invoke-CDVaultAction instead.

.LINK
    Invoke-CDVaultAction
    Get-CDMyVault
#>
function Invoke-CDSignCoinSpend{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, Position=0, ValueFromPipeline)]
        $coin_spend,
        [switch]$submit,
        [switch]$partial
    )
    process {

        if($partial.IsPresent){
            $partial = $true

        } else {
            $partial = $false
        }

        if($submit.IsPresent){
            $auto_submit = $true
        } else {
            $auto_submit = $false
        }


        $json = @{
            auto_submit = $auto_submit
            coin_spends = (@($coin_spend.coin_spend))
            partial = $false
        }


        Invoke-SageRPC -endpoint sign_coin_spends -json $json
    }
}

# ============================================================
# Exported functions
# ============================================================

Export-ModuleMember -Function Get-CDMyVault, Invoke-CDVaultAction, Invoke-CDRPC, Get-CDVault, Get-CDVaults, Get-CDSyntheticPKs, Get-CDMySavingsVault, Invoke-CDSurplusAuctionBid, Invoke-CDSurplusAuctionSettle, Get-CDSurplusAuctions, Get-CDMyPuzzleHash, Get-CDAddress