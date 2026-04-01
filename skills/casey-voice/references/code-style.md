# Code Style Reference

Detailed patterns for writing Go code in Casey's style. These patterns were
extracted from real code across tigera/operator and projectcalico/calico.

## Naming Conventions

### Variables

Broader scope = more descriptive name. Tight local scope = abbreviation is fine.

**Good -- descriptive names for struct fields and parameters:**
```go
needsNamespaceMigration    // not needNsMigration
kubeControllerPrometheusTLS // not kubecontrollerprometheusTLS
certKeyPairOptions
webhooksTLS
installationSpec
managementClusterConnection
```

**Good -- short names for local/loop scope:**
```go
objs
fs
dir
b
doc
obj
```

**Avoid:**
- Single-letter names outside of loop variables or very short closures
- Abbreviations that aren't universally understood in the codebase
- Overly long names that restate the type (`mutatingAdmissionPolicyObject`)

### Functions

Verb-first, action-oriented. PascalCase exported, camelCase internal.

```go
GetMutatingAdmissionPolicies()
parseAdmissionPolicyYAML()
validateAPIServerResource()
updateMutatingAdmissionPolicies()
Ensure()  // single word is fine when meaning is clear from package context
```

### Constants

PascalCase with descriptive names and clear suffixes:

```go
ManagedMAPLabel      = "operator.tigera.io/mutating-admission-policy"
ManagedMAPLabelValue = "managed"
WebhooksTLSSecretName
WebhooksName
WebhooksPolicyName
```

## Comment Patterns

### Function Documentation

Start with the function name (Go convention). First line states core behavior,
subsequent lines document edge cases or constraints. Typically 2-3 lines.

```go
// GetMutatingAdmissionPolicies returns MutatingAdmissionPolicy and MutatingAdmissionPolicyBinding
// objects for the given variant. These are only applicable when v3 CRDs are enabled.
// Each returned object is labeled with ManagedMAPLabel to enable stale resource cleanup.
func GetMutatingAdmissionPolicies(variant opv1.ProductVariant, v3 bool) []client.Object {
```

```go
// Ensure ensures that MutatingAdmissionPolicies necessary for bootstrapping exist in the cluster.
// Further reconciliation is handled by the core controller. If the API is not available (K8s < 1.32),
// a warning is logged and the function returns nil. MAPs are only installed when v3 CRDs are enabled.
func Ensure(c client.Client, variant string, v3 bool, log logr.Logger) error {
```

Don't over-document obvious functions. A simple getter doesn't need a paragraph.

### Constant Documentation

One-line doc comments that explain purpose, not just restate the name:

```go
// ManagedMAPLabel is the label key applied to operator-managed MutatingAdmissionPolicy and
// MutatingAdmissionPolicyBinding resources.
ManagedMAPLabel = "operator.tigera.io/mutating-admission-policy"
```

### Block Comments for Complex Logic

When explaining ordering dependencies, architectural constraints, or non-obvious
design decisions, use numbered block comments. These are the most distinctive
pattern in Casey's code:

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

Another example -- explaining a design choice:

```go
// Use RollingUpdate to avoid downtime during rollouts. Since this is a webhook with
// FailurePolicy=Fail, using Recreate would cause a window where no webhook pod is running,
// blocking all matching API requests.
Type: appsv1.RollingUpdateDeploymentStrategyType,
```

### Where Comments Go

- **Own line above the code**, never inline at end of a line
- On every exported function, type, and constant
- On significant conditional branches that involve business logic
- On architectural or ordering decisions
- NOT on straightforward control flow, variable assignments, or obvious operations

**Branch comments go inside the branch, not above the if/else.** If a comment
explains why a particular branch is taken, put it as the first line inside that
branch body:

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

This keeps the comment co-located with the code it actually describes.

### Struct Field Comments (API Types)

For Kubernetes CRD types, write thorough user-facing doc comments that explain
behavior, defaults, and interactions:

