" plugin/composer.vim - Composer for Vim
" Maintainer:  Noah Frederick (https://noahfrederick.com)

""
" @section Introduction, intro
" @stylized Composer.vim
" @order intro commands maps autocommands functions about
" @plugin(stylized) provides conveniences for working with Composer PHP
" projects. Some features include:
"
" * @command(:Composer) command wrapper around composer with smart completion
" * Navigate to source files using Composer's autoloader
" * Insert use statement for the class/interface/trait under cursor
" * Projectionist support (e.g., :Ecomposer to edit your composer.json, :A to
"   jump to composer.lock and back)
" * Dispatch support (|:Dispatch| runs composer dump-autoload)
"
" This plug-in is only available if 'compatible' is not set.

""
" @section About, about
" @plugin(stylized) is distributed under the same terms as Vim itself (see
" |license|)
"
" You can find the latest version of this plug-in on GitHub:
" https://github.com/noahfrederick/vim-@plugin(name)
"
" Please report issues on GitHub as well:
" https://github.com/noahfrederick/vim-@plugin(name)/issues

""
" @section Mappings, maps
" <Plug>(composer-find)
"
" Find the definition of class, interface, or trait under the cursor using
" Composer's autoload mechanism. It is namespace-aware and even resolves
" aliases in 'use' statements. For example, it does what you want with the
" cursor on 'Env' in the last line: >
"   <?php namespace App;
"
"   use Dotenv\Dotenv as Env;
"
"   $env = new Env(__DIR__);
" <
"
" <Plug>(composer-use)
"
" Insert a use statement for the class, interface, or trait under the cursor.
"
" <Plug>(composer-namespace)
"
" Insert the namespace statement of current class based on the PSR-4 autoload.

""
" @section Autocommands, autocommands
" If you want to set your own Vim settings for buffers belonging to your
" Composer project, you may do so from your vimrc using an autocommand: >
"   autocmd User Composer nmap <buffer> gf <Plug>(composer-find)
" <

if (exists('g:loaded_composer') && g:loaded_composer) || &cp
  finish
endif
let g:loaded_composer = 1

" Detection {{{

""
" Determine whether the current or supplied [path] belongs to a Composer
" project, and set b:composer_root to the path of the project root.
function! s:composer_detect(...) abort
  if exists('b:composer_root')
    return 1
  endif

  let fn = fnamemodify(get(a:000, 0, expand('%')), ':p')

  if !isdirectory(fn)
    let fn = fnamemodify(fn, ':h')
  endif

  let candidates = findfile('composer.json', escape(fn, ', ') . ';', -1)

  for json in candidates
    let root = fnamemodify(json, ':p:h')

    if filereadable(root.'/vendor/autoload.php')
      let b:composer_root = root
      return 1
    endif
  endfor

  if !empty(candidates)
    let b:composer_root = fnamemodify(candidates[0], ':p:h')
    return 1
  endif
endfunction

" }}}
" Initialization {{{

augroup composer_detect
  autocmd!
  " Project detection
  autocmd BufNewFile,BufReadPost *
        \ if s:composer_detect(expand("<afile>:p")) && empty(&filetype) |
        \   call composer#buffer_setup() |
        \ endif
  autocmd VimEnter *
        \ if empty(expand("<amatch>")) && s:composer_detect(getcwd()) |
        \   call composer#buffer_setup() |
        \ endif
  autocmd FileType * if s:composer_detect() | call composer#buffer_setup() | endif
  autocmd BufNewFile,BufRead composer.lock setf json
augroup END

" }}}
" Projections {{{

" Ensure that projectionist gets loaded first
if !exists('g:loaded_projectionist')
  runtime! plugin/projectionist.vim
endif

function! s:projectionist_detect()
  if s:composer_detect(get(g:, 'projectionist_file', ''))
    let dispatch = join([composer#project().makeprg(), 'dump-autoload'])

    call projectionist#append(b:composer_root, {
          \ "*": {
          \   "dispatch": dispatch,
          \ },
          \ "composer.json": {
          \   "type": "composer",
          \   "alternate": "composer.lock",
          \ },
          \ "composer.lock": {
          \   "type": "composerlock",
          \   "alternate": "composer.json",
          \ }})
  endif
endfunction

augroup composer_projections
  autocmd!
  autocmd User ProjectionistDetect call s:projectionist_detect()
augroup END

" }}}

" vim: fdm=marker:sw=2:sts=2:et
