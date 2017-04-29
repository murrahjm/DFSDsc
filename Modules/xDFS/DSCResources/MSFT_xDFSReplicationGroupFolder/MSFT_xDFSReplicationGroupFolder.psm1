$script:ResourceRootPath = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent)

# Import the xCertificate Resource Module (to import the common modules)
Import-Module -Name (Join-Path -Path $script:ResourceRootPath -ChildPath 'xDFS.psd1')

# Import Localization Strings
$localizedData = Get-LocalizedData `
    -ResourceName 'MSFT_xDFSReplicationGroupFolder' `
    -ResourcePath (Split-Path -Parent $Script:MyInvocation.MyCommand.Path)

function Get-TargetResource
{
    [OutputType([Hashtable])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $GroupName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $FolderName,

        [Parameter()]
        [System.String]
        $DomainName
    )

    Write-Verbose -Message ( @(
        "$($MyInvocation.MyCommand): "
        $($LocalizedData.GettingReplicationGroupFolderMessage) `
            -f $GroupName,$FolderName,$DomainName
        ) -join '' )

    # Lookup the existing Replication Group
    $Splat = @{
        GroupName = $GroupName
        FolderName = $FolderName
    }
    $returnValue = $splat.Clone()
    if ($DomainName)
    {
        $Splat += @{ DomainName = $DomainName }
    }
    $ReplicationGroupFolder = Get-DfsReplicatedFolder @Splat `
        -ErrorAction Stop
    if ($ReplicationGroupFolder)
    {
        Write-Verbose -Message ( @(
            "$($MyInvocation.MyCommand): "
            $($LocalizedData.ReplicationGroupFolderExistsMessage) `
                -f $GroupName,$FolderName,$DomainName
            ) -join '' )
        # Array paramters are disabled until this issue is resolved:
        # https://windowsserver.uservoice.com/forums/301869-powershell/suggestions/11088807-get-dscconfiguration-fails-with-embedded-cim-type
        $returnValue += @{
            Description = $ReplicationGroupFolder.Description
            # FilenameToExclude = $ReplicationGroupFolder.FilenameToExclude
            # DirectoryNameToExclude = $ReplicationGroupFolder.DirectoryNameToExclude
            DfsnPath = $ReplicationGroupFolder.DfsnPath
            DomainName = $ReplicationGroupFolder.DomainName
        }
    }
    else
    {
        # The Rep Group folder doesn't exist
        $errorId = 'RegGroupFolderMissingError'
        $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidOperation
        $errorMessage = $($LocalizedData.ReplicationGroupFolderMissingError) `
            -f $GroupName,$FolderName,$DomainName
        $exception = New-Object -TypeName System.InvalidOperationException `
            -ArgumentList $errorMessage
        $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord `
            -ArgumentList $exception, $errorId, $errorCategory, $null

        $PSCmdlet.ThrowTerminatingError($errorRecord)
    }

    $returnValue
} # Get-TargetResource

function Set-TargetResource
{
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $GroupName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $FolderName,

        [Parameter()]
        [System.String]
        $Description,

        [Parameter()]
        [System.String[]]
        $FileNameToExclude,

        [Parameter()]
        [System.String[]]
        $DirectoryNameToExclude,

        [Parameter()]
        [System.String]
        $DfsnPath,

        [Parameter()]
        [System.String]
        $DomainName
    )

    Write-Verbose -Message ( @(
        "$($MyInvocation.MyCommand): "
        $($LocalizedData.SettingRegGroupFolderMessage) `
            -f $GroupName,$FolderName,$DomainName
        ) -join '' )

    # Now apply the changes
    Set-DfsReplicatedFolder @PSBoundParameters `
        -ErrorAction Stop

    Write-Verbose -Message ( @(
        "$($MyInvocation.MyCommand): "
        $($LocalizedData.ReplicationGroupFolderUpdatedMessage) `
            -f $GroupName,$FolderName,$DomainName
        ) -join '' )

} # Set-TargetResource

function Test-TargetResource
{
    [OutputType([System.Boolean])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $GroupName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $FolderName,

        [Parameter()]
        [System.String]
        $Description,

        [Parameter()]
        [System.String[]]
        $FileNameToExclude,

        [Parameter()]
        [System.String[]]
        $DirectoryNameToExclude,

        [Parameter()]
        [System.String]
        $DfsnPath,

        [Parameter()]
        [System.String]
        $DomainName
    )

    # Flag to signal whether settings are correct
    [System.Boolean] $desiredConfigurationMatch = $true

    Write-Verbose -Message ( @(
        "$($MyInvocation.MyCommand): "
        $($LocalizedData.TestingRegGroupFolderMessage) `
            -f $GroupName,$FolderName,$DomainName
        ) -join '' )

    # Lookup the existing Replication Group Folder
    $Splat = @{
        GroupName = $GroupName
        FolderName = $FolderName
    }
    if ($DomainName)
    {
        $Splat += @{ DomainName = $DomainName }
    }
    $ReplicationGroupFolder = Get-DfsReplicatedFolder @Splat `
        -ErrorAction Stop

    if ($ReplicationGroupFolder)
    {
        # The rep group folder is found
        Write-Verbose -Message ( @(
            "$($MyInvocation.MyCommand): "
            $($LocalizedData.ReplicationGroupFolderExistsMessage) `
                -f $GroupName,$FolderName,$DomainName
            ) -join '' )

        # Check the description
        if (($PSBoundParameters.ContainsKey('Description')) `
            -and ($ReplicationGroupFolder.Description -ne $Description))
        {
            Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                $($LocalizedData.ReplicationGroupFolderDescriptionMismatchMessage) `
                    -f $GroupName,$FolderName,$DomainName
                ) -join '' )
            $desiredConfigurationMatch = $false
        }

        # Check the FileNameToExclude
        if (($PSBoundParameters.ContainsKey('FileNameToExclude')) `
            -and ((Compare-Object `
                -ReferenceObject  $ReplicationGroupFolder.FileNameToExclude `
                -DifferenceObject $FileNameToExclude).Count -ne 0))
        {
            Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                $($LocalizedData.ReplicationGroupFolderFileNameToExcludeMismatchMessage) `
                    -f $GroupName,$FolderName,$DomainName
                ) -join '' )
            $desiredConfigurationMatch = $false
        }

        # Check the DirectoryNameToExclude
        if (($PSBoundParameters.ContainsKey('DirectoryNameToExclude')) `
            -and ((Compare-Object `
                -ReferenceObject  $ReplicationGroupFolder.DirectoryNameToExclude `
                -DifferenceObject $DirectoryNameToExclude).Count -ne 0))
        {
            Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                $($LocalizedData.ReplicationGroupFolderDirectoryNameToExcludeMismatchMessage) `
                    -f $GroupName,$FolderName,$DomainName
                ) -join '' )
            $desiredConfigurationMatch = $false
        }

        if (($PSBoundParameters.ContainsKey('DfsnPath')) `
            -and ($ReplicationGroupFolder.DfsnPath -ne $DfsnPath))
        {
            Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                $($LocalizedData.ReplicationGroupFolderDfsnPathMismatchMessage) `
                    -f $GroupName,$FolderName,$DomainName
                ) -join '' )
            $desiredConfigurationMatch = $false
        }
    }
    else
    {
        # The Rep Group folder doesn't exist
        $errorId = 'RegGroupFolderMissingError'
        $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidOperation
        $errorMessage = $($LocalizedData.ReplicationGroupFolderMissingError) `
            -f $GroupName,$FolderName,$DomainName
        $exception = New-Object -TypeName System.InvalidOperationException `
            -ArgumentList $errorMessage
        $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord `
            -ArgumentList $exception, $errorId, $errorCategory, $null

        $PSCmdlet.ThrowTerminatingError($errorRecord)
    }

    return $desiredConfigurationMatch
} # Test-TargetResource

Export-ModuleMember -Function *-TargetResource
