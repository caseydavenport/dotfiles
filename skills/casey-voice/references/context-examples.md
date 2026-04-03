# Context Examples

Real examples from Casey Davenport's writing across different contexts. Read
this file when you need to calibrate your tone for a specific context type.

## Table of Contents

1. [Commit Messages](#commit-messages)
2. [PR Descriptions](#pr-descriptions)
3. [Release Notes](#release-notes)
4. [Code Review Comments](#code-review-comments)
5. [JIRA Issues](#jira-issues)
6. [JIRA Comments](#jira-comments)
7. [GitHub Issue Descriptions](#github-issue-descriptions)
8. [GitHub Issue Comments (Community)](#github-issue-comments-community)
9. [Slack Messages](#slack-messages)
10. [Go Code Comments](#go-code-comments)

---

## Commit Messages

**Subject line pattern:**
- Imperative mood ("Add", "Fix", "Move", "Update", "Use")
- No trailing period
- No conventional commit prefixes (no `feat:`, `fix:`, `chore:`)
- No Claude/AI attribution lines (no Co-Authored-By)
- Be specific: name the concrete things that changed, not just the category
- Use `Component:` prefix when scoped to one component (e.g., `goldmane:`,
  `IPPool:`, `felix:`)
- Work-in-progress commits can be very terse

**Good subjects:**
```
IPPool: add CEL XValidation for LB, Tunnel, and global() constraints
Make findBucket O(1) by computing the ring index directly
Configure logrus formatting and fix rate limiter noise in migration tests
Fix tests
Address code review comments
Fixups
```

**Good subject + body:**
```
Configure logrus and raise rate limits in migration FV tests

- Set up debug logging with the calico formatter
- Bump client-go QPS/burst so tests don't get throttled on envtest
- Bail out of work loop early on context cancellation
```

**Bad:**
```
feat: add new mutating admission policy support for Calico webhooks
This commit adds comprehensive support for...
Co-Authored-By: ...
```

---

## PR Descriptions

### Trivial fix - one sentence
> This was causing a panic here: https://tigera.semaphoreci.com/jobs/...

### Trivial rename - casual explanation
> This is just to reduce some confusion with the public API, which is named v3.

### Small improvement - conversational tone
> Have found it a bit annoying recently when this target fails in CI and there
> isn't enough information to see what is going on!

### Minor behavior fix - concise paragraph
> This is a minor improvement to the pool sorting behavior in the new IP pool
> controller. It ensures the we also account for the deletion time stamp when
> sorting IP pools, which becomes relevant when making decisions about how to
> mask / unmask overlapping IP pools that become active or not when an IP pool
> is terminating, and ensures we do not consider the IP pool active until any
> masking IP pool is fully terminated.
>
> It also adds some UT specifically targeted at the sorting logic.

### Bug fix - structured with root cause
> ## Description
>
> Bug fix for the IPAM GC controller getting stuck during rapid node scale-down.
>
> When ReleaseHostAffinities fails (e.g., because a block still has tunnel IP
> allocations that haven't been GC'd yet), syncIPAM() would return an error,
> which prevented syncComplete() from ever running. Without syncComplete(),
> dirty nodes accumulate, each subsequent sync processes more and more nodes,
> contention increases, and the controller effectively freezes.
>
> The fix:
> - Change releaseNodes() to return failed nodes instead of an error, so that
>   node cleanup failures are non-fatal
> - Always call syncComplete(), ensuring incremental progress on every sync pass
> - Re-dirty failed nodes after syncComplete() so they get retried on the next pass
>
> This is a simpler alternative to the approach in #10333, which improved
> throughput but didn't address the core ordering issue between tunnel IP GC
> and node affinity release.
>
> Related issues/PRs
>
> Fixes https://github.com/projectcalico/calico/issues/8643
> Related: https://github.com/projectcalico/calico/pull/10333

### Substantial change - full structure with tables
> ## Description
>
> Migrates several e2e tests from `tigera/k8s-e2e` into the calico monorepo
> `e2e/` package, and adds new tests that didn't exist in k8s-e2e.
>
> ### New test files
>
> | File | Source | Notes |
> |------|--------|-------|
> | `e2e/pkg/tests/bgp/bgp_password.go` | k8s-e2e `bgp-password.go` | Uses CalicoNodeStatus API instead of `birdcl` exec |
> | `e2e/pkg/tests/ipam/ipam_gc.go` | k8s-e2e `ipam.go` (GC block) | Rewritten using controller-runtime client; marked **Conformance** |
>
> ### Key behavioral differences from k8s-e2e originals
>
> - **BGP password**: Verifies BGP session establishment via CalicoNodeStatus
>   resource polling instead of exec'ing `birdcl` in calico-node pods.
> - **QoS bandwidth**: Uses iperf3 (JSON output) instead of iperf2. Tolerance
>   bands widened from 20% to 50% to reduce flakiness.

### Worktree fix - concise bullet points
> In a git worktree, `.git` is a file pointing to `<main-repo>/.git/worktrees/<name>`.
> When the worktree is mounted into a Docker container, git commands inside
> the container fail with `fatal: not a git repository` because the main
> `.git` directory isn't mounted.
>
> - Adds worktree detection to `lib.Makefile` (compares `git rev-parse --git-dir`
>   vs `--git-common-dir`) and, when in a worktree, passes extra Docker args to
>   mount the main `.git` directory and set `GIT_DIR`/`GIT_WORK_TREE`.
> - Adds `$(DOCKER_GIT_WORKTREE_ARGS)` to the `DOCKER_RUN` overrides in the root
>   `Makefile` and `api/Makefile`.

### Large cross-cutting change - bolded per-category headers
> Adds CEL XValidation rules across v3 API types, moving cross-field
> validation into the CRD schema so the API server rejects at admission time.
>
> New rules by resource:
>
> - **BGPPeer** - reachableBy requires peerIP, keepOriginalNextHop conflicts with nextHopMode
> - **IPPool** - LB pools can't disable BGP export, Tunnel forbids namespaceSelector
> - **Rule** - ICMP fields require ICMP/ICMPv6 protocol, ICMP/ICMPv6 require matching ipVersion

**Key traits:**
- Terse bullets: state the transformation, not a pitch for it
- Technical precision: exact field names, function names, package paths
- Root-cause oriented for bugs: explain *why* it broke, not just what was changed
- Include the user-visible symptom for bugs when there is one
- Include concrete examples that illustrate the problem (a specific scenario
  lands better than an abstract description)
- No filler prose, no coverage tables, no "what's next" sections
- Cross-references to related PRs, JIRA tickets, issues

---

## Release Notes

Every PR description ends with one or more ` ```release-note ` blocks.

**Good:**
```
` ` `release-note
Fix a panic in typha when a NetworkPolicy contains an unparseable CIDR.
` ` `
```

```
` ` `release-note
BPF: Fix zero bytes_in/packets_in counters for NAT-outgoing flows.
` ` `
```

```
` ` `release-note
Enforce a maximum of 1024 Ingress and 1024 Egress rules in network policies.
` ` `

` ` `release-note
Enforce a maximum of 1024 characters in Selector fields.
` ` `
```

```
` ` `release-note
None
` ` `
```

---

## Code Review Comments

### Suggestion framed as question
> Do we actually expect `!ok` here ever? Sounds like a bug if we hit that
> branch. I'd suggest handling it explicitly with an error log.

### Quick approval with note
> One question / comment but otherwise this LGTM.

### Overstepping gracefully
> VERY possible I am jumping the gun and missing important context here, but
> thought I'd do a fast drive-by with some minor thoughts

### Self-correction
> Yes, sorry for rehashing design - let's stick with the agreed plan, it just
> got me thinking!

### Architectural context in review
> Yeah, that's an interesting one. I am trying to remove some of the mess that
> is our various API packages and representations as part of my v3 CRDs work.
> We have a few things:
>
> - `api/pkg/projectcalico.org/v3` - the proper v3 API, intended for end-users.
> - `libcalico-go/lib/api/crd.projectcalico.org/v1` - the structs used to
>   generate the CRDs of the same name, internal use only.
> - `libcalico-go/lib/apis/v3` - internal APIs used only by our code.
>
> So, I think you are correct that this is in the right place. I am just getting
> turned around a little bit by naming!

### User-facing docs suggestion
> I think we can give a bit more context on these comments - they are ultimately
> user facing. e.g., "When Enabled, Calico uses BGP to distribute route
> information between nodes. When disabled, Calico learns the necessary routing
> information from its IPAM database and running workloads on the cluster"
>
> Or something like that.

### Naming bikeshed - thinking out loud
> Maybe something like one of these?
>
> - clusterRouteSource: BGP / CalicoIPAM
> - internalRoutingMode: BGP / Felix (CalicoIPAM?)
> - clusterRoutingMode
>
> ?

### API design feedback with hedging
> I do sort of wonder if we should be moving towards using native k8s selectors
> moving forward. They are easier to validate using CEL rules, and are more
> familiar to users.
>
> They are however, less expressive than what our selector language can do. So
> depends on needs.

### Defensive coding question
> Do you foresee any scenarios where this fallback is going to be necessary?
>
> It shouldn't be a problem, just wondering if there was something you had in
> mind or if this is more defensive. I suppose there could be race conditions
> between querying the addresses and the interfaces.

---

## JIRA Issues

### Bug - precise root cause
> BIRD does not advertise /32 for loadbalancer service IPs. Larger CIDRs like
> /31 or bigger are advertised without issue. Clusters with 30-40 /32 service
> CIDRs configured see none of them being advertised.
>
> Root cause appears to be in the confd-generated `calico_aggr()` function which
> accepts the aggregate block but rejects all subnets matching it - including
> /32 routes that exactly match the block.

### Story - gap analysis with recommendation
> The API server's storage converters do some defaulting beyond what the CEL
> mutation policy covers:
>
> * Set `projectcalico.org/tier` label on policies (tracked separately)
> * For StagedKubernetesNetworkPolicy, set `spec.stagedKubernetesNetworkPolicyName`
>
> Audit the storage converters in `apiserver/pkg/storage/calico/` and verify
> that any defaulting is either replicated in the mutation webhook, handled by
> CRD defaults, or no longer needed in v3 CRD mode.

### Task - clear scope with PR links
> Migrate several e2e tests from tigera/k8s-e2e into the calico monorepo e2e/
> package, plus add new tests that didn't exist in k8s-e2e.
>
> PR: https://github.com/projectcalico/calico/pull/11892
> k8s-e2e removal PR: https://github.com/tigera/k8s-e2e/pull/1006

---

## JIRA Comments

### Linking a fix
> I believe this is the fix: https://github.com/projectcalico/calico/pull/11917

### Status update with nuance
> Tier label defaulting is now covered by PR
> https://github.com/projectcalico/calico/pull/11890 (merged Feb 20). Remaining
> item: StagedKubernetesNetworkPolicy `spec.stagedKubernetesNetworkPolicyName`
> defaulting - needs investigation on whether this is still needed in v3 CRD mode.

### Quick resolution
> The operator code doesn't actually route SKNP to the webhook, so this is OK.

### Investigating - sharing reasoning
> I think the error logs called out in the issue are benign and a red herring.
> Namely, I suspect they are the same as this issue: [link] Which is an upstream
> logging bug which Shaun has a fix in progress for. But, that doesn't explain
> the other symptoms.

### Requesting diagnostics - specific commands
> is there any chance we can get log files from their OpenShift API server pods?
> Specifically I'd like if they could attempt to access some
> projectcalico.org/v3 APIs and capture the logs from the apiserver pods in the
> openshift-apiserver

### Redirecting
> I believe you will need to work with PM to answer that question.

---

## GitHub Issue Descriptions

### Problem discussion with TL;DR and conversational headings
> This issue comes up frequently enough that I think it warrants its own parent
> issue to explain and discuss.
>
> ## **TL;DR**
>
> **Don't touch `crd.projectcalico.org/v1` resources.** They are not currently
> supported for end-users and the entire API group is only used internally.
>
> ## **Ok, but why do it that way?**
>
> Well, it's partly because of limitations in CRDs, and partly due to historical
> reasons. [...]
>
> ## **Pain points**
>
> Yes, this model is not perfect and has a few known (non-trivial) pain points
> that I would love to resolve.
>
> ## **Can we make it better?**
>
> Maybe. I hope so! But the solutions are not simple.

### Simple removal request
> calicoctl was always meant as a CLI tool.
>
> The "calicoctl as a pod" deployment method was a stopgap before we had an
> API server, but now we do!
>
> We should remove the documentation and manifests that support calicoctl as a
> pod - it results in lots of confusing behaviors since calicoctl isn't meant to
> run containerized.

---

## GitHub Issue Comments (Community)

### Patient explanation with validation
> 100% agree this is confusing, and it's why I raised this issue. The fact that
> `calico.yaml` doesn't include the Calico API server by default makes this even
> more confusing, but it's worth noting that the primary install method via
> `tigera-operator.yaml` _does_ install this API server by default.

### Redirecting scope diplomatically
> @user please raise a separate issue for that and ping me on it - this is a
> high-level tracking issue for discussing general strategy, not for individual
> diagnosis.

### Nudging upgrade
> > Calico version: 3.24.3
>
> This is a pretty ancient version of Calico that is long since out of support.
> I'd recommend updating to a more modern version of Calico and seeing if you
> hit the same issue.

### Honest about not knowing
> Really, AKS should be including the Calico API server as part of its offering.
> To be honest, I wasn't aware they weren't already. I think the "best" way in
> your scenario would be to use `calicoctl`, but obviously that's not ideal.

---

## Slack Messages

### Requesting review - friendly, specific
> I've got a relatively simple PR to add some printcolumns to our CRDs so that
> when you do kubectl get on one of our CRDs, it shows more than just the object
> name. Any takers to review my lil' PR?? [link]

### Requesting review - team channel
> Heya EV team, for my apiserver removal work scheduled for the next release I
> have to migrate a few functions into a new admission webhook system. I've got
> a first take at that in this PR: [link]
> Is there anyone who would like to sign up as a reviewer for this?

### Nudging politely
> Any @operator-dev able to take a look at this tomorrow? The Calico PR is
> approved to be merged, and the Calico Enterprise PR is ready to review soon
> as well, so nearing the point that this PR will be the blocker.

### Quick status
> Yep, I'm working on it

### Humorous self-awareness
> I am worried that it is allowing me to produce code far faster than I can
> acquire code reviews for that code :sweat_smile:

### Firm disagreement with reasoning
> It absolutely makes sense to merge this because I'll be getting the code
> built and run through CI and it enables me to progress this epic more
> efficiently. I'm still not convinced that merging this into kube-controllers
> is even correct, and I do not think it's a ship stopper.

### Scoping a PR
> That's a cool idea - and might be something we want to do, but let's leave it
> out of this PR to keep things simpler. Don't want to burden this PR with more
> structural changes!

### Test design guidance
> SGTM - for the most part, we don't even really need to write tests for
> various inputs unless they actually trigger additional end-to-end flows through
> the system (i.e., if modifying API params are just testing different paths
> through the internals of one component, it's not really a good fit for an e2e
> and we could do it more efficiently / reliably with UT / FV)

### Casual thanks
> np, thanks for doing the heavy lifting :grin:

---

## Go Code Comments

### Procedural narration
```go
// Parse command line arguments.
if err := parseArgs(); err != nil { ... }

// Load resources from file.
blocks, err := loadBlocks(blocksPath)

// Load pod information.
podAllocationInfo, err := loadPodInfo()
```

### "Why" over "what"
```go
// Most cards are singleton in my cube. Except for fetches / shocks, for which
// it is very possible there are multiple in the same deck. Create a "set" of
// all the unique cards in the deck - this prevents double counting the wins
// contributed from a deck when there are two of a card in that deck. This is
// imperfect - there is some value in knowing that a deck with two Arid Mesas
// performed well - but I think without this deduplication we would overstate
// the importance of Arid Mesa in that deck more than we understate it now.
```

### Honest TODO
```go
// TODO: This is pretty janky.

// TODO: This is a bit of a hack, and assumes this command is being run
// within the root of this project. That's OK for now since I am the only user.
```

### Struct field documentation
```go
type Deck struct {
    // Contains metadata about the deck file itself.
    Metadata Metadata `json:"metadata"`

    // Tags represents metadata associated with this deck. This could be
    // archetype, playstyle, etc.
    Labels []string `json:"labels"`

    // Colors is an optional list of colors for the deck. If specified, it
    // overrides the colors inferred from the cards in the mainboard. This is
    // useful for decks that don't neatly fit into the color identity of the
    // cards, or when we only have approximate information about the cards
    // in the deck.
    Colors []string `json:"colors,omitempty"`
}
```

### Algorithm explanation
```go
// Bayesian shrinkage toward 1.0 (independence). We mix in K
// pseudo-observations at lift=1.0: score = (n*lift + k*1) / (n+k).
// This prevents low-sample pairs from dominating with extreme lift values.
score := (float64(stats.count)*rawLift + k*1.0) / (float64(stats.count) + k)
```

### Column reference pattern
```go
// 0         1    2     3      4        5   6  7    8              9
// NAMESPACE NAME READY STATUS RESTARTS AGE IP NODE NOMINATED-NODE READINESS-GATES
fields := strings.Fields(l)
```

### Branch comment inside the branch
```go
// Good:
if !r.v3CRDs {
    // Webhooks are only applicable when v3 CRDs are installed.
    return nil
}

// Bad:
// Webhooks are only applicable when v3 CRDs are installed.
if !r.v3CRDs {
    return nil
}
```

### Block comments for complex logic
```go
// If using v3 CRDs, we render the webhooks component that handles various RBAC and validation
// responsibilities. The ordering of resources here is important to avoid a deadlock:
//
// 1. The webhook's network policy must be installed before the webhook pod starts, because
//    the default-deny policy will block traffic to the webhook. If the webhook pod starts
//    first, it will register itself with the API server but be unreachable, blocking all
//    matching API requests (including the request to create the network policy).
//
// 2. The webhook's TLS keypair must be provisioned before the pod will launch, since the
//    pod mounts the keypair as a volume.
//
// The network policy is included within the webhooks component so it is reconciled alongside
// the Deployment. The TLS keypair is provisioned by the CertificateManagement component below.
```
