# 贴图纹理 API 实测

日期：2026-09-29。输入是项目作者化 B01 GLB，已有 UV、20,031 vertices、11,956 triangles。

- 调用：`node_type=8`，算法 `Hy3D-TEX-v3.5-preview`，`resolution=1024`，`unwarp_uv=false`，输入参考为 N01 图形漫画概念图。
- 任务：`Model2026092900609338`，终态 `status=3`。
- 输出包约 161 MB，包含 FBX、GLB、OBJ、MTL、RGB 纹理、PBR、金属度、法线和粗糙度图。
- 纹理 GLB：约 63 MB，1 mesh、1 material、3 images、3 textures、UV 存在，11,956 triangles，0 animation。
- 结论：贴图接口确实能为已有 UV 模型输出完整材质包；它不拆件、不创建动作、不保留游戏挂点语义，也不保证输入的图形漫画风格。因此只作为表面候选，必须与原作者化材质做 Blender/Godot 对照后再决定是否采用。

本次产物保存在 `artifacts/weaver/capability-study/texture/`，不把临时签名 URL 写入报告。
