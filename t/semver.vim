" t/semver.vim - Semver parsing and comparison tests
" Maintainer: Noah Frederick

describe 'composer#semver#parse()'
  it 'parses the major version'
    Expect composer#semver#parse('1.0.0').major is '1'
    Expect composer#semver#parse('2.0').major is '2'
    Expect composer#semver#parse('3').major is '3'
  end

  it 'parses the minor version'
    Expect composer#semver#parse('1.1.0').minor is '1'
    Expect composer#semver#parse('2.2').minor is '2'
    Expect composer#semver#parse('3').minor is ''
  end

  it 'parses the patch version'
    Expect composer#semver#parse('1.0.1').patch is '1'
    Expect composer#semver#parse('2.0').patch is ''
    Expect composer#semver#parse('3').patch is ''
  end
end

describe 'composer#semver#compare()'
  it 'fails with invalid comparator'
    Expect expr { composer#semver#compare('1.0.1', 'blah', '1.2.0').patch } to_throw 'blah is not a valid comparator'
  end

  it 'compares with =='
    Expect composer#semver#compare('1.0.1', '==', '1.0.1') is v:true
    Expect composer#semver#compare('1.4.1', '==', '1.0.1') is v:false
    Expect composer#semver#compare('1.0', '==', '1.0') is v:true
    Expect composer#semver#compare('1', '==', '1') is v:true
    Expect composer#semver#compare('1', '==', '1.6.0') is v:true
  end

  it 'compares with !='
    Expect composer#semver#compare('1.4.1', '!=', '1.0.1') is v:true
    Expect composer#semver#compare('1.0.1', '!=', '1.0.1') is v:false
  end

  it 'compares with <'
    Expect composer#semver#compare('1.4.1', '<', '2.0.0') is v:true
    Expect composer#semver#compare('3.0.1', '<', '1.0.1') is v:false
    Expect composer#semver#compare('1.0.1', '<', '1.0.1') is v:false
    Expect composer#semver#compare('2.0', '<', '2') is v:false
    Expect composer#semver#compare('2', '<', '2.6.3') is v:false
    Expect composer#semver#compare('2.3.4', '<', '3') is v:true
  end

  it 'compares with <='
    Expect composer#semver#compare('1.4.1', '<=', '1.9.0') is v:true
    Expect composer#semver#compare('2.0.0', '<=', '1.0.1') is v:false
    Expect composer#semver#compare('1.0.1', '<=', '1.0.1') is v:true
  end

  it 'compares with >'
    Expect composer#semver#compare('1.4.1', '>', '1.0.1') is v:true
    Expect composer#semver#compare('1.0.1', '>', '2.0.0') is v:false
    Expect composer#semver#compare('1.0.1', '>', '1.0.1') is v:false
    Expect composer#semver#compare('1.0.1', '>', '1') is v:false
  end

  it 'compares with >='
    Expect composer#semver#compare('1.4.1', '>=', '1.0.1') is v:true
    Expect composer#semver#compare('1.0.1', '>=', '8.0.1') is v:false
    Expect composer#semver#compare('1.0.1', '>=', '1.0.1') is v:true
    Expect composer#semver#compare('1', '>=', '1.6.10') is v:true
  end
end

" vim: fdm=marker:sw=2:sts=2:et
