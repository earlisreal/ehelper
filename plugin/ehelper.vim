"Important
if !exists("g:output_window_open")
	let g:output_window_open = 0
endif

"Optional Configs
if !exists("g:ehelper_print_input")
	let g:ehelper_print_input = 1
endif

if !exists("g:ehelper_print_expected_output")
	let g:ehelper_print_expected_output = 1
endif

if !exists("g:ehelper_print_your_output")
	let g:ehelper_print_your_output = 1
endif

function! GotoWindow(nr)
	execute a:nr . "wincmd w"
endfunction

function! FocusProgramWindow()
	let nr = bufwinnr("*.cpp")
	if nr != -1
		call GotoWindow(nr)
		return 1
	endif
	let nr = bufwinnr("*.java")
	if nr != -1
		call GotoWindow(nr)
		return 1
	endif

	return 0
endfunction

function! GetProgramFileName()
	if filereadable("*.cpp")
	endif
endfunction

"Compile File
function! Compile() 
	if !FocusProgramWindow()
		echo "Cannot Find Program File"
		return 0
	endif

	" TODO: Get program path instead of Focusing the window
	w
	let ok = 0
	if expand('%:e') == "cpp"
		let compiler_message = system("g++ -std=c++11 " .expand("%") ." -o " .expand("%:r"))
	elseif expand('%:e') == "java"
		let compiler_message = system("javac " .expand("%"))
	endif
	if v:shell_error == 0
		let compiler_message = "Compiled Successfully!"
		let ok = 1
	endif

	call PrintOutput(compiler_message)
	if ok
		call FocusProgramWindow()
	endif

	return ok
endfunction

"Compile and Run
function! CompileRun()
	if Compile()
		call ExecuteProgram()
	endif
endfunction

function! ExecuteProgram()
	"Get TestCases from file names "tests"
	call FocusProgramWindow()

	if filereadable('tests')
		call ExecuteTestCases()
	else
		call Run()
		call PrintOutput(s:program_output)
	endif
endfunction

"Execute Program
function! Run()
	if expand('%:e') == "cpp"
		if filereadable("in")
			let s:program_output = system(expand("%:r") .".exe " ."< in")
		else
			!%:r.exe
		endif
	elseif expand('%:e') == "java"
		if filereadable("in")
			let s:program_output = system("java " .expand("%:r") ." < in")
		else
			!java %:r
		endif
	endif

	return v:shell_error == 0
endfunction

function! InitializeTestCases()
	call ResetInputOutputArr()
	let s:test_case_no = 1
	let s:correct_test_case = 0

	let s:is_input = 1
	let s:verdict_message = ""
	let s:message = ""
endfunction

function! ResetInputOutputArr()
	let s:input_arr = []
	let s:output_arr = []
endfunction

function! ExecuteTestCases()
	call InitializeTestCases()

	let lines = readfile('tests')
	let n = len(lines)

	let i = 0
	while i < n
		if lines[i] == '<'
			call RunTestCase()
		elseif lines[i] == '='
			let s:is_input = 0
		else
			call add((s:is_input ? s:input_arr : s:output_arr), lines[i])
		endif
		let i = i + 1
	endwhile
	call RunTestCase()

	if s:verdict_message != ""
		let s:verdict_message .= "\n"
		let s:test_case_no -= 1
		if s:test_case_no == s:correct_test_case
			let s:verdict_message .= "[All Test Case Pass]"
		else
			let s:verdict_message .= "[" .s:correct_test_case ." out of " .s:test_case_no  ." Test Cases Pass" ."]"
		endif
	endif

	"Print to Output window (Scratch Buffer)
	call PrintOutput(s:message .s:verdict_message)
endfunction

function! RunTestCase()
	if empty(s:input_arr)
		return
	endif

	let s:message .= "[Test Case " .s:test_case_no ."]\n"

	if g:ehelper_print_input
		let s:message .= "Input:"
		let s:message .= join(s:input_arr, "\n")
		let s:message .= "\n"
	endif

	let s:is_input = 1
	call writefile(s:input_arr, "in")

	"TODO: check for run time error / TLE
	let s:message .= "Your Output:" ."\n"
	if Run()
		if g:ehelper_print_your_output
			let s:message .= s:program_output ."\n"
		endif
	else
		let s:message .= "Runtime Error\n"
	endif

	call filter(s:output_arr, "v:val != ''")
	if !empty(s:output_arr)

		if g:ehelper_print_expected_output
			let s:message .= "Answer:" ."\n"
			let s:message .= join(s:output_arr, "\n")
			let s:message .= "\n"
		endif

		call writefile(s:output_arr, "out")

		let s:verdict_message .= "Test Case " .s:test_case_no .": " .(Check() ? "Correct" : "Wrong") ."\n"
	endif

	let s:test_case_no += 1
	call ResetInputOutputArr()
endfunction

"Compare expected output and your output
function! Check()
	let program_output = split(s:program_output, '\n')
	call filter(program_output, "v:val != ''")
	if len(s:output_arr) > len(program_output)
		echo "invalid length"
		return 0
	endif

	let i = 0
	while i < len(s:output_arr)
		if s:output_arr[i] != program_output[i]
			return 0
		endif
		let i += 1
	endwhile
	let s:correct_test_case += 1
	return 1
endfunction

"Output Window Manipulation

function! OpenOutputWindow()
	if !bufexists("output_scratch")
		"Make Scratch Buffer for output
		botright new output_scratch
		resize 8
		setlocal buftype=nofile bufhidden=hide noswapfile buftype=nowrite
	else
		if !g:output_window_open
			botright sbuffer output_scratch
			resize 8
		endif
	endif
	call FocusOutputWindow()
	let g:output_window_open = 1
endfunction

function! FocusOutputWindow()
	let nr = bufwinnr("output_scratch")
	if nr != -1
		execute nr . "wincmd w"
	endif
endfunction

function! CloseOutputWindow()
	let nr = bufwinnr("output_scratch")
	if nr != -1
		"Hide Output window if Already Open
		execute nr . "wincmd w"
		hide
	endif
	let g:output_window_open = 0
endfunction

function! ToggleOutputWindow()
	if g:output_window_open
		call CloseOutputWindow()
	else
		call OpenOutputWindow()
	endif
endfunction

function! ClearOutputWindow()
	"Assume that current buffer is the output
	normal! ggVGd
endfunction

function! PrintOutput(message)
	call OpenOutputWindow()
	call ClearOutputWindow()
	put!=a:message
endfunction
