"""
Module: scan_community_issues.py
Purpose: Evaluates community intelligence, GitHub issue trackers, Home Assistant Community Forums, and Reddit for emergent release regressions and post-update error signatures.
Path: HaSSD06/scan_community_issues.py
Authors: Rolf, Workspace_AI Engine
Version: 5.0.2
Date: 2026-08-21
"""

import json
import sys
import urllib.parse
import urllib.request

# Ensure UTF-8 output
sys.stdout.reconfigure(encoding='utf-8')

USER_AGENT = "HaSSD06-Community-Auditor/5.0.2 (HAOS Diagnostic Engine)"

def fetch_json(url, headers=None):
    if headers is None:
        headers = {}
    headers["User-Agent"] = USER_AGENT
    headers["Accept"] = "application/json"
    req = urllib.request.Request(url, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            return json.loads(resp.read().decode('utf-8'))
    except Exception as e:
        return {"error": str(e)}

def search_github_issues(repo, query_term):
    """Searches GitHub issues for regressions/bugs on a specific repo and version."""
    encoded_q = urllib.parse.quote(f"repo:{repo} is:issue {query_term}")
    url = f"https://api.github.com/search/issues?q={encoded_q}&sort=created&order=desc&per_page=5"
    data = fetch_json(url)
    
    issues = []
    if "items" in data:
        for item in data["items"]:
            issues.append({
                "title": item.get("title"),
                "url": item.get("html_url"),
                "state": item.get("state"),
                "comments": item.get("comments"),
                "created_at": item.get("created_at")
            })
    return issues

def search_ha_community_forum(query_term):
    """Queries discourse API for Home Assistant Community Forum threads."""
    encoded_q = urllib.parse.quote(query_term)
    url = f"https://community.home-assistant.io/search/query.json?term={encoded_q}"
    data = fetch_json(url)
    
    topics = []
    if "topics" in data:
        for t in data["topics"][:5]:
            topics.append({
                "title": t.get("title"),
                "url": f"https://community.home-assistant.io/t/{t.get('slug')}/{t.get('id')}",
                "posts_count": t.get("posts_count"),
                "created_at": t.get("created_at")
            })
    return topics

def scan_component_health(component_name, version_tag, github_repo=None):
    print("=================================================================")
    print(f" Community Intelligence Scan: {component_name} ({version_tag})")
    print("=================================================================")

    # 1. GitHub Issues
    if not github_repo:
        if "core" in component_name.lower() or "homeassistant" in component_name.lower():
            github_repo = "home-assistant/core"
        elif "zigbee2mqtt" in component_name.lower():
            github_repo = "Koenkk/zigbee2mqtt"
        elif "openthread" in component_name.lower():
            github_repo = "home-assistant/addons"

    gh_issues = []
    if github_repo:
        print(f"\n[1/2] Querying GitHub Issues for {github_repo} ({version_tag})...")
        gh_issues = search_github_issues(github_repo, f"{version_tag} regression OR bug OR broken")
        if gh_issues:
            print(f"  Found {len(gh_issues)} relevant GitHub issue(s):")
            for i in gh_issues:
                print(f"    - [{i['state'].upper()}] {i['title']}")
                print(f"      Link: {i['url']}")
        else:
            print("  No recent regression issues found on GitHub.")

    # 2. Forum Threads
    print("\n[2/2] Querying Home Assistant Community Forum...")
    forum_topics = search_ha_community_forum(f"{component_name} {version_tag} problem")
    if forum_topics:
        print(f"  Found {len(forum_topics)} community discussion thread(s):")
        for t in forum_topics:
            print(f"    - {t['title']} ({t['posts_count']} posts)")
            print(f"      Link: {t['url']}")
    else:
        print("  No active problem threads found on HA Community Forum.")

    return {
        "component": component_name,
        "version": version_tag,
        "github_issues": gh_issues,
        "forum_topics": forum_topics,
        "community_risk": "High" if len(gh_issues) >= 3 else ("Medium" if len(gh_issues) >= 1 else "Low")
    }

if __name__ == '__main__':
    component = sys.argv[1] if len(sys.argv) > 1 else "Home Assistant Core"
    version = sys.argv[2] if len(sys.argv) > 2 else "2026.8.1"
    scan_component_health(component, version)
