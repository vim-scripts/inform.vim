"  vim: set sw=4 sts=4 fdm=marker:
"  Vim Auto-indent file v0.5
"  Maintainer:	    Martin Bays (vim@zugzwang.port5.com)
"  URL:		    http://mbays.freeshell.org/informindent.tgz
"  Last Changes:    Wed Dec 17 18:55:04 GMT 2003 
"  Language:	    Inform

" NOTES: 
"    This is still far from perfect: it should work reasonably well for most code,
"	as long as you don't do anything too weird - but if you find bugs not
"	mentioned in the TODO list then please email me. Please include the
"	date stamp above in your bug report.
"
"    There may be a later version at
"	http://mbays.freeshell.org/informindent.tgz    
"    
"    Some functionality depends on your using Stephon Thomas's inform.vim syntax
"	highlighting file, which comes with the standard vim distribution.
"
"    If you find this works too slowly, and you are using the syntax file, try
"	    :let b:indent_use_syntax = 0
"	which should significantly increase speed, at some cost to accuracy.
"
"    This is for the most part a 'light-weight' indenting script, generally
"	looking at only the last line or two to determine how to indent the 
"	next - though the need to dedent one-liners and switch clauses slightly 
"	interferes with this philosophy. However, this does mean that if you
"	don't like how it indents, you can generally correct it (<CTRL-T> and
"	<CTRL-D> in insert mode) and it'll continue with your corrections.
"
"    There are occasional problems with indenting large numbers of lines with
"	'=', something to do with the interaction between indenting and syntax.
"	For now, this workaround should help:
"
"	    If you want to indent a whole file, or a large number of lines,
"	    first type 
"		qa=13j<CTRL-D>q
"	    (where that's an actual control-and-D)
"	    and then type something like 
"		100@a
"
"    Define "inf_indent_obj_defs", say in your .vimrc, to enable an
"	*experimental* option - indenting property and attribute definitions.

" TODO: {{{
"    Bugs:
"	The line of a one-liner with a multi-line condition doesn't get
"	    indented - e.g:
"		if (cond1
"		    || cond2)
"		Bugger();
"
"	Even worse: if the first line ends in a bracket, it tries to dedent
"	    a third line - e.g.:    
"		if (Test()
"			|| cond1
"		    && cond2)    
"	    VeryBugger();
"		    
"	Occasional weirdo failures when indenting large chunks of code 
"	    I think it might be related to the fact that vim sometimes gets
"	    confused as what's in and out of quotes, particularly when '"' and
"	    ''' interact. See above for a workaround. 
"
"    Multiline statements (terminated by ';')
"
"    Pay attention to the value of &cinoptions
"
"    Clean up -
"	rationalise variable names
"	add more comments
"	improve speed, somehow
"	etc. etc.    
"}}}



" Initialisation: {{{
" Only load this indent file when no other was loaded.
if exists("b:did_indent")
    finish
endif

let b:did_indent = 1

"Some features will only work if syntax highlighting is active
" (using Stephon Thomas's syntax file)
" and some other features will work better with it 
let b:indent_use_syntax = has("syntax") && &syntax == "inform" 

setlocal indentexpr=GetInformIndent()
setlocal indentkeys+=<[>,<{>,<:>,e,=],=},=),=#

if exists("inf_indent_obj_defs")
    let b:inf_indent_obj_defs = 1
    setlocal indentkeys+==;,=with,=has,=class,=private
endif

" Only define the function once.
if exists("*GetInformIndent")
    finish
endif

let cpo_save = &cpo
set cpoptions-=C
"}}}

" Helper functions {{{

function InformIndentSynName(line, column) "{{{
    return synIDattr(synID(a:line,a:column,0),"name") 
endfunction
"}}}

" Function: InformIndentPrevnonblank {{{
" Get the number of the previous line which isn't blank and isn't a comment
"  (that's a strict 'previous', unlike with prevnonblank()) 
function InformIndentPrevnonblank(lnum)
    let lnum = prevnonblank(a:lnum - 1)
    while lnum && getline(lnum) =~ '^\s*!'
	let lnum = prevnonblank(lnum - 1)
    endwhile
    return lnum
endfunction 
"}}}

" Function: InformIndentMatch {{{ 
" Like match(), but ignores comments and strings
"   and the first argument is a line number not a string 
"	returns -1 on failure, like match() does, so 
"		"if InformIndentMatch(bl,a,h) + 1"
"	is just a test for a match. 
function InformIndentMatch(lnum, pattern, from)
    let line = getline(a:lnum)
    let col = match(line, a:pattern, a:from)
    while col + 1
	if b:indent_use_syntax
	    let name = InformIndentSynName(a:lnum, col + 1)
	    if name != "informString"
			\ && name != "informDictString"
			\ && name != "informComment"
		return col
	    endif
	else
	    if line !~ '^\s*!'
			\ && line !~ '"[^"]*' . a:pattern . '[^"]*"'
		return col
	    endif
	endif
	let col = match(line, a:pattern, col + 1)
    endwhile
    return -1
endfunction
"}}}

