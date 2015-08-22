" autoload/composer.vim - Composer autoloads
" Maintainer: Noah Frederick

""
" @public
" Get the version number of the @plugin(stylized) plug-in (e.g., '1.0.0').
function! composer#version()
  return '0.0.0'
endfunction

""
" Throw error with {msg}.
function! s:throw(msg) abort
  let v:errmsg = 'composer: ' . a:msg
  throw v:errmsg
endfunction

""
" Change working directory to {dir}, respecting current window's local dir
" state. Returns old working directory to be restored later by a second
" invocation of the function.
function! s:cd(dir) abort
  let cd = exists('*haslocaldir') && haslocaldir() ? 'lcd' : 'cd'
  let cwd = getcwd()
  execute cd fnameescape(a:dir)
  return cwd
endfunction

""
" Like @function(get) but allows for querying nested keys. The {key} may
" contain a dot separator to delimit nested keys:
"
"   let val = s:get_nested(dict, 'foo.bar')
"
function! s:get_nested(dict, key, default) abort
  let parts = split(a:key, '\.')
  let dict = a:dict

  for part in parts
    unlet! val
    let val = get(dict, part, '')

    if type(val) == type('') && val ==# ''
      return a:default
    elseif type(val) == type({})
      let dict = val
    endif
  endfor

  return val
endfunction

""
" Get Dict from JSON {string}.
function! s:json_parse(string) abort
  return projectionist#json_parse(a:string)
endfunction

""
" Get Funcref from script-local function {name}.
function! s:function(name) abort
  return function(substitute(a:name, '^s:', matchstr(expand('<sfile>'), '<SNR>\d\+_'), ''))
endfunction

""
" Add {method_names} to prototype {namespace} Dict. Follows the same pattern
" as rake.vim.
function! s:add_methods(namespace, method_names) abort
  for name in a:method_names
    let s:{a:namespace}_prototype[name] = s:function('s:' . a:namespace . '_' . name)
  endfor
endfunction

let s:project_prototype = {}
let s:projects = {}

""
" @private
" Get the project object belonging to the current project root, or that
" of [root]. Initializes the project if not initialized.
function! composer#project(...) abort
  let dir = get(a:000, 0, exists('b:composer_root') && b:composer_root !=# '' ? b:composer_root : '')

  if dir !=# ''
    if has_key(s:projects, dir)
      let project = get(s:projects, dir)
    else
      let project = {'_root': dir}
      let s:projects[dir] = project
    endif

    return extend(project, s:project_prototype, 'keep')
  endif

  return {}
endfunction

""
" Get the project object belonging to the current project root, or that
" of [root]. Throws an error if not in a composer project.
function! s:project(...) abort
  let project = call('composer#project', a:000)

  if !empty(project)
    return project
  endif

  call s:throw('not a composer project: ' . expand('%:p'))
endfunction

""
" Get absolute path to project root, optionally with [path] appended.
function! s:project_path(...) dict abort
  return join([self._root] + a:000, '/')
endfunction

""
" Get JSON contents of composer.json as a Dict. If the [recache] flag is
" supplied, reread the file instead of using the cached contents.
function! s:project_json(...) dict abort
  let recache = get(a:000, 0, 0)

  if !has_key(self, '_json') || recache
    let self._json = s:json_parse(readfile(self.path('composer.json')))
  endif

  return self._json
endfunction

""
" Get JSON contents of composer.lock as a Dict. If the [recache] flag is
" supplied, reread the file instead of using the cached contents.
function! s:project_lock(...) dict abort
  let recache = get(a:000, 0, 0)

  if !has_key(self, '_lock') || recache
    let self._lock = s:json_parse(readfile(self.path('composer.lock')))
  endif

  return self._lock
endfunction

""
" Query {key} from project's composer.json.
function! s:project_query(key) dict abort
  return s:get_nested(self.json(), a:key, '')
endfunction

function! s:project_makeprg() dict abort
  if filereadable(self.path('composer.phar'))
    return 'php composer.phar'
  else
    return 'composer'
  endif
endfunction

""
" Call Composer with {args} in project's root directory.
function! s:project_exec(bang, args) dict abort
  let cwd = s:cd(self.path())
  try
    execute '!' . join([self.makeprg()] + a:args)
  finally
    call s:cd(cwd)
  endtry
endfunction

call s:add_methods('project', ['path', 'json', 'query', 'makeprg', 'exec'])

""
" @public
" Query {key} from composer.json for current project.
function! composer#query(key) abort
  return composer#project().query(a:key)
endfunction

""
" @private
" Set up Composer buffers.
function! composer#buffer_setup() abort
  ""
  " @command Composer[!] [arguments]
  " Run Composer with [arguments] with smart completion.
  command! -buffer -bang -bar -nargs=? -complete=customlist,composer#complete
        \ Composer call s:composer_cmd(<q-bang>, <f-args>)

  silent doautocmd User Composer
endfunction

""
" The :Composer command.
function! s:composer_cmd(...) abort
  let args = copy(a:000)
  let bang = remove(args, 0)

  return s:project().exec(bang, args)
endfunction

""
" @private
" Completion for the :Composer command.
function! composer#complete(A, L, P) abort
  return [
        \ 'install',
        \ 'update',
        \ ]
endfunction

" vim: fdm=marker:sw=2:sts=2:et
