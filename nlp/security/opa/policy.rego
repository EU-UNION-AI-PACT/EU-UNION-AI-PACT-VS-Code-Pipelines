package nlp

default allow = false

# Input schema example:
# {
#   "action": "ingest" | "export",
#   "classification": "internal",
#   "user_roles": ["data-steward"]
# }

allow {
  input.action == "ingest"
  "data-steward" in input.user_roles
}

allow {
  input.action == "query"
  input.classification == "public"
}

allow {
  input.action == "query"
  input.classification == "internal"
  some r
  r := input.user_roles[_]
  r == "employee"
}

deny_export[msg] {
  input.action == "export"
  input.classification != "public"
  msg := sprintf("Export verboten für Klassifikation %s", [input.classification])
}

allow {
  input.action == "export"
  input.classification == "public"
}