" Function: InformIndentSwitchStarts {{{
function InformIndentSwitchStart(lnum)
    let col = InformIndentMatch(a:lnum,':',0)
    if col + 1
	let forcol = InformIndentMatch(a:lnum,'\<for\s*(',0) 
	let closeblockcol = InformIndentMatch(a:lnum,'[\]}]',col)
	let openblockcol = InformIndentMatch(a:lnum,'[[{]',col)
	return (forcol == -1
		    \ || forcol > col)
		    \ && (closeblockcol == -1
		    \ || (openblockcol + 1
		    \ && openblockcol < closeblockcol))
    endif
    return 0
endfunction
"}}}

" Function: InformIndentSwitchEndsWithBlock {{{ 
" Are we extra-indented because of a switch-style structure?
function InformIndentSwitchEndsWithBlock(ind)
    let lnum = v:lnum
    let ind = a:ind - &sw
    while lnum > 0 
	let lnum = InformIndentPrevnonblank(lnum)
	let pind = indent(lnum)
	if pind == ind
	    if InformIndentSwitchStart(lnum)
		return 1
	    endif
	    break
	else
	    if pind == ind - &sw
			\ && getline(lnum) =~ '[[{].*:'
			\ && InformIndentSwitchStart(lnum)
		return 1
	    endif
	    if pind < ind
		break
	    endif
	endif
    endwhile
    return 0
endfunction
"}}}

"}}}

