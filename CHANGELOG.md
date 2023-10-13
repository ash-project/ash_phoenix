# Change Log

All notable changes to this project will be documented in this file.
See [Conventional Commits](Https://conventionalcommits.org) for commit guidelines.

<!-- changelog -->

## [v1.2.20](https://github.com/ash-project/ash_phoenix/compare/v1.2.19...v1.2.20) (2023-10-13)




### Bug Fixes:

* Generator: Consider Resource.Info.plural_name as the help text promises (#110)

* Fix module name for Show -> Update in generator (#109)

* don't multiply error messages (#107)

* ensure errors are unique in form

* make opts optional on `for_action/3`

## [v1.2.19](https://github.com/ash-project/ash_phoenix/compare/v1.2.18...v1.2.19) (2023-09-27)




### Bug Fixes:

* check for values in changeset params

* properly supply api for context opts

## [v1.2.18](https://github.com/ash-project/ash_phoenix/compare/v1.2.17...v1.2.18) (2023-09-25)




### Bug Fixes:

* undo previous change for `only_touched?` on form submit

* remove stray } from liveview generator (#101)

* honor ash context opts

## [v1.2.17](https://github.com/ash-project/ash_phoenix/compare/v1.2.16...v1.2.17) (2023-09-04)




### Bug Fixes:

* properly track form params for nested unions

* produce type errors for wrapped union values

* support only_touched? on submit as well

* sanitize path for touched only

* remove warning on Map.take

### Improvements:

* support providing an actor

* initial stab at `mix ash.gen.live`

* tests and better behavior for union forms

* initial stab at support for forms against unions

## [v1.2.16](https://github.com/ash-project/ash_phoenix/compare/v1.2.15...v1.2.16) (2023-07-26)




### Bug Fixes:

* handle single types against to many forms

* more fixes for accidentally list form data

### Improvements:

* add support for `target` and `only_touched?` validate opts

## [v1.2.15](https://github.com/ash-project/ash_phoenix/compare/v1.2.14...v1.2.15) (2023-07-12)




### Bug Fixes:

* don't raise on unknown inputs for filters

* fix Logger deprecations for elixir 1.15 (#96)

## [v1.2.14](https://github.com/ash-project/ash_phoenix/compare/v1.2.13...v1.2.14) (2023-05-25)




### Bug Fixes:

* undo incorrect change and apply correct change for `accessing_from`

* use proper `accessing_from` in nested read actions

## [v1.2.13](https://github.com/ash-project/ash_phoenix/compare/v1.2.12...v1.2.13) (2023-04-26)




### Bug Fixes:

* Remove the id field from params_for_query reply (#93)

* better params generation

* don't do constraints in argument casting

### Improvements:

* Add option to not reset on validate (#94)

* set `accessing_from` when making new forms

* set `accessing_from` context on forms

## [v1.2.12](https://github.com/ash-project/ash_phoenix/compare/v1.2.11...v1.2.12) (2023-04-03)




### Bug Fixes:

* form_for deprecation warning (#84)

### Improvements:

* Rename to_filter! (#90)

## [v1.2.11](https://github.com/ash-project/ash_phoenix/compare/v1.2.10...v1.2.11) (2023-03-23)




### Bug Fixes:

* use initial form options on failed submit (#82)

### Improvements:

* support auto? options as `auto?: [...]`

## [v1.2.10](https://github.com/ash-project/ash_phoenix/compare/v1.2.9...v1.2.10) (2023-03-14)




### Bug Fixes:

* properly handle submit results when given phoenix form

## [v1.2.9](https://github.com/ash-project/ash_phoenix/compare/v1.2.8...v1.2.9) (2023-03-09)




### Bug Fixes:

* Patch for new Form Access Protocol (#77)

* Remove line causing errors (#76)

## [v1.2.8](https://github.com/ash-project/ash_phoenix/compare/v1.2.7...v1.2.8) (2023-03-06)




### Improvements:

* return phoenix forms if phoenix forms are given

## [v1.2.7](https://github.com/ash-project/ash_phoenix/compare/v1.2.6...v1.2.7) (2023-03-01)




### Bug Fixes:

* Support LV 0.15 (#73)

## [v1.2.6](https://github.com/ash-project/ash_phoenix/compare/v1.2.5...v1.2.6) (2023-02-15)




## [v1.2.5](https://github.com/ash-project/ash_phoenix/compare/v1.2.4...v1.2.5) (2023-01-28)




### Improvements:

* support latest ash

## [v1.2.4](https://github.com/ash-project/ash_phoenix/compare/v1.2.3...v1.2.4) (2023-01-18)




### Bug Fixes:

* properly clear value in Form.clear_value/2 (#66)

* handle raised errors when comparing values

* ensure that params is always a map in Phoenix.HTML.Form

### Improvements:

* update to new ash docs patterns

* accept multiple fields in `AshPhoenix.Form.clear_value/2` (#67)

* add `to_filter_map/1` to filter_form

## [v1.2.3](https://github.com/ash-project/ash_phoenix/compare/v1.2.2...v1.2.3) (2022-12-21)




### Bug Fixes:

* update to latest ash and resolve warning

### Improvements:

* add `clear_value/1`

* add update_forms_at_path/4` and `touch/2`

* get rid of phoenix compiler

## [v1.2.2](https://github.com/ash-project/ash_phoenix/compare/v1.2.1...v1.2.2) (2022-12-15)




### Bug Fixes:

* small logic bug when setting param value

* transform params before providing them for a field value

### Improvements:

* add `prepare_source` option for seeding changesets

## [v1.2.1](https://github.com/ash-project/ash_phoenix/compare/v1.2.0...v1.2.1) (2022-12-05)




### Improvements:

* add more exceptions to plug exceptions

## [v1.2.0](https://github.com/ash-project/ash_phoenix/compare/v1.1.2...v1.2.0) (2022-11-30)




### Features:

* add custom HTTP status codes for specific types of errors that can be thrown (#62)

## [v1.1.2](https://github.com/ash-project/ash_phoenix/compare/v1.1.1...v1.1.2) (2022-10-31)




### Bug Fixes:

* properly honor `value_is_key` option

## [v1.1.1](https://github.com/ash-project/ash_phoenix/compare/v1.1.0...v1.1.1) (2022-10-28)




### Bug Fixes:

* properly retain sorting of list forms

## [v1.1.0](https://github.com/ash-project/ash_phoenix/compare/v0.7.7...v1.1.0) (2022-10-17)




### Bug Fixes:

* specify `@derive` in proper place

* infinite loop in inspect

### Improvements:

* update to Ash 2.0

## [v1.1.0-rc.3](https://github.com/ash-project/ash_phoenix/compare/v1.1.0-rc.2...v1.1.0-rc.3) (2022-10-10)




### Improvements:

* handle `%Phoenix.HTML.Form{}` inputs in some cases

* require `%AshPhoenix.Form{}` inputs in some cases

* carry over negated on validate for groups

## [v1.1.0-rc.2](https://github.com/ash-project/ash_phoenix/compare/v1.1.0-rc.1...v1.1.0-rc.2) (2022-10-07)




### Bug Fixes:

* populate hidden fields from server-side form by default

* don't sanitize arguments out of predicate form

* change filter form value even if value doesn't match

* select first public attribute as field when remapping path

* update_predicate correctly handles existing predicate

* nested groups have correct form names (#54)

### Improvements:

* support calculation arguments in FilterForm

* clear filter form value when field changes

* add `update` and `destroy` types to `add_form`

## [v1.1.0-rc.1](https://github.com/ash-project/ash_phoenix/compare/v1.1.0-rc.0...v1.1.0-rc.1) (2022-09-28)




### Bug Fixes:

* properly synthesize nested action errors

## [v1.1.0-rc.0](https://github.com/ash-project/ash_phoenix/compare/v1.0.0-rc.1...v1.1.0-rc.0) (2022-09-27)




### Features:

* append predicate path w/ field when relationship (#53)

### Improvements:

* support latest phoenix/surface

* support latest phoenix

## [v1.0.0-rc.1](https://github.com/ash-project/ash_phoenix/compare/v1.0.0-rc.0...v1.0.0-rc.1) (2022-09-21)




### Bug Fixes:

* only impl Phoenix.HTML.Safe if it hasn't already been

* argument mismatch when calling handle_forms (#50)

* call `get_function/3`

### Improvements:

* update to latest ash

* support latest ash

* decimal protocols (#51)

## [v0.7.7](https://github.com/ash-project/ash_phoenix/compare/v0.7.6-rc.0...v0.7.7) (2022-08-22)




### Bug Fixes:

* remove typo from new transform_params logic

* shore up missing cases around transform_params

* mark forms updated with `update_form/4` as touched by default

### Improvements:

* unlock unnecessary deps

* update to latest ash

* support non-map type nested forms

## [v0.7.6-rc.0](https://github.com/ash-project/ash_phoenix/compare/v0.7.5...v0.7.6-rc.0) (2022-08-15)




### Bug Fixes:

* handle errors in form change tracking

## [v0.7.5](https://github.com/ash-project/ash_phoenix/compare/v0.7.4...v0.7.5) (2022-08-13)




### Bug Fixes:

* properly parse string paths in `FilterForm`

* don't stringify form value

### Improvements:

* add `update_predicate/3`

* pass must load opts when building auto forms

## [v0.7.4](https://github.com/ash-project/ash_phoenix/compare/v0.7.3...v0.7.4) (2022-08-10)




### Bug Fixes:

* reuse opts when validating before submit

### Improvements:

* add `merge_options` and `update_options`

## [v0.7.3](https://github.com/ash-project/ash_phoenix/compare/v0.7.2-rc.2...v0.7.3) (2022-08-09)




### Bug Fixes:

* ensure auto forms have unique keys

* always merge join form, add `fields`

* pass `matcher` down in nested validation

* deduplicate form keys

* when validating, use empty starting point for forms

* include forms when !touched_forms

* keep `added?` on validate

* set changed after add and remove form

* handle case where certain actions are not present

* properly call destroy action with changeset

* Fix validate_opts when single form (#44)

* pass error state down to nested forms properly

* ensure list forms are always `[]` after remove_form

* add opts to `for_action` in `add_form`

### Improvements:

* update to latest ash

* fix typespecs on form submit

* warn on unhandled errors by default

* merge _join forms

* add fields list to join form

* helper functions around ignoring forms

* allow forms to be ignored

* trialing treating all form parameters as strings for keys/values

* pass generated form params in when validating

* add `read_one?` option to submit

* track and submit only touched fields by default

* add `set_params` option

* add `filter` option to `params/2`

* add api_opts to submit

* add `validate_opts` to `add/remove_form`

## [v0.7.2-rc.2](https://github.com/ash-project/ash_phoenix/compare/v0.7.2-rc.1...v0.7.2-rc.2) (2022-06-29)




### Bug Fixes:

* include forms when !touched_forms

* keep `added?` on validate

* set changed after add and remove form

* handle case where certain actions are not present

* properly call destroy action with changeset

* Fix validate_opts when single form (#44)

* pass error state down to nested forms properly

* ensure list forms are always `[]` after remove_form

* add opts to `for_action` in `add_form`

### Improvements:

* helper functions around ignoring forms

* allow forms to be ignored

* trialing treating all form parameters as strings for keys/values

* pass generated form params in when validating

* add `read_one?` option to submit

* track and submit only touched fields by default

* add `set_params` option

* add `filter` option to `params/2`

* add api_opts to submit

* add `validate_opts` to `add/remove_form`

## [v0.7.2-rc.1](https://github.com/ash-project/ash_phoenix/compare/v0.7.2-rc.0...v0.7.2-rc.1) (2022-05-23)




### Bug Fixes:

* properly call destroy action with changeset

* Fix validate_opts when single form (#44)

* pass error state down to nested forms properly

* ensure list forms are always `[]` after remove_form

* add opts to `for_action` in `add_form`

### Improvements:

* add `validate_opts` to `add/remove_form`

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
