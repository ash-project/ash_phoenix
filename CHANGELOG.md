# Change Log

All notable changes to this project will be documented in this file.
See [Conventional Commits](Https://conventionalcommits.org) for commit guidelines.

<!-- changelog -->

## [v0.7.2-rc.0](https://github.com/ash-project/ash_phoenix/compare/v0.7.1...v0.7.2-rc.0) (2022-05-17)




### Bug Fixes:

* validate after adding/removing forms

* don't remove a form unless one exists

* raise error on non-existant resource for api

* respect touched forms in params generation (#37)

* explicitly set `as` and `id` in matched form

* sequence manually matched forms

### Improvements:

* add `produce` option to `params`

## [v0.7.1](https://github.com/ash-project/ash_phoenix/compare/v0.7.0...v0.7.1) (2022-05-09)




### Bug Fixes:

* synthetically cast attributes in read forms

* raise explicitly on non-existent action

* bad key access in `keep_live`

* show hidden fields for read actions

* add pkey ids as params when creating read forms from data

* track data properly for reads generated from data

* handle read_actions with data

* fetch data for read_actions as well

### Improvements:

* remove more managed relationship context

* set a _form error field

* removed source changesets as they are gone from ash

* add destroy_action/destroy_resource for forms

* fix & clarify logic in do_decode_path/4 (#35)

* handle nil paths in do_decode_path/4 (#34)

* use Map.get instead of direct key access (#33)

* support `data` option on `add_form`

* add `after_fetch` option to keep_live

## [v0.7.0](https://github.com/ash-project/ash_phoenix/compare/v0.6.0-rc.7...v0.7.0) (2022-03-17)




## [v0.6.0-rc.7](https://github.com/ash-project/ash_phoenix/compare/v0.6.0-rc.6...v0.6.0-rc.7) (2022-02-17)




### Bug Fixes:

* don't create forms unnecessarily

## [v0.6.0-rc.6](https://github.com/ash-project/ash_phoenix/compare/v0.6.0-rc.5...v0.6.0-rc.6) (2022-01-18)




### Bug Fixes:

* properly restrict errors to the current form

* Fix logic for change detection of boolean defaults (#31)

* check for operators first

* properly set nested names

* allow the `as` option to be set

* properly set params on validate

### Improvements:

* don't return ids by default

* better default name, just use ids elsewhere

## [v0.6.0-rc.5](https://github.com/ash-project/ash_phoenix/compare/v0.6.0-rc.4...v0.6.0-rc.5) (2021-12-06)




### Bug Fixes:

* set proper form ids and names

* support only predicate in params

## [v0.6.0-rc.4](https://github.com/ash-project/ash_phoenix/compare/v0.6.0-rc.3...v0.6.0-rc.4) (2021-12-02)




### Improvements:

* `to_filter` -> `to_filter_expression`

## [v0.6.0-rc.3](https://github.com/ash-project/ash_phoenix/compare/v0.6.0-rc.2...v0.6.0-rc.3) (2021-12-02)




### Bug Fixes:

* don't make operators externally, only `%Call{}` structs

## [v0.6.0-rc.2](https://github.com/ash-project/ash_phoenix/compare/v0.6.0-rc.1...v0.6.0-rc.2) (2021-12-02)




### Improvements:

* better sanitized parameters

* add params_for_query

## [v0.6.0-rc.1](https://github.com/ash-project/ash_phoenix/compare/v0.6.0-rc.0...v0.6.0-rc.1) (2021-12-02)




### Improvements:

* expose paths for filters

* simple error handling patterns for filter forms

## [v0.6.0-rc.0](https://github.com/ash-project/ash_phoenix/compare/v0.5.19-rc.2...v0.6.0-rc.0) (2021-12-01)




### Features:

* new `FilterForm` for building forms to produce `Ash.Filter`s

## [v0.5.19-rc.2](https://github.com/ash-project/ash_phoenix/compare/v0.5.19-rc.1...v0.5.19-rc.2) (2021-11-13)




### Bug Fixes:

* typo on checking if errors are set to the same value as before

* pass matcher in correct argument position

### Improvements:

* support custom matcher experimental

## [v0.5.19-rc.1](https://github.com/ash-project/ash_phoenix/compare/v0.5.19-rc.0...v0.5.19-rc.1) (2021-11-08)




### Improvements:

* don't rebuild a form when params haven't changed

## [v0.5.19-rc.0](https://github.com/ash-project/ash_phoenix/compare/v0.5.18...v0.5.19-rc.0) (2021-11-08)




### Improvements:

* use existing forms on `validate`, instead of rebuilding

## [v0.5.18](https://github.com/ash-project/ash_phoenix/compare/v0.5.17...v0.5.18) (2021-11-06)




### Improvements:

* enrich but also simplify `changed?` behavior

## [v0.5.17](https://github.com/ash-project/ash_phoenix/compare/v0.5.16...v0.5.17) (2021-11-06)




### Improvements:

* add a `.changed?` field

## [v0.5.16](https://github.com/ash-project/ash_phoenix/compare/v0.5.15...v0.5.16) (2021-10-21)




### Bug Fixes:

* fix some error transforming logic

* forms now receive an error if no nested path matches the error path

## [v0.5.15](https://github.com/ash-project/ash_phoenix/compare/v0.5.14...v0.5.15) (2021-09-30)




### Bug Fixes:

* ensure `transform_errors` is never unset

### Improvements:

* always pass errors to `transform_errors/2`

* improve typespec on errors/2 (#27)

* Allow Phoenix 1.6.0 (#25)

## [v0.5.14](https://github.com/ash-project/ash_phoenix/compare/v0.5.13...v0.5.14) (2021-09-15)




### Bug Fixes:

* only include primary key's in hidden

* don't show hidden primary keys

* don't add forms for remaining data

### Improvements:

* work on LiveView being available for regular sockets

## [v0.5.13](https://github.com/ash-project/ash_phoenix/compare/v0.5.12...v0.5.13) (2021-09-06)




### Bug Fixes:

* don't guess on data matches w/ `sparse?: true`

## [v0.5.12](https://github.com/ash-project/ash_phoenix/compare/v0.5.11...v0.5.12) (2021-09-06)




### Bug Fixes:

* handle forms for to_one relationships with data better

## [v0.5.11](https://github.com/ash-project/ash_phoenix/compare/v0.5.10...v0.5.11) (2021-09-01)




### Bug Fixes:

* don't allow embeds to be sparse

* remove sparse lists

* don't fallback to list with index sort

* only access `params["_touched"]` w/ map params

* don't check params in `get_changing_value/2`

* don't check params for attributes/arguments in `input_value/2`

### Improvements:

* add phoenix_html 3.x to allowed deps (#24)

* experimental `Form.params` options

* add `hidden` option to params

* implement error protocol for invalid relationship

* undo some data tracking changes that didn't work

* continue improving sparse forms

* more work on sparse forms

* track touched forms for saner removal cases

* add `sparse?` option for list forms

* add auto options, including sparse forms and relationship_fetcher

## [v0.5.10](https://github.com/ash-project/ash_phoenix/compare/v0.5.9...v0.5.10) (2021-08-11)




### Bug Fixes:

* if data was nilled, don't make a form with it

* attempt to fix data removal for to_one relationships

### Improvements:

* customize relationship fetcher (experimental)

## [v0.5.9](https://github.com/ash-project/ash_phoenix/compare/v0.5.8...v0.5.9) (2021-08-05)




### Bug Fixes:

* don't return NotLoaded from input_value

### Improvements:

* add `Form.value/2`

## [v0.5.8](https://github.com/ash-project/ash_phoenix/compare/v0.5.7...v0.5.8) (2021-08-01)




### Improvements:

* retain original data for form submission

* update to latest ash

## [v0.5.7](https://github.com/ash-project/ash_phoenix/compare/v0.5.6...v0.5.7) (2021-07-23)




### Bug Fixes:

* fix type signature of `Form.errors/2`

## [v0.5.6](https://github.com/ash-project/ash_phoenix/compare/v0.5.5...v0.5.6) (2021-07-23)




### Improvements:

* looser ash version requirement

* add `Form.errors/2`, deprecate `Form.errors_for/3`

## [v0.5.5](https://github.com/ash-project/ash_phoenix/compare/v0.5.4...v0.5.5) (2021-07-21)




### Bug Fixes:

* don't consider `www.` as part of the host

## [v0.5.4](https://github.com/ash-project/ash_phoenix/compare/v0.5.3...v0.5.4) (2021-07-20)




### Bug Fixes:

* track data modifications and execute them again

## [v0.5.3](https://github.com/ash-project/ash_phoenix/compare/v0.5.2...v0.5.3) (2021-07-20)




### Bug Fixes:

* only prepend to data when necessary

* Fix remove form path when a nested single (#19)

* Add form to single (#18)

* actually reindex this time

* reindex after remove form

### Improvements:

* Improve error message when incorrect api configured for resource (#15)

## [v0.5.2](https://github.com/ash-project/ash_phoenix/compare/v0.5.1...v0.5.2) (2021-07-19)




### Bug Fixes:

* Fix nested form naming (#14)

## [v0.5.1](https://github.com/ash-project/ash_phoenix/compare/v0.5.0...v0.5.1) (2021-07-18)




### Bug Fixes:

* set form aliases properly

* ensure existing forms is a list before adding

### Improvements:

* move `api` to initial form creation option

## [v0.5.0](https://github.com/ash-project/ash_phoenix/compare/v0.4.24...v0.5.0) (2021-07-18)
### Breaking Changes:

* refactor forms



## [v0.4.24](https://github.com/ash-project/ash_phoenix/compare/v0.4.23-rc.1...v0.4.24) (2021-07-18)




### Bug Fixes:

* Fix default form id when :as provided (#12)

* various auto form fixes

* always pass forms down

* show forms on single

* always List.wrap() forms

* set manage_opts properly

* don't set data unless necessary

* Wrap single items on to_form (#8)

* don't assume an empty map is an indexed map

### Improvements:

* alter behavior of `params` option to submit

* add `set_data/2`

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
