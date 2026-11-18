while($true){
$to_liquidate = Get-CDVaults -status PendingLiquidation

if($to_liquidate.count -gt 0){
    
    Start-CDVaultAuction -vault ($to_liquidate[0].name) -fee_per_cost 13 -submit 
    $pending = Get-SagePendingTransactions
    while($pending){
        start-sleep 30
        $pending = Get-SagePendingTransactions
    }

}

$to_bid = Get-CDVaults -status InLiquidation
if($to_bid.count -gt 0){
    if($to_bid[0].auction_ttl -lt 600){
        Submit-CDVaultBid -vault ($to_bid[0].name) -amount ($to_bid[0].debt_owed_to_vault) -max_bid_price ($to_bid[0].auction_price + 0.01) -submit
        $pending = Get-SagePendingTransactions
        while($pending){
            start-sleep 30
            $pending = Get-SagePendingTransactions
        }
    }
}
start-sleep 70
}