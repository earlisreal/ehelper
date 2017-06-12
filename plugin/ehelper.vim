let g:output_window_open = 0

"Compile File
function! Compile() 
	w
	"TODO: find program file

	let ok = 0
	if(expand('%:e') == "cpp")
		let compile_output = system("g++ -std=c++11 " .expand("%") ." -o " .expand("%:r"))
	elseif(expand('%:e') == "java")
		let compiler_message = system("javac " .expand("%"))
	endif
	if(compile_output == "")
		let compiler_message = "Compiled Successfully!"
		let ok = 1
	endif

	call PrintOutput(compiler_message)

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
	if(filereadable('tests'))
		call ExecuteTestCases()
	else
		call Run()
	endif
endfunction

"Execute Program
function! Run()
	if(expand('%:e') == "cpp")
		if(filereadable("in"))
			let s:program_output = system(expand("%:r") .".exe " ."< in")
		else
			!%:r.exe
		endif
	elseif(expand('%:e') == "java")
		if(filereadable("in"))
			let s:program_output = system("java " .expand("%:r") ." < in")
		else
			" !gnome-terminal -e "bash -c \"java %:r | tee tmp; read -p \"Press_Enter\"\""
			!java %:r
		endif
	endif
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
	let s:out_arr = []
endfunction

function! ExecuteTestCases()
	"TODO: Make an option variable let g:TestCases_display_input = 1
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
			call add(s:is_input ? s:input_arr : s:output_arr, lines[i])
		endif
		let i = i + 1
	endwhile
	call RunTestCase()

	if(s:verdict != "")
		let s:verdict .= "\n"
		let s:test_case_no -= 1
		if(s:test_case_no == s:correct_test_case)
			let g:verdict .= "\n"
			let g:verdict .= "[All Test Case Pass]"
			" echo "[All Test Case Pass]"
		else
			let g:verdict .= "[" .b:correct ."out of " .b:testCase  ." Test Cases Pass" ."]"
			" echo "[" .b:correct ."out of " .b:testCase  ." Test Cases Pass" ."]"
		endif
	endif

	"Print to Output window (Scratch Buffer)
	call PrintOutput(s:verdict ."\n" .s:message)
	" put!=s:verdict
	" put!=s:message
endfunction

function! RunTestCase()
	if(empty(s:input_arr))
		return
	endif

	let s:message .= "Test Case " .b:test_case_no
	let s:test_case_no += 1

	" if g:ehelper_print_input
	" echo "Input:"
	" echo join(b:in, "\n")
	" echo "\n"
	" endif

	let s:is_input = 1
	call writefile(s:input_arr, "in")
	call Run()

	if(!empty(s:output_arr))

		" if g:ehelper_print_your_output
		" 	echo "Expected Output:"
		" 	echo join(b:out, "\n")
		" 	echo "\n"
		" endif

		"TODO: trim empty lines at the end
		call writefile(s:output_arr, "out")

		let s:verdict_message .= "Test Case " .s:test_case_no .": " .(Check() ? "Correct" : "Wrong") ."\n"
	endif

	" if g:ehelper_print_your_output
	" 	echo "Your Output:"
	" 	echo g:output
	" 	echo "\n"
	" endif

	"TODO: check for run time error / TLE

	call ResetInputOutputArr()
endfunction

"Compare expected output and your output
function! Check()
	let program_output = split(s:program_output, '\n')

	if(len(output_arr) > len(program_output))
		return 0
	endif

	let i = 0
	while i < len(eOutput)
		if(eOutput[i] != output[i])
			return 0
		endif
		let i += 1
	endwhile
	let s:correct_test_case += 1
	return 1
endfunction

"Output Window Manipulation

function! OpenOutputWindow()
	if(!bufexists("output_scratch"))
		"Make Scratch Buffer for output
		botright new output_scratch
		resize 8
		setlocal buftype=nofile bufhidden=hide noswapfile buftype=nowrite
	else
		if !g:output_window_open
			botright sbuffer output_scratch
			resize 8
		else
			call FocusOutputWindow()
		endif
	endif
	let g:output_window_open = 1
endfunction

function! FocusOutputWindow()
	let nr = bufwinnr("output_scratch")
	if(nr != -1)
		execute nr . "wincmd w"
	endif
endfunction

function! CloseOutputWindow()
	let nr = bufwinnr("output_scratch")
	if(nr != -1)
		"Hide Output window if Already Open
		execute nr . "wincmd w"
		hide
	endif
	let g:output_window_open = 0
endfunction

function! ToggleOutputWindow()
	if !g:output_window_open
		call CloseOutputWindow()
	else
		call OpenOutputWindow()
	endif
endfunction

function! ClearOutputWindow()
	"TODO: Check if current window is scratch buffer
	"Assume that current buffer is the output
	normal! ggVGd
endfunction

function! PrintOutput(message)
	call OpenOutputWindow()
	call ClearOutputWindow()
	put!=a:message
endfunction
