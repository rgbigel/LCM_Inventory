<#
Module: tools/Show-LcmActiveLauncher.ps1
Purpose: Interactive Desktop GUI & Active Help Launcher for all LCM and Subsystem tools with one-click execution.
Governance Invariant (RULE-EFF-001): Direct interactive tool orchestration.
Path: tools/Show-LcmActiveLauncher.ps1
Authors: Rolf, LCM_AI Engine
Version: 5.0.3
Date: 2026-09-10
#>

[CmdletBinding()]
param(
    [Alias('h', '?')]
    [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Help) {
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host " LCM ACTIVE LAUNCHER (Show-LcmActiveLauncher)" -ForegroundColor Cyan
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host "SYNOPSIS:" -ForegroundColor Yellow
    Write-Host "  Interactive Desktop GUI & Active Help Launcher for LCM and Subsystem tools."
    Write-Host ""
    Write-Host "USAGE:" -ForegroundColor Yellow
    Write-Host "  pwsh LCM_Inventory/tools/Show-LcmActiveLauncher.ps1 [-h]"
    Write-Host ""
    Write-Host "PARAMETERS:" -ForegroundColor Yellow
    Write-Host "  -Help (-h, -?) : Displays this help screen"
    Write-Host "==========================================================================" -ForegroundColor Cyan
    return
}

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

# Tool Manifest & Active Guidance Catalog
$toolCatalog = @(
    [ordered]@{
        Name        = "Update-HaInventory.ps1"
        Category    = "Subsystem Telemetry"
        Domain      = "HaSSD06_Inventory"
        ScriptPath  = "D:\Git_Repositories\HaSSD06_Inventory\tools\Update-HaInventory.ps1"
        Description = "Queries live Home Assistant OS via WebSocket Central Registry & REST API. Reconciles 159 devices, 74 integrations, and 937 live entities into JSON & Markdown."
        Risk        = "Low (Read-Only Observer)"
        Command     = 'pwsh -NoProfile -NoExit -File "D:\Git_Repositories\HaSSD06_Inventory\tools\Update-HaInventory.ps1"'
    },
    [ordered]@{
        Name        = "Show-HaInventoryApp.ps1"
        Category    = "Subsystem GUI"
        Domain      = "HaSSD06_Inventory"
        ScriptPath  = "D:\Git_Repositories\HaSSD06_Inventory\tools\Show-HaInventoryApp.ps1"
        Description = "Generates and opens the dark-mode interactive HTML browser dashboard displaying 937 live entities, 159 devices, add-ons, and automations."
        Risk        = "Zero (Viewer)"
        Command     = 'pwsh -NoProfile -File "D:\Git_Repositories\HaSSD06_Inventory\tools\Show-HaInventoryApp.ps1"'
    },
    [ordered]@{
        Name        = "Show-HaInventoryGrid.ps1"
        Category    = "Subsystem GridView"
        Domain      = "HaSSD06_Inventory"
        ScriptPath  = "D:\Git_Repositories\HaSSD06_Inventory\tools\Show-HaInventoryGrid.ps1"
        Description = "Opens native Windows Out-GridView interactive table with real-time multi-column sorting and filtering across all entities and devices."
        Risk        = "Zero (Viewer)"
        Command     = 'pwsh -NoProfile -File "D:\Git_Repositories\HaSSD06_Inventory\tools\Show-HaInventoryGrid.ps1" -View All'
    },
    [ordered]@{
        Name        = "Invoke-HaUpdateGate.ps1"
        Category    = "Subsystem Governance"
        Domain      = "HaSSD06_Inventory"
        ScriptPath  = "D:\Git_Repositories\HaSSD06_Inventory\tools\Invoke-HaUpdateGate.ps1"
        Description = "5-stage external update runner (RULE-SUB-006). Ingests release notes, parses breaking changes into CRPs, verifies pre-backup, and dispatches updates."
        Risk        = "Gated (Visual Auth + Pre-Backup)"
        Command     = 'pwsh -NoProfile -NoExit -File "D:\Git_Repositories\HaSSD06_Inventory\tools\Invoke-HaUpdateGate.ps1"'
    },
    [ordered]@{
        Name        = "Test-RepoReadiness.ps1 (HaSSD06)"
        Category    = "Quality Gate"
        Domain      = "HaSSD06"
        ScriptPath  = "D:\Git_Repositories\HaSSD06\tools\Test-RepoReadiness.ps1"
        Description = "Executes 5-stage quality gate verification: Tripartite docs, schema conformance, reparse points, Python syntax, and PowerShell standards."
        Risk        = "Zero (Verification)"
        Command     = 'pwsh -NoProfile -NoExit -File "D:\Git_Repositories\HaSSD06\tools\Test-RepoReadiness.ps1"'
    },
    [ordered]@{
        Name        = "Test-RepoReadiness.ps1 (HaSSD06_Inventory)"
        Category    = "Quality Gate"
        Domain      = "HaSSD06_Inventory"
        ScriptPath  = "D:\Git_Repositories\HaSSD06_Inventory\tools\Test-RepoReadiness.ps1"
        Description = "Executes 5-stage subsystem CM quality gate including Gate 5 Secrets Isolation (asserts secrets.json and tokens are untracked)."
        Risk        = "Zero (Verification)"
        Command     = 'pwsh -NoProfile -NoExit -File "D:\Git_Repositories\HaSSD06_Inventory\tools\Test-RepoReadiness.ps1"'
    },
    [ordered]@{
        Name        = "Invoke-WorkspaceAudit.ps1"
        Category    = "Workspace Parent CM"
        Domain      = "LCM_Inventory"
        ScriptPath  = "D:\Git_Repositories\LCM_Inventory\tools\Invoke-WorkspaceAudit.ps1"
        Description = "Audits all 35+ repositories under D:\Git_Repositories, detects drift, evaluates LCM v5.0.2 alignment, and refreshes the master workspace dashboard."
        Risk        = "Low (Telemetry Audit)"
        Command     = 'pwsh -NoProfile -NoExit -File "D:\Git_Repositories\LCM_Inventory\tools\Invoke-WorkspaceAudit.ps1"'
    },
    [ordered]@{
        Name        = "Show-WorkspaceInventoryApp.ps1"
        Category    = "Workspace GUI"
        Domain      = "LCM_Inventory"
        ScriptPath  = "D:\Git_Repositories\LCM_Inventory\tools\Show-WorkspaceInventoryApp.ps1"
        Description = "Generates and opens the dark-mode interactive HTML browser dashboard displaying the 35+ repository master ledger and governance rule matrix."
        Risk        = "Zero (Viewer)"
        Command     = 'pwsh -NoProfile -File "D:\Git_Repositories\LCM_Inventory\tools\Show-WorkspaceInventoryApp.ps1"'
    },
    [ordered]@{
        Name        = "Invoke-BeyondCompareReview.ps1"
        Category    = "Review Flow"
        Domain      = "LCM_Inventory"
        ScriptPath  = "D:\Git_Repositories\LCM_Inventory\tools\Invoke-BeyondCompareReview.ps1"
        Description = "Launches Beyond Compare 5 on desktop to visually review repository changes against the baseline commit with automatic exclusion filters."
        Risk        = "Zero (Visual Gate)"
        Command     = 'pwsh -NoProfile -NoExit -Command "& \"D:\Git_Repositories\Invoke-BeyondCompareReview.ps1\" -RepositoryName HaSSD06"'
    },
    [ordered]@{
        Name        = "Test-LCMRuleHealth.ps1"
        Category    = "Governance Health"
        Domain      = "LCM_Inventory"
        ScriptPath  = "D:\Git_Repositories\LCM_Inventory\tools\Test-LCMRuleHealth.ps1"
        Description = "Scans all child repositories to verify NTFS reparse point junctions to .agents/rules and validates rule discovery integrity."
        Risk        = "Zero (Audit)"
        Command     = 'pwsh -NoProfile -NoExit -File "D:\Git_Repositories\LCM_Inventory\tools\Test-LCMRuleHealth.ps1"'
    },
    [ordered]@{
        Name        = "Invoke-LCMOnboardBatch.ps1"
        Category    = "Batch Onboarding"
        Domain      = "LCM_Inventory"
        ScriptPath  = "D:\Git_Repositories\LCM_Inventory\tools\Invoke-LCMOnboardBatch.ps1"
        Description = "Batch-migrates all remaining un-governed repositories across D:\Git_Repositories to the full LCM v5.0.2 governance architecture."
        Risk        = "High (Requires Review Gate)"
        Command     = 'pwsh -NoProfile -NoExit -File "D:\Git_Repositories\LCM_Inventory\tools\Invoke-LCMOnboardBatch.ps1"'
    }
)

[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="⚡ LCM Tool Launcher &amp; Active Help Console (v5.0.2)"
        Height="700" Width="1050"
        WindowStartupLocation="CenterScreen"
        Background="#0D1117" Foreground="#F0F6FC"
        FontFamily="Segoe UI, Inter">
    
    <Grid Margin="20">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="200"/>
        </Grid.RowDefinitions>

        <!-- Header -->
        <Border Grid.Row="0" BorderBrush="#30363D" BorderThickness="0,0,0,1" Padding="0,0,0,15" Margin="0,0,0,15">
            <DockPanel>
                <StackPanel DockPanel.Dock="Left">
                    <TextBlock Text="⚡ LCM Tool Launcher &amp; Active Help" FontSize="22" FontWeight="Bold" Foreground="#58A6FF"/>
                    <TextBlock Text="Click any tool to view active guidance, syntax, and execute directly in a live terminal" FontSize="13" Foreground="#8B949E" Margin="0,4,0,0"/>
                </StackPanel>
                <Border DockPanel.Dock="Right" Background="#161B22" BorderBrush="#30363D" BorderThickness="1" CornerRadius="6" Padding="10,6" VerticalAlignment="Center">
                    <TextBlock Text="LCM v5.0.2 Baseline" Foreground="#3FB950" FontWeight="SemiBold" FontSize="12"/>
                </Border>
            </DockPanel>
        </Border>

        <!-- Search Bar -->
        <Grid Grid.Row="1" Margin="0,0,0,12">
            <TextBox Name="SearchBox" Background="#161B22" Foreground="#F0F6FC" BorderBrush="#30363D" BorderThickness="1"
                     Padding="10,8" FontSize="14" Text="Type to filter tools by name, domain, or category..."/>
        </Grid>

        <!-- Tools DataGrid -->
        <Border Grid.Row="2" Background="#161B22" BorderBrush="#30363D" BorderThickness="1" CornerRadius="8" Margin="0,0,0,15">
            <DataGrid Name="ToolGrid" AutoGenerateColumns="False" IsReadOnly="True"
                      Background="Transparent" RowBackground="#161B22" AlternatingRowBackground="#1C2128"
                      Foreground="#F0F6FC" GridLinesVisibility="Horizontal" HorizontalGridLinesBrush="#30363D"
                      BorderThickness="0" HeadersVisibility="Column" SelectionMode="Single"
                      FontSize="13" RowHeight="32">
                <DataGrid.Resources>
                    <Style TargetType="DataGridColumnHeader">
                        <Setter Property="Background" Value="#21262D"/>
                        <Setter Property="Foreground" Value="#8B949E"/>
                        <Setter Property="FontWeight" Value="SemiBold"/>
                        <Setter Property="Padding" Value="10,8"/>
                        <Setter Property="BorderBrush" Value="#30363D"/>
                        <Setter Property="BorderThickness" Value="0,0,1,1"/>
                    </Style>
                    <Style TargetType="DataGridRow">
                        <Setter Property="Cursor" Value="Hand"/>
                        <Style.Triggers>
                            <Trigger Property="IsSelected" Value="True">
                                <Setter Property="Background" Value="#1F6FEB"/>
                                <Setter Property="Foreground" Value="#FFFFFF"/>
                            </Trigger>
                        </Style.Triggers>
                    </Style>
                </DataGrid.Resources>
                <DataGrid.Columns>
                    <DataGridTextColumn Header="Tool Script Name" Binding="{Binding Name}" Width="260"/>
                    <DataGridTextColumn Header="Category" Binding="{Binding Category}" Width="160"/>
                    <DataGridTextColumn Header="Repository Domain" Binding="{Binding Domain}" Width="160"/>
                    <DataGridTextColumn Header="Risk / Governance" Binding="{Binding Risk}" Width="180"/>
                    <DataGridTextColumn Header="Purpose &amp; Guidance" Binding="{Binding Description}" Width="*"/>
                </DataGrid.Columns>
            </DataGrid>
        </Border>

        <!-- Active Help & Action Panel -->
        <Border Grid.Row="3" Background="#161B22" BorderBrush="#30363D" BorderThickness="1" CornerRadius="8" Padding="16">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="220"/>
                </Grid.ColumnDefinitions>

                <StackPanel Grid.Column="0" VerticalAlignment="Center" Margin="0,0,15,0">
                    <TextBlock Name="DetailTitle" Text="Select a tool above to view active guidance" FontSize="16" FontWeight="Bold" Foreground="#58A6FF"/>
                    <TextBlock Name="DetailDesc" Text="Active help documentation, parameters, and safety invariants will appear here." TextWrapping="Wrap" FontSize="13" Foreground="#C9D1D9" Margin="0,6,0,8"/>
                    <Border Background="#0D1117" BorderBrush="#30363D" BorderThickness="1" CornerRadius="4" Padding="8,5">
                        <TextBlock Name="DetailCmd" Text="Command syntax" FontFamily="Consolas, JetBrains Mono" FontSize="12" Foreground="#79C0FF"/>
                    </Border>
                </StackPanel>

                <StackPanel Grid.Column="1" VerticalAlignment="Center" HorizontalAlignment="Right">
                    <Button Name="RunBtn" Content="▶ Run Tool in Terminal" Background="#238636" Foreground="#FFFFFF"
                            FontWeight="Bold" FontSize="14" Padding="14,12" Cursor="Hand" BorderThickness="0" Margin="0,0,0,8">
                        <Button.Resources>
                            <Style TargetType="Border">
                                <Setter Property="CornerRadius" Value="6"/>
                            </Style>
                        </Button.Resources>
                    </Button>
                    <Button Name="OpenFolderBtn" Content="📁 Open Script Location" Background="#21262D" Foreground="#C9D1D9"
                            FontWeight="SemiBold" FontSize="12" Padding="10,6" Cursor="Hand" BorderThickness="1" BorderBrush="#30363D">
                        <Button.Resources>
                            <Style TargetType="Border">
                                <Setter Property="CornerRadius" Value="6"/>
                            </Style>
                        </Button.Resources>
                    </Button>
                </StackPanel>
            </Grid>
        </Border>
    </Grid>
</Window>
"@

$reader = [System.Xml.XmlNodeReader]::new($xaml)
$window = [System.Windows.Markup.XamlReader]::Load($reader)

$grid = $window.FindName("ToolGrid")
$searchBox = $window.FindName("SearchBox")
$detailTitle = $window.FindName("DetailTitle")
$detailDesc = $window.FindName("DetailDesc")
$detailCmd = $window.FindName("DetailCmd")
$runBtn = $window.FindName("RunBtn")
$openFolderBtn = $window.FindName("OpenFolderBtn")

$observableTools = [System.Collections.ObjectModel.ObservableCollection[psobject]]::new()
foreach ($t in $toolCatalog) {
    $observableTools.Add([PSCustomObject]$t)
}
$grid.ItemsSource = $observableTools

# Selection Changed Event
$grid.Add_SelectionChanged({
    $selected = $grid.SelectedItem
    if ($selected) {
        $detailTitle.Text = "$($selected.Name) ($($selected.Category))"
        $detailDesc.Text = $selected.Description
        $detailCmd.Text = $selected.Command
        $runBtn.IsEnabled = $true
        $openFolderBtn.IsEnabled = $true
    }
})

# Search Filtering
$searchBox.Add_GotFocus({
    if ($searchBox.Text -eq 'Type to filter tools by name, domain, or category...') {
        $searchBox.Text = ''
    }
})
$searchBox.Add_TextChanged({
    $query = $searchBox.Text.Trim().ToLower()
    if (-not $query -or $query -eq 'type to filter tools by name, domain, or category...') {
        $grid.ItemsSource = $observableTools
    } else {
        $filtered = [System.Collections.ObjectModel.ObservableCollection[psobject]]::new()
        foreach ($t in $toolCatalog) {
            if ($t.Name.ToLower().Contains($query) -or $t.Category.ToLower().Contains($query) -or $t.Domain.ToLower().Contains($query) -or $t.Description.ToLower().Contains($query)) {
                $filtered.Add([PSCustomObject]$t)
            }
        }
        $grid.ItemsSource = $filtered
    }
})

# Run Button Action
$runBtn.Add_Click({
    $selected = $grid.SelectedItem
    if ($selected) {
        Write-Host "Launching tool in interactive terminal: $($selected.Name)..." -ForegroundColor Cyan
        Start-Process "wt.exe" -ArgumentList "pwsh.exe -NoExit -Command `"$($selected.Command)`"" -ErrorAction SilentlyContinue
        if ($LASTEXITCODE -ne 0 -or -not (Get-Process "WindowsTerminal" -ErrorAction SilentlyContinue)) {
            # Fallback to standard pwsh window
            Start-Process "pwsh.exe" -ArgumentList "-NoExit -Command `"$($selected.Command)`""
        }
    }
})

# Open Folder Button Action
$openFolderBtn.Add_Click({
    $selected = $grid.SelectedItem
    if ($selected -and (Test-Path -LiteralPath $selected.ScriptPath)) {
        $folder = Split-Path $selected.ScriptPath -Parent
        Start-Process "explorer.exe" -ArgumentList "/select,`"$($selected.ScriptPath)`""
    }
})

# Select First Tool by Default
if ($observableTools.Count -gt 0) {
    $grid.SelectedIndex = 0
}

$null = $window.ShowDialog()
