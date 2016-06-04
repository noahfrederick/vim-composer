" t/completion.vim - Completion tests
" Maintainer: Noah Frederick

let s:fixtures = fnamemodify('t/fixtures/', ':p')
let s:composer_commands = ['global', 'install', 'update', 'suggests', 'remove', 'help', 'run-script']

call vspec#hint({'sid': 'composer#commandline#sid()'})

" Mock s:project().commands() and s:project().json()
let b:composer_root = s:fixtures . 'project-composer/'
let s:project = composer#project(b:composer_root)
call s:project.cache.set('commands', s:composer_commands)
call s:project.cache.set('json', {
      \   'require': {'some/package': '1.0.0'},
      \   'scripts': {
      \     'pre-install-cmd': 'foo',
      \     'custom-command':  'bar',
      \   },
      \ })

describe 's:uniq()'
  it 'returns a list'
    let result = vspec#call('s:uniq', [])
    Expect type(result) == type([])
  end

  it 'removes adjacent duplicates'
    let l = ['a', 'b', 'a', 'a', 'c', 'b', 'b', 'b']
    let result = vspec#call('s:uniq', l)
    Expect result == ['a', 'b', 'a', 'c', 'b']
  end
end

describe 's:filter_completions()'
  it 'returns a list of completions'
    let result = vspec#call('s:filter_completions', [], '')
    Expect type(result) == type([])
  end

  it 'sorts the completions alphabetically'
    let candidates = ['b', 'a', '-a', '-b']
    let result = vspec#call('s:filter_completions', candidates, '')
    Expect index(result, 'a')  < index(result, 'b')
    Expect index(result, '-a') < index(result, '-b')
  end

  it 'sorts non-flags before flags'
    let candidates = ['-a', 'b', '--foo', 'a']
    let result = vspec#call('s:filter_completions', candidates, '')
    Expect index(result, 'a')     < index(result, '-a')
    Expect index(result, 'b')     < index(result, '-a')
    Expect index(result, '--foo') < index(result, '-a')
  end

  it 'removes duplicates'
    let candidates = ['a', 'b', 'a', 'a']
    let result = vspec#call('s:filter_completions', candidates, '')
    Expect result == ['a', 'b']
  end

  it 'filters completions based on ArgLead'
    let candidates = ['global', 'help', 'install', 'update']
    let result = vspec#call('s:filter_completions', candidates, 'he')
    Expect result == ['help']
  end

  it 'falls back to fuzzy matching'
    let candidates = ['global', 'help', 'install', 'update']
    let result = vspec#call('s:filter_completions', candidates, 'hl')
    Expect result == ['help']
  end
end

describe 'composer#commandline#complete()'
  it 'returns a list of completions'
    Expect type(composer#commandline#complete('', '', 0)) == type([])
  end

  context 'with no preceding arguments'
    it 'returns a list containing all commands'
      for cmd in s:composer_commands
        Expect index(composer#commandline#complete('', '', 0), cmd) >= 0
      endfor
    end

    it 'returns a list containing custom commands'
      Expect index(composer#commandline#complete('', '', 0), 'custom-command') >= 0
    end

    it 'returns a list containing global flags'
      Expect index(composer#commandline#complete('', '', 0), '--xml') >= 0
    end

    it 'returns a list excluding subcommand flags'
      Expect index(composer#commandline#complete('', '', 0), '--sort-packages') == -1
    end
  end

  context 'with global argument'
    it 'returns a list containing commands modifyable by global'
      let cmds = composer#commandline#complete('', 'global ', 6)
      Expect index(cmds, 'global') == -1
      Expect index(cmds, 'help') >= 0
      Expect index(cmds, 'install') >= 0
      Expect index(cmds, 'update') >= 0
    end

    it 'returns a list containing global flags'
      Expect index(composer#commandline#complete('', 'global ', 6), '--xml') >= 0
    end

    it 'filters completions based on ArgLead'
      Expect composer#commandline#complete('in', 'global in', 8) == ['install']
    end
  end

  context 'with help argument'
    it 'returns a list containing commands modifyable by help'
      let cmds = composer#commandline#complete('', 'help ', 5)
      Expect index(cmds, 'global') >= 0
      Expect index(cmds, 'help') >= 0
      Expect index(cmds, 'install') >= 0
      Expect index(cmds, 'update') >= 0
    end

    it 'returns a list containing global flags'
      Expect index(composer#commandline#complete('', 'help ', 5), '--xml') >= 0
    end

    it 'filters completions based on ArgLead'
      Expect composer#commandline#complete('in', 'help in', 7) == ['install']
    end
  end

  context 'with run-script argument'
    it 'returns a list containing script events'
      Expect index(composer#commandline#complete('', 'run-script ', 11), 'pre-install-cmd') >= 0
    end

    it 'excludes events with no scripts'
      Expect index(composer#commandline#complete('', 'run-script ', 11), 'post-root-package-install') == -1
    end
  end

  context 'with subcommand argument'
    it 'does not return commands'
      let cmds = composer#commandline#complete('', 'install ', 8)
      Expect index(cmds, 'global') == -1
      Expect index(cmds, 'help') == -1
      Expect index(cmds, 'install') == -1
      Expect index(cmds, 'update') == -1
    end

    it 'returns a list containing global flags'
      Expect index(composer#commandline#complete('', 'install ', 8), '--xml') >= 0
      Expect index(composer#commandline#complete('', 'global install ', 15), '--xml') >= 0
    end

    it 'returns a list containing subcommand-specific flags'
      Expect index(composer#commandline#complete('', 'install ', 8), '-o') >= 0
      Expect index(composer#commandline#complete('', 'global install ', 15), '-o') >= 0
    end
  end

  context 'with subcommands that take a required package as argument'
    it 'returns a list containing required packages'
      Expect index(composer#commandline#complete('', 'remove ', 7), 'some/package') >= 0
      Expect index(composer#commandline#complete('', 'update ', 7), 'some/package') >= 0
      Expect index(composer#commandline#complete('', 'suggests ', 9), 'some/package') >= 0
      Expect index(composer#commandline#complete('', 'help ', 5), 'some/package') == -1
      Expect index(composer#commandline#complete('', 'help remove ', 12), 'some/package') == -1
    end
  end
end

" vim: fdm=marker:sw=2:sts=2:et
