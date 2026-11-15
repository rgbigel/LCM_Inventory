<#
Module: tools/subsystem/Show-HaAuthDialog.ps1
Purpose: Displays a visual WPF GUI modal dialog prompting for JIT ephemeral operator credentials with toggleable password visibility and mutation preview.
Path: tools/subsystem/Show-HaAuthDialog.ps1
Authors: Rolf, LCM_AI Engine
Version: 5.0.2
.SYNOPSIS
  Displays a visual WPF GUI modal dialog prompting for JIT ephemeral operator credentials with toggleable password visibility and mutation preview.

.PARAMETER TargetSubsystem
  Name of the target Subsystem requiring authentication.

.PARAMETER MutationAction
  Description of the privileged service or mutation call to execute.

.PARAMETER RiskLevel
  Assessed risk level (Low, Medium, High, Critical).

.PARAMETER MutationPreview
  Text diff or command preview of the mutation.

.PARAMETER Help
  Displays this synopsis and usage screen.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = 'Name of the target Subsystem requiring authentication.')]
    [string]$TargetSubsystem = "HaSSD06 (Home Assistant OS)",

    [Parameter(Mandatory = $false, HelpMessage = 'Description of the privileged service or mutation call to execute.')]
    [string]$MutationAction = "Execute Privileged Service / Mutation Call",

    [Parameter(Mandatory = $false, HelpMessage = 'Assessed risk level (Low, Medium, High, Critical).')]
    [string]$RiskLevel = "Medium",

    [Parameter(Mandatory = $false, HelpMessage = 'Text diff or command preview of the mutation.')]
    [string]$MutationPreview = "Service: homeassistant.update_entity`nTarget: 192.168.10.6:8123`nTimeout: 30s",

    [Parameter(Mandatory = $false, HelpMessage = 'Displays this synopsis and usage screen.')]
    [Alias('h', '?')]
    [switch]$Help
)

if ($Help) {
    Write-Host "Show-HaAuthDialog.ps1 - JIT Ephemeral Authorization dialog for privileged subsystem mutations." -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Usage:"
    Write-Host "  pwsh -File Show-HaAuthDialog.ps1 [-TargetSubsystem <string>] [-MutationAction <string>] [-RiskLevel <string>] [-MutationPreview <string>] [-Help]"
    Write-Host ""
    Write-Host "Parameters:"
    Write-Host "  -TargetSubsystem  Name of the subsystem requiring authorization."
    Write-Host "  -MutationAction   Action description."
    Write-Host "  -RiskLevel        Risk severity (Low, Medium, High, Critical)."
    Write-Host "  -MutationPreview  Diff or command details."
    Write-Host "  -Help             (-h, -?) Displays this help message."
    exit 0
}

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Subsystem JIT Ephemeral Authorization"
        Height="420" Width="520"
        WindowStartupLocation="CenterScreen"
        ResizeMode="NoResize"
        Background="#1E1E2E"
        Foreground="#CDD6F4"
        FontFamily="Segoe UI"
        Topmost="True">
    <Grid Margin="20">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <!-- Header -->
        <StackPanel Grid.Row="0" Margin="0,0,0,12">
            <TextBlock Text="🔒 Privileged Subsystem Authorization" FontSize="18" FontWeight="Bold" Foreground="#89B4FA"/>
            <TextBlock Text="A privileged mutation has been requested on the disjunct Subsystem domain." FontSize="12" Foreground="#A6ADC8" Margin="0,4,0,0"/>
        </StackPanel>

        <!-- Target & Action Info -->
        <Border Grid.Row="1" Background="#181825" CornerRadius="6" Padding="10" Margin="0,0,0,12" BorderBrush="#313244" BorderThickness="1">
            <StackPanel>
                <TextBlock Text="Subsystem: $TargetSubsystem" FontWeight="SemiBold" Foreground="#F9E2AF"/>
                <TextBlock Text="Action: $MutationAction" Foreground="#CDD6F4" Margin="0,2,0,0"/>
                <TextBlock Text="Risk Assessment: $RiskLevel" Foreground="#F38BA8" FontWeight="Bold" Margin="0,2,0,0"/>
            </StackPanel>
        </Border>

        <!-- Mutation Preview Box -->
        <GroupBox Grid.Row="2" Header="Mutation Diff Preview" Foreground="#A6ADC8" BorderBrush="#313244" Margin="0,0,0,12">
            <TextBox Name="txtPreview" Background="#11111B" Foreground="#A6E3A1" FontFamily="Consolas" FontSize="11" 
                     IsReadOnly="True" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto" Margin="5" Padding="5"
                     BorderThickness="0"/>
        </GroupBox>

        <!-- Credential Input -->
        <StackPanel Grid.Row="3" Margin="0,0,0,10">
            <TextBlock Text="Enter Operator Password / Long-Lived Write Token:" FontWeight="SemiBold" Margin="0,0,0,4"/>
            <Grid>
                <PasswordBox Name="txtPassword" Height="28" Background="#11111B" Foreground="#CDD6F4" 
                             BorderBrush="#45475A" Padding="4" VerticalContentAlignment="Center"/>
                <TextBox Name="txtPlainPassword" Height="28" Background="#11111B" Foreground="#CDD6F4" 
                         BorderBrush="#45475A" Padding="4" VerticalContentAlignment="Center" Visibility="Collapsed"/>
            </Grid>
            <CheckBox Name="chkShowPassword" Content="Show Password / Token Characters" Foreground="#A6ADC8" Margin="0,6,0,0"/>
        </StackPanel>

        <!-- Action Buttons -->
        <StackPanel Grid.Row="5" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,5,0,0">
            <Button Name="btnCancel" Content="Cancel Mutation" Width="120" Height="30" Margin="0,0,10,0" 
                    Background="#313244" Foreground="#CDD6F4" BorderThickness="0" Cursor="Hand"/>
            <Button Name="btnAuthorize" Content="Authorize Mutation" Width="140" Height="30" 
                    Background="#89B4FA" Foreground="#11111B" FontWeight="Bold" BorderThickness="0" Cursor="Hand"/>
        </StackPanel>
    </Grid>
