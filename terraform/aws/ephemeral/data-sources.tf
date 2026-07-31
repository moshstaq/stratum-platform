# ── Ephemeral Data Sources ────────────────────────────────────────────────────
# These data sources reference session-scoped resources that are destroyed
# between working sessions to manage cost. Do not include in automated
# plan runs. Apply manually when the referenced resources are active.

data "aws_eks_cluster" "platform" {
  name = "eks-platform"
}

data "aws_iam_role" "app_pod" {
  name = "role-eks-app-stratum"
}
