" autoload/composer.vim - Composer autoloads
" Maintainer: Noah Frederick

""
" Throw error with {msg} and replacements.
function! s:throw(...) abort
  let msg = a:0 > 1 ? call('printf', a:000) : a:1
  let v:errmsg = 'composer: ' . msg
  throw v:errmsg
endfunction

""
" Like @function(get) but allows for querying nested keys. The {key} may
" contain a dot separator to delimit nested keys:
"
"   let val = s:get_nested(dict, 'foo.bar')
"
function! s:get_nested(dict, key, ...) abort
  let parts = split(a:key, '\.')
  let dict = a:dict
  let default = get(a:000, 0, '')

  for part in parts
    unlet! val
    let val = get(dict, part, 'x-undefined')

    if type(val) == type('') && val ==# 'x-undefined'
      return default
    elseif type(val) == type({})
      let dict = val
    endif
  endfor

  return val
endfunction

""
" Get Dict from JSON {string}.
function! s:json_decode(string) abort
  try
    if exists('*json_decode')
      return json_decode(a:string)
    else
      return projectionist#json_parse(a:string)
    endif
  catch /^Vim\%((\a\+)\)\=:E474/
    call s:throw('composer.json cannot be parsed')
  catch /^invalid JSON/
    call s:throw('composer.json cannot be parsed')
  catch /^Vim\%((\a\+)\)\=:E117/
    call s:throw('projectionist is not available')
  endtry
  return {}
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
  let root = get(a:000, 0, exists('b:composer_root') && b:composer_root !=# '' ? b:composer_root : '')

  if empty(root)
    return {}
  endif

  if !has_key(s:projects, root)
    let s:projects[root] = deepcopy(s:project_prototype)
    let s:projects[root]._root = root
  endif

  return get(s:projects, root, {})
endfunction

""
" Get the project object belonging to the current project root, or that
" of [root]. Throws an error if not in a composer project.
function! s:project(...) abort
  let project = call('composer#project', a:000)

  if !empty(project)
    return project
  endif

  call s:throw('%s does not belong to a composer project', expand('%:p'))
endfunction

""
" Get absolute path to project root, optionally with [path] appended.
function! s:project_path(...) dict abort
  return join([self._root] + a:000, '/')
endfunction

""
" Get vendor directory, optionally with [path] appended.
function! s:project_vendor_dir(...) dict abort
  let dir = self.query('config.vendor-dir', 'vendor')

  if dir[0] !=# '/'
    let dir = call('s:project_path', [dir] + a:000, self)
  endif

  return dir
endfunction

""
" Check whether file is readable in project.
function! s:project_has_file(file) dict abort
  let path = a:file[0] ==# '/' ? a:file : self.path(a:file)
  return filereadable(path)
endfunction

""
" Change working directory to project root or [dir], respecting current
" window's local dir state. Returns old working directory to be restored later
" by a second invocation of the function.
function! s:project_cd(...) dict abort
  let dir = get(a:000, 0, self.path())
  let cd = exists('*haslocaldir') && haslocaldir() ? 'lcd' : 'cd'
  let cwd = getcwd()
  execute cd fnameescape(dir)
  return cwd
endfunction

call s:add_methods('project', ['path', 'vendor_dir', 'has_file', 'cd'])

""
" Get JSON contents of composer.json as a Dict.
function! s:project_json() dict abort
  if self.cache.needs('json')
    call self.cache.set('json', s:json_decode(readfile(self.path('composer.json'))))
  endif

  return self.cache.get('json')
endfunction

""
" Get JSON contents of composer.lock as a Dict.
function! s:project_lock() dict abort
  if self.cache.needs('lock') && self.has_file('composer.lock')
    call self.cache.set('lock', s:json_decode(readfile(self.path('composer.lock'))))
  endif

  return self.cache.get('lock')
endfunction

""
" Get JSON contents of installed.json as a Dict.
function! s:project_installed_json() dict abort
  if self.cache.needs('installed_json')
    if self.has_file('vendor/composer/installed.json')
      call self.cache.set('installed_json', s:json_decode(readfile(self.path('vendor/composer/installed.json'))))
    else
      call self.cache.set('installed_json', [])
    endif
  endif

  return self.cache.get('installed_json')
endfunction

""
" Query {key} from project's composer.json with [default] value.
function! s:project_query(key, ...) dict abort
  let default = get(a:000, 0, '')
  return s:get_nested(self.json(), a:key, default)
endfunction

""
" Get Dict of packages required in composer.json, where the keys represent
" package names and the values represent the version constraints.
function! s:project_packages_required() dict abort
  return get(self.json(), 'require', {})
endfunction

""
" Get Dict of packages installed in current project from installed.json.
function! s:project_packages_installed() dict abort
  return self.installed_json()
endfunction

""
" Get Dict of scripts in composer.json, where the keys represent
" event/command names and the values represent commands.
function! s:project_scripts() dict abort
  return get(self.json(), 'scripts', {})
endfunction

""
" Get Composer executable.
function! s:project_makeprg() dict abort
  if self.has_file('composer.phar')
    return 'php composer.phar'
  else
    return 'composer'
  endif
endfunction

""
" Get output from Composer with {args} in project's root directory.
function! s:project_exec(args) dict abort
  try
    let cwd = self.cd(self.path())
    let result = system(join([self.makeprg()] + a:args))
  finally
    call self.cd(cwd)
  endtry

  return result
endfunction

""
" Get Dict of subcommands, optionally belonging to [namespace].
function! s:project_commands(...) dict abort
  let namespace = get(a:000, 0, '')
  let cache = namespace ==# '' ? 'commands' : 'commands_' . namespace

  if self.cache.needs(cache)
    let lines = split(self.exec(['list', namespace, '--raw']), "\n")

    if v:shell_error != 0
      return []
    endif

    call map(lines, "matchstr(v:val, '^.\\{-}\\ze\\s')")
    call filter(lines, 'v:val != ""')

    call self.cache.set(cache, lines)
  endif

  return self.cache.get(cache)
endfunction

""
" Search package names in available repositories.
function! s:project_search(keyword) dict abort
  let cache = 'search_' . a:keyword

  if self.cache.needs(cache)
    let lines = split(self.exec(['search', '--only-name', a:keyword]), "\n")

    if v:shell_error != 0
      return []
    endif

    call map(lines, "matchstr(v:val, '^.\\{-}\\ze\\s')")
    call filter(lines, 'v:val != ""')

    call self.cache.set(cache, lines)
  endif

  return self.cache.get(cache)
endfunction

call s:add_methods('project', ['json', 'lock', 'installed_json', 'query', 'scripts', 'makeprg', 'exec', 'commands', 'packages_required', 'packages_installed', 'search'])

let s:cache_prototype = {'cache': {}}

function! s:cache_clear(...) dict abort
  if a:0 == 0
    let self.cache = {}
  elseif has_key(self, 'cache') && has_key(self.cache, a:1)
    unlet! self.cache[a:1]
  endif
endfunction

function! composer#cache_clear(...) abort
  if exists('b:composer_root')
    return call(composer#project().cache.clear, a:000, composer#project().cache)
  endif
endfunction

function! s:cache_get(...) dict abort
  if a:0 == 0
    return self.cache
  else
    return self.cache[a:1]
  endif
endfunction

function! s:cache_set(key, value) dict abort
  let self.cache[a:key] = a:value
endfunction

function! s:cache_has(key) dict abort
  return has_key(self.cache, a:key)
endfunction

function! s:cache_needs(key) dict abort
  return !has_key(self.cache, a:key)
endfunction

call s:add_methods('cache', ['clear', 'get', 'set', 'has', 'needs'])

let s:project_prototype.cache = s:cache_prototype

augroup composer_cache
  autocmd!
  autocmd BufWritePost composer.json call composer#cache_clear('json')
  autocmd User ComposerCmdPost       call composer#cache_clear('json')
  autocmd User ComposerCmdPost       call composer#cache_clear('lock')
  autocmd User ComposerCmdPost       call composer#cache_clear('json_installed')
augroup END

""
" @public
" Query {key} from composer.json for current project.
function! composer#query(key) abort
  return s:project().query(a:key)
endfunction

""
" @private
" Set up Composer buffers.
function! composer#buffer_setup() abort
  ""
  " @command Composer[!] [arguments]
  " Invoke Composer with [arguments] (with intelligent completion, including
  " completion for package names on packagist.org).
  command! -buffer -bang -bar -nargs=? -complete=customlist,composer#commandline#complete
        \ Composer execute composer#commandline#exec(<q-bang>, <f-args>)

  if &filetype =~# 'php'
    ""
    " Find definition of class, interface, or trait under the cursor using
    " Composer's autoload mechanism.
    nnoremap <buffer> <Plug>(composer-find) :<C-u>execute composer#autoload#find()<CR>

    ""
    " Insert a use statement for the class/interface/trait under the cursor.
    nnoremap <buffer> <Plug>(composer-use) :<C-u>execute composer#namespace#use(0)<CR>
  endif

  silent doautocmd User Composer
endfunction

""
" @private
" Hack for testing script-local functions.
function! composer#sid()
  nnoremap <SID> <SID>
  return maparg('<SID>', 'n')
endfunction

" vim: fdm=marker:sw=2:sts=2:et
