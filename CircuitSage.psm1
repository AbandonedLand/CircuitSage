function Invoke-CDRPC{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [ValidateNotNullOrEmpty()]
        [string]$endpoint,
        [Parameter(Mandatory=$true, Position=1)]
        $json
    )
    process {
        $normalizedEndpoint = $endpoint.Trim().TrimStart('/')
        $uri = "https://api.circuitdao.com/$normalizedEndpoint"

        if ($json -is [string]) {
            $requestBody = $json
        } else {
            $requestBody = $json | ConvertTo-Json -Depth 20 -Compress
        }

        try{
            
            Invoke-RestMethod -Method Post -Uri $uri -Body $requestBody -ContentType "application/json" -AllowInsecureRedirect -ErrorAction Stop -MaximumRetryCount 3 -RetryIntervalSec 2
            
        } catch {
            $responseDetails = $_.ErrorDetails.Message

            if ([string]::IsNullOrWhiteSpace($responseDetails) -and $_.Exception.Response) {
                try {
                    $reader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
                    $responseDetails = $reader.ReadToEnd()
                    $reader.Dispose()
                } catch {
                    $responseDetails = $null
                }
            }

            $errorMessage = "Invoke-CDRPC failed for endpoint '$normalizedEndpoint'. URI: $uri. Reason: $($_.Exception.Message)"
            if (-not [string]::IsNullOrWhiteSpace($responseDetails)) {
                $errorMessage = "$errorMessage`nResponse: $responseDetails"
            }

            Write-Error -Message $errorMessage
            throw
        }   
        
    }
}

function Get-CDOracle{
    [CmdletBinding()]
    param()

    $json = @{}
    Invoke-SpectreCommandWithStatus -Spinner Aesthetic -Title "Getting Oracle Info:" -ScriptBlock {
        return Invoke-CDRPC -endpoint "oracle" -json $json
    }
}

function Get-CDProtocolState{
    [CmdletBinding()]
    param()

    $json = @{
        vaults = $true
    }
    Invoke-SpectreCommandWithStatus -Spinner Aesthetic -Title "Getting Protocol State:" -ScriptBlock {
        return Invoke-CDRPC -endpoint "protocol/state" -json $json
    } 
}

function Get-CDVaults{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [ValidateSet("Any","NearingLiquidation","PendingLiquidation","InLiquidation","BadDebt")]
        [string]$status
    )

    $vaults = Invoke-SpectreCommandWithStatus -Spinner Aesthetic -Title "Getting Vaults:" -ScriptBlock {
        return Invoke-CDRPC -endpoint "protocol/state" -json $json
    }

    switch ($status) {

        "NearingLiquidation" { return $vaults.vaults_nearing_liquidation  }
        "PendingLiquidation" { return $vaults.vaults_pending_liquidation }
        "InLiquidation" { return $vaults.vaults_in_liquidation }
        "BadDebt" { return $vaults.vaults_bad_debt}
        "Any" { return $vaults }
    }
    
}

function Move-CDVaultStabilityFee{
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [string]$vault_name,
        [int32]$fee_per_cost = 0,
        [switch]$submit,
        [switch]$wait
    )

    $synthetic_pks = Get-CDSyntheticPKs
    $json = @{
        synthetic_pks = $synthetic_pks
        vault_name = $vault_name
        fee_per_cost = $fee_per_cost
    }
    $response = Invoke-SpectreCommandWithStatus -Spinner Aesthetic -Title "Building transaction:" -ScriptBlock {
        return Invoke-CDRPC -endpoint '/vaults/transfer_stability_fees' -json $json 
    }
    if($submit.IsPresent){
        $spend = Invoke-SageRPC -endpoint sign_coin_spends -json @{
            auto_submit = $true
            partial = $false
            coin_spends = ($response.bundle.coin_spends)
        }
        if($wait.IsPresent){
            $pending = Get-SagePendingTransactions
            Invoke-SpectreCommandWithStatus -Spinner Aesthetic -Title "Finalizing transaction" -ScriptBlock {
                start-sleep 5
                while($pending.count -gt 0){
                    $pending = Get-SagePendingTransactions
                    start-sleep 5
                }
            }
        }
        return $spend
    } else {
        return $response
    }
    
}

