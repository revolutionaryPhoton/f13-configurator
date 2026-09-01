package f13.tools.permissions
required_roles := {
    # "web_search": "chat-tools-websearch-access",
}

default allow := false

tool_allowed(tool) if {
    not tool in object.keys(required_roles)
}

tool_allowed(tool) if {
    role := required_roles[tool]
    input.authenticated
    role in input.roles
}

allowed_tools contains tool if {
    some tool in input.requested_tools
    tool_allowed(tool)
}

denied_tools contains tool if {
    some tool in input.requested_tools
    not tool_allowed(tool)
}

allow if {
    count(denied_tools) == 0
}
