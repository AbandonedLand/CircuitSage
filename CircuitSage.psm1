function Invoke-CDRPC{
    param(
        [Parameter(Mandatory=$true)]
        [string]$endpoint,
        $json
    )

    $json = $json | ConvertTo-Json

    $uri = "https://api.circuitdao.com/$endpoint" 
    #$uri = "https://testnet-api.circuitdao.com/$endpoint"
    Invoke-RestMethod -Method Post -Uri $uri -Body $json -ContentType "application/json" -AllowInsecureRedirect
}

function Get-CDOracle{
    $json =@{
        
    }
    Invoke-CircuitDaoRPC -endpoint oracle -json $json
}

<#
    endpoint 
    -- /protocol/state

#>
function Get-CDProtocolState{
    $json = @{
        vaults = $true
    }
    Invoke-CDRPC -endpoint "protocol/state" -json $json
}

function Get-CDVaults(){
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
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

function Get-CDVault{
    param(
        [Parameter(Mandatory=$true)]
        [string]$vault
    )
 
    Invoke-CDRPC -endpoint "vaults/$vault/" -json @{}
}

function Get-CDMyVault{
    $synthetic_pks = Get-CDSyntheticPKs
    $json = @{
        synthetic_pks = $synthetic_pks
    }
    Invoke-CDRPC -endpoint "vault" -json $json
}

function Get-CDMySavingsVault{
    $synthetic_pks = Get-CDSyntheticPKs
    $json = @{
        synthetic_pks = $synthetic_pks
    }
    Invoke-CDRPC -endpoint "savings" -json $json
}


function Invoke-CDVaultAction{
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("borrow","deposit","repay","withdraw")]
        [string]$operation,
        [Parameter(Mandatory=$true)]
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

function Get-CDSyntheticPKs{
    
    $keys = (PowerSage\Get-SageDerivations -limit 100 -offset 0 ).derivations.public_key
    return $keys
}

function Start-CDVaultAuction{
    param(
        [Parameter(Mandatory=$true)]
        [string]$vault
    )

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

function Get-CDMyPuzzleHash{
    $response = Get-CDAddress
    if($null -ne $response){
        return ($response."0".puzzle_hash)
    }
    return $false
}

function Get-CDAddress{
        
    $synthetic_pks = Get-CDSyntheticPKs
    

    $json = @{
        synthetic_pks = $synthetic_pks
        fee_per_cost = 0
        derivation_index = 0
        include_puzzle_hashes = $true
    }

    Invoke-CDRPC -endpoint "wallet/addresses" -json $json
   
}

function New-CDVaultBid{
    param(
        [Parameter(Mandatory=$true)]
        [string]$vault,
        [Parameter(Mandatory=$true)]
        [UInt64]$amount,
        [Parameter(Mandatory=$true)]
        [UInt64]$max_bid_price,
        [Parameter(Mandatory=$true)]
        [switch]$info
    )
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

function Invoke-CDSignCoinSpend{
    param(
        [Parameter(Mandatory=$true)]
        $coin_spend,
        [switch]$submit,
        [switch]$partial
    )


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

function Get-CDMyTransactions{
    param(
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