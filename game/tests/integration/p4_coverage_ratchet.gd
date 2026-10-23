## P4 gate coverage ratchet (test_p4_progression.gd). Owner: LEAD.
## Modifier keys <= P4 that were NOT covered when the gate landed, each with the env that owns the
## missing work (tools/ci/owners.json; modifiers.md: ENV A implements hooks and behaviour tests).
## The gate fails if a key outside these lists loses coverage, and if a listed key gains it (remove it
## here: the lists only shrink). A key that gains a hook but no test moves from UNHOOKED to UNTESTED.
extends RefCounted

## No runtime code reads the key (and so no behaviour test can exist).
const UNHOOKED: Dictionary = {
	&"stealth.pocket_ecm": "A",
}

## Read by runtime code (hook file in the comment) but no behaviour test.
const UNTESTED: Dictionary = {
}
