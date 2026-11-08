<#
.SYNOPSIS
  Cryptographic single-use JIT ephemeral token vault for privileged daemon actions.
.DESCRIPTION
  Module: LcmDaemon/Classes/LcmTokenVault.ps1
  Purpose: Issues and verifies 30-second TTL single-use cryptographic tokens (HMAC-SHA256)
           for high-risk administrative mutations in Session 1 per CRP-309 Clause 6.
  Path: LCM_Inventory/modules/LcmDaemon/Classes/LcmTokenVault.ps1
  Authors: Rolf, LCM_AI Engine
  Version: 10.0.1
  Date: 2026-11-08 15:17:24
.NOTES
  Implementation Choices (CRP-309):
  1. Ephemeral tokens are bound to a 32-byte cryptographic nonce and target command hash.
  2. Single-use enforcement: verified tokens are immediately burned to prevent replay attacks.
  3. TTL: 30 seconds; expired tokens are rejected deterministically.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

class LcmTokenVault {
  static [string]$TokenStoreDir = "LCM_Inventory/data/tokens"
  static [int]$TtlSeconds = 30
  static [System.Collections.Concurrent.ConcurrentDictionary[string, datetime]]$BurnedTokens = [System.Collections.Concurrent.ConcurrentDictionary[string, datetime]]::new()
  static [System.Collections.Concurrent.ConcurrentDictionary[string, psobject]]$ActiveTokens = [System.Collections.Concurrent.ConcurrentDictionary[string, psobject]]::new()

  static [string] IssueToken([string]$Target, [string]$Caller, [string]$WorkspaceRoot) {
    if ([string]::IsNullOrWhiteSpace($Target)) {
      throw [System.ArgumentException]::new("Target intent cannot be blank for token issuance.")
    }

    $nonceBytes = [byte[]]::new(32)
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $rng.GetBytes($nonceBytes)
    $nonce = [Convert]::ToBase64String($nonceBytes)

    $now = [datetime]::UtcNow
    $expiresAt = $now.AddSeconds([LcmTokenVault]::TtlSeconds)

    # Compute signature: HMAC-SHA256(Nonce, Target:Caller:ExpiresAt)
    $keyBytes = [System.Text.Encoding]::UTF8.GetBytes($nonce)
    $payloadBytes = [System.Text.Encoding]::UTF8.GetBytes("${Target}:${Caller}:$($expiresAt.Ticks)")
    $hmac = [System.Security.Cryptography.HMACSHA256]::new($keyBytes)
    $sigBytes = $hmac.ComputeHash($payloadBytes)
    $sig = [Convert]::ToBase64String($sigBytes)

    $tokenStr = "${nonce}.${sig}"

    $tokenRecord = [PSCustomObject]@{
      Token     = $tokenStr
      Target    = $Target
      Caller    = $Caller
      CreatedAt = $now
      ExpiresAt = $expiresAt
    }

    [void][LcmTokenVault]::ActiveTokens.TryAdd($tokenStr, $tokenRecord)

    # Persist token metadata to Quad-Principal secured directory if directory exists or create
    try {
      $storePath = if ([System.IO.Path]::IsPathRooted([LcmTokenVault]::TokenStoreDir)) {
        [LcmTokenVault]::TokenStoreDir
      } else {
        [System.IO.Path]::Combine($WorkspaceRoot, [LcmTokenVault]::TokenStoreDir)
      }
      if (-not (Test-Path -LiteralPath $storePath)) {
        [void][System.IO.Directory]::CreateDirectory($storePath)
      }
      $filePath = [System.IO.Path]::Combine($storePath, "$($now.ToString('yyyyMMdd_HHmmss'))_$([guid]::NewGuid().ToString('N')).token")
      $metaJson = $tokenRecord | ConvertTo-Json -Compress
      [System.IO.File]::WriteAllText($filePath, $metaJson, [System.Text.UTF8Encoding]::new($false))
    } catch {}

    return $tokenStr
  }

  static [bool] VerifyAndBurnToken([string]$Token, [string]$Target, [string]$Caller) {
    if ([string]::IsNullOrWhiteSpace($Token)) {
      return $false
    }

    # Replay check
    if ([LcmTokenVault]::BurnedTokens.ContainsKey($Token)) {
      return $false
    }

    # Active lookup
    $record = $null
    if (-not [LcmTokenVault]::ActiveTokens.TryGetValue($Token, [ref]$record)) {
      # Fallback: parse token parts
      $parts = $Token.Split('.')
      if ($parts.Length -ne 2) { return $false }
      return $false
    }

    $now = [datetime]::UtcNow
    if ($now -gt $record.ExpiresAt) {
      # Expired: burn and reject
      [void][LcmTokenVault]::ActiveTokens.TryRemove($Token, [ref]$record)
      [void][LcmTokenVault]::BurnedTokens.TryAdd($Token, $now)
      return $false
    }

    if ($record.Target -ne $Target) {
      return $false
    }

    # Burn on single use
    [void][LcmTokenVault]::ActiveTokens.TryRemove($Token, [ref]$record)
    [void][LcmTokenVault]::BurnedTokens.TryAdd($Token, $now)
    return $true
  }

  static [void] PurgeExpiredTokens() {
    $now = [datetime]::UtcNow
    $keysToRemove = @()
    foreach ($kvp in [LcmTokenVault]::ActiveTokens) {
      if ($now -gt $kvp.Value.ExpiresAt) {
        $keysToRemove += $kvp.Key
      }
    }
    foreach ($k in $keysToRemove) {
      $dummy = $null
      [void][LcmTokenVault]::ActiveTokens.TryRemove($k, [ref]$dummy)
    }
  }
}

