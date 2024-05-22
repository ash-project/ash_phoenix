# Change Log

All notable changes to this project will be documented in this file.
See [Conventional Commits](Https://conventionalcommits.org) for commit guidelines.

<!-- changelog -->

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
