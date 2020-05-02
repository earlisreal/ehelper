"Important Initializations

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

if !exists("g:allow_time_limit")
	let g:allow_time_limit = 0
endif

if !exists("g:executable_path")
	let g:executable_path = ""
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

function! ehelper#Compile(withTc)
	if !FocusProgramWindow()
		echo "Cannot Find Program File"
		return 0
	endif
	w
	call CleanCompile(a:withTc)


	if v:shell_error == 0
		echo "Compiled Successfully!"
		call ClearOutputWindow()
		call CloseOutputWindow()
	else
		call PrintOutput(b:compiler_message)
	endif
endfunction

function! ehelper#CompileWithTimer()
	let source_file = GetSourceFileWithTimer()

endfunction

"Compile File
function! CompileFile(file_name) 
	if expand('%:e') == "cpp"
		if g:executable_path == ""
			let b:compiler_message = system("g++ -std=c++11 -D_DEBUG " .a:file_name ." -o " .expand("%:r"))
		else
			let b:compiler_message = system("g++ -std=c++11 -D_DEBUG " .a:file_name ." -o " .g:executable_path .expand("%:r"))
		endif
	elseif expand('%:e') == "java"
		if g:executable_path == ""
			let b:compiler_message = system("javac " .a:file_name)
		else
			let b:compiler_message = system("javac " .a:file_name ." -d " .g:executable_path)
		endif
	endif
endfunction

function! WriteSourceFileWithTimer(file_name, withTc)
	let source_code = readfile(expand("%"))
	" Include ctime to use the cloc() in c++
	if expand("%:e") == "cpp"
		call insert(source_code, "#include <ctime>", 0)
	endif
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

	let end_lines = []

	let par_count = 0
	while i < len(source_code)
		"For CPP
		if expand("%:e") == "cpp"
			if match(source_code[i], "return 0;") != -1
				call add(end_lines, i)
			endif
		endif

		"For Java
		if expand("%:e") == "java"
			if match(source_code[i], "{") != -1
				let par_count += 1
			endif
			if match(source_code[i], "}") != -1
				if par_count > 0
					let par_count -= 1
				else
					call add(end_lines, i)
					break
				endif
			endif
		endif

		let i += 1
	endwhile

	" Add time Ender for all Exit calls
	let i = len(end_lines) - 1
	while i >= 0
		call insert(source_code, GetTimeEnder(a:withTc), end_lines[i])
		let i -= 1
	endwhile

	"Compile source_code list
	call writefile(source_code, a:file_name)
endfunction

function! GetTimeStarter()
	if expand('%:e') == "java"
		return 'long startTime = System.nanoTime();'
	elseif expand('%:e') == "cpp"
		return 'chrono::milliseconds t_start = chrono::duration_cast<chrono::milliseconds>(chrono::system_clock::now().time_since_epoch());'
	endif
endf

function! GetTimeEnder(withTc)
	if expand('%:e') == "java"
		return 'System.out.printf("\n%d' .(a:withTc ? '' : 'ms\n') .'", (System.nanoTime() - startTime) / 1000000);'
	elseif expand('%:e') == "cpp"
		return 'cout << "\n" << ' .'chrono::duration_cast<chrono::milliseconds>(chrono::system_clock::now().time_since_epoch()).count() - t_start.count()' .(a:withTc ? '' : ' << "ms\n"') .' << endl;'
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

		if v:shell_error == 0
			let s:program_output_list = split(s:program_output, "\n")
			let s:execution_time = remove(s:program_output_list, -1)
			"Trim Output
			call filter(s:program_output_list, "v:val != ''")
			let s:program_output = join(s:program_output_list, "\n")

		endif

	endif
	return v:shell_error == 0
endfunction

function! GetRunCommand()
	let extension = expand('%:e')
	if extension == "cpp"
		if g:executable_path != ""
			return "\"" .g:executable_path .expand('%:r') ."\""
		else
			return "\"" .expand('%:p:h') ."/" .expand('%:r') ."\""
		endif
	elseif extension == "java"
		if g:executable_path != ""
			return "java " ."-cp \"" .g:executable_path ."\" " .expand('%:r')
		else
			return "java " .expand('%:r')
		endif
	endif
endfunction

"Compile and Run Test Cases
function! ehelper#CompileRunTestCases()
	call ehelper#Compile(1)
	if v:shell_error == 0
		call ehelper#ExecuteProgram()
	endif
endfunction

"Compile and Run
function! ehelper#CompileRun()
	call ehelper#Compile(0)
	if v:shell_error == 0
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

	let success = ehelper#Run(join(s:input_arr, "\n"))
	if success
		call filter(s:answer_arr, "v:val != ''")
		let result = CompareOutput() ? "Correct" : "Wrong"
		let out = s:program_output
	else
		let out = "[Runtime Error]"
		let result = "Runtime Error"
		let s:execution_time = -1
	endif
	let output .= "Program Output:\n" .out ."\n"

	" Check for run TLE if time > 5ms
	if g:allow_time_limit && s:execution_time > 5000
		let output = "Program Output:\n[Time Limit Exceeded]\n"
	endif

	let message .= "[Test Case " .s:test_case_no
	"Trim Answer
	let message .= ", time: " .s:execution_time ." ms"
	if !empty(s:answer_arr)
		if g:ehelper_print_expected_output
			let answer .= "Answer:\n"
			let answer .= join(s:answer_arr, "\n") ."\n"
		endif

		let message .= ", verdict: " .result
		let s:verdict_message .= "Test Case " .s:test_case_no .": "
		let s:verdict_message .= result ."\n"
	endif
	let message .= "]"

	let s:message .= message ."\n" .input ."\n" .output ."\n" .answer
	let s:message .= "------------------------------------------------------\n"

	let s:test_case_no += 1
	call ResetInputOutputArr()
endfunction

"Compare expected output and program output
function! CompareOutput()
	let program_output = s:program_output_list
	let alen = len(s:answer_arr)
	let blen = len(program_output)

	let pass = 1
	if alen > blen
		echo "Length not matched"
		let pass = 0
	endif

	let size = alen < blen ? alen : blen
	let i = 0
	while i < size
		if Strip(s:answer_arr[i]) != "earl-skip-earl"
			if Strip(s:answer_arr[i]) != Strip(program_output[i])
				echo "Line not matched"
				let s:program_output_list[i] .= " <- Incorrect"
				let pass = 0
			endif
		endif
		let i += 1
	endwhile
	let s:program_output = join(s:program_output_list, "\n")
	let s:correct_test_case += 1

	return pass
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
	if FocusOutputWindow()
		normal! ggVGd
	endif
endfunction

function! PrintOutput(message)
	call OpenOutputWindow()
	call ClearOutputWindow()
	put!=a:message
endfunction

function! CleanCompile(withTc)
	let file_name = expand("%")
	let temp_file = "Temp_" .expand("%")

	" Write new Source Code with timer to the temp file
	call WriteSourceFileWithTimer(temp_file, a:withTc)

	" Compile the file with timer
	call CompileFile(temp_file)

	" Remove the temp
	call delete(temp_file)
endfunction

function! Strip(str)
    return substitute(a:str, '^\s*\(.\{-}\)\s*$', '\1', '')
endfunction
