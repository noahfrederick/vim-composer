" t/completion.vim - Completion tests
" Maintainer: Noah Frederick

let g:composer_commands = ['install', 'update', 'help']

describe 'composer#complete'
  it 'returns a list of completions'
    Expect type(composer#complete('', '', '')) == type([])
  end

  it 'returns a list of commands'
    Expect composer#complete('', '', '') == g:composer_commands
  end
end

" vim: fdm=marker:sw=2:sts=2:et
