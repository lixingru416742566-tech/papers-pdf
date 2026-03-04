#!/bin/bash
cd ~/.openclaw/workspace/research_vault/01_Incoming_PDFs/

# 检查是否有新PDF
NEW_PDFS=$(git status --porcelain *.pdf 2>/dev/null | grep "^??" | wc -l)

if [ "$NEW_PDFS" -gt 0 ]; then
    echo "发现 $NEW_PDFS 篇新PDF，准备同步..."
    
    # 添加新文件
    git add *.pdf
    
    # 更新README
    echo "# 📚 论文 PDF 集合 - 网络暴力研究" > README.md
    echo "" >> README.md
    echo "## 自动同步" >> README.md
    echo "" >> README.md
    echo "本仓库由 OpenClaw 每日论文速递任务自动维护。" >> README.md
    echo "" >> README.md
    echo "## 更新频率" >> README.md
    echo "" >> README.md
    echo "每 2 小时自动搜索 arxiv，新增论文 PDF 自动上传。" >> README.md
    echo "" >> README.md
    echo "## 最新统计" >> README.md
    echo "" >> README.md
    echo "- **论文总数**: $(ls *.pdf | wc -l) 篇" >> README.md
    echo "- **最后更新**: $(date '+%Y-%m-%d %H:%M:%S')" >> README.md
    echo "- **来源**: arxiv.org" >> README.md
    echo "" >> README.md
    echo "## 论文列表" >> README.md
    echo "" >> README.md
    echo "| 文件名 | arxiv ID | 大小 |" >> README.md
    echo "|--------|----------|------|" >> README.md
    
    for f in *.pdf; do
        arxiv_id=$(basename "$f" .pdf)
        size=$(ls -lh "$f" | awk '{print $5}')
        echo "| $f | $arxiv_id | $size |" >> README.md
    done
    
    echo "" >> README.md
    echo "---" >> README.md
    echo "" >> README.md
    echo "*由 OpenClaw 每日论文速递自动生成*" >> README.md
    
    git add README.md
    
    # Commit
    git commit -m "🦞 自动同步：新增 $NEW_PDFS 篇论文PDF"
    
    # Push
    git push origin master
    
    echo "✅ 同步完成！"
else
    echo "无新PDF，跳过同步"
fi