```go
// HostNetwork forces the webhook pod to use the host's network namespace.
// When true, the webhook pod will run with hostNetwork=true and DNSPolicy=ClusterFirstWithHostNet.
// When nil or omitted, the operator auto-detects whether host networking is required
// (e.g., for EKS/TKG with Calico CNI).
// +optional
HostNetwork *bool `json:"hostNetwork,omitempty"`
```

## Code Organization

### File Structure (top to bottom)

1. Copyright header
2. Package declaration
3. Imports (grouped: stdlib, k8s/external, internal project)
4. Constants
5. Package-level vars (embed directives, etc.)
6. Exported functions (public API first)
7. Unexported helper functions

### Guard Clauses

Handle edge cases first with early returns, then proceed with main logic:

```go
func Ensure(c client.Client, variant string, v3 bool, log logr.Logger) error {
    if !v3 {
        return nil
    }
    // ... main logic follows, unindented
}
```

### Error Handling

Wrap errors with `fmt.Errorf`, lowercase messages, describe the failed action:

```go
return fmt.Errorf("failed to create projectcalico.org/v3 client: %w", err)
return fmt.Errorf("failed to create %s %s: %s", obj.GetObjectKind()..., obj.GetName(), err)
return fmt.Errorf("APIServer spec.CalicoWebhooksDeployment is not valid: %w", err)
```

### Struct Consolidation

When a struct accumulates too many passthrough fields, consolidate into an
options struct:

```go
// Prefer this:
type ReconcileAPIServer struct {
    client         client.Client
    scheme         *runtime.Scheme
    status         status.StatusManager
    tierWatchReady *utils.ReadyFlag
    opts           options.ControllerOptions
}

// Over this:
type ReconcileAPIServer struct {
    client              client.Client
    scheme              *runtime.Scheme
    provider            operatorv1.Provider
    enterpriseCRDsExist bool
    status              status.StatusManager
    clusterDomain       string
    tierWatchReady      *utils.ReadyFlag
    multiTenant         bool
    kubernetesVersion   *common.VersionInfo
}
```

## Test Style

Using Ginkgo/Gomega, write descriptive `It()` blocks that read as sentences.
Include custom failure messages in matchers:

```go
It("returns Calico MAPs when v3=true", func() {
    objs := GetMutatingAdmissionPolicies(opv1.Calico, true)
    Expect(objs).To(HaveLen(4), "Expected 4 admission objects, got %d", len(objs))
})
```

## Multi-line Formatting

When a function call or composite literal doesn't fit on one line, put each
argument or element on its own line. Don't pack several on one line and wrap
the rest — either everything fits on one line, or each item gets its own.

```go
// Good -- all on one line (short enough):
verbs, err := authzreview.PerformReview(ctx, calculator, usr, cluster, attrs)

// Good -- one arg per line (too long for one line):
verbs, err := authzreview.PerformReview(
	req.Context(),
	h.calculator,
	h.csFactory,
	userInfo,
	clusterID,
	in.Spec.ResourceAttributes,
)

// Bad -- mixed packing:
verbs, err := authzreview.PerformReview(
	req.Context(), h.calculator, h.csFactory,
	userInfo, clusterID, in.Spec.ResourceAttributes,
)
```

Same rule applies to slice elements. Either all elements fit on one line, or
each gets its own line. No mixing.

```go
// Good:
Resources: []string{"pods", "nodes", "events"},

// Good:
Resources: []string{
	"hostendpoints",
	"networksets",
	"globalnetworksets",
},

// Bad -- wrapping mid-list:
Resources: []string{
	"hostendpoints", "networksets", "globalnetworksets",
	"packetcaptures",
},
```

The 180-character threshold is a reasonable guide for when to split, but use
judgment — clarity matters more than a hard limit.

## Blank Lines and Formatting

Preserve readability with blank lines:
- Between functions
- After guard clause blocks
- Between logical sections within a function
- In import blocks between groups

Don't let formatters strip these out -- they make the code easier to scan.
