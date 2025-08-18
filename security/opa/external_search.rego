package external.search

default allow = false

# Allow external search for analysts and researchers
allow {
  input.action == "external_search"
  some r
  r := input.user_roles[_]
  r in ["analyst", "researcher", "admin"]
}

# Deny if query is too large
deny[msg] {
  input.action == "external_search"
  count(input.query) > 512
  msg := "Query too large (max 512 characters)"
}

# Deny if too many requests per minute
deny[msg] {
  input.action == "external_search"
  input.requests_per_minute > 30
  msg := "Rate limit exceeded (max 30 requests per minute)"
}

# Allow sandbox execution only for trusted users
allow {
  input.action == "sandbox_execute"
  some r
  r := input.user_roles[_]
  r in ["developer", "admin"]
  input.code_size <= 4000
}

# Deny dangerous code patterns in sandbox
deny[msg] {
  input.action == "sandbox_execute"
  contains(input.code, "import os")
  msg := "OS imports not allowed in sandbox"
}

deny[msg] {
  input.action == "sandbox_execute"
  contains(input.code, "subprocess")
  msg := "Subprocess calls not allowed in sandbox"
}

deny[msg] {
  input.action == "sandbox_execute"
  contains(input.code, "__import__")
  msg := "Dynamic imports not allowed in sandbox"
}
