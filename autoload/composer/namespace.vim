" autoload/composer/namespace.vim - Namespacing and use statements
" Maintainer: Noah Frederick

""
" @private
" Insert use statement for [class], optionally with [alias]. If {sort} is
" non-empty, also sort all use statements in the buffer.
function! composer#namespace#use(sort, ...) abort
  let class = get(a:000, 0, composer#namespace#class_at_cursor())
  let alias = get(a:000, 1, '')
  let sort = !empty(a:sort)

  if !empty(composer#namespace#using(empty(alias) ? class : alias))
    echohl WarningMsg
    echomsg 'Use statement for ' . class . ' already exists'
    echohl None
    return
  endif

  let fqn = composer#namespace#expand(class)
  let line = 'use ' . fqn[1:-1]

  if !empty(alias)
    let line .= ' as ' . alias
  endif

  let line .= ';'

  if search('^use\_s\_[[:alnum:][:blank:]\\,_]\+;', 'wbe') > 0
    put=line
  elseif search('^\s*namespace\_s\_[[:alnum:]\\_]\+;', 'wbe') > 0
    put=''
    put=line
  elseif search('<?\%(php\)\?', 'wbe') > 0
    put=''
    put=line
  else
    0put=line
  endif

  if sort
    call composer#namespace#sort_uses()
  endif

  return ''
endfunction

""
" @private
" Sort use statements in buffer alphabetically.
function! composer#namespace#sort_uses() abort
  let save = @a
  let @a = ''

  normal! m`

  " Collapse multiline use statements into single lines
  while search('^use\_s\_[[:alnum:][:blank:]\\,_]\+,$') > 0
    global/^use\_s\_[[:alnum:][:blank:]\\,_]\+,$/join
  endwhile

  " Gather all use statements
  global/^use\_s\_[[:alnum:][:blank:]\\,_]\+;/delete A

  if search('^\s*namespace\_s\_[[:alnum:]\\_]\+;', 'wbe') > 0
    put a
  elseif search('<?\%(php\)\?', 'wbe') > 0
    put a
  else
    0put a
  endif

  '[,']sort

  " Clean up blank line after pasted use block
  ']+1delete _

  normal! ``

  let @a = save
endfunction

""
" @private
" Find use statement matching {class}. If [allow_aliased] is non-zero, allow
" matching a class name before an 'as'. Adapted from
" https://github.com/arnaud-lb/vim-php-namespace/blob/master/plugin/phpns.vim
function! composer#namespace#using(class, ...) abort
  let class = escape(substitute(a:class, '^\\', '', ''), '\')
  let allow_aliased = get(a:000, 0, 0)

  " Matches: use Foo\Bar as {class};
  let pattern = '\%(^\|\r\|\n\)\s*use\_s\+\_[^;]\{-}\_s*\([^;,]*\)\_s\+as\_s\+' . class . '\_s*[;,]'
  let fqn = s:capture(pattern, 1)
  if fqn isnot 0
    return fqn
  endif

  " Matches: use Foo\{class};
  let pattern = '\%(^\|\r\|\n\)\s*use\_s\+\_[^;]\{-}\_s*\([^;,]*' . class . '\)\_s*[;,]'
  let fqn = s:capture(pattern, 1)
  if fqn isnot 0
    return fqn
  endif

  if allow_aliased
    " Matches: use {class} as Bar;
    let pattern = '\%(^\|\r\|\n\)\s*use\_s\+\_[^;]\{-}\_s*\([^;,]*' . class . '\)'
    let fqn = s:capture(pattern, 1)
    if fqn isnot 0
      return fqn
    endif
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

  let pattern = '\%(<?\%(php\s\+\)\?\)\?\s*namespace\s\+\([[:alnum:]_\\]\+\);'
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
  call substitute(buf, a:pattern, '\=[submatch(0), s:save_match(submatch(' . a:submatch . '))][0]', '')
  return s:match
endfunction

""
" Return the class, trait, or interface name at the cursor's location.
" If no such name is at the cursor, return empty string.
function! s:class_at_cursor() abort
  " Search position of class name with cursor inside
  let pattern = '\(\<\u\|\\\)[[:alnum:]\\_]*\%#[[:alnum:]\\_]*'
  let [lnum, col] = searchpos(pattern, 'cnb', line('.'))

  if col == 0
    " Search position of class name with cursor right before
    let pattern = '\%#\(\<\u\|\\\)[[:alnum:]\\_]\+'
    let [lnum, col] = searchpos(pattern, 'cnb', line('.'))
  endif

  if col == 0
    return ''
  endif

  " Capture the name
  let buf = getline('.')[col - 1:]
  return substitute(buf, '^[[:alnum:]\\_]\+\zs.*', '', '')
endfunction

""
" @private
" Get the class, trait, or interface name at the cursor's location.
" Print a warning if there is nothing relevant at the cursor.
function! composer#namespace#class_at_cursor() abort
  let class = s:class_at_cursor()

  if empty(class)
    echohl WarningMsg
    echomsg 'No class/trait/interface name at cursor'
    echohl None
  endif

  return class
endfunction

""
" @private
" Hack for testing script-local functions.
function! composer#namespace#sid()
  nnoremap <SID> <SID>
  return maparg('<SID>', 'n')
endfunction

" vim: fdm=marker:sw=2:sts=2:et
