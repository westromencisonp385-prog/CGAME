# Weaver 2D 实测结论

日期：2026-09-29
脚本：[tools/weaver_2d_checks.py](../../tools/weaver_2d_checks.py)
证据报告：[artifacts/weaver/capability-study/2d/report.json](../../artifacts/weaver/capability-study/2d/report.json)

这次实测覆盖两种不同输入：N01 施工蟹和 E02 极环猎手。两者都复用了已有的图生 360 资产作为拆分输入，并同时上传原始概念图验证图片输入链。下载结果均保存到 `artifacts/weaver/capability-study/2d/<asset>/`，报告只保留本地文件大小、SHA-256、任务 ID 和脱敏后的非敏感字段。

## 已实际调用

| 能力 | 结果 | 证据 |
|---|---|---|
| `list_algorithm_model` node 11 | 成功 | `VV-MeshGen-V1.5.0` |
| `list_algorithm_model` node 14 | 成功 | `VV-SplitMask-V1.0.0` |
| `list_algorithm_model` node 16 | 成功 | `VV-Pre2D-V1.0.0`、GPT image2、GPT image2.5、Nano Banana2、Nano BananaPro |
| `remove_background` | N01/E02 均成功 | 每个样本各有一张本地透明背景候选图 |
| `style_transfer` | N01/E02 的 1/2/3/4 四种预设均成功 | 每个样本各有四张本地结果图 |
| `patter_auto_remove` | N01/E02 均成功 | 每个样本各有一张本地结果图 |
| `gen_preprocess` | 成功保存四个 node 16 资产 | N01：`Model2026092900609362`、`Model2026092900609363`；E02：`Model2026092900610170`、`Model2026092900610171` |
| `init_segment` | 成功，SSE `req_id → pre_create → thinking → reply` | N01/E02 各有正视图（14/14 个部件）和四视图（13/13 个部件）样本 |
| `begin_segment` | 成功 | 两个四视图会话均成功 |
| `segment` | 成功 | 发送正点、负点和 64×64 矩形小范围编辑 |
| `confirm_segment` | 成功 | 两个会话均成功 |
| `boundary_adjust` | 成功 | 使用 2048×2048 原始单字节 mask；没有误传 PNG |
| `merge` | 成功 | 合并两个部件 label |
| `auto_merge` | 成功 | 两个会话均成功 |
| `part_rename` | 成功 | 两个会话均成功 |
| `save_segment` | 成功，生成 node 14 资产 | N01：`Model2026092900609346`；E02：`Model2026092900610163` |
| `open_segment` | 成功 | 使用上述已保存 node 14 资产重新打开 |
| `cancel_segment` | 成功 | 在重新打开的会话中开始一次拆分后取消，原保存资产未被覆盖 |

## 预处理怎么用

预处理不是“保存一张本地 PNG 就算资产”。正确链路是：

1. 通过 COS 临时凭证上传原始图片。
2. 调用 `style_transfer` 或 `patter_auto_remove`，取得带临时签名的 `result_image`。
3. 在签名 URL 有效期内，把该 URL **原样**传入 `gen_preprocess` 的 `style_param.result_image` 或 `remove_pattern_param.result_image`。
4. `gen_preprocess` 返回 node 16 `model_id`，再把它交给后续模型链。

首轮脚本曾把已下载的本地 PNG 再上传后传给 `gen_preprocess`，服务返回 `120015`。按文档改为直接传上一步返回的临时 `result_image` 后，四个保存任务全部成功。报告保留了首次错误作为 schema 纠正证据，不把它当成接口不可用。

视觉检查结论：style 1 是灰模，style 2 是像素风，style 3 是写实，style 4 是卡通手办。style 2 的硬边和像素块最接近 CGAME 的图形漫画方向；style 4 更像干净的玩具产品渲染，不能直接当作项目最终风格。所有结果仍是 2D 预处理候选，不能代替作者化材质、拆件和 Godot 实机验收。

## 2D 拆分怎么用

`init_segment` 是 SSE，不是普通 JSON 返回。输入 `model_id`（已有图生 360 资产）和 `input_view`（任意图片）二选一。此次用 `model_id` 验证了正视图 `split_type=1` 与四视图 `split_type=2`，同时比较了中等和细颗粒度。四视图结果中，N01 得到 13 个部件，E02 得到 13 个部件；正视图均得到 14 个部件。

编辑必须沿着同一个 `client_id` 进行：`begin_segment` 指定 label，`segment` 传点/矩形，`confirm_segment` 固化当前动作；`boundary_adjust` 传原始单字节掩膜的 base64；`merge`/`auto_merge` 改变部件关系；`part_rename` 改名；最后 `save_segment` 才会生成可供图生模使用的 node 14 资产。`open_segment` 会创建新的会话，`cancel_segment` 只回退当前未保存操作。

## 拆分后中模输入的边界

N01 使用保存后的 `segment_model_id=Model2026092900609346`，并取部件 label 1 调用 node 11 中模，任务 `Model2026092900610164` 最终失败，服务给出 `990017 / findModelPath err: file not found`。保存的 node 14 资产本身随后查询为 `status=3` 且有 `output_model`，所以这次不能把 990017 解释成“node 11 不支持 segment_model_id”。当前更可靠的结论是：**编辑后分割资产的单部件生成兼容性仍未证实，需要用未编辑分割资产或不带 `component_label` 的全部部件方式做下一轮隔离实验。**

这次没有重复提交新的中模任务，避免在原因未隔离时继续消耗额度。`segment_model_id` 与 `component_label` 的组合仍按文档保留为待验证能力；node 11 的算法发现、node 14 资产保存以及所有 2D 编辑接口已经有真实成功证据。

## 未调用或只停留在文档层的接口

- `regenerate_model`：文档明确只支持 node 15 2UV，本轮无 2UV 输入，不调用。
- 2D 删除类接口：文档目录没有对应可安全执行的生产操作；不通过猜端点调用。
- `merge`、`auto_merge`、`boundary_adjust` 的更多复杂多视图策略：本轮只做了小范围样本验证，不宣称覆盖所有边界情况。

所有临时签名 URL、Authorization、APPSECRET 和 COS 临时密钥均未写入本地报告；真实凭证仍只从用户本机凭证文件读取。
