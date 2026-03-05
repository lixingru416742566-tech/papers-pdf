# 📚 arXiv 论文每日推荐 - 标准操作流程 (SOP)

**版本**: v1.0  
**最后更新**: 2026-03-05  
**维护**: 龙虾小星

---

## 🎯 任务目标

每日自动搜索 arXiv 论文，按四个研究方向分类，生成 JSON 数据 + Markdown 报告，推送到 GitHub 展示。

---

## 📋 四个研究方向

| 任务 ID | 方向 | 关键词 | arXiv 分类 | 执行时间 |
|--------|------|--------|-----------|----------|
| arxiv-task1-cyberbullying | 网暴检测 | cyberbullying, hate speech, online harassment, toxicity, online abuse, targeted aggression | cs.AI, cs.LG, cs.CL, cs.SI | 每天 9:00 |
| arxiv-task2-propagation | 攻击中心演化 | complex networks, propagation mechanism, information diffusion, opinion dynamics, influence maximization, attack center evolution, network topology, cascade dynamics, viral spreading, contagion model | cs.SI, cs.AI, physics.soc-ph, cs.LG | 每天 10:00 |
| arxiv-task3-intervention | 干预策略 | intervention strategies, content moderation, counter-speech, debiasing, platform governance, policy intervention, mitigation strategies, preventive measures, regulatory framework | cs.SI, cs.AI, cs.CY | 每天 11:00 |
| arxiv-task4-userbehavior | 用户行为画像 | user behavior, user profiling, behavioral analysis, demographic analysis, psychographic profiling, user engagement, victim-perpetrator dynamics, bystander behavior, user modeling, behavioral patterns | cs.HC, cs.SI, cs.AI | 每天 12:00 |

---

## 🔧 执行步骤（每个任务必须按顺序执行）

### 步骤 1: 调用 arXiv API 搜索论文

**API 端点**: `https://export.arxiv.org/api/query`

**请求示例**:
```bash
curl -G "https://export.arxiv.org/api/query" \
  --data-urlencode "search_query=ALL:cyberbullying AND ALL:hate+speech" \
  --data-urlencode "sortBy=submittedDate" \
  --data-urlencode "sortOrder=descending" \
  --data-urlencode "start=0" \
  --data-urlencode "max_results=50"
```

**Python 示例**:
```python
import requests
from datetime import datetime, timedelta

def search_arxiv(keywords, categories, days=30, max_results=50):
    """搜索 arXiv 论文"""
    base_url = "https://export.arxiv.org/api/query"
    
    # 构建搜索查询
    keyword_query = " +AND+ ".join([f"ALL:{kw.replace(' ', '+')}" for kw in keywords[:3]])
    category_query = " +OR+ ".join([f"cat:{cat}" for cat in categories])
    search_query = f"({keyword_query}) +AND+ ({category_query})"
    
    params = {
        "search_query": search_query,
        "sortBy": "submittedDate",
        "sortOrder": "descending",
        "start": 0,
        "max_results": max_results
    }
    
    response = requests.get(base_url, params=params)
    return response.text
```

---

### 步骤 2: 解析 API 响应并提取字段

**必须提取的字段**:
- `arxiv_id`: arXiv ID (如 2603.02684)
- `title`: 论文标题
- `authors`: 作者列表
- `published`: 发布日期
- `summary`: 摘要
- `doi`: DOI (如有)
- `categories`: arXiv 分类

**Python 解析示例**:
```python
import xml.etree.ElementTree as ET

def parse_arxiv_response(xml_content):
    """解析 arXiv XML 响应"""
    ns = {"atom": "http://www.w3.org/2005/Atom"}
    root = ET.fromstring(xml_content)
    
    papers = []
    for entry in root.findall("atom:entry", ns):
        paper = {
            "arxiv_id": entry.find("atom:id", ns).text.split("/")[-1],
            "title": entry.find("atom:title", ns).text.strip().replace("\n", " "),
            "authors": [a.find("atom:name", ns).text for a in entry.findall("atom:author", ns)],
            "published": entry.find("atom:published", ns).text[:10],
            "summary": entry.find("atom:summary", ns).text.strip().replace("\n", " "),
            "doi": entry.find("prism:doi", {"prism": "http://prismstandard.org/namespaces/basic/2.0/"}).text if entry.find("prism:doi", {"prism": "http://prismstandard.org/namespaces/basic/2.0/"}) is not None else None,
            "categories": [c.get("term") for c in entry.findall("atom:category", ns)]
        }
        papers.append(paper)
    return papers
```

---

### 步骤 3: 计算四维智能评分

