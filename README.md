# vim-composer

Vim support for [Composer PHP][composer] projects.

[![Build Status][buildimg]](https://travis-ci.org/noahfrederick/vim-composer)
[![Release][release]](https://github.com/noahfrederick/vim-composer/releases)

*Note: this is a prerelease version, which may change or break frequently.*

[composer]: https://getcomposer.org/
[buildimg]: https://img.shields.io/travis/noahfrederick/vim-composer/master.svg
[release]:  https://img.shields.io/github/tag/noahfrederick/vim-composer.svg?maxAge=2592000

## Features

Composer.vim provides conveniences for working with Composer PHP projects.
Some features include:

* `:Composer` command wrapper around `composer` with smart completion
* Navigate to source files using Composer's autoloader
* Insert `use` statement for the class/interface/trait under cursor
* [Projectionist][projectionist] support (e.g., `:Ecomposer` to edit your
  `composer.json`, `:A` to jump to `composer.lock` and back)
* [Dispatch][dispatch] support (`:Dispatch` runs `composer install`)

See `:help composer` for details.

## Installation

Composer.vim depends on [Projectionist.vim][projectionist]:

	Plug 'tpope/vim-projectionist'
	Plug 'noahfrederick/vim-composer'

## Credits and License

Thanks to Tim Pope for [Bundler.vim][bundler], which Composer.vim is modeled
after.

Copyright © Noah Frederick. Distributed under the same terms as Vim itself.
See `:help license`.

[projectionist]: https://github.com/tpope/vim-projectionist
[dispatch]: https://github.com/tpope/vim-dispatch
[bundler]: https://github.com/tpope/vim-bundler
