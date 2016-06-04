" t/utils.vim - Utility function tests
" Maintainer: Noah Frederick

call vspec#hint({'sid': 'composer#sid()'})

describe 's:throw()'
  it 'throws an exeption'
    Expect expr { vspec#call('s:throw', 'foo') } to_throw '^composer: foo$'
  end

  it 'sets v:errmsg'
    Expect expr { vspec#call('s:throw', 'foo') } to_throw '^composer: foo$'
    Expect v:errmsg ==# 'composer: foo'
  end

  it 'formats the message'
    Expect expr { vspec#call('s:throw', '(%s)', 'bar') } to_throw '^composer: (bar)$'
  end
end

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

describe 's:get_nested()'
  let g:dict = { 'foo': 'bar', 'baz': { 'x': 'a', 'y': 'b' } }

  it 'retrieves a key from a dict'
    Expect vspec#call('s:get_nested', g:dict, 'foo') ==# 'bar'
  end

  it 'retrieves a nested key from a dict'
    Expect vspec#call('s:get_nested', g:dict, 'baz.y') ==# 'b'
  end

  it 'returns an empty string'
    Expect vspec#call('s:get_nested', g:dict, 'nonexistent') ==# ''
  end

  it 'returns a default value'
    Expect vspec#call('s:get_nested', g:dict, 'nonexistent', 'z') ==# 'z'
  end
end

" vim: fdm=marker:sw=2:sts=2:et
