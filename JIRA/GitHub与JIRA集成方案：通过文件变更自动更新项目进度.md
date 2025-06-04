# GitHub与JIRA集成方案：通过文件变更自动更新项目进度

## 1. 概述

本文档提供了一个完整的解决方案，帮助开发者通过监控GitHub代码仓库的文件变更来自动更新JIRA项目进度。作为一名拥有JIRA管理员权限的开发者，您可以利用此方案实现敏捷开发过程中的自动化进度追踪，减少手动更新工作量，提高团队协作效率。

本方案主要包含以下几个部分：
- GitHub API的使用方法，用于检测文件变更
- JIRA API的使用方法，用于更新任务状态和进度
- 两者之间的集成工作流设计
- 完整的代码示例和部署指南

## 2. GitHub文件变更检测

### 2.1 GitHub API概述

GitHub提供了强大的REST API，允许开发者以编程方式访问仓库信息，包括提交历史、文件变更等。对于检测文件变更，主要有以下几种方法：

#### 2.1.1 使用Commits API

GitHub的Commits API允许您获取特定仓库的提交历史，包括每次提交中修改的文件列表。

```python
# 获取最近的提交
GET /repos/{owner}/{repo}/commits
```

此API返回的数据包含每次提交的基本信息，如提交ID、提交消息、作者等。但要获取详细的文件变更信息，需要进一步请求单个提交的详情：

```python
# 获取单个提交的详情
GET /repos/{owner}/{repo}/commits/{commit_sha}
```

这将返回该提交中修改的文件列表，包括文件路径、添加/删除的行数等信息。

#### 2.1.2 使用Compare API

如果您需要比较两个时间点之间的变更，可以使用Compare API：

```python
# 比较两个提交之间的差异
GET /repos/{owner}/{repo}/compare/{base}...{head}
```

这里的`base`和`head`可以是分支名、标签名或提交SHA。此API返回两个点之间的所有提交以及文件变更信息，非常适合检测特定时间段内的变更。

#### 2.1.3 使用Git命令行工具

除了直接使用GitHub API外，您还可以通过Git命令行工具来检测文件变更：

```bash
# 克隆仓库
git clone https://github.com/{owner}/{repo}.git

# 获取最新变更
git pull

# 查看两个提交之间的文件变更
git diff --name-status {commit1} {commit2}
```

这种方法需要在服务器上维护一个本地仓库副本，但可以减少API调用次数，适合频繁检查变更的场景。

### 2.2 认证与权限

访问GitHub API需要进行身份验证，推荐使用个人访问令牌(Personal Access Token)：

1. 在GitHub账户设置中创建个人访问令牌
2. 为令牌授予适当的权限（至少需要`repo`权限）
3. 在API请求中包含令牌：

```python
headers = {
    "Authorization": "Bearer YOUR_PERSONAL_ACCESS_TOKEN",
    "Accept": "application/vnd.github+json",
    "X-GitHub-Api-Version": "2022-11-28"
}
```

## 3. JIRA进度更新

### 3.1 JIRA REST API概述

JIRA提供了全面的REST API，允许开发者以编程方式管理项目、问题和工作流。对于更新任务进度，主要涉及以下API：

#### 3.1.1 获取问题详情

在更新问题之前，通常需要先获取其当前状态：

```python
# 获取问题详情
GET /rest/api/2/issue/{issueIdOrKey}
```

#### 3.1.2 更新问题字段

JIRA提供了两种更新问题的方式：

1. **简单更新（通过"fields"隐式设置）**：

```python
# 更新问题字段
PUT /rest/api/2/issue/{issueIdOrKey}

{
    "fields": {
        "summary": "新的概要",
        "description": "新的描述"
    }
}
```

2. **基于操作的更新（通过"update"显式操作）**：

```python
# 通过操作更新问题
PUT /rest/api/2/issue/{issueIdOrKey}

{
    "update": {
        "comment": [
            {
                "add": {
                    "body": "新的评论"
                }
            }
        ]
    }
}
```

