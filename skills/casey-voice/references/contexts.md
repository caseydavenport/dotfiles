# Writing Contexts

Detailed guidance for each type of writing output.

## Commit Messages

Casey's commit messages are short, imperative, and to the point. The subject
line is the most important part and should be specific enough to be useful in
`git log --oneline`.

**Subject line pattern:**
- Imperative mood ("Add", "Fix", "Move", "Update", "Use")
- No trailing period
- No conventional commit prefixes (no `feat:`, `fix:`, `chore:`)
- No Claude/AI attribution lines (no Co-Authored-By)
- Be specific: name the concrete things that changed, not just the category.
  `IPPool: add CEL XValidation for LB, Tunnel, and global() constraints`
  is better than `Add CEL XValidation rules for IPPool`.
- Use `Component:` prefix when the commit is scoped to one component
  (e.g., `goldmane:`, `IPPool:`, `felix:`)
- Work-in-progress commits can be very terse

**Body (optional):**
- A terse body is OK for non-trivial commits, but keep it short (2-4 lines)
- Bullet points are good for readability when there are multiple distinct changes
- Don't repeat what the subject line already says
- Skip the body entirely for simple/obvious commits

**Examples (subject only):**
```
IPPool: add CEL XValidation for LB, Tunnel, and global() constraints
Make findBucket O(1) by computing the ring index directly
Configure logrus formatting and fix rate limiter noise in migration tests
Fix tests
Address code review comments
Fixups
```

**Example with body:**
```
Configure logrus and raise rate limits in migration FV tests

- Set up debug logging with the calico formatter
- Bump client-go QPS/burst so tests don't get throttled on envtest
- Bail out of work loop early on context cancellation
```

**What NOT to do:**
```
feat: add new mutating admission policy support for Calico webhooks
This commit adds comprehensive support for...
Co-Authored-By: ...
```

## PR Descriptions

PR descriptions follow a structured format but stay concise. The depth scales
with the complexity of the change.

**For substantial changes:**

Jump straight into the description, no `## Summary` header or other section
headers. Start with a one-line summary, then bullet the key moves. Keep
bullets terse: state what changes and any benefits in as few words as
possible. No elaboration, no selling, no verbose explanations of why the
new approach is better. If a benefit fits in the same bullet as the change,
that's fine; just don't dedicate separate paragraphs to motivation.

```markdown
Replaces the bash-based confd test suite with native Go tests.

- Leave test inputs (YAML fixtures) and expected outputs as they are
- Get rid of bash runners, no more Docker, no binary builds
- Use `go test` with standard Go/Gomega assertions
- Run confd in-process via `RunWithContext()` against envtest or standalone etcd
```

Use bullet points when listing multiple changes, but don't wrap them in
a header. Do NOT include a "Test plan" section.

**For small/obvious changes, keep it minimal:**
Just a one-liner or a link to the related issue/PR. Don't pad small changes
with ceremony.

**Examples of good PR summaries:**

Bug fix:
> Fix for a bug in the LoadBalancer IP advertisement logic. The per-service
> path only checked the deprecated `svc.Spec.LoadBalancerIP` field.
> Introduces `hasAnySingleLoadBalancerIP()` to check both old and new fields.

Refactor:
> Relocates `pkg/crds` to `pkg/imports/crds` for imported external resources.
> Updates all import paths, Makefile references, symlinks. No functional changes.

Feature:
> Adds `Ports` and `HostNetwork` fields to `CalicoWebhooksDeployment` overrides
> on the APIServer CR. Port overrides propagate to the container, service
> targetPort, and network policy.

Minimal:
> Needed for projectcalico/calico#1234

**For large cross-cutting changes** (many resources/types affected), use bolded
per-category headers with terse bullets under each, rather than one long flat
bullet list:

```markdown
Adds CEL XValidation rules across v3 API types, moving cross-field
validation into the CRD schema so the API server rejects at admission time.

New rules by resource:

- **BGPPeer** -- reachableBy requires peerIP, keepOriginalNextHop conflicts with nextHopMode
- **IPPool** -- LB pools can't disable BGP export, Tunnel forbids namespaceSelector
- **Rule** -- ICMP fields require ICMP/ICMPv6 protocol, ICMP/ICMPv6 require matching ipVersion
```

