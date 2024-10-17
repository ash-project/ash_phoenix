# Change Log

All notable changes to this project will be documented in this file.
See [Conventional Commits](Https://conventionalcommits.org) for commit guidelines.

<!-- changelog -->

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
