$env:PATH = "C:\Qt\Tools\mingw1310_64\bin;" + $env:PATH
& "C:\Qt\Tools\CMake_64\bin\cmake.exe" --build "$PSScriptRoot\build"
