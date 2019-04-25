$script:repoBase = "https://api.github.com/repos"

<#
.SYNOPSIS
Get the highest RFC number which is actually part of the repo

.DESCRIPTION
Get the highest RFC number which is actually part of the repo

.EXAMPLE
PS> get-maxrfcnumber
36

.NOTES

#>

function Get-MaxRFCNumber {
    $repoOwner = "PowerShell"
    $repoName = "PowerShell-RFC"
    $repoFiles = Get-RepoFileList -repoOwner $repoOwner -repoName $repoName
    $pattern = "RFC(?<number>\d\d\d\d)-"
    $numbers = $repoFiles.Where({$_.path -cmatch $pattern}).Foreach({if ( $_ -match $pattern ) { [int]($matches.number)}}) | Sort-Object
    $numbers[-1]
}

<#
.SYNOPSIS
Get the repo file information for the highest RFC

.DESCRIPTION
Get the repo file information for the highest RFC

.EXAMPLE
PS> get-maxrfc

size  path                                            file_url
----  ----                                            --------
10393 2-Draft-Accepted/RFC0036-AdditionalTelemetry.md https://github.com/PowerShell/PowerShell-RFC/blob/master/2-Draft-Accepted/RFC0036-AdditionalTelemetry.md

.NOTES
General notes
#>
function Get-MaxRFC {
    $maxNumber = Get-MaxRFCNumber
    $rfcPattern = "RFC{0:0000}" -f $maxNumber
    $RFC = (Get-RepoFileList -repoOwner PowerShell -repoName PowerShell-RFC).Where({$_.path -cmatch $rfcPattern})
    $RFC | Add-Member -TypeName RepoFile -PassThru -MemberType NoteProperty -Name file_url -Value ("https://github.com/PowerShell/PowerShell-RFC/blob/master/" + $RFC.path)
}

# get the RFCs referenced in PRs
<#
.SYNOPSIS
Retrieve the RFC numbers which are part of pull requests

.DESCRIPTION
Retrieve the RFC numbers which are part of pull requests

.PARAMETER State
The state of the PR, open, closed or all

.EXAMPLE
An example

.NOTES
General notes
#>

function Get-PullRFCNumber {
    param (
        [ValidateSet("open","closed","all")]
        [Parameter()]$State = "all"
    )

    $rfcs = [System.Collections.ArrayList]::new()
    $page = 1
    do {
        $st = Invoke-RestMethod "${repoBase}/PowerShell/PowerShell-RFC/pulls?state=${State}&per_page=100&page=${page}"
        $st.Foreach({ if ( $_.Title -match "RFC(?<num>\d\d\d\d)" ) { $null = $rfcs.Add([int]$matches.num) } })
        $page++
    } while ( $st.Count -gt 1 )
    $rfcs.Sort()
    return $rfcs
}

<#
.SYNOPSIS
Get the PRs from a repo

.DESCRIPTION
Get the PRs from a repo

.PARAMETER repoOwner
The repo owner name, the default value is PowerShell

.PARAMETER repoName
The repo name, the default value is PowerShell

.PARAMETER State
The state of the PR, choices are "open", "closed", "all"

.PARAMETER PageCount
how many pages to return, the default is all
Each page contains up to 100 pull requests

.EXAMPLE
PS> Get-PR -state open | select -first 3

Number Author   Updated          Title
------ ------   -------          -----
9466   RDIL     4/25/19 2:47 PM  Fix gulp in markdown tests
9460   xtqqczze 4/25/19 4:05 AM  Suppress PossibleIncorrectUsageOfAssignmentOperator rule violation
9459   xtqqczze 4/24/19 11:48 PM Avoid using Invoke-Expression

.NOTES
General notes
#>

function Get-PR {
    param (
        [Parameter()]$repoOwner = "PowerShell",
        [Parameter()]$repoName = "PowerShell",
        [ValidateSet("open","closed","all")]
        [Parameter()]$State = "all",
        [Parameter()]$PageCount = [int]::maxvalue
    )

    $page = 1
    do {
        $url = "${repoBase}/${repoOwner}/${repoName}/pulls?state=${State}&per_page=100&page=${page}"
        $st = Invoke-RestMethod $url
        $st.Foreach({$_.PSObject.TypeNames.Insert(0,"GitPullRequest");$_})
        $page++
    } while ( $st.Count -gt 1 -and $page -lt $PageCount + 1)

}

<#
.SYNOPSIS
Retrieve pull requestions for the PowerShell-RFC repo

.DESCRIPTION
Retrieve pull requestions for the PowerShell-RFC repo

.PARAMETER State
The state of the PR, choices are "open", "closed", "all"


.EXAMPLE
PS> Get-RFCPullRequest -state open | select-object -first 3

Number Author       Updated          Title
------ ------       -------          -----
167    iSazonov     4/24/19 12:53 PM Enhance some cmdlets with Culture and Comparison parameters
164    daxian-dbw   4/2/19 7:33 PM   Investigation on supporting module isolation
163    SydneyhSmith 4/11/19 1:21 AM  Update RFC0004-PowerShell-Module-Versioning.md

.NOTES
General notes
#>

function Get-RFCPullRequest {
    param (
        [ValidateSet("open","closed","all")]
        [Parameter()]$State = "open"
    )

    Get-PR -repoName "PowerShell-RFC" -State $State
}

<#
.SYNOPSIS
Get the 

.DESCRIPTION
Long description

.EXAMPLE
An example

.NOTES
General notes
#>

function Get-HighestPullRFCNumber
{
    return (Get-PullRFCNumber)[-1]
}

function Get-NextRFCNumber
{
    $highestRFC = Get-HighestPullRFCNumber
    $maxNumber = Get-MaxRFCNumber
    [int]$highest = $lastFileNumber,$highestRFC,$maxNumber | Sort-Object | Select-Object -Last 1
    $highest + 1
}

