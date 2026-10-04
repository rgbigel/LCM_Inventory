@echo off
if not defined Git_Root set "Git_Root=%~dp0..\.."
if not exist "%Git_Root%\LCM_Inventory" set "Git_Root=D:\Git_Repositories"
pwsh.exe -NoExit -NoProfile -ExecutionPolicy Bypass -File "%Git_Root%/SystemConfiguration/Source/@09-Use_Stylefolder_for_Folder_Comments.txt" %*
