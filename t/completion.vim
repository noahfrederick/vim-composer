" t/completion.vim - Completion tests
" Maintainer: Noah Frederick

let g:composer_commands = ['install', 'update', 'help']

describe 'composer#complete()'
  it 'returns a list of completions'
    Expect type(composer#complete('', '', '')) == type([])
  end

  it 'returns a list containing commands'
    for cmd in g:composer_commands
      Expect index(composer#complete('', '', ''), cmd) >= 0
    endfor
  end

  it 'returns a list containing global flags'
    Expect index(composer#complete('', '', ''), '--xml') >= 0
  end

  it 'filters completions based on ArgLead'
    Expect composer#complete('he', '', '') == ['help']
  end
end

" vim: fdm=marker:sw=2:sts=2:et
