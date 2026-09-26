# 认证、上传和异步任务

权威来源：`docs/api/weaver-api-docs.md` §1.2、§1.3、§2.2、§2.3、§2.6、§2.7、§2.8、§4.6。

## 每次请求

- Base URL：`https://ws.visvise.com.cn/openapi`。
- Headers：`app_id`、实际调用人的 `rtx`、当前秒级 `ts`、小写十六进制 HMAC-SHA256 `sign`。
- POST 签名材料是**实际发送的 UTF-8 JSON 字符串 + ts**；GET 按文档的升序 query 序列化后加 ts。
- `app_id`/secret/temporary COS token/签名 URL 只能在进程内使用。任务台账只写请求摘要、ID、终态、本地文件、hash 和错误码。

## 文件

1. POST `weaver/resource/get_cos_cred` 获取临时 COS 凭证。
2. 用临时凭证 PUT 上传图片、模型 zip 或视频；上传模型输入时把模型文件和接口要求的 JSON 放进 zip。
3. 把 COS URL 放进 `input_view`、`input_model` 或 `input_video` 的文档字段。

签名 URL 是短期产物。拿到后立即下载或传给下一阶段，绝不写入仓库、报告或日志。

## 任务台账

每个提交先记录：`name`、`node_type`、算法名、输入 hash、请求摘要和返回的每一个 `model_id`。轮询 `get_model_list` 直到 `status=3` 或 `status=4`；失败保留 `failed_reason.code`，超时状态为 `unknown`，恢复时先查询原 ID，禁止因为超时自动重复提交。

可复用输出前先检查：任务终态、产物 URL 数量、本地文件字节数、SHA256、格式和 Blender/Godot 导入结果。API 成功只代表服务端完成任务。
