package nlp.secret

default allow = false

# input: { action: "read_secret", path: "kv/app", roles:["employee"] }

allow {
  input.action == "read_secret"
  input.path == "kv/app"
  some r
  r := input.roles[_]
  r == "data-steward"
}
