"Important Initializations
let s:compiled_successfully = 0
let s:output_window_open = 0

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
function! ehelper#Compile() 
	if !FocusProgramWindow()
		echo "Cannot Find Program File"
		return 0
	endif

	if !&modified && exists(s:compiled_successfully)
		echo "No Changes"
		return s:compiled_successfully
	endif

	w
	let s:compiled_successfully = 0
	if expand('%:e') == "cpp"
		let compiler_message = system("g++ -std=c++11 " .expand("%") ." -o " .expand("%:r"))
	elseif expand('%:e') == "java"
		let compiler_message = system("javac " .expand("%"))
	endif
	if v:shell_error == 0
		let compiler_message = "Compiled Successfully!"
		let s:compiled_successfully =  1
	endif

	call PrintOutput(compiler_message)
	if s:compiled_successfully ==  1
		call FocusProgramWindow()
	endif

	return s:compiled_successfully
endfunction

"Run Program
function! ehelper#Run(...)
	if !FocusProgramWindow()
		echo "Cannot Find Program File"
		return
	endif
	let run_command = GetRunCommand()
	if a:0 == 0
		execute "!" .run_command
	else
		let s:program_output = system(run_command, a:1)
	endif
	return v:shell_error == 0
endfunction

function! GetRunCommand()
	let extension = expand('%:e')
	if extension == "cpp"
		return expand('%:r') .".exe"
	elseif extension == "java"
		return "java " .expand('%:r')
	endif
endfunction

"Compile and Run Test Cases
function! ehelper#CompileRunTestCases()
	if ehelper#Compile()
		call ehelper#ExecuteProgram()
	endif
endfunction

"Compile and Run
function! ehelper#CompileRun()
	if ehelper#Compile()
		call ehelper#Run()
	endif
endfunction

function! ehelper#ExecuteProgram()
	"Get TestCases from file names "tests"
	if filereadable('tests')
		call MakeTestCases()
	else
		call ehelper#Run()
		call PrintOutput(s:program_output)
	endif
endfunction

" Run Test Cases
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

function! MakeTestCases()
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

	let input_str = join(s:input_arr, "\n")

	if g:ehelper_print_input
		let s:message .= "Input:\n"
		let s:message .= input_str
		let s:message .= "\n"
	endif

	let s:is_input = 1

	"TODO: check for run TLE
	let success = ehelper#Run(input_str)
	let s:message .= "Program Output:\n"
	let s:message .= s:program_output
	if !success
		let s:message .= "\n[Runtime Error]"
	endif

	"Trim Expected output
	call filter(s:output_arr, "v:val != ''")
	if !empty(s:output_arr)
		if g:ehelper_print_expected_output
			let s:message .= "Answer:\n"
			let s:message .= join(s:output_arr, "\n") ."\n\n"
		endif

		let s:verdict_message .= "Test Case " .s:test_case_no .": " .(CompareOutput() ? "Correct" : "Wrong") ."\n"
	endif

	let s:test_case_no += 1
	call ResetInputOutputArr()
endfunction

"Compare expected output and program output
function! CompareOutput()
	let program_output = split(s:program_output, '\n')
	call filter(program_output, "v:val != ''")
	if len(s:output_arr) > len(program_output)
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

function! ehelper#ToggleOutputWindow()
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
