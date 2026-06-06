#!/usr/bin/env python3
"""
RSS AI Summarization for Hyprlock
Uses OpenAI API to summarize RSS feed items
"""

import os
import sys
import json
import subprocess
from urllib.request import Request, urlopen
from urllib.error import URLError, HTTPError


def get_system_context() -> str:
    """Get system info for personalized summaries."""
    try:
        # Get key package versions
        packages = subprocess.run(
            ['pacman', '-Q', 'hyprland', 'neovim', 'waybar', 'kitty',
             'hyprlock', 'hypridle', 'hyprpaper', 'pipewire'],
            capture_output=True, text=True, timeout=5
        ).stdout.strip()

        # Get basic system info
        kernel = subprocess.run(
            ['uname', '-r'], capture_output=True, text=True, timeout=5
        ).stdout.strip()

        cpu = subprocess.run(
            ['bash', '-c', "lscpu | grep 'Model name' | cut -d':' -f2 | xargs"],
            capture_output=True, text=True, timeout=5
        ).stdout.strip()

        gpu = subprocess.run(
            ['bash', '-c', "lspci | grep -i vga | cut -d':' -f3 | head -1 | xargs"],
            capture_output=True, text=True, timeout=5
        ).stdout.strip()

        return f"""System: Arch Linux, Kernel {kernel}
Hardware: {cpu}, {gpu}
Packages: {packages}"""
    except Exception:
        return "System: Arch Linux with Hyprland"


def get_summary(items: str) -> str:
    """Call OpenAI API to summarize RSS items."""

    api_key = os.environ.get('OPENAI_API_KEY')
    if not api_key or api_key == 'sk-your-api-key-here':
        return "API key not configured"

    model = os.environ.get('OPENAI_MODEL', 'gpt-4o-mini')

    system_context = get_system_context()

    prompt = f"""Summarize these software/Linux updates in 2-3 concise sentences.
Focus ONLY on updates that directly affect my system. Mention version upgrades I should do.
Be brief, technical, and personalized. No bullet points.

MY SYSTEM:
{system_context}

UPDATES:
{items}

Summary (focus on what matters for my specific setup):"""

    payload = {
        "model": model,
        "messages": [
            {
                "role": "system",
                "content": "You are a concise technical writer. Respond only with the summary, no preamble."
            },
            {"role": "user", "content": prompt}
        ],
        "max_tokens": 150,
        "temperature": 0.3
    }

    try:
        req = Request(
            "https://api.openai.com/v1/chat/completions",
            data=json.dumps(payload).encode('utf-8'),
            headers={
                "Authorization": f"Bearer {api_key}",
                "Content-Type": "application/json"
            },
            method="POST"
        )

        with urlopen(req, timeout=15) as response:
            result = json.loads(response.read().decode('utf-8'))
            return result['choices'][0]['message']['content'].strip()

    except HTTPError as e:
        if e.code == 401:
            return "Invalid API key"
        elif e.code == 429:
            return "Rate limited"
        else:
            return f"API error ({e.code})"
    except URLError:
        return "Network error"
    except Exception:
        return "Summary unavailable"


def main():
    if len(sys.argv) < 2:
        print("No items provided")
        sys.exit(1)

    items = sys.argv[1]
    summary = get_summary(items)
    print(summary)


if __name__ == "__main__":
    main()
