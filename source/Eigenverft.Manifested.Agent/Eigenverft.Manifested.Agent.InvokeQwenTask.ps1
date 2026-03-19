<#
    Eigenverft.Manifested.Agent.InvokeQwenTask
#>

function Get-QwenSessionStorePath {
    [CmdletBinding()]
    param(
        [string]$LocalRoot = (Get-CodexLocalRoot)
    )

    return (Join-Path (Join-Path $LocalRoot 'sessions') 'named-qwen-sessions.json')
}

function Get-QwenSessionKey {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SessionName
    )

    return ($SessionName.Trim() -replace '\|', '_')
}

function Read-QwenSessionMap {
    [CmdletBinding()]
    param(
        [string]$SessionStorePath = (Get-QwenSessionStorePath)
    )

    $sessionMap = @{}
    if (-not (Test-Path -LiteralPath $SessionStorePath)) {
        return $sessionMap
    }

    try {
        $raw = Get-Content -LiteralPath $SessionStorePath -Raw
        if (-not [string]::IsNullOrWhiteSpace($raw)) {
            $obj = $raw | ConvertFrom-Json
            foreach ($property in $obj.PSObject.Properties) {
                $sessionMap[$property.Name] = $property.Value
            }
        }
    }
    catch {
        throw "Failed to read Qwen session store: $SessionStorePath"
    }

    return $sessionMap
}

function Write-QwenSessionMap {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$SessionMap,

        [string]$SessionStorePath = (Get-QwenSessionStorePath)
    )

    $sessionStoreRoot = Split-Path -Parent $SessionStorePath
    if (-not (Test-Path -LiteralPath $sessionStoreRoot)) {
        New-Item -ItemType Directory -Path $sessionStoreRoot -Force | Out-Null
    }

    ($SessionMap | ConvertTo-Json -Depth 6) | Set-Content -LiteralPath $SessionStorePath -Encoding UTF8
}

function Resolve-QwenCommandPath {
    [CmdletBinding()]
    param()

    foreach ($candidate in @('qwen.cmd', 'qwen', 'qwen.ps1')) {
        $resolvedQwen = Get-Command $candidate -ErrorAction SilentlyContinue
        if (-not $resolvedQwen) {
            continue
        }

        if ($resolvedQwen.PSObject.Properties['Path'] -and $resolvedQwen.Path) {
            return $resolvedQwen.Path
        }

        return $resolvedQwen.Source
    }

    throw 'qwen was not found on PATH. Install the Qwen CLI or add it to PATH before using Invoke-QwenTask.'
}

function ConvertFrom-QwenJsonLine {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [string]$Line
    )

    if ([string]::IsNullOrWhiteSpace($Line)) {
        return $null
    }

    $text = [string]$Line

    if ($text.Length -gt 0 -and [int][char]$text[0] -eq 0xFEFF) {
        $text = $text.Substring(1)
    }

    try {
        return ($text | ConvertFrom-Json)
    }
    catch {
        return $null
    }
}

function Convert-QwenProcessOutputToLines {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [string]$Text
    )

    if ([string]::IsNullOrEmpty($Text)) {
        return @()
    }

    $lines = [regex]::Split($Text, "\r?\n")

    if ($lines.Count -gt 0 -and [string]::IsNullOrEmpty($lines[$lines.Count - 1])) {
        $lines = @($lines | Select-Object -First ($lines.Count - 1))
    }

    return @($lines)
}

function Get-QwenInvocationLineRecords {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Invocation
    )

    $records =
        foreach ($sourceName in @('StdOutLines', 'StdErrLines')) {
            foreach ($line in @($Invocation.$sourceName)) {
                $text = [string]$line

                [pscustomobject]@{
                    Source = $sourceName
                    Line   = $text
                    Event  = ConvertFrom-QwenJsonLine -Line $text
                }
            }
        }

    return @($records)
}

