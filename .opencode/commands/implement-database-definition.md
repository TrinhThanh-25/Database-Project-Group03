# /implement-database-definition

## Description

Translate the logical database design into a complete SQL DDL implementation, including table definitions, primary and foreign key constraints, indexes, and any necessary triggers or views.

## Agent

Before producing the output:
1. Read and follow the agent definition from:
   `.opencode/agent/database-implementation-engineer.md`

## Aliases

* /implement
* /create-tables
* /ddl

## Required Inputs

* Logical Database Design document: `outputs/03-logical-design-G03.md` which is the output of `/design-logical-database` command.
* Design Review Report: `outputs/04-design-validation-G03.md` which is the output of `/validate-database-design` command.

## Required Outputs

* Database Implementation: `outputs/05-db-definition-G03.sql`.
