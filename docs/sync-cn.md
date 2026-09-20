# 同步上游与发布（CN fork）

本文档是 fork 自有的：上游没有这份文件，所以它永远不参与合并冲突。改动同步流程、
汉化约定或发布参数时更新它。参考实现：`241794a`（rebase 恢复合并）+ `bdd1fe8`（汉化跟进）。

## 正常路径：定时检查，也可手动派发

[`sync-upstream-release.yml`](../.github/workflows/sync-upstream-release.yml) 每 6 小时检查一次
（UTC 00:23、06:23、12:23、18:23，也支持手动派发）：解析上游最新**稳定** release
（`/releases/latest`，上游的 beta 与 `-sequoia` 预发布都不参与）→ `git merge <tag>` →
`run-tests.sh` → push main → 调 [`release-cn.yml`](../.github/workflows/release-cn.yml)
发 `<上游版本>-cn.1`。对应 release 已存在时十几秒内退出，幂等，无需干预。

```sh
gh workflow run sync-upstream-release.yml --repo conversun/tinycast-cn
# 指定上游 tag：额外加 -f upstream_tag=vX.Y.Z
```

GitHub 的定时任务可能延迟；需要立即同步时使用上面的手动派发命令。

## 受阻路径：开 issue，不留红叉

汉化 fork 与上游冲突是设计使然，所以 `git merge` 冲突或 `run-tests.sh` 失败都**不算故障**：
工作流回滚合并、不推 main，改为开一条带 `sync-blocked` 标签的 issue（标题 `Sync vX.Y.Z needs a hand`，
正文附冲突文件清单或测试尾部日志），run 本身保持绿色。同一 tag 已有未关闭 issue 时不重复创建。
标签创建失败时仍创建不带标签的 issue，并在日志中警告，避免标签阻断通知。
这一步靠仓库开着 Issues：关掉的话 `gh issue list` 非零退出，整次派发会跟着变红，
冲突清单只能去 run 日志的 `Merge upstream release into main` 一步里看。

按下文配方在本地解完、`main` 带上合并提交后，关掉 issue，等待定时任务或再派发一次 —— merge 已是 no-op，
测试通过，就会照常发 `-cn.1`。

## 上游 rebase 过历史时（merge 炸假冲突）

**症状**：`git merge vX.Y.Z` 出现几十上百个 add/add 与 content 冲突，同步派发失败。
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

## 找出漏译：先用编译器，再补它的盲区

不要靠 grep 猜。Xcode 自己的抽取是权威清单：

```sh
xcodebuild -exportLocalizations -project Tinycast.xcodeproj \
  -localizationPath /tmp/loc -exportLanguage zh-Hans SWIFT_EMIT_LOC_STRINGS=YES
```

`SWIFT_EMIT_LOC_STRINGS=YES` 是关键 —— 不加只抽 SwiftUI 字面量，`String(localized:)` 一条不出
（v0.10.2 那次是 785 条 vs 242 条）。把 `/tmp/loc/zh-Hans.xcloc/Localized Contents/zh-Hans.xliff`
里的 `<source>` 与 `Localizable.strings` 的 key 求差集，就是待译清单。改完再跑一次直到差集为空。

**它抽不到的两类**，得另外找：

- **`.localizedUI` 接的变量** —— 字符串来自 model 层的 `title`/`label`/`detail`/`message` 字面量，
  编译期看不见。扫「合并动过的 .swift 里的字面量，减去抽取集，减去已有词条」，再逐条判断是否用户可见。
- **`Info.plist` 的用途说明** —— 走 `InfoPlist.strings`，按 `NSCameraUsageDescription` 这类
  **键名**索引，不是按英文原文。

## 渲染路径：词条在表里 ≠ 界面会变中文

v0.10.2 那次，292 条用户可见字符串里有 200 条只加词条不生效。判定标准是**这个字面量最终落进
`LocalizedStringKey` 还是 `String`** —— 后者绑定的是不查表的重载：

| 写法 | 结果 | 修法 |
| --- | --- | --- |
| `Text("字面量")` | 查表 | 只加词条 |
| `Text(cond ? "A" : "B")` | **不查表**，三元是 String | 两个分支各套 `String(localized:)` |
| `Text("A" + "B")` | **不查表** | 对**合并后的整句**套一次；分别套会重复出文 |
| `Text(param)`（`param: String`） | **不查表** | 渲染处 `Text(param.localizedUI)` |
| `"前缀 \(x)"` 直接当 String 用 | **不查表** | `String(localized: "前缀 \(x)")` |

两个反复踩到的坑：

- **插值会改 key**。`String(localized: "\(n) models")` 查的是 `"%lld models"`，不是源码文本；
  String 插值变 `%@`。照源码字面量落词条，等于落了一条永远不触发的死条目。
- **拼接要在合并处包一次**。分别包两半时，译者通常把整句写进了其中一半，界面会把开头念两遍；
  合并后原来的两个片段词条即成死条目，应一并删除。

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

- 版本规则：同步工作流固定发 `-cn.1`；同一上游版本之上再发汉化跟进，用 `-cn.2` 起手动派发。
- release 发布后，同步工作流检测到同名 release 即跳过，两者互不干扰。
- 成功后自动 bump [homebrew-tinycast-cn](https://github.com/conversun/homebrew-tinycast-cn)
  的 cask（version + sha256），无需手动操作；`prerelease=true` 的派发只发 GitHub release，
  不动 cask —— `brew upgrade --cask tinycast-cn` 是稳定通道。

## v0.11.3 同步核验

上游再次重写了历史：旧 `v0.10.23` 与新历史中的 `740cbd86` 仅有 `docs/ui.md` 一处差异。
本次以旧发布树为基线做三方合并，保留完整的 `v0.11.3` 树增量；最终合并提交的两个父节点
分别是原 CN main 和真正的 `v0.11.3`，后续同步仍可使用正常祖先关系。

设置编辑器从 Sheet 拆成 Panel 时，必须同步迁移动态标题、说明、占位符和错误的查表入口。
备份分类与 Esc 行为还需核对模型字符串：既要有词条，也要在显示处调用 `.localizedUI`。
本次为用户反馈的备份、Esc 与扩展兼容性文案加入了 `localization-test` 回归检查；继续用
Xcode 抽取核对字面量，并单独核对目录、模型及拼接文案，不能只依赖该测试。

## 防漏检查：区分词条覆盖与渲染覆盖

```sh
./Scripts/check-localization.sh           # 秒级检查，lint.sh 也会运行
./Scripts/check-localization.sh --extract # Xcode 抽取 + 词条差集，首次需要编译
```

检查器自身也运行隔离副本中的反向测试：删除普通及 switch 表达式词条、制造重复键与格式
参数错误、恢复窗口布局的原始漏译，均须被拦截。

快速检查会拒绝重复或空词条、格式参数不一致、已登记目录中的缺失词条，以及可识别的
`Text(计算属性)` 直接接收已有译文的英文分支。新增动态标题目录时，必须更新
`Scripts/check-localization.js` 的目录清单；这不是全 Swift 数据流分析器。

CN 发布工作流在签名和打包前执行完整抽取检查；失败不发布。它只能证明被抽取的词条与
已登记的动态目录完整，不能证明所有运行时路径都查表。发布前还要以简体中文运行 Dev 版，
实际打开受影响页面和编辑器，检查空状态、菜单、提示与错误状态。先完成检查，再派发发布。
第三方扩展及用户命名内容保持原文，不能靠“界面不含英文”判断完整性。
