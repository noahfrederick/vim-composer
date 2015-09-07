" t/completion.vim - Completion tests
" Maintainer: Noah Frederick

let s:fixtures = fnamemodify('t/fixtures/', ':p')
let s:composer_commands = ['global', 'install', 'update', 'suggests', 'remove', 'help']

call vspec#hint({'sid': 'composer#sid()'})

" Mock s:project().commands() and s:project().json()
let b:composer_root = s:fixtures . 'project-composer/'
let s:project = composer#project(b:composer_root)
let s:project._commands = {'_': s:composer_commands}
let s:project._json = {'require': {'some/package': '1.0.0'}}

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

  it 'sorts commands before flags'
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
end

describe 'composer#complete()'
  it 'returns a list of completions'
    Expect type(composer#complete('', '', 0)) == type([])
  end

  context 'with no preceding arguments'
    it 'returns a list containing all commands'
      for cmd in s:composer_commands
        Expect index(composer#complete('', '', 0), cmd) >= 0
      endfor
    end

    it 'returns a list containing global flags'
      Expect index(composer#complete('', '', 0), '--xml') >= 0
    end

    it 'returns a list excluding subcommand flags'
      Expect index(composer#complete('', '', 0), '--sort-packages') == -1
    end
  end

  context 'with global argument'
    it 'returns a list containing commands modifyable by global'
      let cmds = composer#complete('', 'global ', 6)
      Expect index(cmds, 'global') == -1
      Expect index(cmds, 'help') >= 0
      Expect index(cmds, 'install') >= 0
      Expect index(cmds, 'update') >= 0
    end

    it 'returns a list containing global flags'
      Expect index(composer#complete('', 'global ', 6), '--xml') >= 0
    end

    it 'filters completions based on ArgLead'
      Expect composer#complete('in', 'global in', 8) == ['install']
    end
  end

  context 'with help argument'
    it 'returns a list containing commands modifyable by help'
      let cmds = composer#complete('', 'help ', 5)
      Expect index(cmds, 'global') >= 0
      Expect index(cmds, 'help') >= 0
      Expect index(cmds, 'install') >= 0
      Expect index(cmds, 'update') >= 0
    end

    it 'returns a list containing global flags'
      Expect index(composer#complete('', 'help ', 5), '--xml') >= 0
    end

    it 'filters completions based on ArgLead'
      Expect composer#complete('in', 'help in', 7) == ['install']
    end
  end

  context 'with subcommand argument'
    it 'does not return commands'
      let cmds = composer#complete('', 'install ', 8)
      Expect index(cmds, 'global') == -1
      Expect index(cmds, 'help') == -1
      Expect index(cmds, 'install') == -1
      Expect index(cmds, 'update') == -1
    end

    it 'returns a list containing global flags'
      Expect index(composer#complete('', 'install ', 8), '--xml') >= 0
      Expect index(composer#complete('', 'global install ', 15), '--xml') >= 0
    end

    it 'returns a list containing subcommand-specific flags'
      Expect index(composer#complete('', 'install ', 8), '-o') >= 0
      Expect index(composer#complete('', 'global install ', 15), '-o') >= 0
    end
  end

  context 'with subcommands that take a required package as argument'
    it 'returns a list containing required packages'
      Expect index(composer#complete('', 'remove ', 7), 'some/package') >= 0
      Expect index(composer#complete('', 'update ', 7), 'some/package') >= 0
      Expect index(composer#complete('', 'suggests ', 9), 'some/package') >= 0
      Expect index(composer#complete('', 'help ', 5), 'some/package') == -1
      Expect index(composer#complete('', 'help remove ', 12), 'some/package') == -1
    end
  end
end

" vim: fdm=marker:sw=2:sts=2:et
