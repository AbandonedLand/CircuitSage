# CircuitSage
Interact with CircuitDao through Powershell and Sage RPC

### Installation
Open PowerShell
```PowerShell
Install-Module -name CircuitSage
```

### Description
This module is a PowerShell wrapper that interacts with [Circuit Dao](https://circuitdao.com) through the [Sage Wallet](https://github.com/xch-dev/sage). This module lets you view vaults and interact with your vaults.

Governance actions will be added later.

### Get Your Lending Vault
View your vault for the current logged in Sage Wallet.
```PowerShell
Get-CDMyVault


name                        : f51972063332446ede1f44167b88708021c5090801586f7d2edeb1834bad80
inner_puzzle_hash           : 
synthetic_pk                :                               
collateral                  : 1715000000000000
principal                   : 1890984
stability_fees              : 1284
stability_fees_to_transfer  : 1283
debt_owed_to_vault          : 1892268
debt                        : 1892268
min_deposit                 : 1
max_withdraw                : 381629721518987
max_borrow                  : 541594
min_repay                   : 1
max_repay                   : 1892268
collateral_ratio            : 2.14797798197718
liquidation_price           : 183
seized                      : False
nearing_liquidation         : False
is_liquidatable             : False
is_startable                : False
in_liquidation              : False
is_biddable                 : False
is_restartable              : False
in_bad_debt                 : False
initiator_incentive_balance :
auction_ttl                 :
auction_price               :
```

### Interact with Lending Vault
```PowerShell
# - NOTE: amount is in mojo (smallest unit of cat or xch)
# -       to make it easier you can use ( amount | ConvertTo-XchMojo) for XCH
# -       to make it easier you can use ( amount | ConvertTo-CatMojo) for Cats

# Get the spend bundle needed to deposit 65 XCH
Invoke-CDVaultAction -operation deposit -amount 65000000000000


# To Deposit 65 XCH into vault add the [ -submit ] option at the end to request and sign the transaction in one step.
Invoke-CDVaultAction -operation deposit -amount 65000000000000 -submit

# Borrow 200 BYC
Invoke-CDVaultAction -operation borrow -amount 200000 -submit

# Repay 200.02 BYC 
# Note: Using the helper function to convert 200.02 to the mojo amount of 200020
Invoke-CDVaultAction -operation repay -amount ( 200.02 | ConvertTo-CatMojo) -submit

# Withdraw the Deposited XCH (65)
Invoke-CDVaultAction -operation withdraw -amount (65 | ConvertTo-XchMojo) -submit
```

### Get a list of vaults
There are a few different satatus you can search for.

```PowerShell
Get-CDVaults -status Any
Get-CDVaults -status BadDebt
Get-CDVaults -status InLiquidation
Get-CDVaults -status NearingLiquidation
Get-CDVaults -status PendingLiquidation

```

Example of NearingLiquidation

```PowerShell
# Get list of vaults to variable
$vaults = Get-CDVaults -status NearingLiquidation

# Show the list
$vaults

collateral           : 500000000000000
principal            : 603581
auction_state        : 80
in_bad_debt          : False
name                 : 47f2055a01ef8db5c874df595aba262145c8b0134a982911f93fda558c19b33d
discounted_principal : 599166
inner_puzzle_hash    : 4a0fea393414ecf1ff3a8b5703924c920e6a673c124a562ee6cab0d7614fe6e7
height               : 8493330

collateral           : 155829972717000
principal            : 186670
auction_state        : 80
in_bad_debt          : False
name                 : 5b6138c2dfe1f425da66d6af8f69ec75e402cece652e6553ee3a828cd08bd828
discounted_principal : 185751
inner_puzzle_hash    : 6d1e8880db3c8266f87625d84b17dbeb0dd83221692314248f1e0cf87bdad2fe
height               : 8532422

collateral           : 10000000000
principal            : 0
auction_state        : 80
in_bad_debt          : False
name                 : f8ad85e8eb8315fadca3eec77fbdc4094ffe5476d6a7b7ea61ef6113cdcf63ce
discounted_principal : 12
inner_puzzle_hash    : 9d4024cea11000afb95531c7c461c90ace97a2fb7903d506c9dc4665f71abf1c
height               : 8174600

collateral           : 19000000000000
principal            : 25000
auction_state        : 80
in_bad_debt          : False
name                 : 640b6ae6ac265f9d71a1d82f0c6d36d21f8ad22d2d4f23a9bbe0a034d9871707
discounted_principal : 24921
inner_puzzle_hash    : ac712f473b454a56fe2aca8d180361938b068a5582cdb181ca9b5cb3d0b1342f
height               : 8290740
```

### View a specific vault

```PowerShell
Get-CDVault -vault 47f2055a01ef8db5c874df595aba262145c8b0134a982911f93fda558c19b33d
# Can also use the variable from the vaults list
# Get-CDVault -vault $vaults[0].name
name                        : 47f2055a01ef8db5c874df595aba262145c8b0134a982911f93fda558c19b33d
inner_puzzle_hash           : 4a0fea393414ecf1ff3a8b5703924c920e6a673c124a562ee6cab0d7614fe6e7
synthetic_pk                :
collateral                  : 500000000000000
principal                   : 603581
stability_fees              : 711
stability_fees_to_transfer  : 711
debt_owed_to_vault          : 604292
debt                        : 604292
min_deposit                 : 1
max_withdraw                : 74190869198312
max_borrow                  : 105288
min_repay                   : 1
max_repay                   : 604292
collateral_ratio            : 1.96097250997862
liquidation_price           : 200
seized                      : False
nearing_liquidation         : True
is_liquidatable             : False
is_startable                : False
in_liquidation              : False
is_biddable                 : False
is_restartable              : False
in_bad_debt                 : False
initiator_incentive_balance :
auction_ttl                 :
auction_price               :
```