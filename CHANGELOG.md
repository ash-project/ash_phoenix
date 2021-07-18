# Change Log

All notable changes to this project will be documented in this file.
See [Conventional Commits](Https://conventionalcommits.org) for commit guidelines.

<!-- changelog -->

## [v0.4.23-rc.1](https://github.com/ash-project/ash_phoenix/compare/v0.4.23-rc.0...v0.4.23-rc.1) (2021-07-18)




### Bug Fixes:

* various auto form fixes

* always pass forms down

* show forms on single

* always List.wrap() forms

* set manage_opts properly

* don't set data unless necessary

* Wrap single items on to_form (#8)

* don't assume an empty map is an indexed map

### Improvements:

* lots of improvements around errors

* track submission states

* add `AshPhoenix.update_form/3`

* id defaults to name

* add `auto?: true` flag

* update to latest ash

* add destroy error message

* first edition of auto forms

* refactor forms with new data structure `AshPhoenix.Form` (#6)

* add `use_data?` opt to `add_related`

## [v0.4.23-rc.0](https://github.com/ash-project/ash_phoenix/compare/v0.4.23...v0.4.23-rc.0) (2021-07-15)




### Bug Fixes:

* don't assume an empty map is an indexed map

### Improvements:

* refactor forms with new data structure `AshPhoenix.Form` (#6)

* add `use_data?` opt to `add_related`

## [v0.4.23](https://github.com/ash-project/ash_phoenix/compare/v0.4.22-rc2...v0.4.23) (2021-07-02)




### Improvements:

* update to latest ash

## [v0.4.22-rc2](https://github.com/ash-project/ash_phoenix/compare/v0.4.22-rc1...v0.4.22-rc2) (2021-06-24)




## [v0.4.22-rc1](https://github.com/ash-project/ash_phoenix/compare/v0.4.22-rc0...v0.4.22-rc1) (2021-06-24)




### Bug Fixes:

* use new ash type primitives

* map_input_to_list on manage

* understand indexed lists in relationship data

* fix case where "lists" weren't properly added to

## [v0.4.22-rc0](https://github.com/ash-project/ash_phoenix/compare/v0.4.21...v0.4.22-rc0) (2021-06-24)




### Bug Fixes:

* use new ash type primitives

## [v0.4.21](https://github.com/ash-project/ash_phoenix/compare/v0.4.20...v0.4.21) (2021-05-14)




### Bug Fixes:

* use proper input params for embeds

## [v0.4.20](https://github.com/ash-project/ash_phoenix/compare/v0.4.19...v0.4.20) (2021-05-14)


### Regressions:

* Regression in `AshPhoenix.add_to_path/3` https://github.com/ash-project/ash_phoenix/issues/2

### Bug Fixes:

* add removed embeds to hidden fields

### Improvements:

* various improvements to relationship manipulation functions

## [v0.4.19](https://github.com/ash-project/ash_phoenix/compare/v0.4.18...v0.4.19) (2021-05-13)




### Bug Fixes:

* support for to many rels as to_one manipulations

## [v0.4.18](https://github.com/ash-project/ash_phoenix/compare/v0.4.17...v0.4.18) (2021-05-10)




### Improvements:

* track `manage_relationship_source`, as a utility

## [v0.4.17](https://github.com/ash-project/ash_phoenix/compare/v0.4.16...v0.4.17) (2021-05-10)




### Bug Fixes:

* ensure error message is always a string

## [v0.4.16](https://github.com/ash-project/ash_phoenix/compare/v0.4.15...v0.4.16) (2021-04-27)




### Bug Fixes:

* support embeds in relationships

## [v0.4.15](https://github.com/ash-project/ash_phoenix/compare/v0.4.14...v0.4.15) (2021-04-17)




### Bug Fixes:

* remove IO.inspect (facepalm)

## [v0.4.14](https://github.com/ash-project/ash_phoenix/compare/v0.4.13...v0.4.14) (2021-04-17)




### Bug Fixes:

* support proper nested embedded appends

## [v0.4.13](https://github.com/ash-project/ash_phoenix/compare/v0.4.12...v0.4.13) (2021-04-16)




### Improvements:

* add `add_value/4` and `remove_value/3` helpers

## [v0.4.12](https://github.com/ash-project/ash_phoenix/compare/v0.4.11...v0.4.12) (2021-04-14)




### Bug Fixes:

* check for managed relationship before embedded input

## [v0.4.11](https://github.com/ash-project/ash_phoenix/compare/v0.4.10...v0.4.11) (2021-04-06)




### Bug Fixes:

* handle empty error fields

### Improvements:

* support invalid argument errors

## [v0.4.10](https://github.com/ash-project/ash_phoenix/compare/v0.4.9...v0.4.10) (2021-03-30)




### Bug Fixes:

* fix remove from path with indices

* append values to maps properly

## [v0.4.9](https://github.com/ash-project/ash_phoenix/compare/v0.4.8...v0.4.9) (2021-03-28)




### Bug Fixes:

* handle adding to array paths bettter

## [v0.4.8](https://github.com/ash-project/ash_phoenix/compare/v0.4.7...v0.4.8) (2021-03-28)




### Bug Fixes:

* add to path when is a map should be a list

## [v0.4.7](https://github.com/ash-project/ash_phoenix/compare/v0.4.6...v0.4.7) (2021-03-28)




### Bug Fixes:

* fix doubly nested forms and various other issues

### Improvements:

* added various utility functions

## [v0.4.6](https://github.com/ash-project/ash_phoenix/compare/v0.4.5...v0.4.6) (2021-03-25)




### Improvements:

* many fixes around relationship forms

## [v0.4.5](https://github.com/ash-project/ash_phoenix/compare/v0.4.4...v0.4.5) (2021-03-22)




### Bug Fixes:

* transform error order of operations

## [v0.4.4](https://github.com/ash-project/ash_phoenix/compare/v0.4.3...v0.4.4) (2021-03-22)




### Bug Fixes:

* set `impl` correctly

## [v0.4.3](https://github.com/ash-project/ash_phoenix/compare/v0.4.2...v0.4.3) (2021-03-21)




### Improvements:

* improve pagination helpers

* update ash dep

## [v0.4.2](https://github.com/ash-project/ash_phoenix/compare/v0.4.1...v0.4.2) (2021-03-19)




### Improvements:

* readability refactor + additional docs

## [v0.4.1](https://github.com/ash-project/ash_phoenix/compare/v0.4.0...v0.4.1) (2021-03-19)




### Bug Fixes:

* properly set params on related create changeset

## [v0.4.0](https://github.com/ash-project/ash_phoenix/compare/v0.3.2...v0.4.0) (2021-03-19)




### Features:

* add initial support for relationships in `inputs_for`

## [v0.3.2](https://github.com/ash-project/ash_phoenix/compare/v0.3.1...v0.3.2) (2021-03-17)




### Bug Fixes:

* bump ash version

## [v0.3.1](https://github.com/ash-project/ash_phoenix/compare/v0.3.0...v0.3.1) (2021-03-17)




### Improvements:

* remove `value` option

* don't render NotLoaded

## [v0.3.0](https://github.com/ash-project/ash_phoenix/compare/v0.2.3...v0.3.0) (2021-03-05)




### Features:

* support queries as form targets

* new helpers in `AshPhoenix`

### Bug Fixes:

* various fixes

* a whole new error paradigm

* don't assume action is set

### Improvements:

* don't filter errors based on params

* support latest ash version

## [v0.2.3](https://github.com/ash-project/ash_phoenix/compare/v0.2.2...v0.2.3) (2021-02-08)




### Improvements:

* add `params_only` for form helpers

* add `SubdomainPlug`

## [v0.2.2](https://github.com/ash-project/ash_phoenix/compare/v0.2.1...v0.2.2) (2021-01-25)




### Improvements:

* store changeset params in form

## [v0.2.1](https://github.com/ash-project/ash_phoenix/compare/v0.2.0...v0.2.1) (2021-01-24)




### Bug Fixes:

* better error messages

### Improvements:

* support ci_string in html

## [v0.2.0](https://github.com/ash-project/ash_phoenix/compare/v0.1.2...v0.2.0) (2021-01-22)




### Features:

* support arguments in changeset

### Improvements:

* support the latest ash

* support arguments in form_data

## [v0.1.2](https://github.com/ash-project/ash_phoenix/compare/v0.1.1...v0.1.2) (2020-12-28)




### Bug Fixes:

* various improvements

## [v0.1.1](https://github.com/ash-project/ash_phoenix/compare/v0.1.0...v0.1.1) (2020-10-21)




## [v0.1.0](https://github.com/ash-project/ash_phoenix/compare/v0.1.0...v0.1.0) (2020-10-21)




### Features:

* general cleanup, ready for initial release

* init

### Improvements:

* setup project
