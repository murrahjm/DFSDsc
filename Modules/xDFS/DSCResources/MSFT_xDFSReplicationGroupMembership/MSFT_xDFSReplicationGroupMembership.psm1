$script:ResourceRootPath = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent)

# Import the xCertificate Resource Module (to import the common modules)
Import-Module -Name (Join-Path -Path $script:ResourceRootPath -ChildPath 'xDFS.psd1')

# Import Localization Strings
$localizedData = Get-LocalizedData `
    -ResourceName 'MSFT_xDFSReplicationGroupMembership' `
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

        [Parameter(Mandatory = $true)]
        [System.String]
        $ComputerName,

        [Parameter()]
        [System.String]
        $DomainName
    )

    Write-Verbose -Message ( @(
        "$($MyInvocation.MyCommand): "
        $($LocalizedData.GettingReplicationGroupMembershipMessage) `
            -f $GroupName,$FolderName,$ComputerName,$DomainName
        ) -join '' )

    # Lookup the existing Replication Group
    $Splat = @{
        GroupName = $GroupName
        ComputerName = $ComputerName
    }
    $returnValue = $Splat
    if ($DomainName)
    {
        $Splat += @{ DomainName = $DomainName }
    }
    $returnValue += @{ FolderName = $FolderName }
    $ReplicationGroupMembership = Get-DfsrMembership @Splat `
        -ErrorAction Stop `
        | Where-Object { $_.FolderName -eq $FolderName }
    if ($ReplicationGroupMembership)
    {
        Write-Verbose -Message ( @(
            "$($MyInvocation.MyCommand): "
            $($LocalizedData.ReplicationGroupMembershipExistsMessage) `
                -f $GroupName,$FolderName,$ComputerName,$DomainName
            ) -join '' )
        $ReturnValue.ComputerName = $ReplicationGroupMembership.ComputerName
        $returnValue += @{
            ContentPath = $ReplicationGroupMembership.ContentPath
            StagingPath = $ReplicationGroupMembership.StagingPath
            ConflictAndDeletedPath = $ReplicationGroupMembership.ConflictAndDeletedPath
            ReadOnly = $ReplicationGroupMembership.ReadOnly
            PrimaryMember = $ReplicationGroupMembership.PrimaryMember
            DomainName = $ReplicationGroupMembership.DomainName
        }
    }
    else
    {
        # The Rep Group membership doesn't exist
        $errorId = 'RegGroupMembershipMissingError'
        $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidOperation
        $errorMessage = $($LocalizedData.ReplicationGroupMembershipMissingError) `
            -f $GroupName,$FolderName,$ComputerName,$DomainName
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

        [Parameter(Mandatory = $true)]
        [System.String]
        $ComputerName,

        [Parameter()]
        [System.String]
        $ContentPath,

        [Parameter()]
        [System.String]
        $StagingPath,

        [Parameter()]
        [System.Boolean]
        $ReadOnly,

        [Parameter()]
        [System.Boolean]
        $PrimaryMember,

        [Parameter()]
        [System.String]
        $DomainName
    )

    Write-Verbose -Message ( @(
        "$($MyInvocation.MyCommand): "
        $($LocalizedData.SettingRegGroupMembershipMessage) `
            -f $GroupName,$FolderName,$ComputerName,$DomainName
        ) -join '' )

    # Now apply the changes
    Set-DfsrMembership @PSBoundParameters `
        -ErrorAction Stop

    Write-Verbose -Message ( @(
        "$($MyInvocation.MyCommand): "
        $($LocalizedData.ReplicationGroupMembershipUpdatedMessage) `
            -f $GroupName,$FolderName,$ComputerName,$DomainName
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

        [Parameter(Mandatory = $true)]
        [System.String]
        $ComputerName,

        [Parameter()]
        [System.String]
        $ContentPath,

        [Parameter()]
        [System.String]
        $StagingPath,

        [Parameter()]
        [System.Boolean]
        $ReadOnly,

        [Parameter()]
        [System.Boolean]
        $PrimaryMember,

        [Parameter()]
        [System.String]
        $DomainName
    )

    # Flag to signal whether settings are correct
    [System.Boolean] $desiredConfigurationMatch = $true

    Write-Verbose -Message ( @(
        "$($MyInvocation.MyCommand): "
        $($LocalizedData.TestingRegGroupMembershipMessage) `
            -f $GroupName,$FolderName,$ComputerName,$DomainName
        ) -join '' )

    # Lookup the existing Replication Group
    $Splat = @{
        GroupName = $GroupName
        ComputerName = $ComputerName
    }
    if ($DomainName)
    {
        $Splat += @{ DomainName = $DomainName }
    }
    $ReplicationGroupMembership = Get-DfsrMembership @Splat `
        -ErrorAction Stop `
        | Where-Object { $_.FolderName -eq $FolderName }
    if ($ReplicationGroupMembership)
    {
        # The rep group folder is found
        Write-Verbose -Message ( @(
            "$($MyInvocation.MyCommand): "
            $($LocalizedData.ReplicationGroupMembershipExistsMessage) `
                -f $GroupName,$FolderName,$ComputerName,$DomainName
            ) -join '' )

        # Check the ContentPath
        if (($PSBoundParameters.ContainsKey('ContentPath')) `
            -and ($ReplicationGroupMembership.ContentPath -ne $ContentPath))
        {
            Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                $($LocalizedData.ReplicationGroupMembershipContentPathMismatchMessage) `
                    -f $GroupName,$FolderName,$ComputerName,$DomainName
                ) -join '' )
            $desiredConfigurationMatch = $false
        }

        # Check the StagingPath
        if (($PSBoundParameters.ContainsKey('StagingPath')) `
            -and ($ReplicationGroupMembership.StagingPath -ne $StagingPath))
        {
            Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                $($LocalizedData.ReplicationGroupMembershipStagingPathMismatchMessage) `
                    -f $GroupName,$FolderName,$ComputerName,$DomainName
                ) -join '' )
            $desiredConfigurationMatch = $false
        }

        # Check the ReadOnly
        if (($PSBoundParameters.ContainsKey('ReadOnly')) `
            -and ($ReplicationGroupMembership.ReadOnly -ne $ReadOnly))
        {
            Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                $($LocalizedData.ReplicationGroupMembershipReadOnlyMismatchMessage) `
                    -f $GroupName,$FolderName,$ComputerName,$DomainName
                ) -join '' )
            $desiredConfigurationMatch = $false
        }

        # Check the PrimaryMember
        if (($PSBoundParameters.ContainsKey('PrimaryMember')) `
            -and ($ReplicationGroupMembership.PrimaryMember -ne $PrimaryMember))
        {
            Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                $($LocalizedData.ReplicationGroupMembershipPrimaryMemberMismatchMessage) `
                    -f $GroupName,$FolderName,$ComputerName,$DomainName
                ) -join '' )
            $desiredConfigurationMatch = $false
        }

    }
    else
    {
        # The Rep Group membership doesn't exist
        $errorId = 'RegGroupMembershipMissingError'
        $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidOperation
        $errorMessage = $($LocalizedData.ReplicationGroupMembershipMissingError) `
            -f $GroupName,$FolderName,$ComputerName,$DomainName
        $exception = New-Object -TypeName System.InvalidOperationException `
            -ArgumentList $errorMessage
        $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord `
            -ArgumentList $exception, $errorId, $errorCategory, $null

        $PSCmdlet.ThrowTerminatingError($errorRecord)
    }

    return $desiredConfigurationMatch
} # Test-TargetResource

Export-ModuleMember -Function *-TargetResource
