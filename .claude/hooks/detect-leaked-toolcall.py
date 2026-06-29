#!/usr/bin/env python3
"""Stop/SubagentStop hook: detect leaked tool-call markup in the last assistant
message. If the model emitted `<invoke name=` / `<function_calls>` /
`<parameter name=` as plain TEXT (instead of a real tool call), block the stop
so the model re-emits it correctly.

Ref: https://zenn.dev/ultimatile/articles/claude-code-leaked-tool-call-stop-hook
"""
import json
import os
import re
import sys

LOG_PATH = os.path.join(os.path.dirname(__file__), "leaked-toolcall-triggers.log")

# 行頭の漏れたツール呼び出しマークアップ (namespace prefix 付きも含む)。
LEAK_RE = re.compile(
    r"^[ \t]*<(?:[A-Za-z][\w.-]*:)?"
    r"(?:invoke\s+name=|function_calls\s*>|parameter\s+name=)",
    re.M,
)


def last_assistant_text(transcript_path):
    text = ""
    try:
        with open(transcript_path) as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    ev = json.loads(line)
                except json.JSONDecodeError:
                    continue
                msg = ev.get("message") or {}
                if ev.get("type") == "assistant" or msg.get("role") == "assistant":
                    content = msg.get("content", ev.get("content"))
                    if isinstance(content, str):
                        text = content
                    elif isinstance(content, list):
                        text = "".join(
                            b.get("text", "")
                            for b in content
                            if isinstance(b, dict) and b.get("type") == "text"
                        )
    except OSError:
        pass
    return text


def main():
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        sys.exit(0)

    # 差し戻しは 1 ターン 1 回まで (無限ループ防止)。
    if payload.get("stop_hook_active"):
        sys.exit(0)

    text = last_assistant_text(payload.get("transcript_path", ""))
    m = LEAK_RE.search(text)
    if m:
        try:  # トリガ記録 (fail-open)
            with open(LOG_PATH, "a") as f:
                f.write(json.dumps({
                    "session_id": payload.get("session_id", ""),
                    "transcript_path": payload.get("transcript_path", ""),
                    "matched": m.group(0).strip(),
                }, ensure_ascii=False) + "\n")
        except OSError:
            pass
        print(json.dumps({
            "decision": "block",
            "reason": (
                "直前の応答にテキストとして漏れたツール呼び出しがあります "
                "(`<invoke name=` 等)。正しい形式 (antml: プレフィックス付きの "
                "invoke/parameter タグ) で当該ツール呼び出しを再発行してください。"
            ),
        }))
    sys.exit(0)


def _selftest():
    leaks = [
        '<invoke name="Bash">',
        '  <invoke name="Bash">',
        '<parameter name="command">x</parameter>',
        '<function_calls>',
    ]
    clean = [
        "通常のテキスト応答です。",
        "コード例: `invoke name=` をインラインで説明 (行頭でない)。",
        "<div>html</div>",
    ]
    for s in leaks:
        assert LEAK_RE.search(s), f"should detect: {s!r}"
    for s in clean:
        assert not LEAK_RE.search(s), f"false positive: {s!r}"
    print("selftest OK")


if __name__ == "__main__":
    if "--selftest" in sys.argv:
        _selftest()
    else:
        main()
