<#
.SYNOPSIS
ShivTrix Core - Standalone Windows PowerShell Bridge (works on Windows PowerShell 5.1 and PowerShell 7).
Listens on http://127.0.0.1:9871/ and serves the endpoints the web app calls:
  /api/powertoys/health, /metrics, /api/powertoys/adapters,
  /api/powertoys/portcheck, /api/powertoys/ping, /api/powertoys/nslookup
Note: live streaming tools (continuous ping, traceroute) and WebRTC LAN signaling need companion.py.
#>

$port = 9871
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://127.0.0.1:$port/")

try {
    $listener.Start()
} catch {
    Write-Host "Failed to bind to port $port. Is companion.py / another helper already running?" -ForegroundColor Red
    exit 1
}

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  ShivTrix Core - PowerShell Bridge Online" -ForegroundColor Green
Write-Host "  Listening on: http://127.0.0.1:$port/" -ForegroundColor White
Write-Host "  Press Ctrl+C to stop" -ForegroundColor Yellow
Write-Host "==========================================================" -ForegroundColor Cyan

function Send-Json($response, $obj, $status = 200) {
    $json = ConvertTo-Json -InputObject $obj -Depth 6 -Compress
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
    $response.StatusCode = $status
    $response.ContentType = "application/json"
    $response.ContentLength64 = $bytes.Length
    $response.OutputStream.Write($bytes, 0, $bytes.Length)
}

function Get-Param($request, $name, $default = "") {
    $v = $request.QueryString[$name]
    if ([string]::IsNullOrWhiteSpace($v)) { return $default }
    return $v.Trim()
}

function Test-SafeHost($h) { return ($h -match '^[A-Za-z0-9._:-]{1,253}$') }

while ($listener.IsListening) {
    $context = $listener.GetContext()
    $request = $context.Request
    $response = $context.Response
    $response.Headers.Add("Access-Control-Allow-Origin", "*")
    $response.Headers.Add("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
    $response.Headers.Add("Access-Control-Allow-Headers", "*")

    try {
        if ($request.HttpMethod -eq "OPTIONS") { $response.StatusCode = 200; continue }
        $path = $request.Url.AbsolutePath

        switch ($path) {
            "/api/powertoys/health" {
                Send-Json $response @{ status = "online"; platform = "Windows"; engine = "PowerShell Bridge"; version = "5.0.0"; authenticated = $true }
            }
            { $_ -eq "/metrics" -or $_ -eq "/api/metrics" } {
                $cpu = (Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average
                if ($null -eq $cpu) { $cpu = 0 }
                $os = Get-CimInstance Win32_OperatingSystem
                $totalGb = [math]::Round($os.TotalVisibleMemorySize / 1MB, 1)
                $freeGb = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
                $usedGb = [math]::Round($totalGb - $freeGb, 2)
                $pct = [math]::Round(($usedGb / $totalGb) * 100, 1)
                $cores = @(1..[Environment]::ProcessorCount | ForEach-Object { [double]$cpu })
                Send-Json $response @{
                    status = "connected"; os = "Windows"; os_release = $os.Version
                    timestamp = [double](Get-Date -UFormat %s)
                    cpu_percent = [double]$cpu; cpu_cores = $cores
                    ram_total_gb = $totalGb; ram_used_gb = $usedGb; ram_free_gb = $freeGb; ram_percent = $pct
                }
            }
            "/api/powertoys/adapters" {
                $list = @()
                Get-NetAdapter -ErrorAction SilentlyContinue | ForEach-Object {
                    $ip = (Get-NetIPAddress -InterfaceIndex $_.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue | Select-Object -First 1)
                    $list += @{
                        name = $_.Name; description = $_.InterfaceDescription; status = [string]$_.Status
                        speed = $_.LinkSpeed; mac = $_.MacAddress
                        ipv4 = $(if ($ip) { "$($ip.IPAddress) / $($ip.PrefixLength)" } else { "-" })
                        type = $(if ($_.Virtual) { "Virtual" } else { "Physical" })
                    }
                }
                Send-Json $response @{ status = "success"; adapters = $list; count = $list.Count }
            }
            "/api/powertoys/portcheck" {
                $h = Get-Param $request "host"
                $p = [int](Get-Param $request "port" "0")
                if (-not (Test-SafeHost $h) -or $p -lt 1 -or $p -gt 65535) { Send-Json $response @{ status = "error"; message = "Invalid host or port" } 400; continue }
                $sw = [Diagnostics.Stopwatch]::StartNew()
                $client = New-Object System.Net.Sockets.TcpClient
                $ok = $false
                try { $ok = $client.ConnectAsync($h, $p).Wait(3000) -and $client.Connected } catch { $ok = $false }
                $sw.Stop(); $client.Close()
                $msg = if ($ok) { "Port $p on $h is reachable and accepting TCP connections." } else { "Could not connect to ${h}:$p (closed, filtered, or timed out)." }
                Send-Json $response @{
                    status = "success"; host = $h; port = $p; reachable = $ok; protocol = "TCP"
                    latency_ms = [math]::Round($sw.Elapsed.TotalMilliseconds, 2); message = $msg
                    disclaimer = "Outbound TCP reachability test only. Does not open ports on remote computers."
                }
            }
            "/api/powertoys/ping" {
                $h = Get-Param $request "host"
                $c = [math]::Min([math]::Max([int](Get-Param $request "count" "4"), 1), 10)
                if (-not (Test-SafeHost $h)) { Send-Json $response @{ status = "error"; message = "Invalid hostname" } 400; continue }
                $out = (& ping.exe -n $c $h 2>&1 | Out-String)
                $ok = $out -match "TTL="
                Send-Json $response @{ status = "success"; host = $h; count = $c; raw_output = $out.Trim(); success = [bool]$ok }
            }
            "/api/powertoys/nslookup" {
                $h = Get-Param $request "host"
                $t = (Get-Param $request "type" "A").ToUpper()
                $s = Get-Param $request "server" "default"
                if (-not (Test-SafeHost $h)) { Send-Json $response @{ status = "error"; message = "Invalid hostname"; records = @() } 400; continue }
                if (@("A","AAAA","CNAME","MX","TXT","NS","SOA","ANY") -notcontains $t) { $t = "A" }
                $args = @("-type=$t", $h)
                if ($s -ne "default" -and (Test-SafeHost $s)) { $args += $s }
                $out = (& nslookup.exe @args 2>&1 | Out-String)
                $records = @()
                $afterName = $false
                foreach ($line in ($out -split "`r?`n")) {
                    if ($line -match '^\s*Name:') { $afterName = $true; continue }
                    if ($afterName -and $line -match 'Address(es)?:\s*(.+)$') { $records += @{ name = $h; type = $t; ttl = "-"; data = $Matches[2].Trim() }; continue }
                    if ($afterName -and $line -match '^\s+([0-9a-fA-F:.]+)\s*$') { $records += @{ name = $h; type = $t; ttl = "-"; data = $Matches[1] } }
                }
                Send-Json $response @{ status = "success"; host = $h; type = $t; records = $records; raw_output = $out.Trim() }
            }
            default {
                Send-Json $response @{ status = "ok"; message = "ShivTrix PowerShell Bridge Active" }
            }
        }
    } catch {
        try { Send-Json $response @{ status = "error"; message = $_.Exception.Message } 500 } catch {}
    } finally {
        $response.Close()
    }
}
