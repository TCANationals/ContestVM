#!/usr/bin/env python3
"""
Provision users, workspaces, and AI integrations in NocoDB.

What it does:
1) Reads a list of user emails.
2) Creates (or reuses) workspace(s).
3) Adds each user to the workspace (creates user on invite if needed).
4) Creates (or updates) a workspace-level AI integration.
5) Optional (shared mode): creates per-user dedicated bases from a template base.

Examples:
  python scripts/provision_users_workspaces_ai.py \
    --base-url http://localhost:8080 \
    --token "$NC_TOKEN" \
    --emails-file ./emails.txt \
    --workspace-mode per-user \
    --workspace-name-template "{email_local} Workspace" \
    --workspace-role workspace-level-creator \
    --integration-subtype openai \
    --api-key "$OPENAI_API_KEY" \
    --models gpt-4.1-mini,gpt-4o-mini

  python scripts/provision_users_workspaces_ai.py \
    --base-url http://localhost:8080 \
    --token "$NC_TOKEN" \
    --emails alice@example.com,bob@example.com \
    --workspace-mode shared \
    --shared-workspace-title "Contest Workspace" \
    --integration-subtype claude \
    --integration-config-file ./anthropic-config.json \
    --update-existing-integration

  python scripts/provision_users_workspaces_ai.py \
    --base-url http://localhost:8080 \
    --token "$NC_TOKEN" \
    --emails-file ./emails.txt \
    --workspace-mode shared \
    --shared-workspace-title "Contest Workspace" \
    --shared-dedicated-bases \
    --shared-template-base-id "p_template123" \
    --dedicated-base-title-template "{email_local} Contest Base" \
    --dedicated-base-role creator \
    --reuse-existing-dedicated-base \
    --integration-subtype openai \
    --api-key "$OPENAI_API_KEY"
"""

from __future__ import annotations

import argparse
import json
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

import requests


class NocoApiError(RuntimeError):
    """Raised when a NocoDB API call fails."""


def _normalize_base_url(base_url: str) -> str:
    return base_url.rstrip("/")


def _extract_list(payload: Any, preferred_keys: tuple[str, ...]) -> list[dict[str, Any]]:
    """
    Best-effort extraction of list-like API payloads.
    Supports common response shapes used by NocoDB controllers.
    """
    if payload is None:
        return []
    if isinstance(payload, list):
        return [item for item in payload if isinstance(item, dict)]
    if isinstance(payload, dict):
        for key in preferred_keys:
            value = payload.get(key)
            if isinstance(value, list):
                return [item for item in value if isinstance(item, dict)]
        nested = payload.get("individual_members")
        if isinstance(nested, dict):
            value = nested.get("workspace_members")
            if isinstance(value, list):
                return [item for item in value if isinstance(item, dict)]
    return []


def _extract_records(payload: Any) -> list[dict[str, Any]]:
    if payload is None:
        return []
    if isinstance(payload, list):
        return [item for item in payload if isinstance(item, dict)]
    if isinstance(payload, dict):
        value = payload.get("records")
        if isinstance(value, list):
            return [item for item in value if isinstance(item, dict)]
        value = payload.get("list")
        if isinstance(value, list):
            return [item for item in value if isinstance(item, dict)]
    return []


# Field types that are generated/managed by the system.
SYSTEM_FIELD_TYPES = {
    "ID",
    "CreatedTime",
    "CreatedBy",
    "LastModifiedTime",
    "LastModifiedBy",
}

# These are skipped during template cloning because they depend on other entities
# or custom logic and often need post-processing.
DEPENDENT_FIELD_TYPES = {
    "Links",
    "LinkToAnotherRecord",
    "Lookup",
    "Rollup",
    "Formula",
    "Button",
    "Barcode",
    "QrCode",
}

# These are skipped for row-data copy for safety/reliability.
DATA_COPY_EXCLUDED_FIELD_TYPES = (
    SYSTEM_FIELD_TYPES
    | DEPENDENT_FIELD_TYPES
    | {"Attachment", "User", "Geometry"}
)


