# 同步上游与发布（CN fork）

本文档是 fork 自有的：上游没有这份文件，所以它永远不参与合并冲突。改动同步流程、
汉化约定或发布参数时更新它。参考实现：`241794a`（rebase 恢复合并）+ `bdd1fe8`（汉化跟进）。

## 正常路径：全自动

[`sync-upstream-release.yml`](../.github/workflows/sync-upstream-release.yml) 每 6 小时跑一次：
解析上游最新**稳定** release（`/releases/latest`，上游的 beta 与 `-sequoia` 预发布都不参与）→
`git merge <tag>` → `run-tests.sh` → push main → 调
[`release-cn.yml`](../.github/workflows/release-cn.yml) 发 `<上游版本>-cn.1`。
对应 release 已存在时十几秒内退出，幂等，无需干预。

## 上游 rebase 过历史时（merge 炸假冲突）

**症状**：`git merge vX.Y.Z` 出现几十上百个 add/add 与 content 冲突，定时任务失败。
**原因**：上游发布后重写了 main，同一批 PR 换了 SHA，merge-base 退回到很旧的提交，
两侧把相同内容各自「重放」了一遍。v0.9.4 → v0.9.5 实测过一次。

配方（本地手动执行）：

1. **确认内容等价**：`git diff <fork 已合并的上游头> <rebase 后的等价提交>` 应为空。
   不为空说明 rebase 还夹带了改动，残差也要一并应用。
2. **找真实增量**：`git log --oneline <等价提交>..vX.Y.Z`，通常只有几个新提交。
3. 在临时分支上**逐个 cherry-pick**。剩下的冲突才是汉化与上游的真实交叠，逐个解决；
   上游把某文件重构走了的（如 CommandCatalog → CommandID），先取上游形状，
   汉化在后续提交里重新套上。
4. **合成合并提交，恢复祖先关系**——这是让下次自动同步恢复干净的关键：

   ```sh
   M=$(git commit-tree "$(git rev-parse 'HEAD^{tree}')" \
       -p <旧 main> -p vX.Y.Z -m 'Merge upstream vX.Y.Z: …')
   git switch main && git merge --ff-only "$M"
   ```

   第二父是上游 tag，之后 merge-base 就是它。
5. **校验工程文件**：`xcodegen generate` 后 `Tinycast.xcodeproj` 应无 diff，
   证明 pbxproj 的自动合并没有伤到工程。
6. **校验增量纯净**：`git diff vX.Y.Z HEAD --stat` 只应剩 fork 自有改动
   （汉化、拼音搜索、CN workflow、README）。

## 汉化 checklist（同步带来新界面时）

- 新 key 追加到 `Tinycast/zh-Hans.lproj/Localizable.strings` 末尾，新起一节
  `/* Upstream vA → vB: … */`，与既有小节保持一致。
- `Text("字面量")`、`Button("…")`、`TextField("…")` 走 `LocalizedStringKey`，
  **只需加词条，不改源码**。
- 以下走 String 重载、**不查表**，需要 `String(localized:)` 或 `.localizedUI`：
  - `Text(cond ? "A" : "B")` —— 三元表达式是 String；
  - `.help(变量)`、`.accessibilityLabel(变量)`，以及接收 String 参数的自定义视图。
  - `Label("A" + "B")` —— 两段字面量相加就不再是字面量，上游为了排版换行常这么写。
- **词条在表里不等于界面会显示**：上游改一个词（`will be shown` → `are shown`）就让译文静默失效。
  同步后按渲染路径核对，不要只看 `Localizable.strings` 有没有这一条。
- 插值 key 会变成格式串：Int → `%lld`，String → `%@`。
  如 `String(localized: "\(n) characters")` 的词条 key 是 `"%lld characters"`。
- **测试不受影响**：harness 二进制没有 zh bundle，`String(localized:)` 回退英文，
  所以 Model/Service 里包裹是安全的（`notes-test` 断言 `Untitled.md` 依旧通过）。
- 红线：存储路径与目录名（如 Application Support 下的 `Notes` 目录）**绝不本地化**；
  会落成文件名的默认值（`Untitled` → `未命名`）是有意决策，不是遗漏。
- 收尾校验：`plutil -lint` 词条文件；逐 key 与源码字面量交叉核对；
  在构建产物 `Resources/zh-Hans.lproj` 里确认词条真的进了包。

### 汉化会改动搜索的三处

汉化把条目名换成了中文，搜索索引跟着变，这三处是补偿：

- `CommandID.untranslatedName` 保留英文原名，`CommandCatalog` 把它放进 `alternateNames`，
  这样 `clipboard` 仍能搜到「剪贴板历史」；中文与拼音由 name 和 `Pinyin` 覆盖。
- `AppIndex.byCategoryName` 把每个分类词按原文和译文各存一次，`应用` 与 `applications` 都能整段列出。
- emoji 的中文名与关键词来自 CLDR `zh`，由 `Scripts/gen-emoji.js` 一起生成；中文名是记录的第六段，
  `EmojiIndex` 按 name 计分而不是按关键词计分。

## 手动补发 release

```sh
gh workflow run release-cn.yml --repo conversun/tinycast-cn \
  -f version=<上游版本>-cn.N -f prerelease=<跟随上游> \
  -f upstream_tag=vX.Y.Z -f ref=<commit sha>
```

- 版本规则：自动同步固定 `-cn.1`；同一上游版本之上再发汉化跟进，用 `-cn.2` 起手动派发。
- release 发布后，定时同步检测到同名 release 即跳过，两者互不干扰。
- 成功后自动 bump [homebrew-tinycast-cn](https://github.com/conversun/homebrew-tinycast-cn)
  的 cask（version + sha256），无需手动操作；`prerelease=true` 的派发只发 GitHub release，
  不动 cask —— `brew upgrade --cask tinycast-cn` 是稳定通道。
