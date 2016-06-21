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
    2put = 'use Foo;'
    4put = 'use Foo\Bar as Baz;'
    5put = 'use Biz\Wiz as Bar;'
    6put = 'use Foo\Zoo\Woo;'
    7put = 'use Boo, Coo;'
    8put = 'use Doo,'
    9put = '    Goo;'
    10put = '// end'
  end

  after
    bwipeout!
  end

  context 'when there is a matching use statement with as'
    it 'matches the as'
      Expect composer#namespace#using('Bar') ==# 'Biz\Wiz'
    end

    it 'does not match the non-aliased name'
      Expect composer#namespace#using('Foo\Bar') ==# ''
    end

    it 'matches the non-aliased name with second arg'
      Expect composer#namespace#using('Foo\Bar', 1) ==# 'Foo\Bar'
    end
  end

  context 'when there is a matching use statement without as'
    it 'matches a use'
      Expect composer#namespace#using('Foo') ==# 'Foo'
      Expect composer#namespace#using('Woo') ==# 'Foo\Zoo\Woo'
    end

    it 'matches a qualified name'
      Expect composer#namespace#using('Foo\Zoo\Woo') ==# 'Foo\Zoo\Woo'
    end
  end

  context 'when there is a use statement with multiple arguments'
    it 'matches the right argument'
      Expect composer#namespace#using('Boo') ==# 'Boo'
      Expect composer#namespace#using('Coo') ==# 'Coo'
    end
  end

  context 'when there is no matching use statement'
    it 'returns an empty string'
      Expect composer#namespace#using('Xxx') ==# ''
    end
  end

  it 'handles multi-line use statements'
    Expect composer#namespace#using('Doo') ==# 'Doo'
    Expect composer#namespace#using('Goo') ==# 'Goo'
  end
end

describe 'composer#namespace#use()'
  describe 'basic usage'
    before
      enew
      setf php
      0put = '<?php'
      1put = ''
      2put = 'namespace Foo;'
      3put = ''
      4put = 'use Bar;'
      5put = '// end'
    end

    after
      bwipeout!
    end

    context 'given a fully-qualified name'
      it 'inserts it verbatim'
        call composer#namespace#use(0, '\Baz')
        Expect line('$') == 8
        Expect search('^use Baz;$', 'cw') > 0
      end
    end

    context 'given an unqualified name'
      it 'expands the name'
        call composer#namespace#use(0, 'Baz')
        Expect line('$') == 8
        Expect search('^use Foo\\Baz;$', 'cw') > 0
      end
    end

    context 'given an alias'
      it 'include an as'
        call composer#namespace#use(0, '\Baz', 'Fiz')
        Expect line('$') == 8
        Expect search('^use Baz as Fiz;$', 'cw') > 0
      end
    end

    context 'when there is already a matching use statement'
      it 'does nothing without an alias'
        call composer#namespace#use(0, 'Bar')
        Expect line('$') == 7
        call composer#namespace#use(0, '\Bar')
        Expect line('$') == 7
      end

      it 'inserts a new use statement with an alias'
        call composer#namespace#use(0, '\Bar', 'Fiz')
        Expect line('$') == 8
        Expect search('^use Bar as Fiz;$', 'cw') > 0
      end
    end
  end

  describe 'placement'
    after
      bwipeout!
    end

    context 'in a buffer with existing use statements'
      before
        enew
        setf php
        0put = '<?php'
        1put = ''
        2put = 'namespace Foo;'
        3put = ''
        4put = 'use Bar;'
        5put = 'use Baz;'
        6put = '// end'
      end

      it 'inserts after all use statements'
        call composer#namespace#use(0, '\Foo')
        Expect getline(7) ==# 'use Foo;'
        Expect getline(8) ==# '// end'
      end
    end

    context 'in a buffer with only a namespace declaration'
      before
        enew
        setf php
        0put = '<?php'
        1put = ''
        2put = 'namespace Foo;'
        3put = '// end'
      end

      it 'inserts after the namespace and a blank line'
        call composer#namespace#use(0, '\Foo')
        Expect getline(4) ==# ''
        Expect getline(5) ==# 'use Foo;'
        Expect getline(6) ==# '// end'
      end
    end

    context 'in a buffer with a namespace declaration on the first line'
      before
        enew
        setf php
        0put = '<?php namespace Foo;'
        1put = ''
        2put = '// end'
      end

      it 'inserts after the namespace and a blank line'
        " Note: this works because it falls back to searching for the opening
        " PHP tag.
        call composer#namespace#use(0, '\Foo')
        Expect getline(2) ==# ''
        Expect getline(3) ==# 'use Foo;'
        Expect getline(4) ==# ''
        Expect getline(5) ==# '// end'
      end
    end

    context 'in a buffer with no use statements and no namespace'
      before
        enew
        setf php
        0put = '<?php'
        1put = ''
        2put = '// end'
      end

      it 'inserts after the opening tag and a blank line'
        call composer#namespace#use(0, '\Foo')
        Expect getline(2) ==# ''
        Expect getline(3) ==# 'use Foo;'
        Expect getline(4) ==# ''
        Expect getline(5) ==# '// end'
      end
    end

    context 'in a buffer with no use statements, namespace, or opening tag'
      before
        enew
        setf php
        0put = '// end'
      end

      it 'inserts on the first line'
        call composer#namespace#use(0, '\Foo')
        Expect getline(1) ==# 'use Foo;'
        Expect getline(2) ==# '// end'
      end
    end
  end