#### 3.1.3 更新问题状态

更新问题状态需要使用转换(transition)API：

```python
# 获取可用的转换
GET /rest/api/2/issue/{issueIdOrKey}/transitions

# 执行转换
POST /rest/api/2/issue/{issueIdOrKey}/transitions

{
    "transition": {
        "id": "转换ID"
    }
}
```

### 3.2 认证与权限

访问JIRA API需要进行身份验证，常用的方法有：

1. **基本认证**：

```python
import base64

auth_str = base64.b64encode(f"{username}:{password}".encode()).decode()
headers = {
    "Authorization": f"Basic {auth_str}",
    "Content-Type": "application/json"
}
```

2. **API令牌**：

```python
import base64

auth_str = base64.b64encode(f"{email}:{api_token}".encode()).decode()
headers = {
    "Authorization": f"Basic {auth_str}",
    "Content-Type": "application/json"
}
```

3. **OAuth认证**（更安全，推荐用于生产环境）

## 4. GitHub与JIRA集成工作流

### 4.1 整体架构

![GitHub与JIRA集成架构](https://example.com/architecture.png)

集成工作流的核心是一个定时运行的脚本，它执行以下步骤：

1. 检测GitHub仓库中的文件变更
2. 分析变更内容，提取相关信息
3. 根据预定义的规则，映射到JIRA任务
4. 更新JIRA任务状态和进度

### 4.2 触发机制

有几种方式可以触发集成流程：

1. **定时触发**：设置cron作业，定期（如每天）运行脚本
2. **GitHub Webhook**：当有新的提交时，GitHub自动触发脚本运行
3. **手动触发**：开发者可以手动运行脚本，立即同步进度

### 4.3 数据映射

将GitHub变更映射到JIRA任务是集成的关键。常用的映射策略包括：

1. **基于提交消息**：在提交消息中包含JIRA任务ID（如"PROJ-123: 实现登录功能"）
2. **基于分支名称**：使用包含任务ID的分支名（如"feature/PROJ-123-login"）
3. **基于文件路径**：预定义文件路径与JIRA任务的映射关系

### 4.4 状态更新规则

根据文件变更情况，可以定义不同的JIRA状态更新规则，例如：

- 当特定文件首次被修改时，将任务状态更新为"进行中"
- 当包含测试的文件被修改时，将任务状态更新为"测试中"
- 当文件变更达到一定数量或覆盖特定模块时，更新任务完成百分比

## 5. 实现示例

### 5.1 环境准备

1. Python 3.6+
2. 必要的Python库：
   - requests：用于HTTP请求
   - gitpython：用于Git操作（可选）
   - python-dotenv：用于管理环境变量

安装依赖：

```bash
pip install requests gitpython python-dotenv
```

### 5.2 配置文件

创建一个`.env`文件存储配置信息：

```
# GitHub配置
GITHUB_TOKEN=your_github_token
GITHUB_OWNER=repository_owner
GITHUB_REPO=repository_name

# JIRA配置
JIRA_URL=https://your-domain.atlassian.net
JIRA_USERNAME=your_email@example.com
JIRA_API_TOKEN=your_jira_api_token
JIRA_PROJECT=PROJECT_KEY
```

### 5.3 完整代码示例

以下是一个完整的Python脚本示例，实现了基于GitHub提交消息更新JIRA任务状态：

```python
#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import re
import requests
import base64
from datetime import datetime, timedelta
from dotenv import load_dotenv

# 加载环境变量
load_dotenv()

# GitHub配置
GITHUB_TOKEN = os.getenv("GITHUB_TOKEN")
GITHUB_OWNER = os.getenv("GITHUB_OWNER")
GITHUB_REPO = os.getenv("GITHUB_REPO")

# JIRA配置
JIRA_URL = os.getenv("JIRA_URL")
JIRA_USERNAME = os.getenv("JIRA_USERNAME")
JIRA_API_TOKEN = os.getenv("JIRA_API_TOKEN")
JIRA_PROJECT = os.getenv("JIRA_PROJECT")

# 正则表达式，用于从提交消息中提取JIRA任务ID
JIRA_ISSUE_PATTERN = re.compile(rf"{JIRA_PROJECT}-(\d+)")

def get_github_commits(since_date=None):
    """
    获取GitHub仓库中的最近提交
    
    Args:
        since_date: 起始日期，格式为ISO 8601（如2022-01-01T00:00:00Z）
    
    Returns:
        最近的提交列表
    """
    url = f"https://api.github.com/repos/{GITHUB_OWNER}/{GITHUB_REPO}/commits"
    
    headers = {
        "Authorization": f"Bearer {GITHUB_TOKEN}",
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28"
    }
    
    params = {}
    if since_date:
        params["since"] = since_date
    
    response = requests.get(url, headers=headers, params=params)
    
    if response.status_code == 200:
        return response.json()
    else:
        print(f"获取GitHub提交失败: {response.status_code}")
        print(response.text)
        return []

def get_commit_details(commit_sha):
    """
    获取单个提交的详细信息
    
    Args:
        commit_sha: 提交的SHA值
    
    Returns:
        提交的详细信息，包括修改的文件列表
    """
    url = f"https://api.github.com/repos/{GITHUB_OWNER}/{GITHUB_REPO}/commits/{commit_sha}"
    
    headers = {
        "Authorization": f"Bearer {GITHUB_TOKEN}",
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28"
    }
    
    response = requests.get(url, headers=headers)
    
    if response.status_code == 200:
        return response.json()
    else:
        print(f"获取提交详情失败: {response.status_code}")
        print(response.text)
        return None

def extract_jira_issues_from_commit(commit):
    """
    从提交消息中提取JIRA任务ID
    
    Args:
        commit: 提交信息
    
    Returns:
        JIRA任务ID列表
    """
    commit_message = commit["commit"]["message"]
    matches = JIRA_ISSUE_PATTERN.findall(commit_message)
    return [f"{JIRA_PROJECT}-{issue_id}" for issue_id in matches]

def get_jira_issue(issue_key):
    """
    获取JIRA任务详情
    
    Args:
        issue_key: JIRA任务ID
    
    Returns:
        任务详情
    """
    url = f"{JIRA_URL}/rest/api/2/issue/{issue_key}"
    
    auth_str = base64.b64encode(f"{JIRA_USERNAME}:{JIRA_API_TOKEN}".encode()).decode()
    headers = {
        "Authorization": f"Basic {auth_str}",
        "Content-Type": "application/json"
    }
    
    response = requests.get(url, headers=headers)
    
    if response.status_code == 200:
        return response.json()
    else:
        print(f"获取JIRA任务失败: {response.status_code}")
        print(response.text)
        return None

def get_jira_transitions(issue_key):
    """
    获取JIRA任务可用的转换
    
    Args:
        issue_key: JIRA任务ID
    
    Returns:
        可用的转换列表
    """
    url = f"{JIRA_URL}/rest/api/2/issue/{issue_key}/transitions"
    
    auth_str = base64.b64encode(f"{JIRA_USERNAME}:{JIRA_API_TOKEN}".encode()).decode()
    headers = {
        "Authorization": f"Basic {auth_str}",
        "Content-Type": "application/json"
    }
    
    response = requests.get(url, headers=headers)
    
    if response.status_code == 200:
        return response.json()["transitions"]
    else:
        print(f"获取JIRA转换失败: {response.status_code}")
        print(response.text)
        return []

def update_jira_issue_status(issue_key, transition_id):
    """
    更新JIRA任务状态
    
    Args:
        issue_key: JIRA任务ID
        transition_id: 转换ID
    
    Returns:
        是否更新成功
    """
    url = f"{JIRA_URL}/rest/api/2/issue/{issue_key}/transitions"
    
    auth_str = base64.b64encode(f"{JIRA_USERNAME}:{JIRA_API_TOKEN}".encode()).decode()
    headers = {
        "Authorization": f"Basic {auth_str}",
        "Content-Type": "application/json"
    }
    
    data = {
        "transition": {
            "id": transition_id
        }
    }
    
    response = requests.post(url, headers=headers, json=data)
    
    if response.status_code == 204:
        return True
    else:
        print(f"更新JIRA任务状态失败: {response.status_code}")
        print(response.text)
        return False

def add_jira_comment(issue_key, comment):
    """
    添加JIRA任务评论
    
    Args:
        issue_key: JIRA任务ID
        comment: 评论内容
    
    Returns:
        是否添加成功
    """
    url = f"{JIRA_URL}/rest/api/2/issue/{issue_key}/comment"
    
    auth_str = base64.b64encode(f"{JIRA_USERNAME}:{JIRA_API_TOKEN}".encode()).decode()
    headers = {
        "Authorization": f"Basic {auth_str}",
        "Content-Type": "application/json"
    }
    
    data = {
        "body": comment
    }
    
    response = requests.post(url, headers=headers, json=data)
    
    if response.status_code == 201:
        return True
    else:
        print(f"添加JIRA评论失败: {response.status_code}")
        print(response.text)
        return False

def update_jira_progress(issue_key, progress_percent):
    """
    更新JIRA任务进度
    
    Args:
        issue_key: JIRA任务ID
        progress_percent: 进度百分比（0-100）
    
    Returns:
        是否更新成功
    """
    url = f"{JIRA_URL}/rest/api/2/issue/{issue_key}"
    
    auth_str = base64.b64encode(f"{JIRA_USERNAME}:{JIRA_API_TOKEN}".encode()).decode()
    headers = {
        "Authorization": f"Basic {auth_str}",
        "Content-Type": "application/json"
    }
    
    # 注意：进度字段可能因JIRA配置而异
    # 这里假设使用自定义字段"customfield_10001"存储进度
    data = {
        "fields": {
            "customfield_10001": progress_percent
        }
    }
    
    response = requests.put(url, headers=headers, json=data)
    
    if response.status_code == 204:
        return True
    else:
        print(f"更新JIRA进度失败: {response.status_code}")
        print(response.text)
        return False

def main():
    # 获取昨天的日期
    yesterday = (datetime.now() - timedelta(days=1)).strftime("%Y-%m-%dT00:00:00Z")
    
    # 获取最近的提交
    commits = get_github_commits(since_date=yesterday)
    
    for commit in commits:
        # 获取提交详情
        commit_sha = commit["sha"]
        commit_details = get_commit_details(commit_sha)
        
        if not commit_details:
            continue
        
        # 提取JIRA任务ID
        issue_keys = extract_jira_issues_from_commit(commit)
        
        if not issue_keys:
            continue
        
        # 获取修改的文件列表
        changed_files = [file["filename"] for file in commit_details["files"]]
        
        for issue_key in issue_keys:
            # 获取任务详情
            issue = get_jira_issue(issue_key)
            
            if not issue:
                continue
            
            # 获取当前状态
            current_status = issue["fields"]["status"]["name"]
            
            # 根据文件变更情况更新任务状态
            if current_status == "待处理":
                # 获取可用的转换
                transitions = get_jira_transitions(issue_key)
                
                # 查找"进行中"转换
                in_progress_transition = next((t for t in transitions if t["name"] == "开始处理"), None)
                
                if in_progress_transition:
                    # 更新状态为"进行中"
                    update_jira_issue_status(issue_key, in_progress_transition["id"])
                    
                    # 添加评论
                    comment = f"自动更新：检测到代码变更，任务已开始处理。\n\n变更的文件：\n- " + "\n- ".join(changed_files)
                    add_jira_comment(issue_key, comment)
            
            # 根据文件变更数量估算进度
            # 这里使用一个简单的算法，实际应用中可能需要更复杂的逻辑
            if len(changed_files) > 0:
                # 假设每个任务平均需要修改10个文件
                progress = min(len(changed_files) * 10, 100)
                update_jira_progress(issue_key, progress)

if __name__ == "__main__":
    main()
```

### 5.4 部署与调度

#### 5.4.1 使用Cron作业

在Linux/Unix系统上，可以使用cron作业定期运行脚本：

```bash
# 编辑crontab
crontab -e

# 添加以下行，每天凌晨2点运行脚本
0 2 * * * /path/to/python /path/to/github_jira_integration.py
```

#### 5.4.2 使用GitHub Actions

也可以使用GitHub Actions自动运行脚本：

```yaml
# .github/workflows/update-jira.yml
name: Update JIRA Progress

on:
  schedule:
    # 每天凌晨2点运行
    - cron: '0 2 * * *'
  # 也可以手动触发
  workflow_dispatch:

jobs:
  update-jira:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      
      - name: Set up Python
        uses: actions/setup-python@v2
        with:
          python-version: '3.9'
          
      - name: Install dependencies
        run: |
          python -m pip install --upgrade pip
          pip install requests python-dotenv
          
      - name: Run integration script
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          GITHUB_OWNER: ${{ github.repository_owner }}
          GITHUB_REPO: ${{ github.repository }}
          JIRA_URL: ${{ secrets.JIRA_URL }}
          JIRA_USERNAME: ${{ secrets.JIRA_USERNAME }}
          JIRA_API_TOKEN: ${{ secrets.JIRA_API_TOKEN }}
          JIRA_PROJECT: ${{ secrets.JIRA_PROJECT }}
        run: python scripts/github_jira_integration.py
```

#### 5.4.3 使用GitHub Webhook

如果希望在每次提交后立即更新JIRA，可以设置GitHub Webhook：

1. 在GitHub仓库设置中添加Webhook
2. 设置Webhook URL指向您的处理脚本
3. 选择"push"事件作为触发条件

然后创建一个Web服务器来处理Webhook请求：

```python
from flask import Flask, request, jsonify
import hmac
import hashlib
import os
import subprocess

app = Flask(__name__)

@app.route('/webhook', methods=['POST'])
def webhook():
    # 验证GitHub签名
    signature = request.headers.get('X-Hub-Signature')
    if not signature:
        return jsonify({"error": "No signature"}), 400
    
    secret = os.getenv("WEBHOOK_SECRET").encode()
    body = request.data
    
    expected_signature = 'sha1=' + hmac.new(secret, body, hashlib.sha1).hexdigest()
    
    if not hmac.compare_digest(signature, expected_signature):
        return jsonify({"error": "Invalid signature"}), 403
    
    # 运行集成脚本
    subprocess.Popen(["python", "/path/to/github_jira_integration.py"])
    
    return jsonify({"status": "Processing"}), 202

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
```

## 6. 最佳实践与注意事项

### 6.1 性能优化

- 使用增量更新而非全量扫描
- 缓存API响应以减少请求次数
- 对于大型仓库，考虑使用异步处理

### 6.2 错误处理

- 实现重试机制处理临时网络问题
- 记录详细日志便于排查问题
- 设置监控和告警机制

### 6.3 安全考虑

- 安全存储API令牌，避免硬编码
- 使用最小权限原则配置访问权限
- 定期轮换API令牌

### 6.4 扩展建议

- 添加Web界面管理集成配置
- 支持多仓库和多项目映射
- 实现更复杂的进度计算算法

## 7. 结论

通过本文档提供的方案，您可以实现GitHub文件变更与JIRA项目进度的自动同步，大大减少手动更新的工作量。该方案适用于使用敏捷开发方法的团队，可以根据实际需求进行定制和扩展。

随着项目的发展，您可能需要调整映射规则和更新逻辑，以更准确地反映开发进度。建议定期评估集成效果，并根据团队反馈进行优化。

## 8. 参考资料

1. [GitHub REST API文档](https://docs.github.com/rest)
2. [JIRA REST API文档](https://developer.atlassian.com/server/jira/platform/rest-apis/)
3. [Python Requests库文档](https://docs.python-requests.org/)
4. [GitHub Actions文档](https://docs.github.com/actions)