" Main Function: GetInformIndent {{{
function GetInformIndent()

    " Init: {{{
    let line = getline(v:lnum)

    " Find a non-blank line above the current line.
    let lnum = InformIndentPrevnonblank(v:lnum)


    " Hit the start of the file, use zero indent.
    if lnum == 0
	return 0
    endif

    let ind = indent(lnum)
    let pline = getline(lnum)

    let skippedinstruction = 0
    let ignorebrackets = 0
    "}}}

    " Indentations using syntax: {{{
    if b:indent_use_syntax
	" In a quotation
	if InformIndentSynName(lnum,strlen(pline)) == "informString"
		    \ && strpart(pline, strlen(pline) - 1, 1) != '"'

	    " (previous line was) first new line of a quotation?
	    if InformIndentSynName(lnum,1) != "informString" 
			\ || strpart(pline,match(pline,'\S'),1) == '"'
		return ind + &sw
	    endif
	    return ind
	endif

	" Coming out of a multi-line quotation
	if InformIndentSynName(lnum,1) == "informString" 
		    \ && (InformIndentSynName(lnum,strlen(pline)) != "informString"
		    \ || strpart(pline, strlen(pline) - 1, 1) == '"')
	    let plnum = InformIndentPrevnonblank(lnum)
	    let ppline = getline(plnum)
	    if InformIndentSynName(plnum,strlen(ppline)) == "informString"
			\ && strpart(ppline, strlen(ppline) - 1, 1) != '"'
		" Find the start of the quote, and use that line to indent from
		" pline ends up as the join of the lines containing the
		"   quotation
		let pline = getline(plnum) . getline(lnum)
		let lnum = plnum
		while lnum && InformIndentSynName(lnum,1) == "informString"
		    let lnum = InformIndentPrevnonblank(lnum)
		    let pline = getline(lnum) . pline
		endwhile
		let ind = indent(lnum)
		"to mark that a one-liner has probably had its line:
		let skippedinstruction = 1 
		"because the quote might have been wrapped in brackets:
		let ignorebrackets = 1
	    endif
	endif

	" Grammar definition
	if InformIndentSynName(lnum,1) == "informGramPreProc"
	    let ind = ind + &sw
	endif
	if pline =~ ';\s*\($\|!\)'
		    \ && InformIndentSynName(lnum,1) =~ 'Gram'
	    let ind = ind - &sw
	endif

    endif
    "}}}

    " Immediate indents {{{

    if line =~ '^\s*#' "Preprocessor statement
	return 0
    endif

    if line =~ '^\s*!' " Comment: don't change indent - want to be able to
	" position them wherever.
	return -1
    endif
    "}}}

    "Indenting of {}, [], ()  {{{
    "	- adapted from perl.vim 

    let openedblocks = 0
    let openedparenths = 0

    " Find a real opening brace
    let bracepos = InformIndentMatch(lnum, '[(){}\[\]]', matchend(pline, '^\s*[)}\]]'))
    while bracepos != -1
	let brace = strpart(pline, bracepos, 1)
	if ! (ignorebrackets && (brace == '(' || brace == ')'))
	    if brace == '(' || brace == '{' || brace == '['
		if brace != '('
		    let ind = ind + &sw
		    let openedblocks = openedblocks + 1
		else 
		    let ind = ind + 2 * &sw
		    let openedparenths = openedparenths + 1
		endif
	    else
		if brace != ')'
		    let ind = ind - &sw
		    if openedblocks > 0
			let openedblocks = openedblocks - 1
		    endif
		else
		    let ind = ind - 2 * &sw
		    if openedparenths > 0
			let openedparenths = openedparenths - 1
		    endif
		endif
	    endif
	endif
	let bracepos = InformIndentMatch(lnum, '[(){}\[\]]', bracepos + 1)
    endwhile

    if openedparenths > 0
	return ind
    endif

    if openedblocks > 0
	let shoulddedentcolon = 0
    else
	let shoulddedentcolon = 1
    endif
    "}}}

    " indenting in switch-clauses {{{
    if InformIndentSwitchStart(lnum)
	let ind = ind + &sw
	if InformIndentMatch(lnum, '\<switch\>', InformIndentMatch(lnum, ':', 0)) == -1
	    let shoulddedentcolon = 1
	endif
    endif
    "}}}

    " Sort one-liners (braceless if's, for's etc.) {{{
    " This is a bit of a mess... ideas for cleaning appreciated
    " This should go after any positive indentation it might interact with
    if skippedinstruction == 0
	let col = InformIndentMatch(lnum,'\(\(\<if\>\|\<while\>\|\<objectloop\>\|\<for\>\)\s*(.*)\|\(\<else\>\|\<do\>\)\)',0)
	if col + 1
		    \ && InformIndentMatch(lnum,'[{;]',col) == -1
		    \ && line !~ '^\s*{'
	    let ind = ind + &sw
	endif
    endif

    " Dedenting after a one-liner:
    let passedelse = 0 
    if getline(v:lnum) !~ '^\s*{'
	let plnum = lnum
	while plnum > 0 
	    let pind = indent(plnum)
	    if pind < ind
		break
	    endif
	    if pind == ind 
			\ && getline(plnum) !~ '^\s*[}{]'
		if getline(plnum) =~ '^\s*else\>'
		    let passedelse = 1
		else
		    "if getline(prevnonblank(plnum - 1)) =~ '^[^!]*\(\(\<if\>\|\<while\>\|\<objectloop\>\|\<for\>\)\s*(.*)\|\<else\>\)[^{;]*$'
		    "if getline(prevnonblank(plnum - 1)) =~ '\(\<if\>\|\<while\>\|\<objectloop\>\|\<for\>\)[^{]*$'
		    let pplnum = InformIndentPrevnonblank(plnum)
		    if indent(pplnum) < ind
			let col = InformIndentMatch(pplnum,'\(\(\<if\>\|\<while\>\|\<objectloop\>\|\<for\>\)\s*(.*)\|\(\<else\>\|\<do\>\)\)',0)
			if col + 1
				    \ && InformIndentMatch(pplnum,'[{;]',col) == -1
			    let ind = ind - &sw
			    if InformIndentMatch(v:lnum,'\<else\>',0) + 1
					\ && passedelse == 0
				if InformIndentMatch(plnum, '\<if\>',0) + 1
				    let ind = ind + &sw "Don't dedent after all
				    break
				elseif InformIndentMatch(pplnum,'\<if\>',0) + 1
				    break
				endif
			    endif
			    let passedelse = 0
			    let plnum = InformIndentPrevnonblank(plnum)
			    continue
			endif
		    endif
		    break
		endif
	    endif
	    let plnum = InformIndentPrevnonblank(plnum)
	endwhile
    endif
    "}}}

    " Indenting of object definition clauses  {{{
    "	(properties etc.) which wouldn't otherwise be indented - basically for
    "	long lists like in 'name', 'found_in' and 'has'. Should go after all
    "	normal positive indenting.
    "		
    "	This is EXPERIMENTAL - enable by defining "inf_indent_obj_defs", say
    "	in .vimrc. Note that the way it works right now, it only will if you
    "	left-indent all your object and class definitions.  Ideas for fixing
    "	that much appreciated.
    if b:inf_indent_obj_defs
	if ind == 0
		    \ && pline !~ ';\s*\($\|!\)'
		    \ && line  !~ ';\s*\($\|!\)'
		    \ && line !~ '^\s*\(with\|has\|class\|private\)\>'
		    \ && (pline =~ '^\s*\(with\|has\|class\|private\)\>'
		    \ || getline(InformIndentPrevnonblank(lnum)) =~ ',\s*\($\|!\)')
	    let ind = ind + &sw
	endif
	if (pline =~ ',\s*\($\|!\)')
	    let ind = ind - &sw
	endif
    endif
    "}}}

    " Closure of blocks and brackets {{{
    let bracepos = InformIndentMatch(v:lnum, '^\s*[)}\]]', 0)
    if bracepos != -1
	if strpart(line, bracepos, 1) != ')' 
	    let ind = ind - InformIndentSwitchEndsWithBlock(ind)*&sw
	endif
	let ind = ind - &sw
    endif
    "}}}

    " Next line of a switch-style thing {{{
    "	(as in switch statements, before/after methods, and so on) 
    "		(is there actually a 'so on')?	
    if InformIndentSwitchStart(v:lnum)
		\ && shoulddedentcolon == 1
	" Need to check this isn't the first clause of a new switch statement
	let openblockcol = InformIndentMatch(v:lnum, '[[{]', 0)
	if openblockcol == -1
		    \ || openblockcol > InformIndentMatch(v:lnum, ':', 0)
	    let ind = ind - &sw
	endif
    endif
    "}}}

    if ind < 0
	let ind = 0
    endif

    return ind

endfunction
"}}}

let &cpo = cpo_save