end

describe 'composer#namespace#sort_uses()'
  before
    enew
    setf php
    0put  = '<?php'
    1put  = ''
    2put  = 'use Foo;'
    4put  = 'use Foo\Bar as Baz;'
    5put  = 'use Biz\Wiz as Bar;'
    6put  = 'use Foo\Zoo\Woo;'
    7put  = 'use Boo, Coo;'
    8put  = 'use Doo,'
    9put  = '    Goo,'
    10put = '    Hoo;'
    11put = ''
    12put = 'class MyClass {'
    13put = '    use Trait;'
    14put = '}'
    15put = '// end'
  end

  after
    bwipeout!
  end

  it 'sorts all use statements in buffer'
    call composer#namespace#sort_uses()
    Expect getline(1) ==# '<?php'
    Expect getline(2) ==# ''
    Expect getline(3) ==# 'use Biz\Wiz as Bar;'
    Expect getline(4) ==# 'use Boo, Coo;'
    Expect getline(5) ==# 'use Doo, Goo, Hoo;'
    Expect getline(6) ==# 'use Foo;'
    Expect getline(7) ==# 'use Foo\Bar as Baz;'
    Expect getline(8) ==# 'use Foo\Zoo\Woo;'
    Expect getline(9) ==# ''
    Expect getline(10) ==# ''
    Expect getline(11) ==# 'class MyClass {'
    Expect getline(12) ==# '    use Trait;'
    Expect getline(13) ==# '}'
    Expect getline(14) ==# '// end'
  end
end

describe 's:class_at_cursor()'
  before
    enew
    setf php
    0put  = '<?php'
    1put  = ''
    2put  = 'use Foo;'
    3put  = 'use Foo\Bar as Baz;'
    4put  = ''
    5put  = 'class MyClass extends \ThatClass {'
    6put  = '    use SomeTrait;'
    7put  = '    public function fooBar($car) {'
    8put  = '        return new \Zoo\War\Far($car);'
    9put  = '    }'
    10put = '}'
    11put = '// end'
    1
  end

  after
    bwipeout!
  end

  it 'does not move the cursor'
    normal! 4GfB
    call vspec#call('s:class_at_cursor')
    Expect line('.') == 4
    Expect col('.') == 9
  end

  it 'returns empty string when no name is at cursor'
    normal! 3G
    let result = vspec#call('s:class_at_cursor')
    Expect result ==# ''
  end

  it 'does not match inside a non-class name'
    normal! 8GfB
    let result = vspec#call('s:class_at_cursor')
    Expect result ==# ''
  end

  it 'returns a simple class name'
    normal! 3GfF
    let result = vspec#call('s:class_at_cursor')
    Expect result ==# 'Foo'
  end

  it 'returns a qualified class name'
    normal! 4GfF
    let result = vspec#call('s:class_at_cursor')
    Expect result ==# 'Foo\Bar'
  end

  it 'returns a qualified class name when at the middle'
    normal! 4GfB
    let result = vspec#call('s:class_at_cursor')
    Expect result ==# 'Foo\Bar'
  end

  it 'returns a qualified class name when at the end'
    normal! 4Gfr
    let result = vspec#call('s:class_at_cursor')
    Expect result ==# 'Foo\Bar'
  end

  it 'returns a complex qualified class name'
    normal! 9GfZ
    let result = vspec#call('s:class_at_cursor')
    Expect result ==# '\Zoo\War\Far'
  end
end

" vim: fdm=marker:sw=2:sts=2:et