**评分公式**:
```
综合评分 = 相关性×0.4 + 新近性×0.2 + 热门度×0.3 + 质量×0.1
```

**详细评分标准**:

| 维度 | 权重 | 评分标准 |
|------|------|----------|
| **相关性** | 40% | 标题关键词匹配 +0.5/个，摘要关键词匹配 +0.3/个，类别匹配 +1.0，满分 10 分 |
| **新近性** | 20% | 30 天内 +3 分，30-90 天 +2 分，90-180 天 +1 分，180 天以上 0 分，满分 10 分 |
| **热门度** | 30% | 根据 arXiv 版本数/引用情况估算，满分 10 分 |
| **质量** | 10% | 方法创新性（理论推导 + 实验验证 + 开源代码），满分 10 分 |

**Python 评分示例**:
```python
from datetime import datetime

def calculate_score(paper, keywords):
    """计算论文综合评分"""
    # 1. 相关性评分 (40%)
    relevance = 0
    title = paper["title"].lower()
    summary = paper["summary"].lower()
    for kw in keywords:
        if kw.lower() in title:
            relevance += 0.5
        if kw.lower() in summary:
            relevance += 0.3
    relevance = min(relevance, 10)  # 上限 10 分
    
    # 2. 新近性评分 (20%)
    published = datetime.strptime(paper["published"], "%Y-%m-%d")
    days_old = (datetime.now() - published).days
    if days_old <= 30:
        recency = 3
    elif days_old <= 90:
        recency = 2
    elif days_old <= 180:
        recency = 1
    else:
        recency = 0
    recency = recency * 10 / 3  # 转换为 10 分制
    
    # 3. 热门度评分 (30%) - 简化版本数评分
    version_count = paper["arxiv_id"].count("v") if "v" in paper["arxiv_id"] else 1
    popularity = min(version_count * 2, 10)
    
    # 4. 质量评分 (10%) - 根据摘要长度和方法描述估算
    quality = min(len(paper["summary"]) / 500, 10)
    
    # 综合评分
    total = relevance * 0.4 + recency * 0.2 + popularity * 0.3 + quality * 0.1
    return round(total, 2)
```

---

### 步骤 4: 保存到 JSONL 文件

**文件命名**: `arxiv_[direction]_YYYY-MM-DD.jsonl`

**存储路径**: `~/.openclaw/workspace/papers_daily/`

**JSONL 格式** (每行一个 JSON 对象):
```json
{
  "arxiv_id": "2603.02684",
  "title": "HateMirage: An Explainable Multi-Dimensional Dataset for Decoding Faux Hate and Subtle Online Abuse",
  "authors": ["Sai Kartheek Reddy Kasu", "Shankar Biradar", "Sunil Saumya", "Md. Shad Akhtar"],
  "published": "2026-03-02",
  "summary": "Subtle and indirect hate speech remains an underexplored challenge...",
  "doi": "10.1145/xxxxxxx",
  "categories": ["cs.CL", "cs.AI"],
  "score": 9.2,
  "direction": "cyberbullying",
  "timestamp": "2026-03-05T09:00:00+08:00"
}
```

**Python 保存示例**:
```python
import json
from datetime import datetime

def save_to_jsonl(papers, direction, date_str=None):
    """保存论文到 JSONL 文件"""
    if date_str is None:
        date_str = datetime.now().strftime("%Y-%m-%d")
    
    filepath = f"/root/.openclaw/workspace/papers_daily/arxiv_{direction}_{date_str}.jsonl"
    
    with open(filepath, "a", encoding="utf-8") as f:
        for paper in papers:
            paper["direction"] = direction
            paper["timestamp"] = datetime.now().isoformat()
            f.write(json.dumps(paper, ensure_ascii=False) + "\n")
    
    return filepath
```

---

### 步骤 5: 生成每日汇总报告（仅 Task 4 执行）

**触发条件**: 仅 `arxiv-task4-userbehavior` (12:00) 执行此步骤

**报告内容**:
1. 读取当日所有方向的 JSONL 文件
2. 生成 Markdown 格式的每日报告
3. 更新 GitHub 仓库 README.md
4. Git commit + push

