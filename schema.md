# Schema review response

I compared both reconstructions with my `schema.sql`. Both reviewers had the seven tables, their primary keys, and their foreign keys. 

## Category 1: My diagram left something unclear

For the most part, it was all structurally correct besides the constraints, which the ER diagram doesn't usually show. 


**Several attributes have different nullability in the reconstructions.** For example, my schema requires `users.first_seen_at`, `stories.title`, `stories.created_at`, `stories.updated_at`, `stories.points`, `stories.num_comments`, all three story-type flags, `comments.created_at`, `polls.created_at`, and `poll_options.points`. A.sql leaves these nullable. B.sql marks some of them required, but leaves others nullable. In contrast, B.sql requires `poll_options.option_text`, while my schema allows it to be null. These differences are mainly whether the attributes can be null. The ER diagram was meant to show the entities, keys, and relationships, rather than every column-level SQL constraint, so the reviewers had to make their own assumptions about those attributes.

**Some SQL implementation choices were not shown.** A.sql uses plain integer IDs for domains; my schema uses `SERIAL` to generate them. Both reviewers use `TIMESTAMP` where my schema uses `TIMESTAMPTZ`. The reconstructions also differ from my schema like, nonnegative `CHECK` constraints and `ON DELETE` actions. A.sql omits the delete actions, while B.sql mostly includes them. I have the types and constraints in `schema.sql`. An ER diagram alone did not specify all of those SQL details.

Neither reconstruction included the UNIQUE constraint on `domains.domain_name`.

## Category 2: A reviewer misread a marked element

Neither reviewer misread a marked key or relationship.

## Category 3: A reviewer found a real flaw in my schema

None

## Where the reviewers differed

A.sql allows `domain_name` to be null, while B.sql requires a value. I intended it to be required as in my `schema.sql`. B.sql requires `poll_options.option_text`, while A.sql allows null. I intended to allow null. A.sql omits the `ON DELETE` actions that B.sql includes. I intended the actions specified in my `schema.sql`. The diagram did not spell out these column and deletion rules, so the reviewers made different choices.

## Revision

The review above describes the original Project 1 schema. Following the grader’s
feedback, the current diagram now marks required attributes with NN and uses
`timestamptz`. The current schema adds `links` for URL → domain, drops the
repeated poll timestamp and stored poll flag, and replaces stored
`users.first_seen_at` with the `user_first_seen` view. The eight current tables
are documented in `er-diagram.md`; the PNG and peer reconstructions remain
historical Project 1 artifacts.
