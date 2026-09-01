package f13.tools.permissions_test

import rego.v1
import data.f13.tools.permissions

# Mock required roles as empty by default
mock_required_roles := {"web_search": "chat-tools-websearch-access"}

# Tool without role gate -> allowed
test_unrestricted_tool_allowed_even_unauthenticated if {
    permissions.allow with input as {
        "authenticated": false,
        "roles": [],
        "requested_tools": ["search_internal_knowledge"],
    }
        with data.f13.tools.permissions.required_roles as mock_required_roles
}

# Tool with role gate, user authenticated + has role -> allowed
test_gated_tool_allowed_with_role if {
    permissions.allow with input as {
        "authenticated": true,
        "roles": ["chat-tools-websearch-access"],
        "requested_tools": ["web_search"],
    }
        with data.f13.tools.permissions.required_roles as mock_required_roles
}

# Tool with role gate, user authenticated + has not role -> not allowed
test_gated_tool_denied_without_role if {
    not permissions.allow with input as {
        "authenticated": true,
        "roles": ["some-other-role"],
        "requested_tools": ["web_search"],
    }
        with data.f13.tools.permissions.required_roles as mock_required_roles
}

# Tool with role gate, user not authenticated -> not allowed
test_gated_tool_denied_when_not_authenticated if {
    not permissions.allow with input as {
        "authenticated": false,
        "roles": ["chat-tools-websearch-access"],
        "requested_tools": ["web_search"],
    }
        with data.f13.tools.permissions.required_roles as mock_required_roles
}

# Mix: allowed + denied tool -> not allowed
test_mixed_tools_denied_if_any_denied if {
    not permissions.allow with input as {
        "authenticated": true,
        "roles": [],
        "requested_tools": ["search_internal_knowledge", "web_search"],
    }
        with data.f13.tools.permissions.required_roles as mock_required_roles
}

# denied_tools contains missing tool
test_denied_tools_contains_missing_role_tool if {
    permissions.denied_tools == {"web_search"} with input as {
        "authenticated": true,
        "roles": [],
        "requested_tools": ["search_internal_knowledge", "web_search"],
    }
        with data.f13.tools.permissions.required_roles as mock_required_roles
}

# No requested_tools + unauthorized -> allow
test_no_requested_tools_allows if {
    permissions.allow with input as {
        "authenticated": false,
        "roles": [],
        "requested_tools": [],
    }
        with data.f13.tools.permissions.required_roles as mock_required_roles
}

# Default without role mock (no roles reuired) -> allow
test_websearch_allowed_with_real_empty_required_roles if {
    permissions.allow with input as {
        "authenticated": false,
        "roles": [],
        "requested_tools": ["web_search"],
    }
}
