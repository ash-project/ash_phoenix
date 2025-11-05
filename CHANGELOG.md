<!--
SPDX-FileCopyrightText: 2020 Zach Daniel

SPDX-License-Identifier: MIT
-->

# Change Log

All notable changes to this project will be documented in this file.
See [Conventional Commits](Https://conventionalcommits.org) for commit guidelines.

<!-- changelog -->

## [v2.3.18](https://github.com/ash-project/ash_phoenix/compare/v2.3.17...v2.3.18) (2025-11-05)




### Bug Fixes:

* merge_options function to use correct update method (#438) by A.S. Zwaan

* cast to string before comparison by Minsub Kim

* fix type warnings and compile issues on elixir 1.19 by [@zachdaniel](https://github.com/zachdaniel)

## [v2.3.17](https://github.com/ash-project/ash_phoenix/compare/v2.3.16...v2.3.17) (2025-10-16)




### Bug Fixes:

* removed to_string because it was causing related entities to be recreated instead of updated (#421) by Abdessabour Moutik [(#421)](https://github.com/ash-project/ash_phoenix/pull/421)

* removed to_string because it was causing related entities to be recreated instead of being updated by Abdessabour Moutik [(#421)](https://github.com/ash-project/ash_phoenix/pull/421)

* AshPhoenix.Inertia.Error argument error when reporting validation errors (#418) by rmaspoch [(#418)](https://github.com/ash-project/ash_phoenix/pull/418)

* bug when creating a form for a union type which has `nil` as it's value (#417) by Rutgerdj [(#417)](https://github.com/ash-project/ash_phoenix/pull/417)

### Improvements:

* add AshPhoenix.AshEnum by sevenseacat [(#413)](https://github.com/ash-project/ash_phoenix/pull/413)

* soft deprecate page_from_params/3 and introduce params_to_page_opts/3 (#422) by hy2k [(#422)](https://github.com/ash-project/ash_phoenix/pull/422)

* add AshPhoenix.AshEnum by Aidan Gauland [(#413)](https://github.com/ash-project/ash_phoenix/pull/413)

## [v2.3.16](https://github.com/ash-project/ash_phoenix/compare/v2.3.15...v2.3.16) (2025-09-01)




### Improvements:

* add `post_process_errors` option by [@zachdaniel](https://github.com/zachdaniel)

## [v2.3.15](https://github.com/ash-project/ash_phoenix/compare/v2.3.14...v2.3.15) (2025-08-31)




### Bug Fixes:

* error in auto form creation for structs inside of union attributes (#411) by Rutgerdj

* update pattern match in WrappedValue Change by Rutgerdj

* Include constraints in auto form for WrappedValue by Rutgerdj

* handle regexes in error vars in inertia by [@zachdaniel](https://github.com/zachdaniel)

## [v2.3.14](https://github.com/ash-project/ash_phoenix/compare/v2.3.13...v2.3.14) (2025-08-21)




### Bug Fixes:

* ensure nested form errors are included (#401) by [@joangavelan](https://github.com/joangavelan)

* Remove Product from Save Product button - Save button (#403) by Kenneth Kostrešević

### Improvements:

* remove unwanted sections from AGENTS.md when installing ash_phoenix (#406) by Rodolfo Torres

* add resource name for route option for `ash_phoenix.gen.html` (#402) by Kenneth Kostrešević

## [v2.3.13](https://github.com/ash-project/ash_phoenix/compare/v2.3.12...v2.3.13) (2025-08-07)




### Bug Fixes:

* ensure nested form errors are included (#401) by [@joangavelan](https://github.com/joangavelan)

* Remove Product from Save Product button - Save button (#403) by Kenneth Kostrešević

### Improvements:

* add resource name for route option for `ash_phoenix.gen.html` (#402) by Kenneth Kostrešević

## [v2.3.12](https://github.com/ash-project/ash_phoenix/compare/v2.3.11...v2.3.12) (2025-07-29)




### Bug Fixes:

* fix typo in usage rules (#397) by albinkc

## [v2.3.11](https://github.com/ash-project/ash_phoenix/compare/v2.3.10...v2.3.11) (2025-07-17)




### Improvements:

* Add `to_form/2` in usage rules and improve error message when accessing a form without `to_form/2` (#390) by Kenneth Kostrešević

## [v2.3.10](https://github.com/ash-project/ash_phoenix/compare/v2.3.9...v2.3.10) (2025-07-09)




### Bug Fixes:

* handle `value_is_key` forms by [@zachdaniel](https://github.com/zachdaniel)

## [v2.3.9](https://github.com/ash-project/ash_phoenix/compare/v2.3.8...v2.3.9) (2025-06-28)




### Improvements:

* update usage rules with info on `raw_errors` by [@zachdaniel](https://github.com/zachdaniel)

## [v2.3.8](https://github.com/ash-project/ash_phoenix/compare/v2.3.7...v2.3.8) (2025-06-25)




### Bug Fixes:

* resolve warning about map key access as function call by [@zachdaniel](https://github.com/zachdaniel)

### Improvements:

* add `AshPhoenix.Form.raw_errors/2` by [@zachdaniel](https://github.com/zachdaniel)

## [v2.3.7](https://github.com/ash-project/ash_phoenix/compare/v2.3.6...v2.3.7) (2025-06-18)




### Bug Fixes:

* access proper form field for nested argument inputs by [@zachdaniel](https://github.com/zachdaniel)

* handle case where last item in add form path is an integer by [@zachdaniel](https://github.com/zachdaniel)

## [v2.3.6](https://github.com/ash-project/ash_phoenix/compare/v2.3.5...v2.3.6) (2025-06-10)




### Bug Fixes:

* merge overridden params with original params in code interfaces by [@zachdaniel](https://github.com/zachdaniel)

## [v2.3.5](https://github.com/ash-project/ash_phoenix/compare/v2.3.4...v2.3.5) (2025-05-31)




### Bug Fixes:

* live route instructions (#371)

## [v2.3.4](https://github.com/ash-project/ash_phoenix/compare/v2.3.3...v2.3.4) (2025-05-30)




### Bug Fixes:

* reenable migrate task

## [v2.3.3](https://github.com/ash-project/ash_phoenix/compare/v2.3.2...v2.3.3) (2025-05-30)




### Bug Fixes:

* new generators, use actor when getting resource

* new generators, close Layouts.app tag

* new generators, remove handle_params and apply_action, since this no longer handles create/update

* new generators, remove handle params + title, since this no longer handles update

### Improvements:

* implement new codegen status plug

* support `Ash.Scope`

* resolve igniter task deprecation warning

* new generator tweaks (#368)

* explain importants of positional arguments in usage rules

## [v2.3.2](https://github.com/ash-project/ash_phoenix/compare/v2.3.1...v2.3.2) (2025-05-21)




### Bug Fixes:

* support old phoenix generators (#365)

### Improvements:

* update igniter, remove inflex

* add usage-rules.md

## [v2.3.1](https://github.com/ash-project/ash_phoenix/compare/v2.3.0...v2.3.1) (2025-05-15)




### Bug Fixes:

* Initialize :raw_params field of for_action() Form (#362)

* for action params option (#359)

* Accept Phoenix.LiveView.Socket in SubdomainPlug (#355)

### Improvements:

* Document `:params` option for `for_action` (#361)

* Rework gen.live (#353)

* support `AshPhoenix.Form` in error subject

## [v2.3.0](https://github.com/ash-project/ash_phoenix/compare/v2.2.0...v2.3.0) (2025-04-29)




### Features:

* Add Inertia.Errors impl for Ash.Error types (#352)

### Bug Fixes:

* properly route inertia errors to implementation

* handle invalid query error different formats

## [v2.2.0](https://github.com/ash-project/ash_phoenix/compare/v2.1.26...v2.2.0) (2025-04-13)




### Features:

* Add basic Igniter installer to add `ash_phoenix` to the formatter list

## [v2.1.26](https://github.com/ash-project/ash_phoenix/compare/v2.1.25...v2.1.26) (2025-04-09)




### Improvements:

* allow configuring positional args for form code interfaces

* Add subdomain live_view hook (#339)

## [v2.1.25](https://github.com/ash-project/ash_phoenix/compare/v2.1.24...v2.1.25) (2025-03-27)




### Improvements:

* add error impl for Ash.Error.Action.InvalidArgument (#336)

## [v2.1.24](https://github.com/ash-project/ash_phoenix/compare/v2.1.23...v2.1.24) (2025-03-25)




### Bug Fixes:

* assign page and stream to actually stream the stream (#334)

* Prevent empty errors pass to error class (#332)

## [v2.1.23](https://github.com/ash-project/ash_phoenix/compare/v2.1.22...v2.1.23) (2025-03-21)




### Bug Fixes:

* also handle `nil` errors

## [v2.1.22](https://github.com/ash-project/ash_phoenix/compare/v2.1.21...v2.1.22) (2025-03-21)




### Bug Fixes:

* unhandled error in form submission warning (#329)

## [v2.1.21](https://github.com/ash-project/ash_phoenix/compare/v2.1.20...v2.1.21) (2025-03-18)




### Bug Fixes:

* translate errors into an error class before rendering

* Additional function clause for keyset pagination (page_link_params) (#323)

## [v2.1.20](https://github.com/ash-project/ash_phoenix/compare/v2.1.19...v2.1.20) (2025-03-11)




### Bug Fixes:

* always remove `auto?` option after handling it

## [v2.1.19](https://github.com/ash-project/ash_phoenix/compare/v2.1.18...v2.1.19) (2025-03-04)




### Bug Fixes:

* handle case w/ set list of join attributes

## [v2.1.18](https://github.com/ash-project/ash_phoenix/compare/v2.1.17...v2.1.18) (2025-02-10)




### Bug Fixes:

* page_link_params supports integers

## [v2.1.17](https://github.com/ash-project/ash_phoenix/compare/v2.1.16...v2.1.17) (2025-01-30)




### Improvements:

* guess the plural name for resources automatically

## [v2.1.16](https://github.com/ash-project/ash_phoenix/compare/v2.1.15...v2.1.16) (2025-01-29)




### Bug Fixes:

* don't try to build form interfaces for calculations

* reindex forms sorted with `sort_forms/3`

## [v2.1.15](https://github.com/ash-project/ash_phoenix/compare/v2.1.14...v2.1.15) (2025-01-27)




### Bug Fixes:

* handle `nil` nested form when carrying over errors

* Handle invalid params and warn when invalid (#301)

* In AshPhoenix.Form.errors parse path before errors get (#300)

* Make ash_errors private and remove unused default values

* Show correct error message when no form is configured but a relationship is present

### Improvements:

* Move get params logic to private function, put get params on every for call (#304)

* add `AshPhoenix.LiveView.assign_page_and_stream_result/3`  (#303)

* make arguments have higher precedence in do_value (#294)

## [v2.1.14](https://github.com/ash-project/ash_phoenix/compare/v2.1.13...v2.1.14) (2025-01-19)




### Bug Fixes:

* print routes on ash_phoenix.gen.live again

* properly find matching forms by primary key

* Allow re-adding forms to a nested form after deleting the last one from a list (#291)

* handle case where last form is deleted

* simplifications and fixes for drop_param

* ensure that form interfaces properly set data

* fix warning in filter_form.ex (#285)

### Improvements:

* support `_drop_*`, `_add_*` and `_sort_*` params

* add `AshPhoenix.Form.sort_forms` utility

## [v2.1.13](https://github.com/ash-project/ash_phoenix/compare/v2.1.12...v2.1.13) (2025-01-03)




### Bug Fixes:

* ensure that form interfaces properly set data

* update html generators to properly call actions

## [v2.1.12](https://github.com/ash-project/ash_phoenix/compare/v2.1.11...v2.1.12) (2024-12-22)




### Improvements:

* Add `AshPhoenix` extension

## [v2.1.11](https://github.com/ash-project/ash_phoenix/compare/v2.1.10...v2.1.11) (2024-12-20)




### Bug Fixes:

* only ever raise error classes

### Improvements:

* make igniter optional

* simplify setting valid on `AshPhoenix.Form.add_error/3`

* don't populate args that aren't set

## [v2.1.10](https://github.com/ash-project/ash_phoenix/compare/v2.1.9...v2.1.10) (2024-12-12)




### Bug Fixes:

* use Igniter.Project.Module.parse to get module names for generator (#274)

## [v2.1.9](https://github.com/ash-project/ash_phoenix/compare/v2.1.8...v2.1.9) (2024-12-11)




### Bug Fixes:

* ensure that errors on before_action hooks invalidate the form

### Improvements:

* Migrate phoenix gen to igniter (#261)

* add `AshPhoenix.Form.update_params/2`

## [v2.1.8](https://github.com/ash-project/ash_phoenix/compare/v2.1.7...v2.1.8) (2024-10-29)




### Improvements:

* track `raw_params`

## [v2.1.7](https://github.com/ash-project/ash_phoenix/compare/v2.1.6...v2.1.7) (2024-10-29)




### Bug Fixes:

* set _union_type param when unnesting a resource in a union

* don't wrap resources inside of unions as WrappedValue

* warn on missing `params` on submit

* unwrap unions & wrapped values when fetching values

## [v2.1.6](https://github.com/ash-project/ash_phoenix/compare/v2.1.5...v2.1.6) (2024-10-17)




### Improvements:

* allow phoenix_live_view rc

## [v2.1.5](https://github.com/ash-project/ash_phoenix/compare/v2.1.4...v2.1.5) (2024-10-14)




### Improvements:

* support generic actions (#250)

## [v2.1.4](https://github.com/ash-project/ash_phoenix/compare/v2.1.3...v2.1.4) (2024-09-30)




### Bug Fixes:

* properly include calc args in `to_filter_map`

## [v2.1.3](https://github.com/ash-project/ash_phoenix/compare/v2.1.2...v2.1.3) (2024-09-30)




### Bug Fixes:

* properly apply calculations with arguments in filter form

## [v2.1.2](https://github.com/ash-project/ash_phoenix/compare/v2.1.1...v2.1.2) (2024-09-03)




### Bug Fixes:

* spec `update_form` to accept functions of lists

## [v2.1.1](https://github.com/ash-project/ash_phoenix/compare/v2.1.0...v2.1.1) (2024-08-01)




### Bug Fixes:

* Use :public? instead of :private? (#221)

### Improvements:

* raise an error on usage of old option name

## [v2.1.0](https://github.com/ash-project/ash_phoenix/compare/v2.0.4...v2.1.0) (2024-07-26)




### Bug Fixes:

* ensure we `prepare_source` for all read action forms

## [v2.0.4](https://github.com/ash-project/ash_phoenix/compare/v2.0.3...v2.0.4) (2024-06-13)




### Bug Fixes:

* various fixes for union form handling

* properly fill union values on update

* ensure changing union type is reflected in param transformer

### Improvements:

* honor `_union_type` when applying input

## [v2.0.3](https://github.com/ash-project/ash_phoenix/compare/v2.0.2...v2.0.3) (2024-06-05)




### Bug Fixes:

* properly (i.e safely) encode ci strings to iodata and params

* various union param handling fixes

* properly transform nested params

* make sure that _index is correctly updated before and after removal for sparse forms (#196) (#197)

## [v2.0.2](https://github.com/ash-project/ash_phoenix/compare/v2.0.1...v2.0.2) (2024-05-22)




### Bug Fixes:

* don't assume all embeds have a create/update action

## [v2.0.1](https://github.com/ash-project/ash_phoenix/compare/v2.0.0...v2.0.1) (2024-05-17)




### Bug Fixes:

* improve union handling

* Convert entered action names into atoms for lookup in the resource (#187)

* various fixes around union forms

### Improvements:

* support adding a form by inserting to an index

## [v2.0.0](https://github.com/ash-project/ash_phoenix/compare/v2.0.0...v1.3.4) (2024-04-30)

The changelog is being restarted. See `/documentation/1.0-CHANGELOG.md` in GitHub for the old changelog.

### Improvements:

- [AshPhoenix.Form] better error message with hints for accepted/non accepted missing forms

### Bug Fixes:

- [AshPhoenix.Form] don't use `public_attributes?`, check for all accepted attributes. In Ash 3.0, private attributes can be accepted
- [AshPhoenix.Form]

- Pass the tenant to `Ash.can/3` and `Ash.can?/3`. (#165)

- Pass the tenant to `Ash.can/3` and `Ash.can?/3`.
