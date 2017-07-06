"TODO: function to close all window but NERDTree
"TODO: Mark check or X wether the test case is correct or wrong
"TODO: Set output window max height
"TODO: function to move cursor/highlight wrong test case

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

if !exists("g:ehleper_max_print_lines")
	let g:ehelper_max_print_lines = 10
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
	"TODO: find program file on current directory
	if !FocusProgramWindow()
		echo "Cannot Find Program File"
		return 0
	endif

	if !&modified && exists(s:compiled_successfully)
		echo "No Changes"
		return s:compiled_successfully
	endif

	w

	let source_code = readfile(expand("%"))
	let i = 0
	while i < len(source_code)
		if source_code[i] =~ "main("
			"Append timer
			while i < len(source_code) && match(source_code[i], "{") == -1
				let i += 1
			endwhile
			let i += 1
			call insert(source_code, GetTimeStarter(), i)
			break
		endif
		let i += 1
	endwhile
	let par_count = 0
	while i < len(source_code)
		if match(source_code[i], "return 0;") != -1
			call insert(source_code, GetTimeEnder(), i)
			break
		endif
		let i += 1
	endwhile

	"Compile source_code list
	let source_file = tempname() .expand('%:e')
	call writefile(source_code, source_file)
	let s:compiled_successfully = 0
	if expand('%:e') == "cpp"
		let compiler_message = system("g++ -std=c++11 -D_DEBUG " .source_file ." -o " .expand("%:r"))
	elseif expand('%:e') == "java"
		let compiler_message = system("javac " .source_file)
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

function! GetTimeStarter()
	if expand('%:e') == "java"
		return 'long start = System.currentTimeMillis();'
	elseif expand('%:e') == "cpp"
		return 'int t_start = (int) clock();'
	endif
endf

function! GetTimeEnder()
	if expand('%:e') == "java"
		return 'System.out.printf("\ntime: %d ms", endTime - startTime);'
	elseif expand('%:e') == "cpp"
		return 'fprintf(stderr, "time: %d ms", clock() - t_start);'
	endif
endf

"Run Program
function! ehelper#Run(...)
	let s:std_err = tempname()
	let s:std_out = tempname()
	if !FocusProgramWindow()
		echo "Cannot Find Program File"
		return
	endif
	let run_command = GetRunCommand()
	if a:0 == 0
		execute "!" .run_command
	else
		let s:program_output = system(run_command, a:1)
		let s:program_output_list = split(s:program_output, "\n")
		" if match(s:program_output_list[-1], "time:") != -1
		let s:execution_time = remove(s:program_output_list, -1)
		" endif
		let s:program_output = join(s:program_output_list, "\n")
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
		" call PrintOutput(s:program_output)
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
		if lines[i] == '<' || lines[i] == 'input'
			call RunTestCase()
		elseif lines[i] == '=' || lines[i] == 'output'
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
			let s:verdict_message .= "[" .s:correct_test_case ." out of "
			let s:verdict_message .= s:test_case_no  ." Test Cases Pass" ."]"
		endif
	endif

	"Print to Output window (Scratch Buffer)
	call PrintOutput(s:message .s:verdict_message)
endfunction

function! RunTestCase()
	if empty(s:input_arr)
		return
	endif

	let message = ""
	let input = ""
	let output = ""
	let answer = ""

	if g:ehelper_print_input
		let input .= "Input:\n"
		let input .= LimitList(s:input_arr, g:ehelper_max_print_lines) ."\n"
	endif

	let s:is_input = 1

	"TODO: check for run TLE
	let success = ehelper#Run(join(s:input_arr, "\n"))
	let output .= "Program Output:\n" .s:program_output
	if !success
		let output .= "\n[Runtime Error]"
	endif

	let message .= "[Test Case " .s:test_case_no
	"Trim Expected output
	call filter(s:output_arr, "v:val != ''")
	if !empty(s:output_arr)
		if g:ehelper_print_expected_output
			let answer .= "Answer:\n"
			let answer .= join(s:output_arr, "\n") ."\n\n"
		endif

		let correct = CompareOutput()
		let message .= ", " .s:execution_time
		let message .= ", verdict: " .(correct ? "Correct" : "Wrong") ."]"
		let s:verdict_message .= "Test Case " .s:test_case_no .": "
		let s:verdict_message .= (correct ? "Correct" : "Wrong") ."\n"
	endif

	let s:message .= message ."\n" .input ."\n" .output ."\n" .answer

	let s:test_case_no += 1
	call ResetInputOutputArr()
endfunction

"Compare expected output and program output
function! CompareOutput()
	let program_output = s:program_output_list
	call filter(program_output, "v:val != ''")
	"May also be "!="
	if len(s:output_arr) > len(program_output) - 1
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

function! LimitList(original_list, limit)
	let new_list = []
	let i = 0
	let l = len(a:original_list)
	while i < min([l, a:limit])
		call add(new_list, a:original_list[i])
		let i += 1
	endwhile
	let new_list_str = join(new_list, "\n")
	let new_list_str .= l > a:limit ? "\n.\n.\n.\n" : ""
	return new_list_str
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

function! ToInput()
	execute "normal! S<\<Esc>"
endfunction

function! ToOutput()
	execute "normal! S=\<Esc>"
endfunction
