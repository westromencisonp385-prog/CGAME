# 模型和几何接口

权威来源：`docs/api/weaver-api-docs.md` §2.1、§2.4–§2.8、§3.1–§3.12。

| node_type | 能力 | 关键输入/输出 |
|---:|---|---|
| 1 | 重拓扑 | `input_model`; `re_topology_params`；输出 FBX/OBJ |
| 2 | LOD | `input_model`; `lod_params.reduce_faces`；可返回多个 LOD URL |
| 3 | 图生高模 | `input_view` 或分割部件；`image_gen_model_params` |
| 7 | 图生360 | 单张 `main_view`；返回四视图和一个 model_id |
| 8 | 贴图纹理 | `input_model` + 可选 `input_view`；`tex_params` |
| 9 | UV | `input_model`；`uv_params` |
| 10 | 布线重建 | `input_model`；`mesh_refine_params`，mode 1 优化/2 加密 |
| 11 | 图生中模 | 多视图、360 资产或分割部件；`image_gen_model_params` |
| 15 | 2UV | `auto_luv_params`；按 mesh、分辨率和通道指定 |

## 当前生产决策

- G1 玩家/敌人/设施先用 7 → 3（或 11）得到候选，再用 9 → 8（确有 UV/材质收益时）→ 2。
- 3D 低模 node_type=13 在文档中标为本期未开放；用高模/中模再 LOD。
- 图生模型的面数是目标，不是质量证明。必须检查拆件、材质槽、UV、碰撞、枢轴和真实镜头。
- 模块优先用部件生成或 Blender 手工拆件，不能把整车和模块焊成不可替换网格。
