$script:ResourceRootPath = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent)

# Import the xCertificate Resource Module (to import the common modules)
Import-Module -Name (Join-Path -Path $script:ResourceRootPath -ChildPath 'xDFS.psd1')

# Import Localization Strings
$localizedData = Get-LocalizedData `
    -ResourceName 'MSFT_xDFSNamespaceFolder' `
    -ResourcePath (Split-Path -Parent $Script:MyInvocation.MyCommand.Path)

function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([Hashtable])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Path,

        [Parameter(Mandatory = $true)]
        [System.String]
        $TargetPath,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Present','Absent')]
        [System.String]
        $Ensure
    )

    Write-Verbose -Message ( @(
            "$($MyInvocation.MyCommand): "
            $($LocalizedData.GettingNamespaceFolderMessage) `
                -f $Path,$TargetPath
        ) -join '' )

    # Generate the return object assuming absent.
    $ReturnValue = @{
        Path = $Path
        TargetPath = $TargetPath
        Ensure = 'Absent'
    }

    # Remove the Ensue parmeter from the bound parameters
    $null = $PSBoundParameters.Remove('Ensure')

    # Lookup the existing Namespace Folder
    $Folder = Get-Folder `
        -Path $Path

    if ($Folder)
    {
        # The namespace folder exists
        Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                $($LocalizedData.NamespaceFolderExistsMessage) `
                    -f $Path,$TargetPath
            ) -join '' )
    }
    else
    {
        # The namespace folder does not exist
        Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                $($LocalizedData.NamespaceFolderDoesNotExistMessage) `
                    -f $Path,$TargetPath
            ) -join '' )
        return $ReturnValue
    }

    $ReturnValue += @{
        TimeToLiveSec                = $Folder.TimeToLiveSec
        State                        = $Folder.State
        Description                  = $Folder.Description
        EnableInsiteReferrals        = ($Folder.Flags -contains 'Insite Referrals')
        EnableTargetFailback         = ($Folder.Flags -contains 'Target Failback')
    }

    # DFS Folder exists but does target exist?
    $Target = Get-FolderTarget `
        -Path $Path `
        -TargetPath $TargetPath

    if ($Target)
    {
        # The target exists in this namespace
        $ReturnValue.Ensure = 'Present'
        $ReturnValue += @{
            ReferralPriorityClass        = $Target.ReferralPriorityClass
            ReferralPriorityRank         = $Target.ReferralPriorityRank
        }

        Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                $($LocalizedData.NamespaceFolderTargetExistsMessage) `
                    -f $Path,$TargetPath
            ) -join '' )
    }
    else
    {
        # The target does not exist in this namespace
        Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                $($LocalizedData.NamespaceFolderTargetDoesNotExistMessage) `
                    -f $Path,$TargetPath
            ) -join '' )
    }

    return $ReturnValue
} # Get-TargetResource

