command! EhelperToggleOutput silent call ehelper#ToggleOutputWindow()
command! EhelperCompile call ehelper#Compile(0)
command! EhelperCompileRun call ehelper#CompileRun()
command! EhelperCompileRunTestCases silent call ehelper#CompileRunTestCases()
command! EhelperRun call ehelper#Run()
command! EhelperRunTestCases silent call ehelper#ExecuteProgram()
command! EhelperToggleTests silent call ehelper#ToggleTestsWindow()

