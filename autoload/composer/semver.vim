" autoload/composer/semver.vim - Semver parsing and comparison
" Maintainer: Noah Frederick

""
" @private
" Parse semver version string into object.
function! composer#semver#parse(version_string) abort
  let semver = {}
  let parts = matchlist(a:version_string, '\v^(\d+)%(.(\d+)%(.(\d+))?)?')

  let semver.major = get(parts, 1, '')
  let semver.minor = get(parts, 2, '')
  let semver.patch = get(parts, 3, '')

  return semver
endfunction

""
" @private
" Compare semver version strings.
function! composer#semver#compare(a, comparator, b) abort
  if !has_key(s:comparators, a:comparator)
    echoerr 'Composer semver: ' . a:comparator . ' is not a valid comparator'
    return v:false
  endif

  let a = composer#semver#parse(a:a)
  let b = composer#semver#parse(a:b)

  if funcref(s:comparators[a:comparator], [a, b])() is v:false
    return v:false
  endif

  return v:true
endfunction

let s:comparators = {
      \   '==': 's:is_equal',
      \   '!=': 's:is_not_equal',
      \   '>':  's:is_greater_than',
      \   '>=': 's:is_greater_than_or_equal',
      \   '<':  's:is_less_than',
      \   '<=': 's:is_less_than_or_equal',
      \ }

function! s:is_equal(a, b) abort
  if a:a.major != a:b.major
    return v:false
  endif

  if empty(a:a.minor) || empty(a:b.minor)
    return v:true
  endif

  if a:a.minor != a:b.minor
    return v:false
  endif

  if empty(a:a.patch) || empty(a:b.patch)
    return v:true
  endif

  if a:a.patch != a:b.patch
    return v:false
  endif

  return v:true
endfunction

function! s:is_not_equal(a, b) abort
  return s:is_equal(a:a, a:b) ? v:false : v:true
endfunction

function! s:is_greater_than(a, b) abort
  if s:is_equal(a:a, a:b)
    return v:false
  endif

  if a:a.major > a:b.major
    return v:true
  elseif a:a.major == a:b.major
    if a:a.minor > a:b.minor
      return v:true
    elseif a:a.minor == a:b.minor
      return a:a.patch > a:b.patch
    endif
  endif

  return v:false
endfunction

function! s:is_less_than(a, b) abort
  return ((s:is_greater_than(a:a, a:b) || s:is_equal(a:a, a:b))) ? v:false : v:true
endfunction

function! s:is_greater_than_or_equal(a, b)
  return ((s:is_greater_than(a:a, a:b) || s:is_equal(a:a, a:b))) ? v:true : v:false
endfunction

function! s:is_less_than_or_equal(a, b)
  return ((s:is_less_than(a:a, a:b) || s:is_equal(a:a, a:b))) ? v:true : v:false
endfunction

" vim: fdm=marker:sw=2:sts=2:et