function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Path,

        [Parameter(Mandatory = $true)]
        [System.String]
        $TargetPath,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Present','Absent')]
        [System.String]
        $Ensure,

        [Parameter()]
        [System.String]
        $Description,

        [Parameter()]
        [System.UInt32]
        $TimeToLiveSec,

        [Parameter()]
        [System.Boolean]
        $EnableInsiteReferrals,

        [Parameter()]
        [System.Boolean]
        $EnableTargetFailback,

        [Parameter()]
        [ValidateSet('Global-High','SiteCost-High','SiteCost-Normal','SiteCost-Low','Global-Low')]
        [System.String]
        $ReferralPriorityClass,

        [Parameter()]
        [System.UInt32]
        $ReferralPriorityRank
    )

    Write-Verbose -Message ( @(
            "$($MyInvocation.MyCommand): "
            $($LocalizedData.SettingNamespaceFolderMessage) `
                -f $Path,$TargetPath
        ) -join '' )

    # Lookup the existing Namespace Folder
    $Folder = Get-Folder `
        -Path $Path

    if ($Ensure -eq 'Present')
    {
        # Set desired Configuration
        if ($Folder)
        {
            # Does the Folder need to be updated?
            [System.Boolean] $FolderChange = $false

            # The Folder properties that will be updated
            $FolderProperties = @{
                State = 'online'
            }

            if (($Description) `
                -and ($Folder.Description -ne $Description))
            {
                $FolderProperties += @{
                    Description = $Description
                }
                $FolderChange = $true
            }

            if (($TimeToLiveSec) `
                -and ($Folder.TimeToLiveSec -ne $TimeToLiveSec))
            {
                $FolderProperties += @{
                    TimeToLiveSec = $TimeToLiveSec
                }
                $FolderChange = $true
            }

            if (($null -ne $EnableInsiteReferrals) `
                -and (($Folder.Flags -contains 'Insite Referrals') -ne $EnableInsiteReferrals))
            {
                $FolderProperties += @{
                    EnableInsiteReferrals = $EnableInsiteReferrals
                }
                $FolderChange = $true
            }

            if (($null -ne $EnableTargetFailback) `
                -and (($Folder.Flags -contains 'Target Failback') -ne $EnableTargetFailback))
            {
                $FolderProperties += @{
                    EnableTargetFailback = $EnableTargetFailback
                }
                $FolderChange = $true
            }

            if ($FolderChange)
            {
                # Update Folder settings
                $null = Set-DfsnFolder `
                    -Path $Path `
                    @FolderProperties `
                    -ErrorAction Stop

                $FolderProperties.GetEnumerator() | ForEach-Object -Process {
                    Write-Verbose -Message ( @(
                        "$($MyInvocation.MyCommand): "
                        $($LocalizedData.NamespaceFolderUpdateParameterMessage) `
                            -f $Path,$TargetPath,$_.name, $_.value
                    ) -join '' )
                }
            }

            # Get target
            $Target = Get-FolderTarget `
                -Path $Path `
                -TargetPath $TargetPath

            # Does the target need to be updated?
            [System.Boolean] $TargetChange = $false

            # The Target properties that will be updated
            $TargetProperties = @{}

            # Check the target properties
            if (($ReferralPriorityClass) `
                -and ($Target.ReferralPriorityClass -ne $ReferralPriorityClass))
            {
                $TargetProperties += @{
                    ReferralPriorityClass = ($ReferralPriorityClass -replace '-','')
                }
                $TargetChange = $true
            }

            if (($ReferralPriorityRank) `
                -and ($Target.ReferralPriorityRank -ne $ReferralPriorityRank))
            {
                $TargetProperties += @{
                    ReferralPriorityRank = $ReferralPriorityRank
                }
                $TargetChange = $true
            }

            # Is the target a member of the namespace?
            if ($Target)
            {
                # Does the target need to be changed?
                if ($TargetChange)
                {
                    # Update target settings
                    $null = Set-DfsnFolderTarget `
                        -Path $Path `
                        -TargetPath $TargetPath `
                        @TargetProperties `
                        -ErrorAction Stop
                }
            }
            else
            {
                # Add target to Namespace
                $null = New-DfsnFolderTarget `
                    -Path $Path `
                    -TargetPath $TargetPath `
                    @TargetProperties `
                    -ErrorAction Stop
            }

            # Output the target parameters that were changed/set
            $TargetProperties.GetEnumerator() | ForEach-Object -Process {
                Write-Verbose -Message ( @(
                    "$($MyInvocation.MyCommand): "
                    $($LocalizedData.NamespaceFolderTargetUpdateParameterMessage) `
                        -f $Path,$TargetPath,$_.name, $_.value
                ) -join '' )
            }
        }
        else
        {
            # Prepare to use the PSBoundParameters as a splat to created
            # The new DFS Namespace Folder.
            $null = $PSBoundParameters.Remove('Ensure')

            # Correct the ReferralPriorityClass field
            if ($ReferralPriorityClass)
            {
                $PSBoundParameters.ReferralPriorityClass = ($ReferralPriorityClass -replace '-','')
            }

            # Create New-DfsnFolder
            $null = New-DfsnFolder `
                @PSBoundParameters `
                -ErrorAction Stop

            $PSBoundParameters.GetEnumerator() | ForEach-Object -Process {
                Write-Verbose -Message ( @(
                    "$($MyInvocation.MyCommand): "
                    $($LocalizedData.NamespaceFolderUpdateParameterMessage) `
                        -f $Path,$TargetPath,$_.name, $_.value
                ) -join '' )
            }
        }
    }
    else
    {
        # The Namespace Folder Target should not exist

        # Get Folder target
        $Target = Get-FolderTarget `
            -Path $Path `
            -TargetPath $TargetPath

        if ($Target)
        {
            # Remove the target from the Namespace Folder
            $null = Remove-DfsnFolderTarget `
                -Path $Path `
                -TargetPath $TargetPath `
                -Confirm:$false `
                -ErrorAction Stop

            Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                $($LocalizedData.NamespaceFolderTargetRemovedMessage) `
                    -f $Path,$TargetPath
            ) -join '' )
        }
    }
} # Set-TargetResource

function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Path,

        [Parameter(Mandatory = $true)]
        [System.String]
        $TargetPath,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Present','Absent')]
        [System.String]
        $Ensure,

        [Parameter()]
        [System.String]
        $Description,

        [Parameter()]
        [System.UInt32]
        $TimeToLiveSec,

        [Parameter()]
        [System.Boolean]
        $EnableInsiteReferrals,

        [Parameter()]
        [System.Boolean]
        $EnableTargetFailback,

        [Parameter()]
        [ValidateSet('Global-High','SiteCost-High','SiteCost-Normal','SiteCost-Low','Global-Low')]
        [System.String]
        $ReferralPriorityClass,

        [Parameter()]
        [System.UInt32]
        $ReferralPriorityRank
    )

    Write-Verbose -Message ( @(
            "$($MyInvocation.MyCommand): "
            $($LocalizedData.TestingNamespaceFolderMessage) `
                -f $Path,$TargetPath
        ) -join '' )

    # Flag to signal whether settings are correct
    [System.Boolean] $DesiredConfigurationMatch = $true

    # Lookup the existing Namespace Folder
    $Folder = Get-Folder `
        -Path $Path

    if ($Ensure -eq 'Present')
    {
        # The Namespace Folder should exist
        if ($Folder)
        {
            # The Namespace Folder exists and should

            # Check the Namespace parameters
            if (($Description) `
                -and ($Folder.Description -ne $Description)) {
                Write-Verbose -Message ( @(
                    "$($MyInvocation.MyCommand): "
                    $($LocalizedData.NamespaceFolderParameterNeedsUpdateMessage) `
                        -f $Path,$TargetPath,'Description'
                    ) -join '' )
                $desiredConfigurationMatch = $false
            }

            if (($TimeToLiveSec) `
                -and ($Folder.TimeToLiveSec -ne $TimeToLiveSec)) {
                Write-Verbose -Message ( @(
                    "$($MyInvocation.MyCommand): "
                    $($LocalizedData.NamespaceFolderParameterNeedsUpdateMessage) `
                        -f $Path,$TargetPath,'TimeToLiveSec'
                    ) -join '' )
                $desiredConfigurationMatch = $false
            }

            if (($null -ne $EnableInsiteReferrals) `
                -and (($Folder.Flags -contains 'Insite Referrals') -ne $EnableInsiteReferrals)) {
                Write-Verbose -Message ( @(
                    "$($MyInvocation.MyCommand): "
                    $($LocalizedData.NamespaceFolderParameterNeedsUpdateMessage) `
                        -f $Path,$TargetPath,'EnableInsiteReferrals'
                    ) -join '' )
                $desiredConfigurationMatch = $false
            }

            if (($null -ne $EnableTargetFailback) `
                -and (($Folder.Flags -contains 'Target Failback') -ne $EnableTargetFailback)) {
                Write-Verbose -Message ( @(
                    "$($MyInvocation.MyCommand): "
                    $($LocalizedData.NamespaceFolderParameterNeedsUpdateMessage) `
                        -f $Path,$TargetPath,'EnableTargetFailback'
                    ) -join '' )
                $desiredConfigurationMatch = $false
            }

            $Target = Get-FolderTarget `
                -Path $Path `
                -TargetPath $TargetPath

            if ($Target)
            {
                if (($ReferralPriorityClass) `
                    -and ($Target.ReferralPriorityClass -ne $ReferralPriorityClass)) {
                    Write-Verbose -Message ( @(
                        "$($MyInvocation.MyCommand): "
                        $($LocalizedData.NamespaceFolderTargetParameterNeedsUpdateMessage) `
                            -f $Path,$TargetPath,'ReferralPriorityClass'
                        ) -join '' )
                    $desiredConfigurationMatch = $false
                }

                if (($ReferralPriorityRank) `
                    -and ($Target.ReferralPriorityRank -ne $ReferralPriorityRank)) {
                    Write-Verbose -Message ( @(
                        "$($MyInvocation.MyCommand): "
                        $($LocalizedData.NamespaceFolderTargetParameterNeedsUpdateMessage) `
                            -f $Path,$TargetPath,'ReferralPriorityRank'
                        ) -join '' )
                    $desiredConfigurationMatch = $false
                }
            }
            else
            {
                # The Folder target does not exist but should - change required
                Write-Verbose -Message ( @(
                    "$($MyInvocation.MyCommand): "
                    $($LocalizedData.NamespaceFolderTargetDoesNotExistButShouldMessage) `
                        -f $Path,$TargetPath
                    ) -join '' )
                $desiredConfigurationMatch = $false
            }
        }
        else
        {
            # Ths Namespace Folder doesn't exist but should - change required
            Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                 $($LocalizedData.NamespaceFolderDoesNotExistButShouldMessage) `
                    -f $Path,$TargetPath
                ) -join '' )
            $desiredConfigurationMatch = $false
        }
    }
    else
    {
        # The Namespace target should not exist
        if ($Folder)
        {
            $Target = Get-FolderTarget `
                -Path $Path `
                -TargetPath $TargetPath

            if ($Target)
            {
                # The Folder target exists but should not - change required
                Write-Verbose -Message ( @(
                    "$($MyInvocation.MyCommand): "
                    $($LocalizedData.NamespaceFolderTargetExistsButShouldNotMessage) `
                        -f $Path,$TargetPath
                    ) -join '' )
                $desiredConfigurationMatch = $false
            }
            else
            {
                # The Namespace exists but the target doesn't - change not required
                Write-Verbose -Message ( @(
                    "$($MyInvocation.MyCommand): "
                    $($LocalizedData.NamespaceFolderTargetDoesNotExistAndShouldNotMessage) `
                        -f $Path,$TargetPath
                    ) -join '' )
            }
        }
        else
        {
            # The Namespace does not exist (so neither does the target) - change not required
            Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                 $($LocalizedData.NamespaceFolderDoesNotExistAndShouldNotMessage) `
                    -f $Path,$TargetPath
                ) -join '' )
        }
    } # if

    return $DesiredConfigurationMatch

} # Test-TargetResource

# Helper Functions
Function Get-Folder
{
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Path
    )
    # Lookup the DFSN Folder.
    # Return null if doesn't exist.
    try
    {
        $DfsnFolder = Get-DfsnFolder `
            -Path $Path `
            -ErrorAction Stop
    }
    catch [Microsoft.Management.Infrastructure.CimException]
    {
        $DfsnFolder = $null
    }
    catch
    {
        Throw $_
    }
    Return $DfsnFolder
}

Function Get-FolderTarget
{
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Path,

        [Parameter(Mandatory = $true)]
        [System.String]
        $TargetPath
    )
    # Lookup the DFSN Folder Target in a namespace.
    # Return null if doesn't exist.
    try
    {
        $DfsnTarget = Get-DfsnFolderTarget `
            -Path $Path `
            -TargetPath $TargetPath `
            -ErrorAction Stop
    }
    catch [Microsoft.Management.Infrastructure.CimException]
    {
        $DfsnTarget = $null
    }
    catch
    {
        Throw $_
    }
    Return $DfsnTarget
}

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
