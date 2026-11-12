/*
================================================================================
FILE NAME      : types.go
PACKAGE        : main
DESCRIPTION    : Data transfer objects and request/response models for LCM DO.
AUTHOR         : Rolf
DATE CREATED   : 2026-11-11
LAST MODIFIED  : 2026-11-11
VERSION        : 10.2.0
GO VERSION     : 1.22+
ENCODING       : ASCII (No BOM)
================================================================================
CHANGE LOG:
2026-11-11 - 10.0.0: Initial implementation.
================================================================================
*/

package main

// ExecuteRequest defines the input payload for the /execute endpoint.
type ExecuteRequest struct {
	Command     string `json:"command"`
	Elevated    bool   `json:"elevated"`
	Sync        bool   `json:"sync"`
	NoExit      bool   `json:"noExit"`
	WindowStyle string `json:"windowStyle"`
	TimeoutMs   int    `json:"timeoutMs"`
}

// ExecuteResponse defines the output payload from the /execute endpoint.
type ExecuteResponse struct {
	Status      string `json:"status"`
	ExitCode    int    `json:"exitCode"`
	Stdout      string `json:"stdout"`
	Stderr      string `json:"stderr"`
	DurationMs  int64  `json:"durationMs"`
	Command     string `json:"command"`
	Elevated    bool   `json:"elevated"`
	NoExit      bool   `json:"noExit"`
	WindowStyle string `json:"windowStyle"`
	DirectExe   string `json:"directExe,omitempty"`
}

// StatusResponse defines daemon telemetry and runtime metrics.
type StatusResponse struct {
	Status           string  `json:"status"`
	Pid              int     `json:"pid"`
	UptimeSec        int64   `json:"uptimeSec"`
	StandardDisplays int     `json:"standardDisplays"`
	User             string  `json:"user"`
	WorkingSetMB     float64 `json:"workingSetMB"`
	Version          string  `json:"version"`
	SessionID        int     `json:"sessionId"`
	LogFile          string  `json:"logFile"`
	Port             int     `json:"port"`
}

// OpenRequest defines the input payload for the /open endpoint.
type OpenRequest struct {
	Target     string `json:"target"`
	URL        string `json:"url"`
	FilePath   string `json:"filePath"`
	Args       string `json:"args"`
	Foreground bool   `json:"foreground"`
	Title      string `json:"title"`
	Pane       bool   `json:"pane"`
}

// ForegroundRequest defines the input payload for the /foreground endpoint.
type ForegroundRequest struct {
	Title string `json:"title"`
}

// ActionLog represents a persistent execution receipt.
type ActionLog struct {
	Timestamp  string `json:"timestamp"`
	Command    string `json:"command"`
	ExitCode   int    `json:"exitCode"`
	DurationMs int64  `json:"durationMs"`
	Status     string `json:"status"`
	Elevated   bool   `json:"elevated"`
	Stdout     string `json:"stdout,omitempty"`
	Stderr     string `json:"stderr,omitempty"`
}