</Window>
"@

$reader = [System.Xml.XmlNodeReader]::new($xaml)
$window = [System.Windows.Markup.XamlReader]::Load($reader)

$txtPreview = $window.FindName('txtPreview')
$txtPassword = $window.FindName('txtPassword')
$txtPlainPassword = $window.FindName('txtPlainPassword')
$chkShowPassword = $window.FindName('chkShowPassword')
$btnAuthorize = $window.FindName('btnAuthorize')
$btnCancel = $window.FindName('btnCancel')

$txtPreview.Text = $MutationPreview

# Password Reveal Toggle Logic
$chkShowPassword.add_Checked({
    $txtPlainPassword.Text = $txtPassword.Password
    $txtPassword.Visibility = [System.Windows.Visibility]::Collapsed
    $txtPlainPassword.Visibility = [System.Windows.Visibility]::Visible
})

$chkShowPassword.add_Unchecked({
    $txtPassword.Password = $txtPlainPassword.Text
    $txtPlainPassword.Visibility = [System.Windows.Visibility]::Collapsed
    $txtPassword.Visibility = [System.Windows.Visibility]::Visible
})

$script:authResult = $null

$btnAuthorize.add_Click({
    $secret = if ($chkShowPassword.IsChecked) { $txtPlainPassword.Text } else { $txtPassword.Password }
    if ([string]::IsNullOrWhiteSpace($secret)) {
        [System.Windows.MessageBox]::Show("Please provide the operator credential to authorize the mutation.", "Authentication Required", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
        return
    }
    $script:authResult = [pscustomobject]@{
        Authorized = $true
        Credential = $secret
        AuthorizedAt = (Get-Date).ToString('o')
    }
    $window.Close()
})

$btnCancel.add_Click({
    $script:authResult = [pscustomobject]@{
        Authorized = $false
        Credential = $null
        AuthorizedAt = (Get-Date).ToString('o')
    }
    $window.Close()
})

$null = $window.ShowDialog()
return $script:authResult
