echo on
echo path: %2
echo file: %1
set _f=%~1
if /I x%2%==x (
	set _p=
) else (
	set _p=%~2%\
)
Everything64.exe -new-window -filter everything -s sha256:[get-property:"%_p%%_f%",sha256]