function Get-NextRFCFileName ( [parameter(Mandatory=$true,Position=0)]$RfcTitle ) {
    "RFC{0:0000}-${RfcTitle}.md" -f (Get-NextRFCNumber)
}


<#
.SYNOPSIS
Get-GitFork [-repoOwner [string]] [-repoName [string]]

Get-GitFork [-forkurl [string]]]

.DESCRIPTION
Get the forks that have been created against the repoOwner and repo name.

.PARAMETER repoOwner
The owner of a repository - this defaults to PowerShell

.PARAMETER repoName
The name of a repository - this defaults to PowerShell

.PARAMETER forkUrl
the url which represents the path to the repo

.EXAMPLE

PS> get-gitfork -repoName PowerShell-RFC | select -first 3

pushed_at           html_url
---------           --------
4/24/19 10:16:37 PM https://github.com/SydneyhSmith/PowerShell-RFC
1/16/19 4:34:24 PM  https://github.com/vcgato29/PowerShell-RFC
11/21/18 6:14:03 PM https://github.com/IISResetMe/PowerShell-RFC

.NOTES
#>

function Get-GitFork {
    [CmdletBinding(DefaultParameterSetName="owner")]
    param (
        [Parameter(ParameterSetName="owner")]$repoOwner = "PowerShell", $repoName = "PowerShell" ,
        [Parameter(ParameterSetName="fork")]$forkUrl
        )
    if ( ! $forkUrl ) {
        $forkUrl = "${repoBase}/${repoOwner}/${repoName}/forks"
    }
    try {
        # if we have a problem bail
        $result = Invoke-WebRequest "${forkUrl}?per_page=100"
    }
    catch {
        Write-Warning "Could not get data from $forkUrl"
        return
    }
    $forks = $result.Content | ConvertFrom-Json
    foreach ( $fork in $forks ) {
        if ( $fork.forks -ne 0 ) {
            Get-GitFork -forkUrl $fork.forks_url
        }
        # name this so we can use formatting
        $fork.PSObject.TypeNames.Insert(0, "GitForkInfo")
        # emit the fork
        $fork
    }
}

<#
.SYNOPSIS
Get the branches from a fork

.DESCRIPTION
Get the branches from a fork

.PARAMETER Fork
A fork object produced by Get-GitFork

.EXAMPLE
An example

.NOTES
General notes
#>

function Get-GitBranchesFromFork {
    param ( $Fork )
    $branchurl = $Fork.branches_url -replace "{/branch}$"
    $branchInfo = (Invoke-WebRequest $branchurl).Content | ConvertFrom-Json
    $branchInfo.Foreach({$_.psobject.typenames.insert(0,"GitBranchInfo");$_})
}

<#
.SYNOPSIS
Get the last commit id from a repository

.DESCRIPTION
Get the last commit id from a repository

.PARAMETER repoOwner
The repo owner. Default value is PowerShell

.PARAMETER repoName
The repo name. Default value is PowerShell

.EXAMPLE
PS> Get-LastCommit -reponame powershell-rfc
249e8d88eb779a6003fd138609ae94417ae13698

.NOTES
General notes
#>

function Get-LastCommit
{
    param ( $repoOwner = "PowerShell", $repoName = "PowerShell" )
    #$d = "{0:YYYY}-{0:MM}-{0:DD}T{0:HH}:{0:mm}:{0:ss}Z" -f [datetime]::now()
    $repo ="${repoBase}/${repoOwner}/${repoName}/commits"
    $r = invoke-webrequest $repo
    $rContent = $r.content | ConvertFrom-Json
    $lastCommit = $rContent | Sort-Object {$_.commit.committer.date}|Select-Object -Last 1
    return $lastCommit.sha
}

<#
.SYNOPSIS
Retrieve the file list from a repository

.DESCRIPTION
Retrieve the file list from a repository

.PARAMETER commit
The commit to use when retrieving the file list

.PARAMETER repoOwner
The repository owner. Default value is PowerShell

.PARAMETER repoName
The repository name. Default value is PowerShell

.EXAMPLE
PS> Get-RepoFileList -repoName "PowerShell-RFC" | Select-Object -First 3

size path                                            FileUrl
---- ----                                            -------
2498 1-Draft/RFC0003-Lexical-Strict-Mode.md          https://github.com/PowerShell/PowerShell-RFC/blob/master/1-Draft/RFC0003-Lexical-Strict-Mode.md
6342 1-Draft/RFC0004-PowerShell-Module-Versioning.md https://github.com/PowerShell/PowerShell-RFC/blob/master/1-Draft/RFC0004-PowerShell-Module-Versioning.md


.NOTES
General notes
#>

function Get-RepoFileList
{
    param ( $commit, $repoOwner = "PowerShell", $repoName = "PowerShell" )
    if ( ! $commit ) {
        $commit = Get-LastCommit -repoOwner $repoOwner -repoName $repoName
    }
    $repo = "${repoBase}/${repoOwner}/${repoName}/git/trees/${commit}?recursive=1"
    $r = invoke-webrequest $repo
    $rContent = $r.content | ConvertFrom-Json
    if ( $rContent.truncated ) {
        #Get-RepoFileListFromTree $commit
    }
    else {
        $rContent.Tree.Where({$_.type -eq "blob"}).Foreach({
                $_.PSObject.TypeNames.Insert(0,"RepoFile")
                $fileUrl = "https://github.com/${repoOwner}/${repoName}/blob/master/" + $_.path
                $np = [System.Management.Automation.PSNoteProperty]::new("FileUrl",$fileUrl)
                $_.PSObject.Properties.Add($np)
                $_
            })
    }
}
