" autoload/composer.vim - Composer autoloads
" Maintainer: Noah Frederick

""
" @public
" Get the version number of the @plugin(stylized) plug-in (e.g., '1.0.0').
function! composer#version()
  return '0.1.0'
endfunction

""
" Throw error with {msg}.
function! s:throw(msg) abort
  let v:errmsg = 'composer: ' . a:msg
  throw v:errmsg
endfunction

""
" Implement uniq() for older Vims. Adapted from projectionist.vim.
function! s:uniq(list) abort
  if exists('*uniq')
    return uniq(a:list)
  endif

  let i = 0
  let seen = {}
  while i < len(a:list)
    let str = string(a:list[i])
    if has_key(seen, str)
      call remove(a:list, i)
    else
      let seen[str] = 1
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
  let result = {}
  try
    let result = projectionist#json_parse(a:string)
  catch /^Vim\%((\a\+)\)\=:E117/
    call s:throw('projectionist is not available')
  endtry
  return result
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
  let lockfile = self.path('composer.lock')

  if  (!has_key(self, '_lock') || recache) && filereadable(lockfile)
    let self._lock = s:json_parse(readfile(lockfile))
  endif

  return self._lock
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
  let namespace = get(a:000, 0, '_')

  if !has_key(self, '_commands')
    let self._commands = {}
  endif

  if !has_key(self._commands, namespace)
    let ns = namespace ==# '_' ? '' : namespace
    let lines = split(self.exec(['list', ns, '--raw']), "\n")
    let self._commands[namespace] = []

    if v:shell_error != 0
      return self._commands[namespace]
    endif

    call filter(lines, 'v:val != ""')

    for line in lines
      let parts = split(line, '\s\s\+')
      call add(self._commands[namespace], parts[0])
    endfor
  endif

  return self._commands[namespace]
endfunction

call s:add_methods('project', ['path', 'has_file', 'json', 'query', 'makeprg', 'exec', 'commands', 'packages_required'])

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

  let old_makeprg = &l:makeprg
  let old_errorformat = &l:errorformat
  let old_compiler = get(b:, 'current_compiler', '')

  try
    let cwd = s:cd(s:project().path())

    if !empty(findfile('compiler/composer.vim', escape(&rtp, ' ')))
      compiler composer
    else
      let &l:errorformat = '%+I%.%#'
      let b:current_compiler = 'composer'
    endif
    let &l:makeprg = s:project().makeprg()

    if exists(':Make') == 2
      execute join(['Make' . bang] + args)
    else
      execute join(['make!'] + args)
      if bang ==# ''
        return 'cwindow'
      endif
    endif
    return ''
  finally
    let &l:errorformat = old_errorformat
    let &l:makeprg = old_makeprg
    let b:current_compiler = old_compiler
    if empty(old_compiler)
      unlet! b:current_compiler
    endif

    call s:cd(cwd)
  endtry
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

  if global ==# 'global' && subcommand ==# ''
    let candidates = commands + s:composer_flags['_global'] + ['help']
  elseif help ==# 'help' && subcommand ==# ''
    let candidates = commands + s:composer_flags['_global'] + ['global', 'help']
  elseif has_key(s:composer_flags, subcommand) && subcommand !=# ''
    let candidates = s:composer_flags['_global'] + s:composer_flags[subcommand]
  elseif subcommand !=# ''
    let candidates = s:composer_flags['_global']
  else
    let candidates = commands + s:composer_flags['_global'] + ['global', 'help']
  endif

  if help ==# '' && index(['remove', 'update', 'suggests'], subcommand) >= 0
    let candidates = candidates + keys(s:project().packages_required())
  endif

  return s:filter_completions(candidates, a:A)
endfunction

""
" Sort and filter completion {candidates} based on the current argument {A}.
function! s:filter_completions(candidates, A) abort
  let candidates = copy(a:candidates)
  if len(candidates) == 0
    return []
  endif
  if len(a:A) > 0
    call filter(candidates, "v:val =~# '^' . a:A")
  endif
  call sort(candidates)
  call s:uniq(candidates)

  let commands = filter(copy(candidates), "v:val[0] !=# '-'")
  let flags = filter(copy(candidates), "v:val[0] ==# '-'")

  return commands + flags
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
