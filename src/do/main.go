/*
================================================================================
FILE NAME      : main.go
PACKAGE        : main
DESCRIPTION    : Unified entrypoint routing between LCM DO CLI client and desktop daemon.
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

import (
	"fmt"
	"os"
	"strconv"
	"strings"
)

func main() {
	args := os.Args[1:]

	if len(args) > 0 && strings.ToLower(args[0]) == "daemon" {
		port := GetDaemonPort()
		for i := 1; i < len(args); i++ {
			if (args[i] == "-port" || args[i] == "--port" || args[i] == "-p") && i+1 < len(args) {
				if p, err := strconv.Atoi(args[i+1]); err == nil && p > 0 {
					port = p
					i++
				}
			}
		}

		err := RunDaemon(port)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Daemon encountered fatal error: %v\n", err)
			os.Exit(1)
		}
		os.Exit(0)
	}

	exitCode, err := RunClient(args)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
	}
	os.Exit(exitCode)
}