**For bug fixes and redesigns**, include concrete examples that illustrate the
problem. A specific scenario like "`retry_until_success(curl, retries=90,
wait_time=1)` looks like a 90s timeout but actually runs for ~360s" lands
much better than an abstract description of the issue. Same for user-facing
symptoms: "the Whisker UI displays policies in random order" is more useful
than "Go map iteration is non-deterministic". Also include cross-references
to related PRs or issues that motivated the change.

**For performance PRs**, include benchmark results if available. Use natural
language for the descriptions, not CS jargon. e.g., "We were calling
findBucket twice unnecessarily, now just do it once" rather than "Eliminate
redundant O(1) amortized bucket lookup invocation".

**Key traits:**
- Terse bullets: state the transformation, not a pitch for it
- Technical precision: exact field names, function names, package paths
- Root-cause oriented for bugs: explain *why* it broke, not just what was changed
- Include the user-visible symptom for bugs when there is one
- No filler prose, no coverage tables, no "what's next" sections
- Cross-references to related PRs, JIRA tickets, issues

## Release Notes

Every PR description ends with one or more ` ```release-note ` blocks. No
`**Release note:**` prefix, just the bare fenced block.

**When to include a release note:**
- Bug fixes, new features, behavioral changes, API changes: yes
- Performance optimizations: yes (users care about these)
- Behavior corrections that affect user-visible output (e.g., fixing sort
  order in a UI, changing default values): yes, even if the old behavior
  was a bug. Users may have adapted to the old behavior.
- Internal refactors, test-only changes, CI fixes: use `None`

**Format:**
- One sentence, focused on what the user sees or what changed for them
- Focus on the *impact*, not the implementation. "Enforce a maximum of 1024
  Ingress and 1024 Egress rules in network policies" is better than "Added
  CEL validation rules to network policy CRDs". Users need to know what
  might break or change for them, not how it was implemented.
- Include specific values, limits, and thresholds when they exist. "Selector
  fields limited to 1024 characters" is actionable. "Enforce maximum sizes
  on selector fields" is not. Users need the number to check their configs.
- Prefix with a subsystem tag when the change only affects a subset of users:
  `BPF: ...`, `HELM: ...`, `eBPF: ...`, `Windows: ...`, `nftables: ...`
- Breaking changes or API changes get more detail
- Multiple distinct user-facing changes get separate release-note blocks. e.g.,
  if the same type of change applies to different API fields or resources, each
  one gets its own note so users can find the one relevant to them

**Examples:**

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
None
` ` `
```

Multiple notes for one PR:
```
` ` `release-note
Enforce a maximum of 1024 Ingress and 1024 Egress rules in network policies.
` ` `

` ` `release-note
Enforce a maximum of 1024 characters in Selector fields.
` ` `
```

## Design Documents and Issues

For complex topics that warrant thorough discussion, Casey writes structured
posts with clear organization. These are the longest-form writing Casey does.

**Pattern:**
- Start with a clear problem statement
- Use headings to organize sections
- TL;DR at the top for long posts
- Bullet points for lists of options or pain points
- Historical context when it explains why things are the way they are
- Direct language: state opinions clearly rather than hedging
- End with concrete options or next steps

**Example structure for a design discussion:**

```markdown
# Discussion: v1 vs v3 API

TL;DR: We have two API groups that represent the same resources. This causes
confusion and maintenance burden. Here are the options for fixing it.

## Background
[2-3 paragraphs of history and context]

## Pain Points
- [concrete problem 1]
- [concrete problem 2]

## Options
### Option A: ...
### Option B: ...

## Recommendation
[clear opinion with reasoning]
```

## GitHub Issue Descriptions

Issues range from brief feature requests to thorough problem descriptions.

**Short issues** (feature requests, small asks):
> A how-to style doc for setting memory and CPU limits. This is a frequent
> question from users. CC @colleague

**Thorough issues** (bugs, design discussions):
Explain the problem clearly, include relevant context, and if possible
suggest the direction for a fix. Use the same structured format as design docs
when warranted.

## Slack Messages

Casey's Slack style is distinctly more casual than his GitHub writing.

**Characteristics:**
- Short, rapid-fire messages rather than long blocks
- Lowercase starts for casual messages ("ah", "oh yeah, that one")
- Contractions everywhere ("I'm", "I'll", "don't", "em" for "them")
- "Yep" over "Yes"
- Periods often omitted at end of short messages
- Exclamation marks for warmth, not emphasis
- Action-first: report what you've already done, not what you plan to do
- Single targeted questions for debugging ("What's the name of your cluster?")
- Moderate emoji use for emotional color, not decoration

**In public channels:**
- Slightly more structured
- Context + PR link + CC tags for review requests
- Still concise

**In DMs:**
- Very casual, mix social chat with work
- Self-deprecating humor when own code causes problems
- Multiple short messages in sequence

**Example patterns:**
```
I just added some permissions to that service account
```
```
Will send em your way
```
```
Here's a PR: [link]
@person perhaps you've got a moment to take a look? CC @other
```
```
I suspect the issue is the "name" field - if you query the policy with
kubectl from the k8s API, what is the Name field?
```
