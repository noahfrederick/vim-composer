" t/project.vim - Project methods tests
" Maintainer: Noah Frederick

let g:fixtures = fnamemodify('t/fixtures/', ':p')

call vspec#hint({'sid': 'composer#sid()'})

runtime plugin/composer.vim

describe 'composer#project()'
  after
    bwipeout!
  end

  context 'in a non-composer project'
    before
      execute 'edit' g:fixtures . 'project-other/index.php'
      let b:project = composer#project()
    end

    it 'returns an empty dict'
      Expect has_key(b:project, '_root') to_be_false
    end
  end

  context 'in a composer project'
    before
      execute 'edit' g:fixtures . 'project-composer/index.php'
      let b:project = composer#project()
    end

    it 'returns a project object'
      Expect has_key(b:project, '_root') to_be_true
    end

    context 's:project_path()'
      it 'returns path to project root'
        Expect b:project.path() ==# g:fixtures . 'project-composer'
      end

      it 'appends the supplied argument to the project root'
        Expect b:project.path('foo') ==# g:fixtures . 'project-composer/foo'
      end
    end

    context 's:project_makeprg()'
      it 'returns the composer executable name'
        Expect b:project.makeprg() ==# 'composer'
      end
    end
  end

  context 'in a composer project with composer.phar'
    before
      execute 'edit' g:fixtures . 'project-phar/index.php'
      let b:project = composer#project()
    end

    context 's:project_makeprg()'
      it 'returns the composer executable name'
        Expect b:project.makeprg() ==# 'php composer.phar'
      end
    end
  end
end

describe 's:project()'
  after
    bwipeout!
  end

  context 'in a non-composer project'
    before
      execute 'edit' g:fixtures . 'project-other/index.php'
    end

    it 'throws an error'
      Expect expr { vspec#call('s:project') } to_throw '^composer: \(.*\) does not belong to a composer project$'
    end
  end

  context 'in a composer project'
    before
      execute 'edit' g:fixtures . 'project-composer/index.php'
    end

    it 'does not throw an error'
      Expect expr { vspec#call('s:project') } not to_throw '^composer:'
    end

    it 'returns a project object'
      Expect has_key(vspec#call('s:project'), '_root') to_be_true
    end
  end
end

" vim: fdm=marker:sw=2:sts=2:et
