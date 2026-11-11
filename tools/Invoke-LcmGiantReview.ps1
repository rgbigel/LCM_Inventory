<#
.SYNOPSIS
  [DEPRECATED & RETIRED] Legacy review launcher replaced by BCR.
.DESCRIPTION
  This script is permanently decommissioned under RULE-REV-014.
  All baseline reviews must route exclusively through BCR (Invoke-MacriumBcrReview.ps1 / BCR.cmd)
  using today's Macrium Reflect backup baseline and the _LCM Beyond Compare profile.
#>
[CmdletBinding()]
param()

throw "Invoke-LcmGiantReview is RETIRED and FORBIDDEN under RULE-REV-014. Baseline reviews must exclusively use BCR (Invoke-MacriumBcrReview.ps1 / BCR.cmd) with the Macrium Reflect backup baseline and _LCM profile."
