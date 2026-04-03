# Go Code Formatting Conventions

Conventions derived from the Calico codebase (particularly goldmane) and
gofumpt rules. All Go code must be gofumpt-clean.

## Table of Contents

1. [gofumpt Rules](#gofumpt-rules)
2. [Newlines and Blank Lines](#newlines-and-blank-lines)
3. [Imports](#imports)
4. [Multi-line Patterns](#multi-line-patterns)
5. [Struct Definitions](#struct-definitions)
6. [Variable Declarations](#variable-declarations)
7. [Error Handling](#error-handling)
8. [Comments](#comments)
9. [Function Organization](#function-organization)
10. [Naming](#naming)
11. [Logging](#logging)
12. [Other Patterns](#other-patterns)

---

## gofumpt Rules

gofumpt is a stricter superset of gofmt. Key rules that affect how you write
code (violations will be reformatted automatically, but it's better to produce
clean code from the start):

**Blank line rules:**
- No blank lines at start/end of function bodies
- No blank lines at start/end of composite literals or field lists
- No blank line between an `err` assignment and `if err != nil`
- No blank lines around single-statement blocks (`if`, `for`, `switch`)
- Empty blocks collapse to single line: `for {}` not `for {\n}`
- Multiline top-level declarations must be separated by blank lines

**Composite literals:**
- If any element is on a different line, ALL elements get their own line
- Trailing comma required on every element in a multiline literal
- Opening/closing braces get their own lines in multiline literals
- In slices of structs, each element's `{` starts on its own line - never
  put `}, {` on the same line

**Function signatures:**
- When parameters span multiple lines, closing `) {` goes on its own line
- Trailing comma after the last parameter in multiline signatures

**Imports:**
- Standard library imports grouped at the top, separated by blank line
- Consecutive single-line `var`/`const` declarations merged into blocks

**Other:**
- `var x = v` inside function bodies becomes `x := v` (no explicit type)
- Single-spec `var()` blocks lose their parentheses
- Octal literals use `0o` prefix: `0o755` not `0755`
- Comments must start with a space after `//` (except directives)

---

## Newlines and Blank Lines

**Between functions:** Exactly one blank line.

**Within functions:** Blank lines separate logical blocks. Almost every distinct
"phase" gets a blank line, often preceded by a comment:

```go
func (a *Goldmane) run(startTime int64, ready chan<- struct{}) {
	// Initialize the buckets.
	opts := []storage.BucketRingOption{
		storage.WithBucketsToAggregate(a.bucketsToAggregate),
		storage.WithPushAfter(a.pushIndex),
	}
	a.flowStore = storage.NewBucketRing(numBuckets, startTime, opts...)

	// Register with the health aggregator.
	a.health.RegisterReporter(healthName, &health.HealthReport{Live: true})

	// Start the stream manager.
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go a.streams.Run(ctx)

	// Indicate that we're ready.
	close(ready)
```

**After variable declarations:** Blank line after a group of var declarations
before the next logical block.

**Before return:** No blank line before `return` in short functions. In longer
functions, blank line before final return only if preceded by substantial logic.

**In const/var blocks:** Blank lines separate multi-line items. Simple
single-line constants can be grouped without blank lines if logically related.

---

## Imports

Three groups, separated by blank lines, alphabetical within each:

1. Standard library
2. Third-party (including `k8s.io/`, `sigs.k8s.io/`, `google.golang.org/`)
3. Internal calico packages (`github.com/projectcalico/calico/...`)

```go
import (
	"context"
	"fmt"

	"github.com/sirupsen/logrus"
	corev1 "k8s.io/api/core/v1"
	"sigs.k8s.io/controller-runtime/pkg/client"

	"github.com/projectcalico/calico/goldmane/pkg/storage"
	"github.com/projectcalico/calico/goldmane/pkg/types"
	cprometheus "github.com/projectcalico/calico/libcalico-go/lib/prometheus"
)
```

Aliases only when necessary to avoid conflicts. In test files, dot-import for
gomega: `. "github.com/onsi/gomega"`.

---

## Multi-line Patterns

**Function calls** - one arg per line, trailing comma, closing paren on own line:

```go
a.flowStore = storage.NewBucketRing(
	numBuckets,
	int(a.bucketDuration.Seconds()),
	startTime,
	opts...,
)
```

**Struct literals** - one field per line, trailing comma, closing brace on own
line. Fields are NOT manually aligned beyond what gofmt does:

```go
return &AggregationBucket{
	StartTime: start.Unix(),
	EndTime:   end.Unix(),
	Flows:     set.New[*DiachronicFlow](),
	stats:     newStatisticsIndex(),
}
```

**Slice of structs** - each element gets its own line with its opening `{`.
Never put a closing `},` and next opening `{` on the same line. The `}, {`
pattern is wrong - always break to a new line:

```go
// CORRECT
var attrs = []v3.AuthorizationReviewResourceAttributes{
	{
		APIGroup:  "projectcalico.org",
		Resources: []string{"hostendpoints", "networksets"},
		Verbs:     []string{"list"},
	},
	{
		APIGroup:  "",
		Resources: []string{"pods"},
		Verbs:     []string{"list"},
	},
}

// WRONG - never do this
var attrs = []v3.AuthorizationReviewResourceAttributes{
	{
		APIGroup: "projectcalico.org",
	}, {
		APIGroup: "",
	},
}
```

**Long if-conditions** - operator at end of line, continuation indented:

```go
if (startGte == 0 || w.start >= startGte) &&
	(startLt == 0 || w.end <= startLt) {
```

**Method chains** - dot on continuation line:

```go
logrus.WithFields(logrus.Fields{
	"start": flow.StartTime,
}).WithFields(flow.Key.Fields()).
	WithError(err).
	Warn("Unable to sort flow into a bucket")
```

**Map literals** - one entry per line when multiline:

```go
r.indices = map[proto.SortBy]Index[string]{
	proto.SortBy_DestName:      NewIndex(func(k *types.FlowKey) string { return k.DestName() }),
	proto.SortBy_SourceName:    NewIndex(func(k *types.FlowKey) string { return k.SourceName() }),
}
```

**Multiline function signatures** - trailing comma, `) {` on own line:

```go
func foo(
	s string,
	i int,
) {
	println("bar")
}
```

---

## Struct Definitions

Fields grouped by logical category with blank lines and comments between
groups. Comments go above fields, not beside them:

```go
type Emitter struct {
	client *emitterClient

	kcli client.Client

	// Configuration for emitter endpoint.
	url        string
	caCert     string
	clientKey  string
	clientCert string

	// For health checking.
	health *health.HealthAggregator

	// Use a rate limited workqueue to manage bucket emission.
	buckets *bucketCache
	queue   workqueue.TypedRateLimitingInterface[bucketKey]
}
```

Embedded fields at the top, before named fields:

```go
type AggregationBucket struct {
	sync.RWMutex

	index     int
	StartTime int64
```

Struct tags are NOT manually aligned - they follow the type immediately.

Interface compliance checks at file/package level:

```go
var _ FlowProvider = &AggregationBucket{}
var _ storage.Sink = &Emitter{}
```

---

## Variable Declarations

**`:=` is strongly preferred** for all local variables with initializers.

**`var` only when:**
- Zero value is desired with no initializer: `var matchedFlows []*types.Flow`
- Type needs to be explicit: `var err error`
- Package-level declarations in `var()` blocks

**Declare close to first use**, not all at the top of the function:

```go
var matchedFlows []*types.Flow
var totalMatchedCount int

pageStart := int(opts.page * opts.pageSize)

// Iterate through the DiachronicFlows...
```

---

## Error Handling

**Combined form** when error is only needed for the check:

```go
if err := e.client.Post(rdr); err != nil {
	return err
}
```

**Separated form** when both result and error are needed:

```go
grpcClient, err := grpc.NewClient(server, opts...)
if err != nil {
	return nil, err
}
```

**Error messages:** `fmt.Errorf` with `%v` (NOT `%w`), lowercase, descriptive:

```go
return fmt.Errorf("failed to find bucket for flow")
return fmt.Errorf("error getting configmap: %v", err)
return fmt.Errorf("startTimeGt (%d) must be less than startTimeLt (%d)", startTimeGt, startTimeLt)
```

**Sentinel errors** as package-level variables:

```go
var ErrStopBucketIteration = errors.New("stop bucket iteration")
```

Compared with `errors.Is`:

```go
if errors.Is(err, ErrStopBucketIteration) {
```

---

## Comments

**Doc comments on exported types/functions** start with the name:

```go
// Emitter is a type that emits aggregated Flow objects to an HTTP endpoint.
type Emitter struct {

// Run starts Goldmane and returns a channel to wait for readiness.
func (a *Goldmane) Run(startTime int64) <-chan struct{} {
```

**Inline comments** above code blocks, preceded by a blank line (unless at
function start). First word capitalized. Period at end is optional - the
codebase is inconsistent but more often omits it:

```go
	// Initialize the buckets.
	opts := []storage.BucketRingOption{

	// Schedule the first rollover one aggregation period from now.
	rolloverCh := a.rolloverFunc(a.bucketDuration)
```

**Struct field comments** go above the field, not beside it. Put a blank line
before a field's comment if the previous line is a field declaration (not another
comment). This visually separates fields from each other:

```go
type Goldmane struct {
	// streams is responsible for managing active streams.
	streams stream.StreamManager

	// flowStore is the main data structure used to store flows.
	flowStore *storage.BucketRing
```

**TODO format**: `// TODO:` followed by the description.

Only single-line comments (`//`). Never block comments (`/* */`).

---

## Function Organization

**Files organized by concept** - one type per file with all its methods.

**Constructor near the top**: `New*` functions appear close to the type definition.

**Functional options in separate file**: `options.go` with `Option` type alias
and `With*` functions:

```go
type Option func(*Goldmane)

func WithRolloverTime(rollover time.Duration) Option {
	return func(a *Goldmane) {
		a.bucketDuration = rollover
	}
}
```

**`init()` after package-level `var` blocks**, before type definitions.

---

## Naming

**Receivers:** Single letter or very short, consistent across all methods on
a type:
- `a` for aggregator, `b` for bucket, `r` for ring, `d` for diachronic flow
- `e` for emitter, `s` for server/stream, `c` for client/cache
- `m` for manager, `w` for window, `k` for key
- `idx` for index (when single letter is ambiguous)

**Parameters:** Full descriptive names, not abbreviations:
- `flow`, `stream`, `start`, `end`, `recv`, `opts`

**Named returns:** Not used. All returns are unnamed.

---

## Logging

`logrus` exclusively. Patterns:

```go
// Single field
logrus.WithField("key", val).Debug("message")

// Multiple fields
logrus.WithFields(logrus.Fields{
	"start": flow.StartTime,
	"end":   flow.EndTime,
}).Debug("Processing flow")

// Errors - use WithError, not format strings
logrus.WithError(err).Warn("Failed to close client")

// Chained
logrus.WithFields(logrus.Fields{...}).WithError(err).Warn("message")

// Guard expensive debug logging
if logrus.IsLevelEnabled(logrus.DebugLevel) {
	logrus.WithFields(logrus.Fields{...}).Debug("Expensive message")
}
```

---

## Other Patterns

**Defer for cleanup:**

```go
b.Lock()
defer b.Unlock()

ctx, cancel := context.WithCancel(context.Background())
defer cancel()
```

**Channel signaling** - close a channel to signal readiness:

```go
ready := make(chan struct{})
go a.run(startTime, ready)
return ready
```

**Copyright header** on every file:

```go
// Copyright (c) 2025 Tigera, Inc. All rights reserved.

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
```

**Test setup** returns a cleanup function:

```go
func setupTest(t *testing.T, opts ...goldmane.Option) func() {
	RegisterTestingT(t)
	gm = goldmane.NewGoldmane(opts...)
	return func() {
		gm.Stop()
		gm = nil
	}
}

func TestList(t *testing.T) {
	defer setupTest(t, opts...)()
```

**Generics** used where appropriate for index/cache types.
