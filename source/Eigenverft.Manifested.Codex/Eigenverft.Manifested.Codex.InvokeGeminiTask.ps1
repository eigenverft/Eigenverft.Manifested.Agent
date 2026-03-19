<#
    Eigenverft.Manifested.Codex.InvokeGeminiTask
#>

function Get-GeminiSessionStorePath {
    [CmdletBinding()]
    param(
        [string]$LocalRoot = (Get-CodexLocalRoot)
    )

    return (Join-Path (Join-Path $LocalRoot 'sessions') 'named-gemini-sessions.json')
}

function Get-GeminiSessionKey {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SessionName
    )

    return ($SessionName.Trim() -replace '\|', '_')
}

function Read-GeminiSessionMap {
    [CmdletBinding()]
    param(
        [string]$SessionStorePath = (Get-GeminiSessionStorePath)
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
        throw "Failed to read Gemini session store: $SessionStorePath"
    }

    return $sessionMap
}

function Write-GeminiSessionMap {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$SessionMap,

        [string]$SessionStorePath = (Get-GeminiSessionStorePath)
    )

    $sessionStoreRoot = Split-Path -Parent $SessionStorePath
    if (-not (Test-Path -LiteralPath $sessionStoreRoot)) {
        New-Item -ItemType Directory -Path $sessionStoreRoot -Force | Out-Null
    }

    ($SessionMap | ConvertTo-Json -Depth 6) | Set-Content -LiteralPath $SessionStorePath -Encoding UTF8
}

function Resolve-GeminiCommandPath {
    [CmdletBinding()]
    param()

    foreach ($candidate in @('gemini.cmd', 'gemini', 'gemini.ps1')) {
        $resolvedGemini = Get-Command $candidate -ErrorAction SilentlyContinue
        if (-not $resolvedGemini) {
            continue
        }

        if ($resolvedGemini.PSObject.Properties['Path'] -and $resolvedGemini.Path) {
            return $resolvedGemini.Path
        }

        return $resolvedGemini.Source
    }

    throw 'gemini was not found on PATH. Install the Gemini CLI or add it to PATH before using Invoke-GeminiTask.'
}

function Get-GeminiSessionListing {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$GeminiCommandPath,

        [Parameter(Mandatory = $true)]
        [string]$Directory
    )

    $outputLines = @()
    $exitCode = 0

    try {
        Push-Location -LiteralPath $Directory
        $global:LASTEXITCODE = 0
        $outputLines = @(& $GeminiCommandPath '--list-sessions' 2>&1)
        $exitCode = $global:LASTEXITCODE
    }
    catch {
        $outputLines = @([string]$_)
        $exitCode = 1
    }
    finally {
        Pop-Location
    }

    $sessionIds = New-Object System.Collections.Generic.List[string]

    foreach ($line in $outputLines) {
        $text = [string]$line
        $match = [regex]::Match($text, '\[(?<id>[^\]]+)\]')

        if ($match.Success) {
            [void]$sessionIds.Add($match.Groups['id'].Value)
        }
    }

    [pscustomobject]@{
        Succeeded  = ($exitCode -eq 0)
        ExitCode   = $exitCode
        SessionIds = @($sessionIds | Select-Object -Unique)
        Lines      = @($outputLines | ForEach-Object { [string]$_ })
    }
}

