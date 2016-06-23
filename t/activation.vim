" t/activation.vim - Activation tests
" Maintainer: Noah Frederick

let g:fixtures = fnamemodify('t/fixtures/', ':p')

runtime plugin/composer.vim

augroup composer_test
  autocmd!
  autocmd User Composer let b:did_autocommand = 1
augroup END

describe 's:composer_detect()'
  after
    bwipeout!
  end

  context 'in a non-composer project'
    it 'does not set b:composer_root'
      execute 'edit' g:fixtures . 'project-other/index.php'
      Expect exists('b:composer_root') to_be_false
    end
  end

  context 'in the root of a composer project'
    it 'sets b:composer_root'
      execute 'edit' g:fixtures . 'project-composer/index.php'
      Expect exists('b:composer_root') to_be_true
      Expect b:composer_root == g:fixtures . 'project-composer'
    end
  end

  context 'in a nested directory of a composer project'
    it 'sets b:composer_root'
      execute 'edit' g:fixtures . 'project-composer/src/index.php'
      Expect exists('b:composer_root') to_be_true
      Expect b:composer_root == g:fixtures . 'project-composer'
    end
  end
end

describe 'composer#buffer_setup()'
  after
    bwipeout!
  end

  context 'in a non-composer project'
    before
      execute 'edit' g:fixtures . 'project-other/index.php'
    end

    it 'does not define the :Composer command'
      Expect exists(':Composer') != 2
    end

    it 'does not fire user autocommand'
      Expect exists('b:did_autocommand') to_be_false
    end
  end

  context 'in a composer project'
    before
      filetype plugin on
      execute 'edit' g:fixtures . 'project-composer/index.php'
    end

    it 'defines the :Composer command'
      Expect exists(':Composer') == 2
    end

    it 'fires user autocommand'
      Expect exists('b:did_autocommand') to_be_true
    end
  end

  context 'editing a non-PHP file in a composer project'
    before
      execute 'edit' g:fixtures . 'project-composer/foo'
    end

    it 'does not define the :Use command'
      Expect &filetype !=# 'php'
      Expect exists(':Use') == 0
    end

    it 'fires user autocommand'
      Expect exists('b:did_autocommand') to_be_true
    end
  end
end

" vim: fdm=marker:sw=2:sts=2:et
