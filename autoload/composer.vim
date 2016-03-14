" autoload/composer.vim - Composer autoloads
" Maintainer: Noah Frederick

""
" Throw error with {msg}.
function! s:throw(msg) abort
  let v:errmsg = 'composer: ' . a:msg
  throw v:errmsg
endfunction

""
" Implement the one-argument version of uniq() for older Vims.
function! s:uniq(list) abort
  if exists('*uniq')
    return uniq(a:list)
  endif

  let i = 0
  let last = ''

  while i < len(a:list)
    let str = string(a:list[i])
    if str ==# last && i > 0
      call remove(a:list, i)
    else
      let last = str
      let i += 1
    endif
  endwhile

  return a:list
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
  try
    return projectionist#json_parse(a:string)
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
" Check whether file is readable in project.
function! s:project_has_file(file) dict abort
  return filereadable(self.path(a:file))
endfunction

call s:add_methods('project', ['path', 'has_file'])

""
" Get JSON contents of composer.json as a Dict.
function! s:project_json() dict abort
  if self.cache.needs('json')
    call self.cache.set('json', s:json_parse(readfile(self.path('composer.json'))))
  endif

  return self.cache.get('json')
endfunction

""
" Get JSON contents of composer.lock as a Dict.
function! s:project_lock() dict abort
  if self.cache.needs('lock') && self.has_file('composer.lock')
    call self.cache.set('lock', s:json_parse(readfile(self.path('composer.lock'))))
  endif

  return self.cache.get('lock')
endfunction

""
" Get JSON contents of installed.json as a Dict.
function! s:project_installed_json() dict abort
  if self.cache.needs('installed_json')
    if self.has_file('vendor/composer/installed.json')
      call self.cache.set('installed_json', s:json_parse(readfile(self.path('vendor/composer/installed.json'))))
    else
      call self.cache.set('installed_json', [])
    endif
  endif

  return self.cache.get('installed_json')
endfunction

""
" Query {key} from project's composer.json.
function! s:project_query(key) dict abort
  return s:get_nested(self.json(), a:key, '')
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
    let cwd = s:cd(self.path())
    let result = system(join([self.makeprg()] + a:args))
  finally
    call s:cd(cwd)
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
  " Run Composer with [arguments] via @command(:make)[!] with smart
  " completion. The command is run asynchronously when paired with
  " Dispatch.vim.
  command! -buffer -bang -bar -nargs=? -complete=customlist,composer#complete
        \ Composer execute s:composer_cmd(<q-bang>, <f-args>)

  silent doautocmd User Composer
endfunction

""
" The :Composer command.
function! s:composer_cmd(...) abort
  let args = copy(a:000)
  let bang = remove(args, 0)

  let g:composer_cmd_args = args
  silent doautocmd User ComposerCmdPre

  if exists(':terminal')
    tabedit %
    execute 'lcd' fnameescape(s:project().path())
    execute 'terminal' s:project().makeprg() join(args)
  else
    let cwd = s:cd(s:project().path())
    execute '!' . s:project().makeprg() join(args)
    call s:cd(cwd)
  endif

  silent doautocmd User ComposerCmdPost
  unlet! g:composer_cmd_args

  return ''
endfunction

""
" @private
" Completion for the :Composer command.
function! composer#complete(A, L, P) abort
  let commands = copy(s:project().commands())

  call remove(commands, index(commands, 'global'))
  call remove(commands, index(commands, 'help'))
  let subcommand = matchstr(a:L, '\<\(' . join(commands, '\|') . '\)\>')
  let global = matchstr(a:L, '\<global\>')
  let help = matchstr(a:L, '\<help\>')

  let candidates = s:composer_flags['_global']

  if empty(subcommand)
    let candidates = candidates + commands

    if empty(global)
      let candidates = candidates + ['global', 'help']
    else
      let candidates = candidates + ['help']
    endif
  elseif has_key(s:composer_flags, subcommand)
    let candidates = candidates + s:composer_flags[subcommand]
  endif

  if empty(help) && index(['depends', 'remove', 'update', 'suggests'], subcommand) >= 0
    try
      let candidates = candidates + keys(s:project().packages_required())
    catch
      " Fail silently when composer.json cannot be parsed because of missing
      " dependency or invalid/empty file.
    endtry
  endif

  if empty(help) && index(['run-script', ''], subcommand) >= 0
    try
      let candidates = candidates + keys(s:project().scripts())
    catch
      " Fail silently when composer.json cannot be parsed because of missing
      " dependency or invalid/empty file.
    endtry
  endif

  if empty(help) && index(['browse', 'home', 'require', 'show'], subcommand) >= 0 && !empty(a:A)
    let candidates = candidates + s:project().search(a:A)
  endif

  return s:filter_completions(candidates, a:A)
endfunction

