" autoload/composer/namespace.vim - Namespacing and use statements
" Maintainer: Noah Frederick

""
" @private
" Find use statement matching {class}. Adapted from
" https://github.com/arnaud-lb/vim-php-namespace/blob/master/plugin/phpns.vim
function! composer#namespace#using(class) abort
  " Matches: use Foo\Bar as {class};
  let pattern = '\%(^\|\r\|\n\)\s*use\_s\+\_[^;]\{-}\_s*\([^;,]*\)\_s\+as\_s\+' . a:class . '\_s*[;,]'
  let fqn = s:capture(pattern, 1)
  if fqn isnot 0
    return fqn
  endif

  " Matches: use Foo\{class};
  let pattern = '\%(^\|\r\|\n\)\s*use\_s\+\_[^;]\{-}\_s*\([^;,]*' . a:class . '\)\_s*[;,]'
  let fqn = s:capture(pattern, 1)
  if fqn isnot 0
    return fqn
  endif

  return ''
endfunction

""
" @private
" Expand {class} to fully-qualified name in the context of the current file's
" namespace.
function! composer#namespace#expand(class) abort
  if a:class[0] ==# '\'
    return a:class
  endif

  let pattern = '\%(<?\%(php\s\+\)\?\)\?\s*namespace\s\+\([A-Za-z0-9_\\]\+\);'
  let ns = s:capture(pattern, 1)

  if ns isnot 0
    return '\' . ns . '\' . a:class
  endif

  return '\' . a:class
endfunction

let s:match = 0

function! s:save_match(match) abort
  let s:match = a:match
endfunction

""
" Search for {pattern} and return {submatch}. Adapted from
" https://github.com/arnaud-lb/vim-php-namespace/blob/master/plugin/phpns.vim
function! s:capture(pattern, submatch)
  let s:match = 0
  let buf = join(getline(1, '$'), "\n")
  call substitute(buf, a:pattern, '\=[submatch(0), s:save_match(submatch(' . a:submatch . '))][0]', 'e')
  return s:match
endfunction

""
" @private
" Hack for testing script-local functions.
function! composer#namespace#sid()
  nnoremap <SID> <SID>
  return maparg('<SID>', 'n')
endfunction

" vim: fdm=marker:sw=2:sts=2:et
