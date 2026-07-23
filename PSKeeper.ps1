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
            Send-SageCat -amount $crt_balance -address $first_address -asset_id $crt_id -fee 0 -auto_submit
            Wait-OnPendingTransaction
        }
    }
    
}