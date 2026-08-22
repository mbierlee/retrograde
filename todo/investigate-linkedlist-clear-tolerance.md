# TODO: Decide whether `LinkedList.clear()` should tolerate a corrupted chain

## Origin

Carried over from the (now removed) WASM test-wipe investigation, which ended
with the action item:

> Consider making `LinkedList.clear()` (and friends) tolerant the way
> `HashMap.clear()` is — though this only downgrades the crash to a benign
> warning; it does not remove the need to avoid freeing wiped memory.

The trigger for that item is gone: the WASM harness no longer wipes the heap
between tests (only the allocator suite does, via its own `memTest` wrapper in
`source/retrograde/wasm/memory.d`), so no reset helper hands `clear()` a chain
of freed nodes any more. What remains is a design question worth settling on
its own terms, not a live bug.

## The premise is partly false

`HashMap` is not structurally more tolerant than `LinkedList`. Both walk a node
chain and free as they go:

- `LinkedList.clear()` (`source/retrograde/std/collections.d:1492`) — reads
  `node.next` out of each node before freeing it.
- `HashMap.clear()` (`source/retrograde/std/collections.d:2211`) → `freeNodes()`
  (`source/retrograde/std/collections.d:2435`) — same `auto next = node.next;`
  walk, per bucket.

The difference in the original symptom was luck about *where the state lived*,
not about defensiveness. After a heap wipe, `HashMap`'s `buckets` array read
back as all zeroes, so every bucket head looked empty and the only bad operation
left was `free(buckets)` on a stale pointer — which the WASM allocator rejects
with a log line. `LinkedList` keeps `head` in the data segment, where the wipe
could not reach it, so it dereferenced a node whose memory the rebuilt page map
had already overwritten, read garbage from `next`, and faulted.

So "make `LinkedList` behave like `HashMap`" is not implementable as stated:
there is nothing in `HashMap` to copy.

## The real question

Should a container's teardown path try to survive state that is already
corrupt?

Arguments for fail-fast (leave both as they are): a garbage `next` pointer means
something has already gone badly wrong, and an out-of-bounds trap points at it
immediately. Papering over it with a validity check turns a loud, locatable
failure into a silent one, and no correct program ever reaches that code.

Arguments for tolerance: on WASM a trap kills the whole module, so a corrupted
teardown takes down a test suite or a running game with no chance to report
anything useful. A cheap check could downgrade that to a diagnostic.

Note that on WASM the allocator already has the information needed to answer
"is this pointer a live allocation?" — the page map plus the checks behind
`reportInvalid` in `source/retrograde/wasm/memory.d`. Any tolerance mechanism
should reuse that rather than invent a parallel one, and it has no native
counterpart, which is itself an argument against building the behavior into the
containers.

## Tasks

- [ ] Decide fail-fast vs. tolerant for container teardown, and record the
      decision. Nothing below matters until this is settled; the default is to
      close this todo as "fail-fast, by design".
- [ ] If tolerant: define what a check may cost on the happy path (this runs in
      every `clear()` and every container destructor) and where the predicate
      lives, given that native has no equivalent of the WASM page map.
- [ ] If tolerant: apply it uniformly — `LinkedList.clear()`, `HashMap.freeNodes()`,
      and the node-freeing paths listed in
      [investigate-collection-destructors.md](investigate-collection-destructors.md).
      A guard on one container only reproduces the accidental asymmetry that
      started this.

See also [investigate-collection-destructors.md](investigate-collection-destructors.md)
for the destructor-correctness audit of the same teardown paths.
