" vim: set sts=4:
" Inform filetype plugin v0.5
" Language:	Inform
" Maintainer:	Martin Bays <vim@zugzwang.port5.com>
" Last Change:	Wed Dec 17 18:55:04 GMT 2003
"
" (adapted from vim.vim by Bram Moolenaar (himself)) 

" Just the basics

" Only do this when not done yet for this buffer
if exists("b:did_ftplugin")
  finish
endif

" Don't load another plugin for this buffer
let b:did_ftplugin = 1

let cpo_save = &cpo
set cpo-=C

let b:undo_ftplugin = "setl fo< com< tw< commentstring<"
	    \ . "| unlet! b:match_ignorecase b:match_words"

" Set 'formatoptions' to break comment lines,
" and insert the comment leader when hitting <CR>, but not when using "o",
" becuase that really ticks me off.
setlocal fo+=crql

" Set 'comments' 
setlocal com=:!

" Format comments to be up to 78 characters long
setlocal tw=78

" Comments start with a bang
setlocal commentstring=!%s

" Include doesn't need a hash
setlocal include=^#\\?\\s*[iI]nclude

" Various definition statements
setlocal define=^#\\?\\s*\\([Cc]onstant\\\\|[Dd]efault\\\\|[Gg]lobal\\\\|[Aa]rray\\)

" For :make - doesn't work well yet (need to set errorformat appropriately)
" Change: the library path below -
setlocal makeprg=inform\ +/home/martin/if/z/library\ %

" Let the matchit plugin know what items can be matched.
if exists("loaded_matchit")
    let b:match_ignorecase = 1
    let b:match_words = '\<if\>:\<else\>,' .
		\ '\<do\>:\<until\>,' .
		\ '\<IF\(DEF\|NDEF\|TRUE\|FALSE\|V3\|V5\|NOT\)\>:\<ENDIF\>'

endif

let &cpo = cpo_save
