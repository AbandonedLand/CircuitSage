@{
    RootModule = 'CircuitSage.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'dfc0ed88-44b8-4f71-b169-c07b02d1109b'
    Author = 'MayorAbandoned'
    Copyright = '(c) MayorAbandoned. All rights reserved.'

    Description = 'Terminal application for trading Chia Blockchain assets using the Sage Wallet.'
    PowerShellVersion = '7.4'
    RequiredModules = @(
        @{ ModuleName = 'PowerSage'},
        'PwshSpectreConsole'
    )

    FunctionsToExport = @('*')

    CmdletsToExport = @()


    VariablesToExport = '*'


    AliasesToExport = @()
    PrivateData = @{

        PSData = @{
            ProjectUri = 'https://github.com/AbandonedLand/CircuitSage'
        } 

    } 
}

