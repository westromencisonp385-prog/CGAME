# 2D、预处理和错误边界

权威来源：`docs/api/weaver-api-docs.md` §2.11、§2.14–§2.24、§5。

- `remove_background`、风格化、去花纹是输入预处理；必须保存原图、处理图和 prompt/参数 hash，不能把预处理结果冒充最终风格。
- 2D 拆分先用图生360资产；从 `segment_output.{view}.components[].label` 取得部件 label，再把 `segment_model_id` + `component_label` 传给高模/中模。
- 错误码 410/411 先查签名和本机时钟；120008 查 schema；120020/120040 分别处理配额和频率；990015/971126/960002 按格式、顶点数、UV 岛限制修复；动画/骨骼/图生Pose错误必须记录原始 code 并停止猜参数。
- 生产报告中的错误可保留 code、任务 ID 和本地输入 hash，不能保留临时凭证、Authorization 或签名 URL。
