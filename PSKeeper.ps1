function Watch-ForLiquidations(){
    $alert_sent = $false

    while(-not $alert_sent){
        $next_vault = ((Get-CDAllVaults) | Sort-Object liquidation_price -Descending)[0].liquidation_price
        $oracle = Get-CDOracle
        foreach($price in $oracle.price_infos){
            if($next_vault -ge $price[0]){
                Send-Pushover -Message "A vault is about to liquidate"
                $alert_sent = $true
            }

        }
        Write-Host "Waiting 120 seconds"
        Start-Sleep -Seconds 120
    }
}

function Join-CRTCats {
    $crt_id = "ea3ace5525d6aaf6d921b66052afc67da11c820b676de91d61ae1a766c8ce615"
    $first_address = (Get-SageDerivations -limit 1 -offset 0).derivations[0].address
    $crt_balance = (get-sagecat -asset_id $crt_id).token.balance
    if($crt_balance -gt 1){
        $crt_coin_count = ((get-sagecoins -asset_id $crt_id).coins | Where-Object {$_.spent_height -eq 0}).count
        if($crt_coin_count -gt 1){
            Send-SageCat -amount $crt_balance -address $first_address -asset_id $crt_id -fee 0 -auto_submit $true
            Wait-OnPendingTransaction
        }
    }   
}

function Watch-ForSurplusTrigger{
    $alert_sent = $false
    while(-not ($alert_sent)){
        $amt = (((Get-CDTreasury).treasury_balance) + ((Get-CDAllVaults).stability_fees_to_transfer  | measure-object -sum).Sum)-1600000
        if($amt -ge 50000){
            Send-Pushover -Message "Surplus auction ready to be triggered" -Title "Surplus Auction - Can be forced"
            $alert_sent = $true
        }
        Start-Sleep -Seconds 120
    }
    
}

function Watch-ForSurplusAuction{
    $alert_sent = $false
    while(-not ($alert_sent)){
        $amt = ((Get-CDTreasury).treasury_balance)
        $amt
        if($amt -ge 1650000){
            Send-Pushover -Message "Surplus auction ready to be started" -Title "Surplus Auction - Can Start"
            $alert_sent = $true
        }
        Start-Sleep -Seconds 120
    }
    
}

function Remove-CDLargestStabilityFee{
    param(
        [int32]$min_price = 100
    )
    $vaults = ((Get-CDAllVaults) | Sort-Object stability_fees_to_transfer -Descending)
    if(($vaults[0].stability_fees_to_transfer) -gt $min_price){
        try {
            $output = Move-CDVaultStabilityFee -vault_name ($vaults[0].name) -fee_per_cost 0 -submit -wait
            Write-Host "Moved $($vaults[0].stability_fees_to_transfer) from $($vaults[0].name)"
        }
        catch {
            Write-Error "Could not move funds"
        }
    } else {
        Write-Information "No funds to move at this time."
    }
}

function Start-StabilityFeeBot{
    while($true){
        Get-Date

        Remove-CDLargestStabilityFee
        Write-Host "Sleeping for 5 minutes"
        Start-Sleep -Seconds 600
    }
}

function Watch-SurplusBid{
     $alert_sent = $false
    while(-not ($alert_sent)){
    $auction = Get-CDSurplusAuctions
    if($auction.last_bid.target_puzzle_hash -ne '44afacdc162edfb610d5b4d7193c467967ffef38baa5907b0c57e00409b756e6'){
        Send-Pushover -Message "outbid"
    }
    
    }

}