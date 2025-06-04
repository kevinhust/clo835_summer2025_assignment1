# GitHub and JIRA Integration Solution: Automatically Update Project Progress via File Changes

## 1. Overview

This document provides a complete solution to help developers automatically update JIRA project progress by monitoring file changes in a GitHub repository. As a developer with JIRA admin rights, you can use this solution to automate progress tracking in agile development, reduce manual updates, and improve team collaboration efficiency.

The solution mainly includes the following parts:
- How to use the GitHub API to detect file changes
- How to use the JIRA API to update issue status and progress
- The integration workflow design between the two
- Complete code examples and deployment guide

## 2. Detecting File Changes in GitHub

### 2.1 GitHub API Overview

GitHub provides a powerful REST API that allows developers to programmatically access repository information, including commit history and file changes. For detecting file changes, there are several methods:

#### 2.1.1 Using the Commits API

The Commits API allows you to get the commit history of a repository, including the list of files changed in each commit.

```python
# Get recent commits
GET /repos/{owner}/{repo}/commits
```

The returned data includes basic info for each commit, such as commit ID, message, author, etc. To get detailed file change info, request the details for a single commit:

```python
# Get details for a single commit
GET /repos/{owner}/{repo}/commits/{commit_sha}
```

This returns the list of files changed in the commit, including file paths and lines added/deleted.

#### 2.1.2 Using the Compare API

To compare changes between two points in time, use the Compare API:

```python
# Compare differences between two commits
GET /repos/{owner}/{repo}/compare/{base}...{head}
```

`base` and `head` can be branch names, tags, or commit SHAs. This API returns all commits and file changes between the two points, ideal for detecting changes over a period.

#### 2.1.3 Using Git CLI

Besides the API, you can use the Git CLI to detect file changes:

```bash
# Clone the repo
git clone https://github.com/{owner}/{repo}.git

# Get latest changes
git pull

# See file changes between two commits
git diff --name-status {commit1} {commit2}
```

This requires maintaining a local repo copy on the server but reduces API calls, suitable for frequent checks.

### 2.2 Authentication and Permissions

Accessing the GitHub API requires authentication, recommended via Personal Access Token (PAT):

1. Create a PAT in GitHub account settings
2. Grant the token appropriate permissions (at least `repo`)
3. Include the token in API requests:

```python
headers = {
    "Authorization": "Bearer YOUR_PERSONAL_ACCESS_TOKEN",
    "Accept": "application/vnd.github+json",
    "X-GitHub-Api-Version": "2022-11-28"
}
```

## 3. Updating Progress in JIRA

### 3.1 JIRA REST API Overview

JIRA provides a comprehensive REST API for managing projects, issues, and workflows. For updating issue progress, the main APIs are:

#### 3.1.1 Get Issue Details

Before updating, fetch the current status:

```python
# Get issue details
GET /rest/api/2/issue/{issueIdOrKey}
```

#### 3.1.2 Update Issue Fields

JIRA offers two ways to update issues:

1. **Simple update (implicit via "fields")**:

```python
# Update issue fields
PUT /rest/api/2/issue/{issueIdOrKey}

{
    "fields": {
        "summary": "New summary",
        "description": "New description"
    }
}
```

2. **Action-based update (explicit via "update")**:

```python
# Update issue via actions
PUT /rest/api/2/issue/{issueIdOrKey}

{
    "update": {
        "comment": [
            {
                "add": {
                    "body": "New comment"
                }
            }
        ]
    }
}
```

#### 3.1.3 Update Issue Status

Use the transitions API to update status:

```python
# Get available transitions
GET /rest/api/2/issue/{issueIdOrKey}/transitions

# Perform a transition
POST /rest/api/2/issue/{issueIdOrKey}/transitions

{
    "transition": {
        "id": "transitionID"
    }
}
```

### 3.2 Authentication and Permissions

To access the JIRA API, authenticate via:

1. **Basic Auth**:

```python
import base64

auth_str = base64.b64encode(f"{username}:{password}".encode()).decode()
headers = {
    "Authorization": f"Basic {auth_str}",
    "Content-Type": "application/json"
}
```

2. **API Token**:

```python
import base64

auth_str = base64.b64encode(f"{email}:{api_token}".encode()).decode()
headers = {
    "Authorization": f"Basic {auth_str}",
    "Content-Type": "application/json"
}
```

3. **OAuth** (recommended for production)

## 4. GitHub and JIRA Integration Workflow

### 4.1 Architecture

The core is a scheduled script that:
1. Detects file changes in GitHub
2. Analyzes changes and extracts info
3. Maps to JIRA issues by rules
4. Updates JIRA issue status and progress

### 4.2 Trigger Mechanisms

Several ways to trigger the integration:
1. **Scheduled**: cron job runs script regularly
2. **GitHub Webhook**: triggers script on new commits
3. **Manual**: developer runs script to sync progress
