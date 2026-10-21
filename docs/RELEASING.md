# 自动发布 / Automated releases

`dev` 用于开发；将准备好的正式版本合并到 `main` 后，GitHub Actions 自动打包并发布到 GitHub 和 CurseForge。

## 一次性配置

- 仓库 Actions Secret：`CF_API_TOKEN`，使用 CurseForge 作者后台创建的上传 Token。
- 项目 ID 已配置为 **1754497**，EllesmereUI 必需依赖为 **1477613**。
- `.github/release-config.json` 指定 Forever **1.60.1 / Interface 16001**。接口中找不到唯一匹配版本时停止，避免错误发布为其他客户端。

## 每次发布

1. 在 `dev` 完成功能和验证。
2. 将 `BelToolbox.toc` 的版本改为新的正式 `x.y.z`，更新 README 版本。
3. 在 `CHANGELOG.md` 顶部编写 `# Bel Toolbox x.y.z` 及本次更新内容。将本轮开发版本的改动整理到该节；历史章节保留在后面。
4. 提交 `dev → main` PR。自动检查版本、打包文件和发布脚本；PR 检查不会使用 CF 密钥或发布。
5. 合并到 `main` 后自动触发发布，无需手动建 tag。

发布包根目录固定为 `BelToolbox/`，只包含插件代码、Data、Media、许可证和用户文档。GitHub、Actions、开发资料和本地角色数据不进入 ZIP。

GitHub Release 与 CF 使用相同 ZIP 和相同 Markdown 更新日志。只提取 changelog 顶部本次版本章节，历史不会重复上传。CF 元数据包含 EllesmereUI 必需依赖。项目首页简介不随此流程更改。

## 失败与重跑

- Actions 的 `package` 任务提供 ZIP、更新日志、发布清单和 SHA256 下载，保留 30 天。
- 上传前验证 CF Token/游戏版本；随后创建 GitHub 草稿 Release。
- CF 返回文件 ID 并保存 `curseforge-upload.json` 回执后，才将 GitHub Release 正式发布。CF 自身审核仍由平台处理。
- 对已有成功回执重跑时不重复上传 CF，也不覆盖其他提交的同名版本。
- 如果网络超时导致上传结果不确定，流程停止。先在 CF 后台检查该版本：已收到则按实际文件 ID 补全回执；确认未收到，才删除草稿 Release 中的 `curseforge-upload-started.json` 附件并重跑。避免重复提交。
- 在 Actions 中选择 **Release → Run workflow → main** 可重跑；也可重跑失败任务。`dev` 禁止实际发布，`-dev` 版本禁止作为正式包发布。

The workflow uses the official CurseForge Upload API and GitHub Releases API. Tokens are read only from Actions secrets, never included in the ZIP, metadata or logs.
