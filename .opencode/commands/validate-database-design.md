# /validate-database-design

## Description

Review and validate the conceptual and logical database designs against the business requirements, identifying issues with these designs.

## Agent

database-design-reviewer

## Aliases

* /validate-design
* /database-design-review
* /design-review

## Required Inputs

* Business Requirements document: `req/business-requirement.md`.
* Business Requirement Analysis document: `outputs/01-business-req-analysis-G03.md` which is the output of `/analyze-requirement` command.
* Conceptual Database Design document: `outputs/02-erd-design-G03.md` which is the output of `/design-conceptual-database` command.
* Logical Database Design document: `outputs/03-logical-design-G03.md` which is the output of `/design-logical-database` command.

## Required Outputs

* Database Design Validation Report: `outputs/04-design-validation-G03.md`.
