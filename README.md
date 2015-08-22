# vim-composer

Vim support for [Composer PHP][composer] projects.

[![Build Status][buildimg]](https://travis-ci.org/noahfrederick/vim-composer)

*Note: this is a prerelease version, which may change or break frequently.*

[composer]: https://getcomposer.org/
[buildimg]: https://img.shields.io/travis/noahfrederick/vim-composer/master.svg

## Features

Composer.vim provides conveniences for working with Composer PHP projects.
Some features include:

* `:Composer` command wrapper around `composer` with smart completion
* Projectionist support (e.g., `:Ecomposer` to edit your `composer.json`, `:A`
  to jump to `composer.lock` and back)
* Dispatch support (`:Dispatch` runs `composer install`)

See `:help composer` for details.

## Installation

Composer.vim depends on [Projectionist.vim][projectionist] and has an optional
dependency on [Dispatch.vim][dispatch] for asynchronous execution of Composer
commands.

	Plug 'tpope/vim-dispatch'
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