function ConvertTo-QwenProcessArgument {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [string]$Value
    )

    if ($null -eq $Value) {
        return '""'
    }

    if ($Value.Length -eq 0) {
        return '""'
    }

    if ($Value -notmatch '[\s"]') {
        return $Value
    }

    $builder = New-Object System.Text.StringBuilder
    [void]$builder.Append('"')
    $pendingBackslashes = 0

    foreach ($char in $Value.ToCharArray()) {
        if ($char -eq '\') {
            $pendingBackslashes++
            continue
        }

        if ($char -eq '"') {
            if ($pendingBackslashes -gt 0) {
                [void]$builder.Append(('\' * ($pendingBackslashes * 2)))
                $pendingBackslashes = 0
            }

            [void]$builder.Append('\"')
            continue
        }

        if ($pendingBackslashes -gt 0) {
            [void]$builder.Append(('\' * $pendingBackslashes))
            $pendingBackslashes = 0
        }

        [void]$builder.Append($char)
    }

    if ($pendingBackslashes -gt 0) {
        [void]$builder.Append(('\' * ($pendingBackslashes * 2)))
    }

    [void]$builder.Append('"')
    return $builder.ToString()
}

function ConvertTo-QwenProcessArgumentString {
    [CmdletBinding()]
    param(
        [string[]]$Arguments
    )

    return ((@($Arguments) | ForEach-Object { ConvertTo-QwenProcessArgument -Value $_ }) -join ' ')
}

function Invoke-QwenProcess {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$QwenCommandPath,

        [string[]]$Arguments,

        [Parameter(Mandatory = $true)]
        [string]$Directory
    )

    $stdoutPath = Join-Path $env:TEMP ("qwen-stdout-{0}.log" -f ([Guid]::NewGuid().ToString('N')))
    $stderrPath = Join-Path $env:TEMP ("qwen-stderr-{0}.log" -f ([Guid]::NewGuid().ToString('N')))

    $argumentString = ConvertTo-QwenProcessArgumentString -Arguments $Arguments

    try {
        $process = Start-Process `
            -FilePath $QwenCommandPath `
            -ArgumentList $argumentString `
            -WorkingDirectory $Directory `
            -RedirectStandardOutput $stdoutPath `
            -RedirectStandardError $stderrPath `
            -Wait `
            -PassThru `
            -NoNewWindow

        $stdoutRaw = ''
        $stderrRaw = ''

        if (Test-Path -LiteralPath $stdoutPath) {
            $stdoutRaw = Get-Content -LiteralPath $stdoutPath -Raw
        }

        if (Test-Path -LiteralPath $stderrPath) {
            $stderrRaw = Get-Content -LiteralPath $stderrPath -Raw
        }

        [pscustomobject]@{
            ExitCode    = [int]$process.ExitCode
            StdOutRaw   = [string]$stdoutRaw
            StdErrRaw   = [string]$stderrRaw
            StdOutLines = @(Convert-QwenProcessOutputToLines -Text $stdoutRaw)
            StdErrLines = @(Convert-QwenProcessOutputToLines -Text $stderrRaw)
        }
    }
    finally {
        Remove-Item -LiteralPath $stdoutPath, $stderrPath -Force -ErrorAction SilentlyContinue
    }
}

function Get-QwenAssistantMessageText {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$Message
    )

    if ($null -eq $Message) {
        return $null
    }

    if ($Message -is [string]) {
        return [string]$Message
    }

    $contentItems = @()
    if ($Message.PSObject.Properties['content'] -and $null -ne $Message.content) {
        $contentItems = @($Message.content)
    }

    $builder = New-Object System.Text.StringBuilder

    foreach ($item in $contentItems) {
        if ($null -eq $item) {
            continue
        }

        if ($item -is [string]) {
            [void]$builder.Append([string]$item)
            continue
        }

        if ($item.PSObject.Properties['text'] -and $item.text) {
            [void]$builder.Append([string]$item.text)
            continue
        }
    }

    if ($builder.Length -gt 0) {
        return $builder.ToString()
    }

    if ($Message.PSObject.Properties['text'] -and $Message.text) {
        return [string]$Message.text
    }

    return $null
}

function Invoke-QwenTask {
<#
.SYNOPSIS
Runs a Qwen non-interactive task and maintains wrapper-level named session state.

.DESCRIPTION
Thin PowerShell wrapper around Qwen Code headless mode using `--output-format stream-json`
for structured runs. Named wrapper sessions store:

- SessionName
- SessionId
- LastDirectory
- UpdatedUtc

Automation behavior:
- always uses `--approval-mode yolo`
- adds `--sandbox` only when `-AllowDangerous:$false`
- named sessions force `--chat-recording`
- named sessions use `--resume <session_id>` for continuity

The wrapper keeps a friendly session name that maps to the last observed Qwen session id.
If a stored session id cannot be resumed, the wrapper fails fast instead of silently
starting a fresh conversation.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Prompt,

        [Alias('Path')]
        [string]$Directory,

        [Alias('Session')]
        [string]$SessionName,

        [bool]$AllowDangerous = $true,

        [bool]$Json = $true,

        [string]$OutputLastMessage,

        [string]$Model,

        [string[]]$AddDir
    )

    $qwenCmd = Resolve-QwenCommandPath

    $currentDirectory = Resolve-CodexDirectory -Directory ((Get-Location).ProviderPath)
    $directoryProvided = $PSBoundParameters.ContainsKey('Directory')
    $requestedDirectory = $null

    if ($directoryProvided) {
        $requestedDirectory = Resolve-CodexDirectory -Directory $Directory
    }

    $sessionStorePath = Get-QwenSessionStorePath
    $sessionStoreRoot = Split-Path -Parent $sessionStorePath

    if (-not (Test-Path -LiteralPath $sessionStoreRoot)) {
        New-Item -ItemType Directory -Path $sessionStoreRoot -Force | Out-Null
    }

    $sessionMap =
        if (Test-Path -LiteralPath $sessionStorePath) {
            Read-QwenSessionMap -SessionStorePath $sessionStorePath
        }
        else {
            @{}
        }

    $sessionKey = $null
    $existingSession = $null
    $effectiveDirectory = $currentDirectory

    if (-not [string]::IsNullOrWhiteSpace($SessionName)) {
        $sessionKey = Get-QwenSessionKey -SessionName $SessionName

        if ($sessionMap.ContainsKey($sessionKey)) {
            $existingSession = $sessionMap[$sessionKey]
        }

        if ($directoryProvided) {
            $effectiveDirectory = $requestedDirectory
        }
        elseif ($existingSession -and $existingSession.LastDirectory) {
            $effectiveDirectory = Resolve-CodexDirectory -Directory ([string]$existingSession.LastDirectory)
        }
        else {
            $effectiveDirectory = $currentDirectory
        }
    }
    elseif ($directoryProvided) {
        $effectiveDirectory = $requestedDirectory
    }

    $canResume = [bool](
        $existingSession -and
        $existingSession.SessionId
    )

    $effectiveStructuredOutput = [bool](
        -not [string]::IsNullOrWhiteSpace($SessionName) -or
        $Json
    )

    if ([string]::IsNullOrWhiteSpace($OutputLastMessage) -and $effectiveStructuredOutput) {
        $safeDirName = ([IO.Path]::GetFileName($effectiveDirectory)).Trim()
        if ([string]::IsNullOrWhiteSpace($safeDirName)) {
            $safeDirName = 'workspace'
        }

        $safeDirName = ($safeDirName -replace '[^A-Za-z0-9._-]', '_')

        if ([string]::IsNullOrWhiteSpace($SessionName)) {
            $OutputLastMessage = Join-Path $env:TEMP ("qwen-last-message-{0}-{1}.txt" -f $safeDirName, ([Guid]::NewGuid().ToString('N')))
        }
        else {
            $safeSessionFile = ($SessionName -replace '[^A-Za-z0-9._-]', '_')
            $OutputLastMessage = Join-Path $env:TEMP ("qwen-last-message-{0}-{1}.txt" -f $safeDirName, $safeSessionFile)
        }
    }

    $cargs = New-Object System.Collections.Generic.List[string]

    if ($canResume) {
        [void]$cargs.Add('--resume')
        [void]$cargs.Add([string]$existingSession.SessionId)
    }

    if (-not [string]::IsNullOrWhiteSpace($SessionName)) {
        [void]$cargs.Add('--chat-recording')
    }

    if (-not [string]::IsNullOrWhiteSpace($Model)) {
        [void]$cargs.Add('--model')
        [void]$cargs.Add($Model)
    }

    [void]$cargs.Add('--approval-mode')
    [void]$cargs.Add('yolo')

    if (-not $AllowDangerous) {
        [void]$cargs.Add('--sandbox')
    }

    foreach ($dir in @($AddDir)) {
        if (-not [string]::IsNullOrWhiteSpace($dir)) {
            [void]$cargs.Add('--include-directories')
            [void]$cargs.Add((Resolve-CodexDirectory -Directory $dir))
        }
    }

    if ($effectiveStructuredOutput) {
        [void]$cargs.Add('--output-format')
        [void]$cargs.Add('stream-json')
    }

    [void]$cargs.Add($Prompt)

    $argArray = $cargs.ToArray()
    $observedSessionId =
        if ($canResume) {
            [string]$existingSession.SessionId
        }
        else {
            $null
        }
    $lastAgentMessage = $null
    $structuredErrorMessage = $null
    $exitCode = 0

    $invocation = Invoke-QwenProcess -QwenCommandPath $qwenCmd -Arguments $argArray -Directory $effectiveDirectory
    $exitCode = $invocation.ExitCode

    if ($effectiveStructuredOutput) {
        $streamJsonRecords = @(Get-QwenInvocationLineRecords -Invocation $invocation)

        foreach ($record in $streamJsonRecords) {
            Write-Host ([string]$record.Line)
        }

        foreach ($record in $streamJsonRecords) {
            $evt = $record.Event

            if (-not $evt) {
                continue
            }

            if (
                -not [string]::IsNullOrWhiteSpace($SessionName) -and
                $evt.type -eq 'system' -and
                $evt.PSObject.Properties.Match('subtype').Count -gt 0 -and
                $evt.subtype -eq 'session_start' -and
                $evt.PSObject.Properties.Match('session_id').Count -gt 0 -and
                $evt.session_id
            ) {
                $observedSessionId = [string]$evt.session_id

                $sessionMap[$sessionKey] = @{
                    SessionName   = $SessionName
                    SessionId     = $observedSessionId
                    LastDirectory = $effectiveDirectory
                    UpdatedUtc    = [DateTime]::UtcNow.ToString('o')
                }

                Write-QwenSessionMap -SessionMap $sessionMap -SessionStorePath $sessionStorePath
                $existingSession = $sessionMap[$sessionKey]
            }

            if (
                [string]::IsNullOrWhiteSpace($observedSessionId) -and
                $evt.PSObject.Properties.Match('session_id').Count -gt 0 -and
                $evt.session_id
            ) {
                $observedSessionId = [string]$evt.session_id
            }

            if (
                $evt.type -eq 'assistant' -and
                $evt.PSObject.Properties.Match('message').Count -gt 0 -and
                $evt.message
            ) {
                $assistantMessage = Get-QwenAssistantMessageText -Message $evt.message
                if (-not [string]::IsNullOrWhiteSpace($assistantMessage)) {
                    $lastAgentMessage = [string]$assistantMessage
                }
            }

            if (
                [string]::IsNullOrWhiteSpace($lastAgentMessage) -and
                $evt.type -eq 'result' -and
                $evt.PSObject.Properties.Match('result').Count -gt 0 -and
                $evt.result
            ) {
                $lastAgentMessage = [string]$evt.result
            }

            if (
                $evt.type -eq 'error' -and
                $evt.PSObject.Properties.Match('message').Count -gt 0 -and
                $evt.message
            ) {
                $structuredErrorMessage = [string]$evt.message
            }

            if (
                $evt.type -eq 'result' -and
                (
                    ($evt.PSObject.Properties.Match('is_error').Count -gt 0 -and [bool]$evt.is_error) -or
                    ($evt.PSObject.Properties.Match('subtype').Count -gt 0 -and $evt.subtype -ne 'success')
                )
            ) {
                if ($evt.PSObject.Properties.Match('result').Count -gt 0 -and $evt.result) {
                    $structuredErrorMessage = [string]$evt.result
                }
            }
        }
    }
    else {
        foreach ($line in @($invocation.StdErrLines + $invocation.StdOutLines)) {
            Write-Host ([string]$line)
        }
    }

    if ($exitCode -eq 0 -and -not [string]::IsNullOrWhiteSpace($SessionName)) {
        $finalSessionId =
            if (-not [string]::IsNullOrWhiteSpace($observedSessionId)) {
                $observedSessionId
            }
            elseif ($existingSession -and $existingSession.SessionId) {
                [string]$existingSession.SessionId
            }
            else {
                $null
            }

        if ([string]::IsNullOrWhiteSpace($finalSessionId)) {
            throw "qwen completed successfully but did not emit a session id for named session '$SessionName'."
        }

        $sessionMap[$sessionKey] = @{
            SessionName   = $SessionName
            SessionId     = $finalSessionId
            LastDirectory = $effectiveDirectory
            UpdatedUtc    = [DateTime]::UtcNow.ToString('o')
        }

        Write-QwenSessionMap -SessionMap $sessionMap -SessionStorePath $sessionStorePath
        $existingSession = $sessionMap[$sessionKey]
    }

    if (-not [string]::IsNullOrWhiteSpace($OutputLastMessage) -and -not [string]::IsNullOrWhiteSpace($lastAgentMessage)) {
        Set-Content -LiteralPath $OutputLastMessage -Value $lastAgentMessage -Encoding UTF8
    }

    if ($exitCode -ne 0) {
        if ($canResume) {
            $resumeMessage = "qwen command failed with exit code $exitCode while resuming session '$SessionName' ($([string]$existingSession.SessionId))."

            if (-not [string]::IsNullOrWhiteSpace($structuredErrorMessage)) {
                throw "$resumeMessage $structuredErrorMessage Remove or replace the stored Qwen session mapping if the session id is stale."
            }

            throw "$resumeMessage Remove or replace the stored Qwen session mapping if the session id is stale."
        }

        if (-not [string]::IsNullOrWhiteSpace($structuredErrorMessage)) {
            throw "qwen command failed with exit code $exitCode. $structuredErrorMessage"
        }

        throw "qwen command failed with exit code $exitCode."
    }

    [pscustomobject]@{
        CommandPath       = $qwenCmd
        Directory         = $effectiveDirectory
        SessionName       = $SessionName
        SessionId         = if ($existingSession) { $existingSession.SessionId } else { $observedSessionId }
        Prompt            = $Prompt
        AllowDangerous    = [bool]$AllowDangerous
        Json              = [bool]$effectiveStructuredOutput
        OutputLastMessage = $OutputLastMessage
        LastAgentMessage  = $lastAgentMessage
        ExitCode          = $exitCode
        Resumed           = $canResume
        EffectiveArgs     = $argArray
    }
}
