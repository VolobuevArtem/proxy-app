#!/usr/bin/env python3
import json
import sys


def read_text(path: str) -> str:
    with open(path, "r", encoding="utf-8") as f:
        return f.read()


def json_str(s: str) -> str:
    return json.dumps(s, ensure_ascii=False)


def render(template: str, mapping: dict) -> str:
    out = template
    for k, v in mapping.items():
        out = out.replace("${" + k + "}", str(v))
    return out


def main():
    if len(sys.argv) != 4:
        print("Usage: render_templates.py TEMPLATE_JSON META_JSON OUTPUT_JSON", file=sys.stderr)
        sys.exit(2)

    template_path, meta_path, out_path = sys.argv[1], sys.argv[2], sys.argv[3]
    template = read_text(template_path)
    meta = json.loads(read_text(meta_path))

    mapping = {
        "PUBLIC_PORT": meta["public_port"],
        "INNER_PORT": meta["inner_port"],
        "HOST_JSON": json_str(meta["host"]),
        "SNI_JSON": json_str(meta["sni"]),
        "SS_METHOD_JSON": json_str(meta["ss_method"]),
        "SHADOWTLS_PASSWORD_JSON": json_str(meta["shadowtls_password"]),
    }

    # server users
    if "users" in meta:
        mapping["SS_USERS_JSON"] = json.dumps(
            [{"name": u["name"], "password": u["ss_password"]} for u in meta["users"]],
            ensure_ascii=False,
        )
    # client user
    if "ss_password" in meta:
        mapping["SS_PASSWORD_JSON"] = json_str(meta["ss_password"])

    rendered = render(template, mapping)
    # sanity: must be valid json
    obj = json.loads(rendered)
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(obj, f, ensure_ascii=False, indent=2)
        f.write("\n")


if __name__ == "__main__":
    main()