""
" Sort and filter completion {candidates} based on the current argument {A}.
" Adapted from bundler.vim.
function! s:filter_completions(candidates, A) abort
  let candidates = copy(a:candidates)
  if len(candidates) == 0
    return []
  endif
  call sort(candidates)
  call s:uniq(candidates)

  let commands = filter(copy(candidates), "v:val[0] !=# '-'")
  let flags = filter(copy(candidates), "v:val[0] ==# '-'")

  let candidates = commands + flags

  let filtered = filter(copy(candidates), 'v:val[0:strlen(a:A)-1] ==# a:A')
  if !empty(filtered) | return filtered | endif

  let regex = substitute(a:A, '[^/:]', '[&].*', 'g')
  let filtered = filter(copy(candidates), 'v:val =~# "^".regex')
  if !empty(filtered) | return filtered | endif

  let filtered = filter(copy(candidates), '"/".v:val =~# "[/:]".regex')
  if !empty(filtered) | return filtered | endif

  let regex = substitute(a:A, '.', '[&].*', 'g')
  let filtered = filter(copy(candidates),'"/".v:val =~# regex')
  return filtered
endfunction

" Unlike subcommands, composer does not list switches/flags in a friendly
" format, so we hard-code them.
let s:composer_flags = {
      \   '_global': [
      \     '--xml',
      \     '--format',
      \     '--raw',
      \     '--help',
      \     '-h',
      \     '--quiet',
      \     '-q',
      \     '--verbose',
      \     '-v',
      \     '-vv',
      \     '-vvv',
      \     '--version',
      \     '-V',
      \     '--ansi',
      \     '--no-ansi',
      \     '--no-interaction',
      \     '-n',
      \     '--profile',
      \     '--working-dir',
      \     '-d',
      \   ],
      \   'install': [
      \     '--prefer-source',
      \     '--prefer-dist',
      \     '--ignore-platform-reqs',
      \     '--dry-run',
      \     '--dev',
      \     '--no-dev',
      \     '--no-autoloader',
      \     '--no-scripts',
      \     '--no-plugins',
      \     '--no-progress',
      \     '--optimize-autoloader',
      \     '-o',
      \   ],
      \   'update': [
      \     '--prefer-source',
      \     '--prefer-dist',
      \     '--ignore-platform-reqs',
      \     '--dry-run',
      \     '--dev',
      \     '--no-dev',
      \     '--no-autoloader',
      \     '--no-scripts',
      \     '--no-plugins',
      \     '--no-progress',
      \     '--optimize-autoloader',
      \     '-o',
      \     '--lock',
      \     '--with-dependencies',
      \     '--prefer-stable',
      \     '--prefer-lowest',
      \   ],
      \   'require': [
      \     '--prefer-source',
      \     '--prefer-dist',
      \     '--ignore-platform-reqs',
      \     '--dev',
      \     '--no-update',
      \     '--no-progress',
      \     '--update-no-dev',
      \     '--update-with-dependencies',
      \     '--sort-packages',
      \   ],
      \   'remove': [
      \     '--ignore-platform-reqs',
      \     '--dev',
      \     '--no-update',
      \     '--no-progress',
      \     '--update-no-dev',
      \     '--update-with-dependencies',
      \   ],
      \   'search': [
      \     '--only-name',
      \     '-N',
      \   ],
      \   'show': [
      \     '--installed',
      \     '-i',
      \     '--platform',
      \     '-p',
      \     '--self',
      \     '-s',
      \   ],
      \   'browse': [
      \     '--homepage',
      \     '-H',
      \   ],
      \   'home': [
      \     '--homepage',
      \     '-H',
      \   ],
      \   'suggests': [
      \     '--no-dev',
      \     '--verbose',
      \     '-v',
      \   ],
      \   'depends': [
      \     '--link-type',
      \   ],
      \   'validate': [
      \     '--no-check-all',
      \     '--no-check-lock',
      \     '--no-check-publish',
      \   ],
      \   'status': [
      \   ],
      \   'self-update': [
      \     '--rollback',
      \     '-r',
      \     '--clean-backups',
      \   ],
      \   'config': [
      \     '--global',
      \     '-g',
      \     '--editor',
      \     '-e',
      \     '--unset',
      \     '--list',
      \     '-l',
      \     '--file',
      \     '-f',
      \     '--absolute',
      \   ],
      \   'create-project': [
      \     '--repository-url',
      \     '--stability',
      \     '-s',
      \     '--prefer-source',
      \     '--prefer-dist',
      \     '--dev',
      \     '--no-install',
      \     '--no-plugins',
      \     '--no-scripts',
      \     '--no-progress',
      \     '--keep-vcs',
      \     '--ignore-platform-reqs',
      \   ],
      \   'dump-autoload': [
      \     '--optimize',
      \     '-o',
      \     '--no-dev',
      \   ],
      \   'clear-cache': [
      \   ],
      \   'licenses': [
      \     '--no-dev',
      \     '--format',
      \   ],
      \   'run-script': [
      \     '--no-dev',
      \     '--list',
      \   ],
      \   'diagnose': [
      \   ],
      \   'archive': [
      \     '--format',
      \     '-f',
      \     '--dir',
      \   ],
      \ }

""
" @private
" Hack for testing script-local functions.
function! composer#sid()
  nnoremap <SID> <SID>
  return maparg('<SID>', 'n')
endfunction

" vim: fdm=marker:sw=2:sts=2:et