@dataclass
class NocoClient:
    base_url: str
    token: str
    use_bearer: bool = False
    timeout_seconds: float = 30.0
    verify_ssl: bool = True
    session: requests.Session = field(default_factory=requests.Session)

    def __post_init__(self) -> None:
        self.base_url = _normalize_base_url(self.base_url)
        self.session.headers.update({"Accept": "application/json"})
        if self.use_bearer:
            self.session.headers["Authorization"] = f"Bearer {self.token}"
        else:
            self.session.headers["xc-token"] = self.token

    def _request(
        self,
        method: str,
        path: str,
        *,
        params: dict[str, Any] | None = None,
        json_body: Any | None = None,
        expected: tuple[int, ...] = (200,),
    ) -> Any:
        url = f"{self.base_url}/{path.lstrip('/')}"
        try:
            response = self.session.request(
                method=method.upper(),
                url=url,
                params=params,
                json=json_body,
                timeout=self.timeout_seconds,
                verify=self.verify_ssl,
            )
        except requests.RequestException as exc:
            raise NocoApiError(f"Request error calling {method.upper()} {url}: {exc}") from exc

        if response.status_code not in expected:
            body = response.text.strip()
            if len(body) > 1200:
                body = f"{body[:1200]}..."
            raise NocoApiError(
                f"{method.upper()} {url} failed: HTTP {response.status_code}. Response: {body}"
            )

        if response.status_code == 204 or not response.content:
            return None

        content_type = response.headers.get("content-type", "")
        if "application/json" in content_type:
            return response.json()

        try:
            return response.json()
        except ValueError:
            return response.text

    def list_workspaces(self) -> list[dict[str, Any]]:
        payload = self._request("GET", "/api/v3/meta/workspaces")
        return _extract_list(payload, ("list", "workspaces"))

    def create_workspace(self, title: str, org_id: str | None = None) -> dict[str, Any]:
        body: dict[str, Any] = {"title": title}
        if org_id:
            body["org_id"] = org_id
        payload = self._request(
            "POST",
            "/api/v3/meta/workspaces",
            json_body=body,
            expected=(200, 201),
        )
        if not isinstance(payload, dict):
            raise NocoApiError(f"Unexpected workspace create response: {payload!r}")
        return payload

    def list_workspace_members(self, workspace_id: str) -> list[dict[str, Any]]:
        payload = self._request(
            "GET",
            f"/api/v3/meta/workspaces/{workspace_id}/members",
        )
        return _extract_list(payload, ("list", "workspace_members", "members"))

    def add_workspace_members(self, workspace_id: str, members: list[dict[str, str]]) -> Any:
        return self._request(
            "POST",
            f"/api/v3/meta/workspaces/{workspace_id}/members",
            json_body=members,
            expected=(200, 201),
        )

    def list_available_integrations(self) -> list[dict[str, Any]]:
        payload = self._request("GET", "/api/v2/integrations")
        return _extract_list(payload, ("list", "integrations"))

    def list_workspace_integrations(
        self,
        workspace_id: str,
        *,
        integration_type: str | None = None,
        query: str | None = None,
    ) -> list[dict[str, Any]]:
        params: dict[str, Any] = {}
        if integration_type:
            params["type"] = integration_type
        if query:
            params["query"] = query
        payload = self._request(
            "GET",
            f"/api/v2/meta/workspaces/{workspace_id}/integrations",
            params=params or None,
        )
        return _extract_list(payload, ("list", "integrations"))

    def create_workspace_integration(
        self,
        workspace_id: str,
        *,
        title: str,
        subtype: str,
        config: dict[str, Any],
        is_restricted: bool = False,
    ) -> dict[str, Any]:
        payload = self._request(
            "POST",
            f"/api/v2/meta/workspaces/{workspace_id}/integrations",
            json_body={
                "title": title,
                "config": config,
                "type": "ai",
                "sub_type": subtype,
                "is_restricted": is_restricted,
            },
            expected=(200, 201),
        )
        if not isinstance(payload, dict):
            raise NocoApiError(f"Unexpected integration create response: {payload!r}")
        return payload

    def update_integration(self, integration_id: str, body: dict[str, Any]) -> dict[str, Any]:
        payload = self._request(
            "PATCH",
            f"/api/v2/meta/integrations/{integration_id}",
            json_body=body,
            expected=(200,),
        )
        if not isinstance(payload, dict):
            raise NocoApiError(f"Unexpected integration update response: {payload!r}")
        return payload

    def list_workspace_bases(self, workspace_id: str) -> list[dict[str, Any]]:
        payload = self._request(
            "GET",
            f"/api/v3/meta/workspaces/{workspace_id}/bases",
        )
        return _extract_list(payload, ("list", "bases"))

    def create_base(
        self, workspace_id: str, title: str, meta: dict[str, Any] | None = None
    ) -> dict[str, Any]:
        body: dict[str, Any] = {"title": title}
        if isinstance(meta, dict):
            body["meta"] = meta
        payload = self._request(
            "POST",
            f"/api/v3/meta/workspaces/{workspace_id}/bases",
            json_body=body,
            expected=(200, 201),
        )
        if not isinstance(payload, dict):
            raise NocoApiError(f"Unexpected base create response: {payload!r}")
        return payload

    def list_base_tables(self, base_id: str) -> list[dict[str, Any]]:
        payload = self._request("GET", f"/api/v3/meta/bases/{base_id}/tables")
        return _extract_list(payload, ("list", "tables"))

    def get_table_schema(self, base_id: str, table_id: str) -> dict[str, Any]:
        payload = self._request(
            "GET",
            f"/api/v3/meta/bases/{base_id}/tables/{table_id}",
        )
        if not isinstance(payload, dict):
            raise NocoApiError(f"Unexpected table schema response: {payload!r}")
        return payload

    def create_table(self, base_id: str, body: dict[str, Any]) -> dict[str, Any]:
        payload = self._request(
            "POST",
            f"/api/v3/meta/bases/{base_id}/tables",
            json_body=body,
            expected=(200, 201),
        )
        if not isinstance(payload, dict):
            raise NocoApiError(f"Unexpected table create response: {payload!r}")
        return payload

    def create_field(
        self, base_id: str, table_id: str, body: dict[str, Any]
    ) -> dict[str, Any]:
        payload = self._request(
            "POST",
            f"/api/v3/meta/bases/{base_id}/tables/{table_id}/fields",
            json_body=body,
            expected=(200, 201),
        )
        if not isinstance(payload, dict):
            raise NocoApiError(f"Unexpected field create response: {payload!r}")
        return payload

    def list_table_records(
        self, base_id: str, table_id: str, *, page_size: int = 200, max_pages: int = 1000
    ) -> list[dict[str, Any]]:
        records: list[dict[str, Any]] = []
        for page in range(1, max_pages + 1):
            payload = self._request(
                "GET",
                f"/api/v3/data/{base_id}/{table_id}/records",
                params={"page": page, "pageSize": page_size},
                expected=(200,),
            )
            page_records = _extract_records(payload)
            if not page_records:
                break
            records.extend(page_records)
            if len(page_records) < page_size:
                break
        return records

    def insert_table_records(
        self, base_id: str, table_id: str, records: list[dict[str, Any]]
    ) -> Any:
        return self._request(
            "POST",
            f"/api/v3/data/{base_id}/{table_id}/records",
            json_body=records,
            expected=(200, 201),
        )

    def list_base_users(self, base_id: str) -> list[dict[str, Any]]:
        payload = self._request("GET", f"/api/v2/meta/bases/{base_id}/users")
        return _extract_list(payload, ("users", "list"))

    def invite_base_user(self, base_id: str, email: str, role: str) -> Any:
        return self._request(
            "POST",
            f"/api/v2/meta/bases/{base_id}/users",
            json_body={"email": email, "roles": role},
            expected=(200, 201),
        )

    def update_base_user_role(self, base_id: str, user_id: str, role: str) -> Any:
        return self._request(
            "PATCH",
            f"/api/v2/meta/bases/{base_id}/users/{user_id}",
            json_body={"roles": role, "base_id": base_id},
            expected=(200,),
        )


