## Persisted pro-job locks (QB-BRD1, D-049; save v5, B4-16). Owner: ENV B. Static.
##
## A failed pro Board contract cannot be taken again until its slot rotates. The lock lives in
## `PlayerProfile.pro_job_locks` as BoardContracts.contract_key() -> the contract's `expires_at`
## (Unix seconds), so it survives a restart, and is pruned once that time has passed. MenuFlow
## mirrors the live keys into its `consumed_contracts` (the dict the Board reads).
class_name ProJobLocks
extends RefCounted


## Locks `contract` (a BoardContracts contract dict). False for an empty contract or no profile.
static func lock(p: PlayerProfile, contract: Dictionary) -> bool:
	if p == null or contract.is_empty():
		return false
	p.pro_job_locks[BoardContracts.contract_key(contract)] = float(contract.get("expires_at", 0.0))
	return true


## Drops every lock whose contract expired at or before `now` (Unix s). Returns how many were dropped.
static func prune(p: PlayerProfile, now: float) -> int:
	if p == null:
		return 0
	var dropped: int = 0
	for key: Variant in p.pro_job_locks.keys():
		if float(p.pro_job_locks[key]) <= now:
			p.pro_job_locks.erase(key)
			dropped += 1
	return dropped


## True while `contract` is locked at `now`.
static func is_locked(p: PlayerProfile, contract: Dictionary, now: float) -> bool:
	if p == null:
		return false
	var key: String = BoardContracts.contract_key(contract)
	return p.pro_job_locks.has(key) and float(p.pro_job_locks[key]) > now
