## What

<!-- Describe what this PR changes. Be specific about resources created, modified, or destroyed. -->

## Why

<!-- Explain the motivation for this change. Link to any related issues or discussions. -->

## Testing done

<!-- Describe how you tested this change. Include terraform plan output summary if applicable. -->

- [ ] `terraform fmt -check -recursive` passes
- [ ] `terraform validate` passes
- [ ] `tflint --recursive` passes
- [ ] `tfsec .` passes (or exceptions documented below)
- [ ] Reviewed plan output for unexpected resource changes

## Security checklist

- [ ] IAM least-privilege verified — no wildcard actions or resources unless required and commented
- [ ] No hardcoded secrets, credentials, or tokens in any file
- [ ] `tfsec` passes with no unacknowledged HIGH/CRITICAL findings
- [ ] New variables marked `sensitive = true` where appropriate
- [ ] CODEOWNERS review requested (auto-assigned)

## Exceptions / notes

<!-- Document any tfsec/checkov ignores added and why they are acceptable. -->