def parse_emails(emails_arg: str | None, emails_file: str | None) -> list[str]:
    raw_tokens: list[str] = []
    if emails_arg:
        raw_tokens.extend(part.strip() for part in emails_arg.split(","))
    if emails_file:
        text = Path(emails_file).read_text(encoding="utf-8")
        for line in text.splitlines():
            stripped = line.strip()
            if not stripped or stripped.startswith("#"):
                continue
            raw_tokens.extend(part.strip() for part in stripped.split(","))

    deduped: list[str] = []
    seen: set[str] = set()
    for token in raw_tokens:
        if not token:
            continue
        email = token.lower()
        if email not in seen:
            seen.add(email)
            deduped.append(email)
    return deduped


def build_integration_config(args: argparse.Namespace) -> dict[str, Any]:
    provided = sum(
        1
        for value in (
            args.integration_config_file,
            args.integration_config_json,
            args.api_key,
        )
        if value
    )
    if provided != 1:
        raise ValueError(
            "Provide exactly one of --integration-config-file, --integration-config-json, or --api-key."
        )

    if args.integration_config_file:
        text = Path(args.integration_config_file).read_text(encoding="utf-8")
        payload = json.loads(text)
        if not isinstance(payload, dict):
            raise ValueError("Integration config file must contain a JSON object.")
        return payload

    if args.integration_config_json:
        payload = json.loads(args.integration_config_json)
        if not isinstance(payload, dict):
            raise ValueError("Integration config JSON must be a JSON object.")
        return payload

    models: list[str] = []
    if args.models:
        models = [m.strip() for m in args.models.split(",") if m.strip()]

    config: dict[str, Any] = {args.api_key_field: args.api_key}
    if models:
        config[args.models_field] = models
    return config