function Get-CDAllVaults{
    
    Invoke-SpectreCommandWithStatus -Spinner Aesthetic -Title "Getting All Vaults:" -ScriptBlock { Invoke-CDRPC -endpoint '/vaults' -json @{} }
}

function Get-CDVault{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, Position=0, ValueFromPipeline)]
        [string]$vault
    )
    process {
        Invoke-SpectreCommandWithStatus -Spinner Aesthetic -Title "Getting Vault: $vault" -ScriptBlock { 
            return Invoke-CDRPC -endpoint "vaults/$vault/" -json @{} 
        }
    }
}

function Get-CDMyVault{
    [CmdletBinding()]
    param()

    $synthetic_pks = Get-CDSyntheticPKs
    $json = @{
        synthetic_pks = $synthetic_pks
    }
    Invoke-CDRPC -endpoint "vault" -json $json
}

function Get-CDMySavingsVault{
    [CmdletBinding()]
    param()

    $synthetic_pks = Get-CDSyntheticPKs
    $json = @{
        synthetic_pks = $synthetic_pks
    }
    Invoke-CDRPC -endpoint "savings" -json $json
}

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

function Submit-CDVaultBid{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, Position=0, ValueFromPipeline)]
        [string]$vault,
        [Parameter(Mandatory=$true, Position=1)]
        [UInt64]$amount,
        [Parameter(Mandatory=$true, Position=2)]
        [UInt64]$max_bid_price
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

function Get-CDSurplusAuctions{
    [CmdletBinding()]
    param()
    $auctions = Invoke-CDRPC -endpoint "surplus_auctions" -json @{}
    if($auctions.count -lt 1){
        Write-Host "There are no auctions currently"
        return $false
    } else {
        return $auctions
    }

}


function Complete-CDSurplusAuction{
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

function Submit-CDSurplusAuctionBid{
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

    $response = Invoke-SpectreCommandWithStatus -Spinner Aesthetic -Title "Creating Bid: $vault" -ScriptBlock { 
        return Invoke-CDRPC -endpoint "surplus_auctions/$($auction_coin)/" -json $json
    }
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

function Get-CDSyntheticPKs{
    [CmdletBinding()]
    param()

    try{
        $keys = (PowerSage\Get-SageDerivations -limit 100 -offset 0 ).derivations.public_key
    } catch {
        Write-Error "Failed to get SyntheticPKs"
        throw
    }
    
    return $keys
}

function Get-CDMyPuzzleHash{
    [CmdletBinding()]
    param()

    try{

        $response = Get-CDAddress
        return ($response."0".puzzle_hash)
    } catch {
        Write-Error "Could not fetch PuzzleHash"
        throw
    }
    
    
}

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

function Approve-CDCoinSpend{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, Position=0, ValueFromPipeline)]
        [array]$coin_spend
    )
    process {

        $json = @{
            auto_submit = $true
            coin_spends = $coin_spend
            partial = $false
        }

        Invoke-SageRPC -endpoint sign_coin_spends -json $json
    }
}

function Start-CDSurplusAuction{
    $pks = Get-CDSyntheticPKs
    $json = @{
        synthetic_pks = $pks
        fee_per_cost=0
        only_estimate_fee=$false
    }
    Invoke-CDRPC -endpoint '/surplus_auctions/start' -json $json
}

function Get-CDTreasury{
    Invoke-CDRPC -endpoint "/treasury" -json @{}
}


Export-ModuleMember -Function Get-CDMyVault, Invoke-CDVaultAction, Invoke-CDRPC, Get-CDVault, Get-CDVaults, Get-CDSyntheticPKs, Get-CDMySavingsVault, Invoke-CDSurplusAuctionBid, Invoke-CDSurplusAuctionSettle, Get-CDSurplusAuctions, Get-CDMyPuzzleHash, Get-CDAddress, Get-CDAllVaults, Move-CDVaultStabilityFee, Get-CDOracle