# 骨骼、蒙皮和动作接口

权威来源：`docs/api/weaver-api-docs.md` §2.12、§2.13、§4.1–§4.6。

## 骨骼链

1. `node_type=5`：输入带模型文件和 JSON 参数的 zip；`go_rigging_params.algorithm_model` 从算法列表选择。角色类别、模板骨骼和自动蒙皮按完整文档/服务端校验。
2. `node_type=6`：输入带骨骼模型和 JSON 的 zip；`params={}`，zip 内 JSON 的 `config.algo_name`、`selection.mesh_names`、`selection.joint_names` 必须与实际文件一致。
3. 先在 Blender 检查 armature、mesh/joint 名称和父子关系，再提交动作；不要从空列表猜关节。

## 动画

- `node_type=4` 视频生动画：`input_video` + rigged/skinned `input_model`；`MotusAI-V2M-*`；输出 FBX/BVH。
- `node_type=4` 文生动画：`input_model` + `framing_ai_params`；`MotusAI-T2M-V1.5` 或 `V1.1`；单段返回一个 model_id，任务内通常含 4 个候选；多段用 `segments`，非空时忽略 `prompt`。
- `node_type=12` 图生Pose：标准人物模型输入，不能把它当作任意工程车动作接口。

## CGAME 动作落地

Weaver 动作是候选。最终工程车的挖臂、鲸口、泵阀和桥体优先用 named pivot + Godot/Blender 关键帧；F-12 权威事件决定接触时刻。动作包必须覆盖 `prepare → contact → afterglow`，并保留原始 API 任务 ID、候选选择理由和人工修正记录。