def validate_ai_subtype_if_requested(
    client: NocoClient, subtype: str, skip_validation: bool
) -> None:
    if skip_validation:
        return

    available = client.list_available_integrations()
    ai_subtypes = sorted(
        {
            item.get("sub_type")
            for item in available
            if isinstance(item, dict)
            and item.get("type") == "ai"
            and isinstance(item.get("sub_type"), str)
        }
    )
    if not ai_subtypes:
        # If endpoint gives no data (or plugin registration is dynamic), avoid hard-fail.
        print(
            "Warning: could not determine available AI subtypes from /api/v2/integrations. Continuing.",
            file=sys.stderr,
        )
        return
    if subtype not in ai_subtypes:
        raise ValueError(
            f"AI subtype '{subtype}' is not in available list: {', '.join(ai_subtypes)}"
        )


def workspace_title_for_email(template: str, email: str) -> str:
    local = email.split("@", 1)[0]
    domain = email.split("@", 1)[1] if "@" in email else ""
    return template.format(email=email, email_local=local, email_domain=domain)


def role_choices() -> tuple[str, ...]:
    return (
        "workspace-level-creator",
        "workspace-level-editor",
        "workspace-level-viewer",
        "workspace-level-commenter",
        "workspace-level-no-access",
    )


def base_role_choices() -> tuple[str, ...]:
    return ("owner", "creator", "editor", "commenter", "viewer", "no-access")