function Invoke-GeminiTask {
<#
.SYNOPSIS
Runs a Gemini non-interactive task and maintains wrapper-level named session state.

.DESCRIPTION
Thin PowerShell wrapper around Gemini CLI headless mode.

Wrapper-managed named sessions store:
- SessionName
- SessionId
- LastDirectory
- UpdatedUtc

Gemini-native sessions remain project-scoped.
This wrapper keeps a friendly session name that points at the last observed Gemini session id.

For named sessions, the wrapper uses `--output-format stream-json`
so it can capture the Gemini session id from the `init` event.

Before resuming a named session, the wrapper checks `gemini --list-sessions`
in the effective directory. If the stored Gemini session is no longer listed,
the wrapper starts a fresh Gemini session instead of forcing a stale resume id.
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

    $geminiCmd = Resolve-GeminiCommandPath

    $currentDirectory = Resolve-CodexDirectory -Directory ((Get-Location).ProviderPath)
    $directoryProvided = $PSBoundParameters.ContainsKey('Directory')
    $requestedDirectory = $null

    if ($directoryProvided) {
        $requestedDirectory = Resolve-CodexDirectory -Directory $Directory
    }

    $sessionStorePath = Get-GeminiSessionStorePath
    $sessionStoreRoot = Split-Path -Parent $sessionStorePath

    if (-not (Test-Path -LiteralPath $sessionStoreRoot)) {
        New-Item -ItemType Directory -Path $sessionStoreRoot -Force | Out-Null
    }

    $sessionMap =
        if (Test-Path -LiteralPath $sessionStorePath) {
            Read-GeminiSessionMap -SessionStorePath $sessionStorePath
        }
        else {
            @{}
        }

    $sessionKey = $null
    $existingSession = $null
    $effectiveDirectory = $currentDirectory

    if (-not [string]::IsNullOrWhiteSpace($SessionName)) {
        $sessionKey = Get-GeminiSessionKey -SessionName $SessionName

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

    $preRunListing = $null

    if ($existingSession -and $existingSession.SessionId) {
        $preRunListing = Get-GeminiSessionListing -GeminiCommandPath $geminiCmd -Directory $effectiveDirectory

        if ($preRunListing.Succeeded) {
            $storedSessionId = [string]$existingSession.SessionId

            if (-not ($preRunListing.SessionIds -contains $storedSessionId)) {
                $existingSession = $null
            }
        }
    }

    $canResume = [bool](
        $existingSession -and
        $existingSession.SessionId
    )

    $effectiveOutputFormat =
        if (-not [string]::IsNullOrWhiteSpace($SessionName)) {
            'stream-json'
        }
        elseif ($Json) {
            'json'
        }
        else {
            'text'
        }

    if ([string]::IsNullOrWhiteSpace($OutputLastMessage) -and $effectiveOutputFormat -ne 'text') {
        $safeDirName = ([IO.Path]::GetFileName($effectiveDirectory)).Trim()
        if ([string]::IsNullOrWhiteSpace($safeDirName)) {
            $safeDirName = 'workspace'
        }

        $safeDirName = ($safeDirName -replace '[^A-Za-z0-9._-]', '_')

        if ([string]::IsNullOrWhiteSpace($SessionName)) {
            $OutputLastMessage = Join-Path $env:TEMP ("gemini-last-message-{0}-{1}.txt" -f $safeDirName, ([Guid]::NewGuid().ToString('N')))
        }
        else {
            $safeSessionFile = ($SessionName -replace '[^A-Za-z0-9._-]', '_')
            $OutputLastMessage = Join-Path $env:TEMP ("gemini-last-message-{0}-{1}.txt" -f $safeDirName, $safeSessionFile)
        }
    }

    $cargs = New-Object System.Collections.Generic.List[string]

    if ($canResume) {
        [void]$cargs.Add('--resume')
        [void]$cargs.Add([string]$existingSession.SessionId)
    }

    if (-not [string]::IsNullOrWhiteSpace($Model)) {
        [void]$cargs.Add('--model')
        [void]$cargs.Add($Model)
    }

    if ($AllowDangerous) {
        [void]$cargs.Add('--approval-mode')
        [void]$cargs.Add('yolo')
    }
    else {
        [void]$cargs.Add('--sandbox')
    }

    foreach ($dir in @($AddDir)) {
        if (-not [string]::IsNullOrWhiteSpace($dir)) {
            [void]$cargs.Add('--include-directories')
            [void]$cargs.Add((Resolve-CodexDirectory -Directory $dir))
        }
    }

    [void]$cargs.Add('--output-format')
    [void]$cargs.Add($effectiveOutputFormat)
    [void]$cargs.Add('-p')
    [void]$cargs.Add($Prompt)

    $argArray = $cargs.ToArray()
    $observedSessionId = $null
    $lastAgentMessage = $null
    $structuredErrorMessage = $null
    $exitCode = 0
    $assistantMessageBuilder = New-Object System.Text.StringBuilder

    try {
        Push-Location -LiteralPath $effectiveDirectory

        if ($effectiveOutputFormat -eq 'stream-json') {
            $global:LASTEXITCODE = 0
            $outputLines = @(& $geminiCmd @argArray 2>&1)
            $exitCode = $global:LASTEXITCODE

            foreach ($line in $outputLines) {
                $text = [string]$line
                Write-Host $text

                try {
                    $evt = $text | ConvertFrom-Json -Depth 100

                    if ($evt.type -eq 'init' -and $evt.session_id) {
                        $observedSessionId = [string]$evt.session_id
                    }

                    if ($evt.type -eq 'message' -and $evt.role -eq 'assistant' -and $evt.content) {
                        if ($evt.PSObject.Properties['delta'] -and [bool]$evt.delta) {
                            [void]$assistantMessageBuilder.Append([string]$evt.content)
                        }
                        elseif ($assistantMessageBuilder.Length -eq 0) {
                            [void]$assistantMessageBuilder.Append([string]$evt.content)
                        }
                    }

                    if ($evt.type -eq 'result' -and $evt.error -and $evt.error.message) {
                        $structuredErrorMessage = [string]$evt.error.message
                    }
                }
                catch {
                    # Ignore non-JSON lines.
                }
            }

            if ($assistantMessageBuilder.Length -gt 0) {
                $lastAgentMessage = $assistantMessageBuilder.ToString()
            }
        }
        elseif ($effectiveOutputFormat -eq 'json') {
            $global:LASTEXITCODE = 0
            $rawStructuredOutput = (& $geminiCmd @argArray 2>&1 | Out-String)
            $exitCode = $global:LASTEXITCODE

            if (-not [string]::IsNullOrWhiteSpace($rawStructuredOutput)) {
                Write-Host ($rawStructuredOutput.TrimEnd("`r", "`n"))

                try {
                    $payload = $rawStructuredOutput | ConvertFrom-Json -Depth 100

                    if ($payload.PSObject.Properties['session_id'] -and $payload.session_id) {
                        $observedSessionId = [string]$payload.session_id
                    }

                    if ($payload.PSObject.Properties['response'] -and $payload.response) {
                        $lastAgentMessage = [string]$payload.response
                    }

                    if ($payload.PSObject.Properties['error'] -and $payload.error -and $payload.error.message) {
                        $structuredErrorMessage = [string]$payload.error.message
                    }
                }
                catch {
                    # Ignore invalid JSON payloads.
                }
            }
        }
        else {
            $global:LASTEXITCODE = 0
            & $geminiCmd @argArray
            $exitCode = $global:LASTEXITCODE
        }
    }
    finally {
        Pop-Location
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

        if (-not [string]::IsNullOrWhiteSpace($finalSessionId)) {
            $sessionMap[$sessionKey] = @{
                SessionName   = $SessionName
                SessionId     = $finalSessionId
                LastDirectory = $effectiveDirectory
                UpdatedUtc    = [DateTime]::UtcNow.ToString('o')
            }

            Write-GeminiSessionMap -SessionMap $sessionMap -SessionStorePath $sessionStorePath
            $existingSession = $sessionMap[$sessionKey]
        }

        [void](Get-GeminiSessionListing -GeminiCommandPath $geminiCmd -Directory $effectiveDirectory)
    }

    if (-not [string]::IsNullOrWhiteSpace($OutputLastMessage) -and -not [string]::IsNullOrWhiteSpace($lastAgentMessage)) {
        Set-Content -LiteralPath $OutputLastMessage -Value $lastAgentMessage -Encoding UTF8
    }

    if ($exitCode -ne 0) {
        if (-not [string]::IsNullOrWhiteSpace($structuredErrorMessage)) {
            throw "gemini command failed with exit code $exitCode. $structuredErrorMessage"
        }

        throw "gemini command failed with exit code $exitCode."
    }

    [pscustomobject]@{
        CommandPath       = $geminiCmd
        Directory         = $effectiveDirectory
        SessionName       = $SessionName
        SessionId         = if ($existingSession) { $existingSession.SessionId } else { $observedSessionId }
        Prompt            = $Prompt
        AllowDangerous    = [bool]$AllowDangerous
        Json              = [bool]($effectiveOutputFormat -ne 'text')
        OutputLastMessage = $OutputLastMessage
        LastAgentMessage  = $lastAgentMessage
        ExitCode          = $exitCode
        Resumed           = $canResume
        EffectiveArgs     = $argArray
    }
}
