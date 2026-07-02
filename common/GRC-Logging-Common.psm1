function Write-GRCLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet('Info','Warning','Error','Success')][string]$Level = 'Info'
    )
    $timestamp = (Get-Date).ToString('s')
    $prefix = switch ($Level) {
        'Info'    { '[INFO]' }
        'Warning' { '[WARN]' }
        'Error'   { '[ERROR]' }
        'Success' { '[OK]' }
    }
    Write-Host "$timestamp $prefix $Message"
}
Export-ModuleMember -Function Write-GRCLog