def sanitize_field_for_clone(field: dict[str, Any]) -> dict[str, Any] | None:
    """
    Convert a table field payload from read-schema format into create-field format.
    """
    ftype = str(field.get("type", "")).strip()
    title = field.get("title")
    if not ftype or not isinstance(title, str) or not title.strip():
        return None
    if ftype in SYSTEM_FIELD_TYPES or ftype in DEPENDENT_FIELD_TYPES:
        return None

    payload: dict[str, Any] = {
        "title": title,
        "type": ftype,
    }
    if isinstance(field.get("description"), str) and field["description"].strip():
        payload["description"] = field["description"]

    if "default_value" in field:
        payload["default_value"] = field["default_value"]
    if isinstance(field.get("options"), dict):
        payload["options"] = field["options"]
    if isinstance(field.get("meta"), dict):
        payload["meta"] = field["meta"]
    if isinstance(field.get("required"), bool):
        payload["required"] = field["required"]
    if isinstance(field.get("unique"), bool):
        payload["unique"] = field["unique"]
    return payload


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Provision NocoDB workspaces, users, and AI integrations."
    )
    parser.add_argument("--base-url", required=True, help="NocoDB base URL, e.g. http://localhost:8080")
    parser.add_argument("--token", required=True, help="NocoDB auth token (xc-token or bearer)")
    parser.add_argument(
        "--use-bearer",
        action="store_true",
        help="Use Authorization: Bearer <token> instead of xc-token header.",
    )
    parser.add_argument(
        "--insecure-skip-verify",
        action="store_true",
        help="Disable TLS verification (not recommended).",
    )
    parser.add_argument("--timeout-seconds", type=float, default=30.0)
    parser.add_argument("--org-id", default=None, help="Optional org_id for workspace creation.")

    email_group = parser.add_mutually_exclusive_group(required=True)
    email_group.add_argument("--emails", help="Comma-separated emails.")
    email_group.add_argument("--emails-file", help="Path to file with emails (one per line or comma-separated).")

    parser.add_argument(
        "--workspace-mode",
        choices=("per-user", "shared"),
        default="per-user",
        help="Create one workspace per email, or a single shared workspace.",
    )
    parser.add_argument(
        "--workspace-name-template",
        default="{email_local} Workspace",
        help="Template for per-user workspace title. Available placeholders: {email}, {email_local}, {email_domain}",
    )
    parser.add_argument(
        "--shared-workspace-title",
        default=None,
        help="Workspace title to use in shared mode.",
    )
    parser.add_argument(
        "--workspace-role",
        choices=role_choices(),
        default="workspace-level-creator",
        help="Role assigned when adding user to workspace.",
    )
    parser.add_argument(
        "--reuse-existing-workspace",
        action="store_true",
        help="Reuse existing workspace by exact title instead of creating duplicates.",
    )
    parser.add_argument(
        "--shared-template-base-id",
        default=None,
        help=(
            "Template base ID to clone from when using shared workspace mode. "
            "Requires --shared-dedicated-bases."
        ),
    )
    parser.add_argument(
        "--shared-dedicated-bases",
        action="store_true",
        help=(
            "In shared workspace mode, create (or reuse) a dedicated base per user and "
            "grant base-level permissions."
        ),
    )
    parser.add_argument(
        "--dedicated-base-title-template",
        default="{email_local} Base",
        help=(
            "Template for dedicated base title in shared mode. "
            "Available placeholders: {email}, {email_local}, {email_domain}"
        ),
    )
    parser.add_argument(
        "--dedicated-base-role",
        choices=base_role_choices(),
        default="creator",
        help="Base-level role assigned to the user for their dedicated base.",
    )
    parser.add_argument(
        "--reuse-existing-dedicated-base",
        action="store_true",
        help="Reuse existing dedicated base by exact title in the shared workspace.",
    )
    parser.add_argument(
        "--skip-template-data-copy",
        action="store_true",
        help="Only clone table schema from template base, skip row data copy.",
    )
    parser.add_argument(
        "--record-copy-batch-size",
        type=int,
        default=100,
        help="Batch size for record inserts when cloning template data (default: 100).",
    )

    parser.add_argument(
        "--integration-subtype",
        required=True,
        help="AI integration subtype, e.g. openai or claude.",
    )
    parser.add_argument(
        "--integration-title-template",
        default="{workspace_title} - {subtype}",
        help="Template for integration title. Available placeholders: {workspace_title}, {subtype}",
    )
    parser.add_argument(
        "--reuse-existing-integration",
        action="store_true",
        help="Skip create if an AI integration with matching title+subtype already exists.",
    )
    parser.add_argument(
        "--update-existing-integration",
        action="store_true",
        help="If integration exists, PATCH it with the new config/title.",
    )
    parser.add_argument(
        "--skip-subtype-validation",
        action="store_true",
        help="Skip validation against /api/v2/integrations list.",
    )

    cfg_group = parser.add_argument_group("Integration config input (choose exactly one)")
    cfg_group.add_argument("--integration-config-file", help="Path to JSON file for integration config.")
    cfg_group.add_argument("--integration-config-json", help="Inline JSON object for integration config.")
    cfg_group.add_argument("--api-key", help="Convenience mode: API key value for generated config.")
    cfg_group.add_argument(
        "--api-key-field",
        default="apiKey",
        help="Field name used with --api-key (default: apiKey).",
    )
    cfg_group.add_argument(
        "--models",
        default=None,
        help="Comma-separated model IDs used with --api-key mode.",
    )
    cfg_group.add_argument(
        "--models-field",
        default="models",
        help="Field name used for --models (default: models).",
    )

    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Show intended actions without creating/updating resources.",
    )
    parser.add_argument(
        "--fail-fast",
        action="store_true",
        help="Stop at first email failure.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    emails = parse_emails(args.emails, args.emails_file)
    if not emails:
        print("No emails provided after parsing input.", file=sys.stderr)
        return 2

    if args.workspace_mode == "shared" and not args.shared_workspace_title:
        print("--shared-workspace-title is required when --workspace-mode=shared", file=sys.stderr)
        return 2
    if args.shared_dedicated_bases and args.workspace_mode != "shared":
        print("--shared-dedicated-bases requires --workspace-mode=shared", file=sys.stderr)
        return 2
    if args.shared_dedicated_bases and not args.shared_template_base_id:
        print("--shared-template-base-id is required with --shared-dedicated-bases", file=sys.stderr)
        return 2
    if args.record_copy_batch_size < 1:
        print("--record-copy-batch-size must be >= 1", file=sys.stderr)
        return 2

    try:
        integration_config = build_integration_config(args)
    except Exception as exc:
        print(f"Invalid integration config input: {exc}", file=sys.stderr)
        return 2

    client = NocoClient(
        base_url=args.base_url,
        token=args.token,
        use_bearer=args.use_bearer,
        timeout_seconds=args.timeout_seconds,
        verify_ssl=not args.insecure_skip_verify,
    )

    try:
        validate_ai_subtype_if_requested(
            client=client,
            subtype=args.integration_subtype,
            skip_validation=args.skip_subtype_validation or args.dry_run,
        )
    except Exception as exc:
        print(f"Subtype validation failed: {exc}", file=sys.stderr)
        return 2

    existing_workspaces_by_title: dict[str, dict[str, Any]] = {}
    if args.reuse_existing_workspace and not args.dry_run:
        for ws in client.list_workspaces():
            title = ws.get("title")
            if isinstance(title, str) and title not in existing_workspaces_by_title:
                existing_workspaces_by_title[title] = ws

    workspace_member_cache: dict[str, set[str]] = {}
    workspace_integration_cache: dict[str, list[dict[str, Any]]] = {}
    workspace_base_cache: dict[str, dict[str, dict[str, Any]]] = {}
    base_member_cache: dict[str, dict[str, dict[str, Any]]] = {}
    template_tables_cache: list[dict[str, Any]] | None = None

    results: list[dict[str, Any]] = []
    failed = False

    def ensure_workspace(title: str) -> dict[str, Any]:
        if args.reuse_existing_workspace:
            existing = existing_workspaces_by_title.get(title)
            if existing:
                return existing
        if args.dry_run:
            return {"id": f"dryrun::{title}", "title": title}
        created = client.create_workspace(title=title, org_id=args.org_id)
        if args.reuse_existing_workspace:
            existing_workspaces_by_title[title] = created
        return created

    def ensure_member(workspace_id: str, email: str) -> str:
        if workspace_id not in workspace_member_cache:
            if args.dry_run:
                workspace_member_cache[workspace_id] = set()
            else:
                members = client.list_workspace_members(workspace_id)
                workspace_member_cache[workspace_id] = {
                    m.get("email", "").lower()
                    for m in members
                    if isinstance(m.get("email"), str)
                }
        if email in workspace_member_cache[workspace_id]:
            return "already_member"
        if args.dry_run:
            workspace_member_cache[workspace_id].add(email)
            return "would_add_member"
        client.add_workspace_members(
            workspace_id,
            [{"email": email, "workspace_role": args.workspace_role}],
        )
        workspace_member_cache[workspace_id].add(email)
        return "member_added"

    def ensure_integration(workspace_id: str, workspace_title: str) -> tuple[str, str]:
        title = args.integration_title_template.format(
            workspace_title=workspace_title,
            subtype=args.integration_subtype,
        )

        if workspace_id not in workspace_integration_cache:
            if args.dry_run:
                workspace_integration_cache[workspace_id] = []
            else:
                workspace_integration_cache[workspace_id] = client.list_workspace_integrations(
                    workspace_id,
                    integration_type="ai",
                )

        existing = None
        for item in workspace_integration_cache[workspace_id]:
            if (
                item.get("title") == title
                and item.get("sub_type") == args.integration_subtype
                and item.get("type") == "ai"
            ):
                existing = item
                break

        if existing:
            integration_id = str(existing.get("id", ""))
            if args.update_existing_integration:
                if args.dry_run:
                    return "would_update_integration", integration_id or "<existing>"
                updated = client.update_integration(
                    integration_id,
                    {
                        "title": title,
                        "config": integration_config,
                        "sub_type": args.integration_subtype,
                        "type": "ai",
                        "is_restricted": False,
                    },
                )
                return "integration_updated", str(updated.get("id", integration_id))
            if args.reuse_existing_integration:
                return "integration_reused", integration_id or "<existing>"

        if args.dry_run:
            return "would_create_integration", f"dryrun::{workspace_id}::{title}"

        created = client.create_workspace_integration(
            workspace_id=workspace_id,
            title=title,
            subtype=args.integration_subtype,
            config=integration_config,
            is_restricted=False,
        )
        workspace_integration_cache[workspace_id].append(created)
        return "integration_created", str(created.get("id", ""))

    def ensure_workspace_bases_index(workspace_id: str) -> dict[str, dict[str, Any]]:
        if workspace_id not in workspace_base_cache:
            if args.dry_run:
                workspace_base_cache[workspace_id] = {}
            else:
                bases = client.list_workspace_bases(workspace_id)
                workspace_base_cache[workspace_id] = {
                    str(base.get("title")): base
                    for base in bases
                    if isinstance(base.get("title"), str)
                }
        return workspace_base_cache[workspace_id]

    def ensure_base_member(base_id: str, email: str) -> str:
        if base_id not in base_member_cache:
            if args.dry_run:
                base_member_cache[base_id] = {}
            else:
                members = client.list_base_users(base_id)
                member_index: dict[str, dict[str, Any]] = {}
                for member in members:
                    raw_email = member.get("email")
                    if isinstance(raw_email, str) and raw_email.strip():
                        member_index[raw_email.lower()] = member
                base_member_cache[base_id] = member_index

        existing = base_member_cache[base_id].get(email)
        if existing:
            current_role = existing.get("roles") or existing.get("base_role")
            if current_role == args.dedicated_base_role:
                return "base_member_already_has_role"

            user_id = existing.get("id") or existing.get("user_id") or existing.get("fk_user_id")
            if not user_id:
                return "base_member_exists_role_unknown"

            if args.dry_run:
                return "would_update_base_member_role"

            client.update_base_user_role(base_id, str(user_id), args.dedicated_base_role)
            existing["roles"] = args.dedicated_base_role
            existing["base_role"] = args.dedicated_base_role
            return "base_member_role_updated"

        if args.dry_run:
            base_member_cache[base_id][email] = {
                "email": email,
                "roles": args.dedicated_base_role,
            }
            return "would_add_base_member"

        client.invite_base_user(base_id, email, args.dedicated_base_role)
        base_member_cache[base_id][email] = {
            "email": email,
            "roles": args.dedicated_base_role,
        }
        return "base_member_added"

    def get_template_tables() -> list[dict[str, Any]]:
        nonlocal template_tables_cache
        if template_tables_cache is not None:
            return template_tables_cache
        if args.dry_run:
            template_tables_cache = []
            return template_tables_cache

        template_base_id = str(args.shared_template_base_id)
        templates: list[dict[str, Any]] = []
        for item in client.list_base_tables(template_base_id):
            table_id = item.get("id")
            if not isinstance(table_id, str) or not table_id:
                continue
            templates.append(client.get_table_schema(template_base_id, table_id))
        template_tables_cache = templates
        return template_tables_cache

    def clone_template_base_into(base_id: str) -> dict[str, Any]:
        """
        Best-effort clone: table schema + optional row data.
        Dependent/system fields are skipped by design.
        """
        if args.dry_run:
            return {
                "tables_created": 0,
                "fields_created": 0,
                "records_copied": 0,
                "warning_count": 0,
            }

        template_base_id = str(args.shared_template_base_id)
        template_tables = get_template_tables()
        stats = {
            "tables_created": 0,
            "fields_created": 0,
            "records_copied": 0,
            "warning_count": 0,
        }

        for src_table in template_tables:
            src_table_id = src_table.get("id")
            src_table_title = src_table.get("title")
            if not isinstance(src_table_id, str) or not isinstance(src_table_title, str):
                continue

            table_body: dict[str, Any] = {"title": src_table_title}
            if isinstance(src_table.get("description"), str) and src_table["description"].strip():
                table_body["description"] = src_table["description"]
            if isinstance(src_table.get("meta"), dict):
                table_body["meta"] = src_table["meta"]

            source_fields = (
                src_table.get("fields")
                if isinstance(src_table.get("fields"), list)
                else []
            )
            cloned_fields: list[dict[str, Any]] = []
            data_copyable_titles: list[str] = []
            for source_field in source_fields:
                if not isinstance(source_field, dict):
                    continue
                field_payload = sanitize_field_for_clone(source_field)
                if not field_payload:
                    continue
                cloned_fields.append(field_payload)
                if str(source_field.get("type")) not in DATA_COPY_EXCLUDED_FIELD_TYPES:
                    data_copyable_titles.append(str(field_payload.get("title")))

            created_table: dict[str, Any]
            created_field_titles: set[str] = set()
            try:
                body_with_fields = dict(table_body)
                if cloned_fields:
                    body_with_fields["fields"] = cloned_fields
                created_table = client.create_table(base_id, body_with_fields)
                created_field_titles = {
                    str(field.get("title"))
                    for field in cloned_fields
                    if isinstance(field.get("title"), str)
                }
                stats["fields_created"] += len(created_field_titles)
            except Exception:
                created_table = client.create_table(base_id, table_body)
                for field_payload in cloned_fields:
                    field_title = str(field_payload.get("title", ""))
                    try:
                        client.create_field(base_id, str(created_table.get("id", "")), field_payload)
                        if field_title:
                            created_field_titles.add(field_title)
                            stats["fields_created"] += 1
                    except Exception as field_exc:
                        stats["warning_count"] += 1
                        print(
                            (
                                f"Warning: could not clone field '{field_title}' from table "
                                f"'{src_table_title}': {field_exc}"
                            ),
                            file=sys.stderr,
                        )

            target_table_id = created_table.get("id")
            if not isinstance(target_table_id, str) or not target_table_id:
                raise NocoApiError(
                    f"Template clone created table without id (source: {src_table_title})"
                )
            stats["tables_created"] += 1

            if args.skip_template_data_copy:
                continue

            copy_titles = [t for t in data_copyable_titles if t in created_field_titles]
            if not copy_titles:
                continue

            records = client.list_table_records(template_base_id, src_table_id)
            if not records:
                continue

            payload_batch: list[dict[str, Any]] = []
            for record in records:
                fields_obj = record.get("fields")
                if not isinstance(fields_obj, dict):
                    continue
                clone_fields: dict[str, Any] = {
                    field_name: fields_obj[field_name]
                    for field_name in copy_titles
                    if field_name in fields_obj
                }
                if clone_fields:
                    payload_batch.append({"fields": clone_fields})

            for i in range(0, len(payload_batch), args.record_copy_batch_size):
                chunk = payload_batch[i : i + args.record_copy_batch_size]
                if not chunk:
                    continue
                try:
                    client.insert_table_records(base_id, target_table_id, chunk)
                    stats["records_copied"] += len(chunk)
                except Exception as copy_exc:
                    stats["warning_count"] += 1
                    print(
                        (
                            f"Warning: could not copy a record batch into table "
                            f"'{src_table_title}': {copy_exc}"
                        ),
                        file=sys.stderr,
                    )

        return stats

    def ensure_dedicated_base(workspace_id: str, email: str) -> dict[str, Any]:
        title = workspace_title_for_email(args.dedicated_base_title_template, email)
        bases_by_title = ensure_workspace_bases_index(workspace_id)
        existing = bases_by_title.get(title) if args.reuse_existing_dedicated_base else None

        if existing:
            base = existing
            base_status = "dedicated_base_reused"
        elif args.dry_run:
            base = {"id": f"dryrun::{workspace_id}::{title}", "title": title}
            base_status = "would_create_dedicated_base"
        else:
            base = client.create_base(workspace_id=workspace_id, title=title)
            base_status = "dedicated_base_created"
            bases_by_title[title] = base

        base_id = str(base.get("id", ""))
        if not base_id:
            raise NocoApiError(f"Dedicated base response missing id: {base!r}")

        clone_status = "template_clone_skipped_existing_base"
        clone_stats: dict[str, Any] | None = None
        if base_status in {"dedicated_base_created", "would_create_dedicated_base"}:
            clone_stats = clone_template_base_into(base_id)
            clone_status = (
                "would_clone_template_base"
                if args.dry_run
                else "template_base_cloned"
            )

        member_status = ensure_base_member(base_id, email)
        result: dict[str, Any] = {
            "dedicated_base_status": base_status,
            "dedicated_base_id": base_id,
            "dedicated_base_title": str(base.get("title", title)),
            "template_clone_status": clone_status,
            "dedicated_base_member_status": member_status,
        }
        if clone_stats is not None:
            result["template_clone_stats"] = clone_stats
        return result

    shared_workspace: dict[str, Any] | None = None
    if args.workspace_mode == "shared":
        shared_workspace = ensure_workspace(args.shared_workspace_title)
        if args.shared_dedicated_bases and not args.dry_run:
            shared_workspace_id = str(shared_workspace.get("id", ""))
            bases = client.list_workspace_bases(shared_workspace_id)
            workspace_base_cache[shared_workspace_id] = {
                str(base.get("title")): base
                for base in bases
                if isinstance(base.get("title"), str)
            }
            template_base_id = str(args.shared_template_base_id)
            if not any(str(base.get("id")) == template_base_id for base in bases):
                print(
                    (
                        f"Template base '{template_base_id}' was not found in shared workspace "
                        f"'{shared_workspace_id}'."
                    ),
                    file=sys.stderr,
                )
                return 2

    for email in emails:
        row: dict[str, Any] = {"email": email}
        try:
            if args.workspace_mode == "shared":
                workspace = shared_workspace
            else:
                ws_title = workspace_title_for_email(args.workspace_name_template, email)
                workspace = ensure_workspace(ws_title)

            workspace_id = str(workspace.get("id", ""))
            workspace_title = str(workspace.get("title", ""))
            if not workspace_id:
                raise NocoApiError(f"Workspace response missing id: {workspace!r}")

            row["workspace_id"] = workspace_id
            row["workspace_title"] = workspace_title

            member_status = ensure_member(workspace_id, email)
            row["member_status"] = member_status

            integration_status, integration_id = ensure_integration(workspace_id, workspace_title)
            row["integration_status"] = integration_status
            row["integration_id"] = integration_id

            if args.shared_dedicated_bases:
                row.update(ensure_dedicated_base(workspace_id, email))

            results.append(row)
            print(json.dumps(row, ensure_ascii=True))
        except Exception as exc:
            failed = True
            row["error"] = str(exc)
            results.append(row)
            print(json.dumps(row, ensure_ascii=True), file=sys.stderr)
            if args.fail_fast:
                break

    summary = {
        "total": len(results),
        "failed": sum(1 for r in results if "error" in r),
        "succeeded": sum(1 for r in results if "error" not in r),
        "dry_run": bool(args.dry_run),
    }
    print(json.dumps({"summary": summary}, ensure_ascii=True))

    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
