" t/namespace.vim - Namespacing and use statement tests
" Maintainer: Noah Frederick

call vspec#hint({'sid': 'composer#namespace#sid()'})

describe 's:capture'
  before
    enew
    0put = 'foo;'
    1put = 'bar;'
    2put = 'baz;'
  end

  after
    bwipeout!
  end

  it 'searches for a string and returns a given submatch'
    Expect vspec#call('s:capture', '\(foo\)\(;\)', 1) ==# 'foo'
    Expect vspec#call('s:capture', '\(foo\)\(;\)', 2) ==# ';'
  end

  it 'returns 0 in case of no match'
    Expect vspec#call('s:capture', '\(zoo\);', 1) is 0
  end

  it 'searches across lines'
    Expect vspec#call('s:capture', '\(bar\);\nbaz', 1) ==# 'bar'
  end
end

describe 'composer#namespace#expand()'
  before
    enew
    setf php
    0put = '<?php'
    1put = ''
    2put = 'namespace Foo;'
    3put = '// end'
  end

  after
    bwipeout!
  end

  context 'given a fully-qualified class name'
    it 'returns its argument'
      Expect composer#namespace#expand('\Bar') ==# '\Bar'
      Expect composer#namespace#expand('\Foo\Bar') ==# '\Foo\Bar'
    end
  end

  context 'given an unqualified class name'
    it 'resolves the namespace from the namespace statement'
      Expect composer#namespace#expand('Bar') ==# '\Foo\Bar'
    end
  end
end

describe 'composer#namespace#using()'
  before
    enew
    setf php
    0put = '<?php'
    1put = ''
    2put = 'use \Foo;'
    4put = 'use \Foo\Bar as Baz;'
    5put = 'use \Biz\Wiz as Bar;'
    6put = 'use \Foo\Zoo\Woo;'
    7put = 'use \Boo, \Coo;'
    8put = 'use \Doo,'
    9put = '    \Goo;'
    10put = '// end'
  end

  after
    bwipeout!
  end

  context 'when there is a matching use statement with as'
    it 'matches the as'
      Expect composer#namespace#using('Bar') ==# '\Biz\Wiz'
    end
  end

  context 'when there is a matching use statement without as'
    it 'matches a use'
      Expect composer#namespace#using('Foo') ==# '\Foo'
      Expect composer#namespace#using('Woo') ==# '\Foo\Zoo\Woo'
    end
  end

  context 'when there is a use statement with multiple arguments'
    it 'matches the right argument'
      Expect composer#namespace#using('Boo') ==# '\Boo'
      Expect composer#namespace#using('Coo') ==# '\Coo'
    end
  end

  context 'when there is no matching use statement'
    it 'returns an empty string'
      Expect composer#namespace#using('Xxx') ==# ''
    end
  end

  it 'handles multi-line use statements'
    Expect composer#namespace#using('Doo') ==# '\Doo'
    Expect composer#namespace#using('Goo') ==# '\Goo'
  end
end

" vim: fdm=marker:sw=2:sts=2:et
