" autoload/composer/commandline.vim - Commandline support
" Maintainer: Noah Frederick

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
" @private
" The :Composer command. Execute !composer {arguments} in the project root.
function! composer#commandline#exec(...) abort
  let args = copy(a:000)
  let bang = remove(args, 0)
  let project = composer#project()

  let g:composer_cmd_args = args
  silent doautocmd User ComposerCmdPre

  if exists(':terminal')
    tabedit %
    execute 'lcd' fnameescape(project.path())
    execute 'terminal' project.makeprg() join(args)
  else
    let cwd = project.cd()
    execute '!' . project.makeprg() join(args)
    call project.cd(cwd)
  endif

  silent doautocmd User ComposerCmdPost
  unlet! g:composer_cmd_args

  return ''
endfunction

""
" @private
" Completion for the :Composer command, including completion of:
"   - Global flags
"   - Built-in subcommands
"   - Subcommand-specific flags
"   - Package names
"   - Scripts defined in composer.json
function! composer#commandline#complete(A, L, P) abort
  let commands = copy(composer#project().commands())

  call remove(commands, index(commands, 'global'))
  call remove(commands, index(commands, 'help'))
  let subcommand = matchstr(a:L, '\<\(' . join(commands, '\|') . '\)\>')
  let global = matchstr(a:L, '\<global\>')
  let help = matchstr(a:L, '\<help\>')

  let candidates = s:flags['_global']

  if empty(subcommand)
    let candidates = candidates + commands

    if empty(global)
      let candidates = candidates + ['global', 'help']
    else
      let candidates = candidates + ['help']
    endif
  elseif has_key(s:flags, subcommand)
    let candidates = candidates + s:flags[subcommand]
  endif

  if empty(help) && index(['depends', 'remove', 'update', 'suggests'], subcommand) >= 0
    try
      let candidates = candidates + keys(composer#project().packages_required())
    catch
      " Fail silently when composer.json cannot be parsed because of missing
      " dependency or invalid/empty file.
    endtry
  endif

  if empty(help) && index(['run-script', ''], subcommand) >= 0
    try
      let candidates = candidates + keys(composer#project().scripts())
    catch
      " Fail silently when composer.json cannot be parsed because of missing
      " dependency or invalid/empty file.
    endtry
  endif

  if empty(help) && index(['browse', 'home', 'require', 'show'], subcommand) >= 0 && !empty(a:A)
    let candidates = candidates + composer#project().search(a:A)
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
let s:flags = {
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
function! composer#commandline#sid()
  nnoremap <SID> <SID>
  return maparg('<SID>', 'n')
endfunction

" vim: fdm=marker:sw=2:sts=2:et
