" autoload/composer/autoload.vim - Find source code via Composer autoloader
" Maintainer: Noah Frederick

""
" Throw error with {msg} and replacements.
function! s:throw(...) abort
  let msg = a:0 > 1 ? call('printf', a:000) : a:1
  let v:errmsg = 'composer: ' . msg
  throw v:errmsg
endfunction

""
" @private
" Edit source file for class/trait/interface at cursor or specified in
" [class]. The name is automatically expanded into a fully-qualified name.
function! composer#autoload#find(...) abort
  let class = get(a:000, 0, composer#namespace#class_at_cursor())

  if empty(class)
    return ''
  elseif class[0] ==# '\'
    let fqn = class
  else
    let fqn = composer#namespace#using(class, 1)

    if empty(fqn)
      let fqn = composer#namespace#expand(class)
    endif
  endif

  try
    return 'edit ' . s:find_file(fqn)
  catch /^composer:/
  endtry

  return ''
endfunction

""
" Find source file for the class/trait/interface {fqn} using Composer's
" autoloader.
function! s:find_file(fqn) abort
  let project = composer#project()
  let autoload = project.vendor_dir('autoload.php')

  if !project.has_file(autoload)
    call s:throw('autoload.php not found. Run composer install.')
  endif

  let fqn = substitute(a:fqn, '^\', '', '')
  let s = '$c = require("' . autoload . '"); echo $c->findFile($argv[1]);'
  let path = system('php -r ' . shellescape(s) . ' ' . shellescape(fqn))

  if v:shell_error != 0
    call s:throw('Command exited with code %d', v:shell_error)
  endif

  if !project.has_file(path)
    call s:throw('Cannot find file for %s', a:fqn)
  endif

  return path
endfunction

""
" @private
" Hack for testing script-local functions.
function! composer#autoload#sid()
  nnoremap <SID> <SID>
  return maparg('<SID>', 'n')
endfunction

" vim: fdm=marker:sw=2:sts=2:et
