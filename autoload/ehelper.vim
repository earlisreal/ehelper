"TODO: put all temp source codes on one folder
"TODO: function to close all window but NERDTree
"TODO: function to move cursor/highlight wrong test case
"TODO: try async functions
"TODO: put extension based function to files

"New function:
"TODO:	delete modified source file after compiling
"		Store output (.exe, .class) file to the working folder, think how to save the temp file name	

"Important Initializations

" BUG: Previous program replacing current buffer when Compile has errors. The Temp Program remain on the dir and the original has the timer (The Compilations doesnt finish the function when there is an error).

if !exists("t:output_window_open")
	let t:output_window_open = 0
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

function! ehelper#Compile()
	if !FocusProgramWindow()
		echo "Cannot Find Program File"
		return 0
	endif
	w
	return CleanCompile()
endfunction

function! ehelper#CompileWithTimer()
	let source_file = GetSourceFileWithTimer()

endfunction

"Compile File
function! CompileFile(file_name) 
	let s:compiled_successfully = 0
	if expand('%:e') == "cpp"
		let compiler_message = system("g++ -std=c++11 -D_DEBUG " .a:file_name ." -o " .expand("%:r"))
	elseif expand('%:e') == "java"
		let compiler_message = system("javac " .a:file_name)
	endif
	"TODO: delete source_file after compiling
	if v:shell_error == 0
		let s:compiled_successfully =  1
	endif

	if s:compiled_successfully ==  1
		echo "Compiled Successfully!"
		cclose
	else
		"use quickfix
		cexpr compiler_message
		" call PrintOutput(compiler_message)
	endif

	return s:compiled_successfully
endfunction

function! WriteSourceFileWithTimer(file_name)
	let source_code = readfile(a:file_name)
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
		"For CPP
		if match(source_code[i], "return 0;") != -1
			call insert(source_code, GetTimeEnder(), i)
			break
		endif

		"For Java
		if match(source_code[i], "{") != -1
			let par_count += 1
		endif
		if match(source_code[i], "}") != -1
			if par_count > 0
				let par_count -= 1
			else
				call insert(source_code, GetTimeEnder(), i)
				break
			endif
		endif
		let i += 1
	endwhile
	"Compile source_code list
	call writefile(source_code, expand("%"))
endfunction

function! GetTimeStarter()
	if expand('%:e') == "java"
		return 'long startTime = System.nanoTime();'
	elseif expand('%:e') == "cpp"
		return 'int t_start = (int) clock();'
	endif
endf

function! GetTimeEnder()
	if expand('%:e') == "java"
		return 'System.out.printf("\n%d", (System.nanoTime() - startTime) / 1000000);'
	elseif expand('%:e') == "cpp"
		return 'printf("\n%d", clock() - t_start);'
	endif
endf

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

		let s:program_output_list = split(s:program_output, "\n")
		let s:execution_time = remove(s:program_output_list, -1)
		"Trim Output
		call filter(s:program_output_list, "v:val != ''")
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
	let s:answer_arr = []
endfunction

function! MakeTestCases()
	call InitializeTestCases()

	let lines = readfile('tests')
	let n = len(lines)

	let i = 0
	while i < n
		if match(lines[i], '\cinput') != -1
			call RunTestCase()
		elseif match(lines[i], '\coutput') != -1
			let s:is_input = 0
		else
			call add((s:is_input ? s:input_arr : s:answer_arr), lines[i])
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
	let output .= "Program Output:\n" .s:program_output ."\n"
	if !success
		let output = "Program Output:\n[Runtime Error]\n"
	endif

	let message .= "[Test Case " .s:test_case_no
	"Trim Answer
	call filter(s:answer_arr, "v:val != ''")
	if !empty(s:answer_arr)
		if g:ehelper_print_expected_output
			let answer .= "Answer:\n"
			let answer .= join(s:answer_arr, "\n") ."\n"
		endif

		let correct = CompareOutput()
		let message .= ", time: " .s:execution_time ." ms"
		let message .= ", verdict: " .(correct ? "Correct" : "Wrong") ."]"
		let s:verdict_message .= "Test Case " .s:test_case_no .": "
		let s:verdict_message .= (correct ? "Correct" : "Wrong") ."\n"
	endif

	let s:message .= message ."\n" .input ."\n" .output ."\n" .answer
	let s:message .= "------------------------------------------------------\n"

	let s:test_case_no += 1
	call ResetInputOutputArr()
endfunction

"Compare expected output and program output
function! CompareOutput()
	let program_output = s:program_output_list
	"May also be "!="
	if len(s:answer_arr) > len(program_output)
		return 0
	endif

	let i = 0
	while i < len(s:answer_arr)
		if Strip(s:answer_arr[i]) != Strip(program_output[i])
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
	if !FocusOutputWindow()
		"Make Scratch Buffer for output
		botright new output_scratch
		resize 8
		setlocal buftype=nofile bufhidden=hide noswapfile buftype=nowrite
	endif
endfunction

function! FocusOutputWindow()
	let nr = bufwinnr("output_scratch")
	if nr != -1
		execute nr . "wincmd w"
		return 1
	endif
	return 0
endfunction

function! CloseOutputWindow()
	if FocusOutputWindow()
		"Hide Output window if Already Open
		hide
	endif
endfunction

function! ehelper#ToggleOutputWindow()
	if FocusOutputWindow()
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

function! CleanCompile()
	let file_name = expand("%")
	let temp_file = "Temp_" .expand("%")

	call rename(file_name, temp_file)

	call WriteSourceFileWithTimer(temp_file)

	let result = CompileFile(file_name)

	call rename(temp_file, file_name)

	return result
endfunction

function! Strip(str)
    return substitute(a:str, '^\s*\(.\{-}\)\s*$', '\1', '')
endfunction