**Python 生成报告示例**:
```python
def generate_daily_report(date_str=None):
    """生成每日汇总报告"""
    if date_str is None:
        date_str = datetime.now().strftime("%Y-%m-%d")
    
    directions = ["cyberbullying", "propagation", "intervention", "userbehavior"]
    direction_names = {
        "cyberbullying": "🔴 网暴检测",
        "propagation": "🔵 攻击中心演化",
        "intervention": "🟢 干预策略",
        "userbehavior": "🟡 用户行为画像"
    }
    
    all_papers = []
    for direction in directions:
        filepath = f"/root/.openclaw/workspace/papers_daily/arxiv_{direction}_{date_str}.jsonl"
        if os.path.exists(filepath):
            with open(filepath, "r", encoding="utf-8") as f:
                for line in f:
                    if line.strip():
                        all_papers.append(json.loads(line))
    
    # 生成 Markdown
    md = f"# 📚 arXiv 每日论文推荐 - {date_str}\n\n"
    md += f"**总论文数**: {len(all_papers)} 篇\n\n"
    
    for direction, name in direction_names.items():
        dir_papers = [p for p in all_papers if p.get("direction") == direction]
        if dir_papers:
            md += f"## {name}\n\n"
            md += "| 评分 | 标题 | 作者 | 链接 |\n"
            md += "|------|------|------|------|\n"
            for p in sorted(dir_papers, key=lambda x: x.get("score", 0), reverse=True)[:10]:
                md += f"| ⭐{p['score']:.1f} | {p['title'][:50]}... | {', '.join(p['authors'][:2])} | [PDF](https://arxiv.org/abs/{p['arxiv_id']}) |\n"
            md += "\n"
    
    return md
```

---

### 步骤 6: 推送到 GitHub

**仓库**: https://github.com/lixingru416742566-tech/papers-pdf

**前置条件**:
- ✅ 环境变量 `GITHUB_TOKEN` 已配置 (ghp_jVXG...)
- ✅ 本地已克隆仓库到 `~/.openclaw/workspace/papers-pdf-repo/`
- ✅ Git 用户配置：OpenClaw Bot <openclaw@local>

**推送步骤**:
```bash
# 1. 拉取最新代码
cd ~/.openclaw/workspace/papers-pdf-repo
git pull origin main

# 2. 复制每日报告
cp ~/.openclaw/workspace/papers_daily/daily_report_${DATE}.md ./daily/${DATE}.md
cp ~/.openclaw/workspace/papers_daily/daily_report_${DATE}.md ./README.md

# 3. 复制 JSON 数据
cp ~/.openclaw/workspace/papers_daily/arxiv_*_${DATE}.jsonl ./data/

# 4. Git 提交
git add .
git commit -m "📚 每日论文推荐 - ${DATE}"

# 5. 推送到 GitHub
git push origin main
```

---

## 📁 文件结构

```
~/.openclaw/workspace/
├── papers_daily/
│   ├── SOP.md                          # 本文件（操作指南）
│   ├── arxiv_cyberbullying_2026-03-05.jsonl
│   ├── arxiv_propagation_2026-03-05.jsonl
│   ├── arxiv_intervention_2026-03-05.jsonl
│   ├── arxiv_userbehavior_2026-03-05.jsonl
│   ├── daily_report_2026-03-05.md      # 每日汇总报告
│   └── github_report.py                # GitHub 推送脚本
│
└── papers-pdf-repo/                    # GitHub 仓库本地副本
    ├── README.md                       # 最新报告
    ├── daily/                          # 历史报告归档
    │   ├── 2026-03-05.md
    │   └── ...
    └── data/                           # 原始 JSON 数据
        ├── arxiv_cyberbullying_2026-03-05.jsonl
        └── ...
```

---

## ⚠️ 注意事项

1. **每次执行前必须读取本 SOP** - 确保按标准流程操作
2. **JSONL 文件追加模式** - 避免覆盖同一方向多次搜索的结果
3. **评分系统一致性** - 四个方向使用相同的评分标准
4. **GitHub Token 安全** - 不要硬编码在代码中，使用环境变量
5. **错误处理** - API 失败时记录日志，不中断后续任务

---

## 🔍 检查清单

每个任务完成后自检：

- [ ] arXiv API 调用成功
- [ ] 解析出至少 5 篇论文
- [ ] 每篇论文包含所有必需字段
- [ ] 评分计算完成
- [ ] JSONL 文件已保存
- [ ] 文件路径正确（包含日期和方向）
- [ ] (仅 Task 4) 每日报告已生成
- [ ] (仅 Task 4) GitHub 推送成功

---

## 📞 问题排查

| 问题 | 可能原因 | 解决方案 |
|------|----------|----------|
| API 返回空结果 | 关键词太窄 | 减少关键词数量或扩大 arXiv 分类 |
| 评分全为 0 | 评分函数错误 | 检查 calculate_score() 实现 |
| GitHub 推送失败 | Token 过期/权限不足 | 重新生成 Token，确认 repo 权限 |
| JSONL 文件为空 | 解析失败 | 检查 XML 解析代码，打印原始响应调试 |

---

**SOP 结束** - 每次执行任务前请重新阅读本文件
