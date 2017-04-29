$script:ResourceRootPath = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent)

# Import the xCertificate Resource Module (to import the common modules)
Import-Module -Name (Join-Path -Path $script:ResourceRootPath -ChildPath 'xDFS.psd1')

# Import Localization Strings
$localizedData = Get-LocalizedData `
    -ResourceName 'MSFT_xDFSNamespaceServerConfiguration' `
    -ResourcePath (Split-Path -Parent $Script:MyInvocation.MyCommand.Path)

<#
    This is an array of all the parameters used by this resource
    If the property Restart is true then when this property is updated the service
    Will be restarted.
#>
data ParameterList
{
    @(
        @{ Name = 'LdapTimeoutSec';            Type = 'Uint32'  },
        @{ Name = 'SyncIntervalSec';           Type = 'String'  },
        @{ Name = 'UseFQDN';                   Type = 'Uint32'; Restart = $True }
    )
}

function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([Hashtable])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateSet('Yes')]
        [System.String]
        $IsSingleInstance
    )

    Write-Verbose -Message ( @(
            "$($MyInvocation.MyCommand): "
            $($LocalizedData.GettingNamespaceServerConfigurationMessage)
        ) -join '' )

    # The ComputerName will always be LocalHost unless a good reason can be provided to
    # enable it as a parameter.
    $ComputerName = 'LocalHost'

    # Get the current DFSN Server Configuration
    $ServerConfiguration = Get-DfsnServerConfiguration `
        -ComputerName $ComputerName `
        -ErrorAction Stop

    # Generate the return object.
    $ReturnValue = @{
        IsSingleInstance = 'Yes'
    }
    foreach ($parameter in $ParameterList)
    {
        $ReturnValue += @{ $parameter.Name = $ServerConfiguration.$($parameter.name) }
    } # foreach

    return $ReturnValue
} # Get-TargetResource

function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateSet('Yes')]
        [System.String]
        $IsSingleInstance,

        [Parameter()]
        [System.UInt32]
        $LdapTimeoutSec,

        [Parameter()]
        [System.UInt32]
        $SyncIntervalSec,

        [Parameter()]
        [System.Boolean]
        $UseFQDN
    )

    Write-Verbose -Message ( @(
            "$($MyInvocation.MyCommand): "
            $($LocalizedData.SettingNamespaceServerConfigurationMessage)
        ) -join '' )

    # The ComputerName will always be LocalHost unless a good reason can be provided to
    # enable it as a parameter.
    $ComputerName = 'LocalHost'

    # Get the current DFSN Server Configuration
    $ServerConfiguration = Get-DfsnServerConfiguration `
        -ComputerName $ComputerName `
        -ErrorAction Stop

    # Generate a list of parameters that will need to be changed.
    $ChangeParameters = @{}
    $Restart = $False
    foreach ($parameter in $ParameterList)
    {
        $parameterSource = $ServerConfiguration.$($parameter.name)
        $parameterNew = (Get-Variable -Name ($parameter.name)).Value
        if ($PSBoundParameters.ContainsKey($parameter.Name) `
            -and ($ParameterSource -ne $ParameterNew))
        {
            $ChangeParameters += @{
                $($parameter.name) = $ParameterNew
            }
            Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                $($LocalizedData.NamespaceServerConfigurationUpdateParameterMessage) `
                    -f $parameter.Name,$ParameterNew
                ) -join '' )
            if ($parameter.Restart)
            {
                $Restart = $True
            } # if
        } # if
    } # foreach
    if ($ChangeParameters.Count -gt 0)
    {
        # Update any parameters that were identified as different
        $null = Set-DfsnServerConfiguration `
            -ComputerName $ComputerName `
            @ChangeParameters `
            -ErrorAction Stop

        Write-Verbose -Message ( @(
            "$($MyInvocation.MyCommand): "
            $($LocalizedData.NamespaceServerConfigurationUpdatedMessage)
            ) -join '' )

        if ($Restart)
        {
            # Restart the DFS Service
            $null = Restart-Service `
                -Name DFS `
                -Force `
                -ErrorAction Stop

            Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                $($LocalizedData.NamespaceServerConfigurationServiceRestartedMessage)
                ) -join '' )
        }
    } # if
} # Set-TargetResource

function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateSet('Yes')]
        [System.String]
        $IsSingleInstance,

        [Parameter()]
        [System.UInt32]
        $LdapTimeoutSec,

        [Parameter()]
        [System.UInt32]
        $SyncIntervalSec,

        [Parameter()]
        [System.Boolean]
        $UseFQDN
    )

    Write-Verbose -Message ( @(
            "$($MyInvocation.MyCommand): "
            $($LocalizedData.TestingNamespaceServerConfigurationMessage)
        ) -join '' )

    # The ComputerName will always be LocalHost unless a good reason can be provided to
    # enable it as a parameter.
    $ComputerName = 'LocalHost'

    # Flag to signal whether settings are correct
    [System.Boolean] $DesiredConfigurationMatch = $true

    # Get the current DFSN Server Configuration
    $ServerConfiguration = Get-DfsnServerConfiguration `
        -ComputerName $ComputerName `
        -ErrorAction Stop

    # Check each parameter
    foreach ($parameter in $ParameterList)
    {
        $parameterSource = $ServerConfiguration.$($parameter.name)
        $parameterNew = (Get-Variable -Name ($parameter.name)).Value
        if ($PSBoundParameters.ContainsKey($parameter.Name) `
            -and ($ParameterSource -ne $ParameterNew)) {
            Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                $($LocalizedData.NamespaceServerConfigurationParameterNeedsUpdateMessage) `
                    -f $parameter.Name,$ParameterSource,$ParameterNew
                ) -join '' )
            $desiredConfigurationMatch = $false
        } # if
    } # foreach

    return $DesiredConfigurationMatch
} # Test-TargetResource

# Helper Functions
function New-TerminatingError
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $ErrorId,

        [Parameter(Mandatory = $true)]
        [System.String]
        $ErrorMessage,

        [Parameter(Mandatory = $true)]
        [System.Management.Automation.ErrorCategory]
        $ErrorCategory
    )

    $exception = New-Object `
        -TypeName System.InvalidOperationException `
        -ArgumentList $errorMessage
    $errorRecord = New-Object `
        -TypeName System.Management.Automation.ErrorRecord `
        -ArgumentList $exception, $errorId, $errorCategory, $null
    $PSCmdlet.ThrowTerminatingError($errorRecord)
}

Export-ModuleMember -Function *-TargetResource
