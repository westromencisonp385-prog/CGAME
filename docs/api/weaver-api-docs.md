# VISVISE Weaver API 开发者文档

---

## 目录

- [1. 快速开始](#1-快速开始)
  - [1.1 产品简介](#11-产品简介)
  - [1.2 签名认证](#12-签名认证)
  - [1.3 接入流程](#13-接入流程)
  - [1.4 通用返回结构](#14-通用返回结构)
- [2. API 参考](#2-api-参考)
  - [2.1 公共数据结构](#21-公共数据结构)
  - [2.2 获取文件上传临时凭证](#22-获取文件上传临时凭证)
  - [2.3 获取用户剩余生成次数](#23-获取用户剩余生成次数)
  - [2.4 生成3D模型资产](#24-生成3d模型资产)
  - [2.5 生成多视图](#25-生成多视图)
  - [2.6 获取模型资产列表](#26-获取模型资产列表)
  - [2.7 获取算法模型列表](#27-获取算法模型列表)
  - [2.8 下载模型资产](#28-下载模型资产)
  - [2.9 删除模型资产](#29-删除模型资产)
  - [2.10 批量删除模型资产](#210-批量删除模型资产)
  - [2.11 去除图片背景](#211-去除图片背景)
  - [2.12 批量图生Pose](#212-批量图生pose)
  - [2.13 获取文生动画提示词Demo列表](#213-获取文生动画提示词demo列表)
  - [2.14 2D拆分](#214-2d拆分)
  - [2.15 打开拆分](#215-打开拆分)
  - [2.16 拆分编辑-智能拆分](#216-拆分编辑-智能拆分)
  - [2.17 拆分编辑-合并](#217-拆分编辑-合并)
  - [2.18 拆分编辑-修边](#218-拆分编辑-修边)
  - [2.19 保存拆分](#219-保存拆分)
  - [2.20 部件重命名](#220-部件重命名)
  - [2.21 重新生成模型](#221-重新生成模型)
  - [2.22 原画风格化](#222-原画风格化)
  - [2.23 花纹智能去除](#223-花纹智能去除)
  - [2.24 保存2D预处理资产](#224-保存2d预处理资产)
- [3. 模型生成 Demo](#3-模型生成-demo)
  - [3.1 图生360](#31-图生360)
  - [3.2 2D 拆分](#32-2d-拆分)
  - [3.3 2D预处理](#33-2d预处理)
    - [3.3.1 风格化](#331-风格化)
    - [3.3.2 智能去花纹](#332-智能去花纹)
  - [3.4 图生高模](#34-图生高模)
  - [3.5 图生中模](#35-图生中模)
  - [3.6 图生低模（本期暂未开放）](#36-图生低模本期暂未开放)
  - [3.7 布线重建](#37-布线重建)
  - [3.8 重拓扑](#38-重拓扑)
  - [3.9 LOD](#39-lod)
  - [3.10 UV](#310-uv)
  - [3.11 贴图纹理](#311-贴图纹理)
  - [3.12 2UV](#312-2uv)
  - [3.13 混元 3D API 区域](#313-混元-3d-api-区域)
- [4. 动画生成 Demo](#4-动画生成-demo)
  - [4.1 整体流程](#41-整体流程)
  - [4.2 智能骨骼架设](#42-智能骨骼架设)
  - [4.3 智能蒙皮](#43-智能蒙皮)
  - [4.4 3D动画生成](#44-3d动画生成)
    - [4.4.1 视频生动画](#441-视频生动画)
    - [4.4.2 文本生动画](#442-文本生动画)
  - [4.5 图生Pose](#45-图生pose)
  - [4.6 通用轮询逻辑](#46-通用轮询逻辑)
- [5. 错误码说明](#5-错误码说明)
  - [5.1 通用错误码](#51-通用错误码)
  - [5.2 重拓扑 / LOD 错误码](#52-重拓扑-lod-错误码)
  - [5.3 图生模 / 3D动画生成 错误码](#53-图生模-3d动画生成-错误码)
  - [5.4 智能骨骼架设 错误码](#54-智能骨骼架设-错误码)
  - [5.5 图生Pose 错误码](#55-图生pose-错误码)
  - [5.6 贴图纹理 错误码](#56-贴图纹理-错误码)
  - [5.7 2UV（AutoLUV）错误码](#57-2uvautoluv错误码)
- [6. SDK](#6-sdk)
  - [6.1 Python SDK](#61-python-sdk)
  - [6.2 Go SDK](#62-go-sdk)
  - [6.3 Java SDK](#63-java-sdk)
- [7. 版本更新记录](#7-版本更新记录)

---

## 1. 快速开始

### 1.1 产品简介

VISVISE 开放平台，是基于前沿 AI 技术打造的一站式 3D 资产全链路开放服务平台。平台以核心引擎 VISVISE Weaver 为技术底座，开放全套智能化 3D 生产能力，覆盖 3D 模型生成、重拓扑优化、LOD、骨骼自动架设、AI 智能蒙皮、动画智能生成等创作全流程资产制作能力。

**API 基础地址：**

```
https://ws.visvise.com.cn/openapi
```

---

### 1.2 签名认证

OpenAPI 采用 **HMAC-SHA256** 签名认证方式，您需要在每次请求的 HTTP Header 中携带以下参数：

| 参数名称 | 必选 | 类型 | 描述 |
|---|---|---|---|
| `app_id` | 是 | String | 客户端标识，由平台分配 |
| `rtx` | 是 | String | 实际使用人的 RTX（公司账号）。**按公司要求，内部用户必须传入实际使用人的 rtx**，不可使用项目账号或共享账号代填；外部用户可传业务标识 |
| `ts` | 是 | String | 当前时间戳（秒级） |
| `sign` | 是 | String | HMAC-SHA256 签名 |

> **关于 rtx 参数：** 该字段用于标识请求的实际发起人，便于审计与追溯。**内部用户必须传入实际使用人的 rtx，不可代填**——若由项目账号统一调用而所有请求都打到同一个 RTX 上，将无法满足公司合规要求。

**签名流程：**

![签名流程图](https://visvise-weaver-bj-rel-1311802504.cos.ap-beijing.myqcloud.com/weaver/public/%E7%AD%BE%E5%90%8D%E6%B5%81%E7%A8%8B%E5%9B%BE.png)

**签名算法：**

签名方式区分 GET 与 POST 请求：

- **GET 请求**：将 query 参数 + timestamp 按升序排序后用 `&` 拼接成字符串，使用 HMAC-SHA256 算法和密钥（key）生成签名。
- **POST 请求**：将请求体（body）序列化为 JSON 字符串后拼接 timestamp，使用 HMAC-SHA256 算法和密钥（key）生成签名。

**签名生成示例（Python）：**

```python
import hmac
import hashlib
import time
import json

app_id = "your_app_id"
key = "your_secret_key"
rtx = "actual_user_rtx"  # 实际使用人的 RTX；内部用户必须传实际使用人的，不可代填

ts = str(int(time.time()))
body = json.dumps({"name": "test_model", "node_type": 5})

# POST 签名：body + timestamp
sign_str = body + ts
sign = hmac.new(key.encode('utf-8'), sign_str.encode('utf-8'), hashlib.sha256).hexdigest()

headers = {
    "app_id": app_id,
    "rtx": rtx,
    "ts": ts,
    "sign": sign,
    "Content-Type": "application/json"
}
```

**签名生成示例（Go）：**

```go
package main

import (
    "crypto/hmac"
    "crypto/sha256"
    "encoding/hex"
    "encoding/json"
    "fmt"
    "time"
)

func main() {
    appID := "your_app_id"
    key := "your_secret_key"
    rtx := "actual_user_rtx" // 实际使用人的 RTX；内部用户必须传实际使用人的，不可代填

    ts := fmt.Sprintf("%d", time.Now().Unix())
    bodyBytes, _ := json.Marshal(map[string]interface{}{
        "name":      "test_model",
        "node_type": 5,
    })

    // POST 签名：body + timestamp
    signStr := string(bodyBytes) + ts
    h := hmac.New(sha256.New, []byte(key))
    h.Write([]byte(signStr))
    sign := hex.EncodeToString(h.Sum(nil))

    headers := map[string]string{
        "app_id":       appID,
        "rtx":          rtx,
        "ts":           ts,
        "sign":         sign,
        "Content-Type": "application/json",
    }
    fmt.Println(headers)
}
```

---

### 1.3 接入流程

**1. 申请 API 权限**
前往 [API 权限申请页面]() 提交申请，获取 `app_id` 和 `secret_key`。
调用每个接口时还需在 header 中传入 `rtx`（实际使用人的 RTX 公司账号）；内部用户必须传实际使用人的 RTX，外部用户可传业务标识。

**2. 获取 COS 临时密钥**
调用 [获取文件上传临时凭证](#22-获取文件上传临时凭证) 接口获取上传凭证。

**3. 上传资源**
通过 [COS SDK](https://cloud.tencent.com/document/product/436/6474) 上传图片/视频/模型文件（模型需 zip 压缩）。

**4. 创建任务**
调用 [生成3D模型资产](#24-生成3d模型资产) / [生成多视图](#25-生成多视图) 创建生成任务。

**5. 轮询结果**
调用 [获取模型资产列表](#26-获取模型资产列表) 轮询状态直到 `status=3`（成功）或 `status=4`（失败）。

**6. 获取产物**
从返回结果的 `output_model` 字段获取生成结果。

![接入流程图](https://visvise-weaver-bj-rel-1311802504.cos.ap-beijing.myqcloud.com/weaver/public/api_flow.svg)

---

### 1.4 通用返回结构

所有 API 接口统一返回以下 JSON 结构：

```json
{
    "code": 0,
    "msg": "success",
    "req_id": "unique-request-id",
    "data": { ... }
}
```

| 字段 | 类型 | 描述 |
|---|---|---|
| `code` | Integer | 错误码，`0` 表示正常，其他值为错误。详见 [错误码说明](#5-错误码说明) |
| `msg` | String | 错误信息，`code` 不为 0 时返回具体错误描述 |
| `req_id` | String | 请求唯一标识，用于问题排查 |
| `data` | Object | 接口返回的业务数据，具体结构因接口而异 |

---

## 2. API 参考

### 2.1 公共数据结构

以下枚举和数据结构在多个接口中复用。

#### 模型资产（status）状态码

| 状态值 | 含义 |
|---|---|
| `0` | 无效状态 |
| `1` | 等待生成 |
| `2` | 生成中 |
| `3` | 生成成功 |
| `4` | 生成失败 |

#### 节点类型（node_type）枚举

| 值 | 类型                | 说明                                    |
|---|-------------------|---------------------------------------|
| `1` | 重拓扑               | 对高面数模型进行拓扑优化                          |
| `2` | LOD               | 生成多级细节模型                              |
| `3` | 图生3D（高模）          | 从图片生成高精度3D模型                          |
| `4` | 3D动画生成            | 从视频/文本生成动画                            |
| `5` | 骨骼架设              | 自动为模型生成骨骼                             |
| `6` | 智能蒙皮              | 自动为模型绑定蒙皮权重                           |
| `7` | 图生360             | 从单张图片生成360度多视图                        |
| `8` | 贴图纹理              | 为模型生成贴图纹理                             |
| `9` | UV                | 自动UV展开                                |
| `10` | 布线重建              | 网格布线重建                                |
| `11` | 图生3D（中模）          | 从图片生成中精度3D模型                          |
| `12` | 图生Pose            | 从图片生成Pose动画                           |
| `13` | 图生3D（低模）⚠️ 本期暂未开放 | 从图片生成低精度3D模型（本期暂未开放，请改用高模/中模 + LOD 替代） |
| `14` | 2D 拆分             | 对图生360的多视图进行 2D 组件分割                  |
| `15` | 2UV               | 为模型生成第二套 UV（光照贴图 UV）                  |
| `16` | 2D预处理              | 对图片风格化/去花纹                            |

---

#### View

视图数据，包含多角度的图片地址。

| 参数名称 | 必选 | 类型 | 描述 |
|---|---|---|---|
| `main_view` | 是 | String | 主视图图片地址 |
| `back_view` | 否 | String | 背视图图片地址 |
| `left_view` | 否 | String | 左视图图片地址 |
| `right_view` | 否 | String | 右视图图片地址 |

#### TemplateParams

生成参数，根据 [node_type](#节点类型node_type枚举) 选填对应子结构。

| 参数名称 | 类型 | 适用 node_type | 描述 |
|---|---|---|---|
| `re_topology_params` | [ReTopologyParams](#retopologyparams) | 1 | 重拓扑 参数 |
| `lod_params` | [LODParams](#lodparams) | 2 | LOD 参数 |
| `image_gen_model_params` | [ImageGenModelParams](#imagegenmodelparams) | 3, 11, 13 | 图生模（高模/中模/低模）参数 |
| `framing_ai_params` | [FramingAIParams](#framingaiparams) | 4 | 3D动画生成 参数 |
| `go_rigging_params` | [GoRiggingParams](#goriggingparams) | 5 | 智能骨骼架设 参数 |
| `image_gen_360_params` | [ImageGen360Params](#imagegen360params) | 7 | 图生360 参数 |
| `tex_params` | [TexParams](#texparams) | 8 | 贴图纹理 参数 |
| `uv_params` | [UVParams](#uvparams) | 9 | UV 参数 |
| `mesh_refine_params` | [MeshRefineParams](#meshrefineparams) | 10 | 布线重建 参数 |
| `image_gen_pose_params` | [ImageGenPoseParams](#imagegenposeparams) | 12 | 图生Pose 参数 |
| `seg_params_2d` | [SegParams2D](#segparams2d) | 14 | 2D 拆分节点参数 |
| `auto_luv_params` | [AutoLuvParams](#autoluvparams) | 15 | 2UV 参数 |
| `pre_2d_params` | [Pre2DParams](#pre2dparams) | 16 | 2D 预处理参数|

#### ImageGenModelParams

图生模参数。

| 参数名称 | 必选 | 类型 | 描述 |
|---|---|---|---|
| `algorithm_model` | 是 | String | 算法模型名称，可通过 [获取算法模型列表](#27-获取算法模型列表) 获取 |
| `output_model_format` | 是 | String | 输出格式：`fbx` / `obj` / `glb`（SDK 枚举：`OutputModelFormat.FBX` / `.OBJ` / `.GLB`）|
| `face_type` | 是 | Unsigned Integer | 面数类型：1 三角面 / 2 四边面（SDK 枚举：`FaceType.TRIANGLE` / `.QUAD`） |
| `face_num` | 否 | Unsigned Integer | 面数参数。中模（node_type=11）取值范围 0&#126;30000，0 使用默认值；高模（node_type=3）取值范围 1000&#126;1500000，不传则自动配置 |
| `segment_model_id` | 否 | String | 2D 分割资产 ID（node_type=14 的 model_id），配合 [2D 拆分](#32-2d-拆分) 任务使用，传入后将基于分割结果生成模型。<br>**图生中模（node_type=11）**：<br>• 仅传 `segment_model_id`（不传 `component_label`）：触发全部部件一起生成，不需要传 `input_view`<br>• 同时传 `segment_model_id` + `component_label`：触发单部件生成，不需要传 `input_view`<br>**图生高模（node_type=3）**：<br>• 仅传 `segment_model_id` 为**无效参数**<br>• 同时传 `segment_model_id` + `component_label`：触发单部件生成，不需要传 `input_view` |
| `component_label` | 否 | Integer | 2D 分割资产的单部件 label，配合 `segment_model_id` 使用。传入后根据该 label 对应的部件单独生成 3D 模型，不需要传 `input_view`。<br>**取值来源**：完成 [2D 拆分](#32-2d-拆分) 后，从 `ModelInfo.segment_output.{view}.components[].label` 获取（详见 [SegmentComponent](#segmentcomponent)）。<br>适用场景：<br>• **图生中模（node_type=11）**：`segment_model_id` + `component_label` 触发单部件生成<br>• **图生高模（node_type=3）**：`segment_model_id` + `component_label` 触发单部件生成（仅此方式支持分割输入） |
| `model_id_360` | 否 | String | 图生 360 资产 ID（node_type=7 的 model_id）。**仅图生中模（node_type=11）** 有效，传入后将直接使用前置 360 任务的多视图结果生成模型，无需再传 `input_view`。图生高模（node_type=3）不支持 |
| `enable_a_pose` | 否 | Bool | 是否开启 A-Pose，默认 false |
| `enable_pbr` | 否 | Bool | 图生高模贴图开关，默认 false。启用后输出模型将使用 PBR 材质类型（仅混元算法生效） |
| `strict_mode` | 否 | Bool | 是否按照目标面数强制生成，默认 true |
| `skip_360_preprocess` | 否 | Bool | 是否跳过图生 360 前置处理。多图输入时使用，需要 ≥3 张视图且含 front + back，默认 false |
| `group_ids` | 否 | String | `final_group_ids.npz` COS 路径。传入后直接使用该分组结果；未传时自动生成分组结果 |
| `packed_part_images` | 否 | String | 部件图片 zip 包 COS 路径 |
| `part_names` | 否 | String | part_id → part_name 映射的 JSON 字符串，格式如 `{"3":"头部"}` |

#### ReTopologyParams

重拓扑参数。

| 参数名称 | 必选 | 类型 | 描述 |
|---|---|---|---|
| `algorithm_model` | 是 | String | 算法模型，可通过 [获取算法模型列表](#27-获取算法模型列表) 获取 |
| `face_type` | 是 | Unsigned Integer | 拓扑类型，1 三角面 / 2 四边面，参考：[图生模参数中的描述](#imagegenmodelparams) |
| `output_model_format` | 是 | String | 模型格式，支持 `fbx` / `obj` ，参考：[图生模参数中的描述](#imagegenmodelparams) |
| `detail_level` | 否 | Unsigned Integer | 精细程度：1 低 / 2 中 / 3 高，若是「混元 1.5 模型」，则必传<br />- `Python SDK` 枚举：`DetailLevel.LOW` / `.MEDIUM` / `.HIGH`）<br />- `Go SDK` 枚举：`DetailLevelLow` / `DetailLevelMedium` / `DetailLevelHigh`<br />- `Java SDK` 枚举：`DetailLevel.LOW` / `.MEDIUM` / `.HIGH` |
| `face_num` | 否 | Unsigned Integer | 生成面数。VISVISE 自研模型必传；混元 2.0 模型可选，不传则自动匹配面数，visvise 模型取值范围 200-40000, 混元 2.0 模型取值范围 1000-20000 |
| `smooth_strength` | 否 | Float | 平滑强度，当前只支持 `0.0`（不平滑） 或 `1.0`（完全平滑），不传默认 `1.0` |

> 💡 根据算法模型选择参数：混元 1.5 模型传 `detail_level`，VISVISE 自研模型传 `face_num`，混元 2.0 模型可选传 `face_num`（不传则自动匹配面数）。

#### LODParams

LOD 减面参数。

| 参数名称 | 必选 | 类型 | 描述 |
|---|---|---|---|
| `algorithm_model` | 是 | String | 算法模型，可通过 [获取算法模型列表](#27-获取算法模型列表) 获取 |
| `reduce_faces` | 是 | Array of [ReduceFace](#reduceface) | 减面配置数组 |
| `output_model_format` | 是 | String | 模型格式，支持 `fbx` / `obj` |
| `gen_times` | 否 | Integer | 生成次数，用于抽卡选择，不需要抽卡传 `1`，建议传 `3`（抽卡 `3` 次），默认 `1` |

#### ReduceFace

单个 LOD 级别的减面配置。

| 参数名称 | 必选 | 类型 | 描述 |
|---|---|---|---|
| `reduce_level` | 是 | Integer | 减面等级，默认传1 |
| `reduce_percent` | 否 | Integer | 减面百分比：20~99 |
| `face_num` | 否 | Integer | 保面面数，面数和百分比二选一，不可同时传递 |
| `face_type` | 是 | Integer | 面数类型：1 三角面 / 2 四边面 |
| `algorithm_model` | 否 | String | 算法模型 |
| `face_tab` | 否 | Unsigned Integer | 保面 Tab 切换，支持 `0` 按比例 / `1` 按面数 |

#### FramingAIParams

3D动画生成参数。

| 参数名称 | 必选 | 类型 | 描述 |
|---|---|---|---|
| `algorithm_model` | 是 | String | 算法模型，可通过 [获取算法模型列表](#27-获取算法模型列表) 获取 |
| `output_model_format` | 是 | String | 输出模型格式，支持 `fbx` / `bvh` |
| `prompt` | 否 | String | 文生动画单段提示词。可通过 [获取文生动画提示词Demo列表](#213-获取文生动画提示词demo列表) 获取参考 |
| `rotate_axis_angle` | 否 | Array of Float | 旋转轴角，固定 3 个元素 `[x, y, z]`（弧度） |
| `with_hand` | 否 | Bool | 手部捕捉，默认为 `false` |
| `multiple_track` | 否 | Bool | 多人捕捉，默认为 `false` |
| `enable_rewrite` | 否 | Bool | 是否开启 rewrite 选项（文生动画选项），默认 `true` |
| `duration` | 否 | Integer | 文生动画单段生成时长（单位 s） |
| `segments` | 否 | Array of [MotionSegment](#motionsegment) | 多段时间轴列表（支持 1~15 段，非空时以 `segments` 为准） |
| `enable_loop` | 否 | Bool | 是否开启循环播放 |
| `loop_frames` | 否 | Integer | 循环帧数，输入范围 1~20 |

##### MotionSegment

时间轴动作段参数。

| 参数名称 | 必选 | 类型 | 描述 |
|---|---|---|---|
| `text` | 是 | String | 动作描述 |
| `num_frames` | 否 | Integer | 帧数，与 `duration` 必须有一个不为空，同时提供时以 `num_frames` 为准 |
| `duration` | 否 | Float | 段时长（s） |
| `overlap_frames_with_prev` | 否 | Integer | 该段前面的过渡帧数 |
| `overlap_duration_with_prev` | 否 | Float | 该段前面的过渡时长（s） |

#### ImageGen360Params

图生360参数。

| 参数名称 | 必选 | 类型 | 描述 |
|---|---|---|---|
| `algorithm_model` | 是 | String | 算法模型，可通过 [获取算法模型列表](#27-获取算法模型列表) 获取 |
| `enable_a_pose` | 否 | Bool | 标准化A-Pose，默认为 `false` |
| `prompt` | 否 | String | 文本提示词 |
| `style` | 否 | String | 风格类型（仅 VISVISE 自研模型支持），**只接受以下固定枚举值**，传其它自定义值会被服务端拒绝：`灰模` / `超写实` / `Q版卡通` / `像素风格`。不传则不做风格转换<br />- `Python SDK` 枚举：`ImageGen360Style.GRAY_MODEL` / `.PHOTOREAL` / `.Q_TOON` / `.PIXEL`<br />- `Go SDK` 枚举：`GRAY_MODEL` / `PHOTOREAL` / `Q_TOON` / `PIXEL`<br />- `Java SDK` 枚举：`GRAY_MODEL` / `PHOTOREAL` / `Q_TOON` / `PIXEL` |

#### TexParams
贴图纹理参数。

| 参数名称 | 必选 | 类型 | 描述 |
|---|---|---|---|
| `algorithm_model` | 是 | String | 算法模型，可通过 [获取算法模型列表](#27-获取算法模型列表) 获取 |
| `resolution` | 否 | Long Integer | 贴图分辨率 |
| `unwarp_uv` | 否 | Bool | 保持模型原始 UV，默认为 `false` |
| `prompt` | 否 | String | 文本贴图提示词 |

#### UVParams
UV 展开参数。

| 参数名称 | 必选 | 类型 | 描述 |
|---|---|---|---|
| `algorithm_model` | 是 | String | 算法模型，可通过 [获取算法模型列表](#27-获取算法模型列表) 获取 |
| `enable_auto_smoothing` | 否 | Bool | 开启自动平滑，默认为 `false` |
| `output_model_format` | 否 | String | 输出格式 |
| `lightmap_resolution` | 否 | Unsigned Integer | 纹理分辨率（像素），取值范围 16~2048，未传默认 `1024`。**仅自研 UV 模型（`VV-UV-v2.6.0`）有效** |
| `uv_island_padding` | 否 | Unsigned Integer | UV 岛边沿像素数，取值范围 1~16，步进 1，未传默认 `1`。**仅自研 UV 模型（`VV-UV-v2.6.0`）有效** |
| `pack_into_same_uv_space` | 否 | Bool | 多 mesh 是否 pack 到同一 UV 空间，以前端传值为准，未传默认 `false`。**仅自研 UV 模型（`VV-UV-v2.6.0`）有效** |

> 说明：`lightmap_resolution` / `uv_island_padding` / `pack_into_same_uv_space` 是自研 UV 模型（`VV-UV-v2.6.0`）的专属参数，混元 UV（`Hy3D-UV-*`）不使用。服务端仅在自研 UV 模型下做范围校验与默认值补齐，未传时返回给前端的三个参数均为补齐后的默认值。

#### MeshRefineParams
布线重建参数。

| 参数名称 | 必选 | 类型 | 描述 |
|---|---|---|---|
| `algorithm_model` | 是 | String | 算法模型，可通过 [获取算法模型列表](#27-获取算法模型列表) 获取 |
| `input_model_format` | 否 | String | 输入模型格式 |
| `mode` | 否 | Integer | 处理模式：1 布线优化 / 2 布线加密，默认 1 布线优化<br />- `Python SDK` 枚举：`MeshRefineMode.OPTIMIZE` / `.DENSIFY`<br />- `Go SDK` 枚举：`MeshRefineModeOptimize` / `MeshRefineModeDensify`<br />- `Java SDK` 枚举：`MeshRefineMode.OPTIMIZE` / `.DENSIFY` |
| `face_num` | 否 | Unsigned Integer | 目标面数，仅布线优化（mode=1）支持，取值范围 0~50000，0 表示不设置 |
| `color_model` | 否 | String | 颜色模型文件 COS 路径 |
| `basecolor_image` | 否 | String | 基础颜色图片 COS 路径 |

#### GoRiggingParams
智能骨骼架设参数。

| 参数名称 | 必选 | 类型 | 描述 |
|---|---|---|---|
| `algorithm_model` | 是 | String | 算法模型，可通过 [获取算法模型列表](#27-获取算法模型列表) 获取 |
| `template_skeleton` | 否 | String | 模板骨骼 COS 地址 |
| `enable_auto_skinning` | 否 | Bool | 是否开启一键骨骼+蒙皮（`algo_scenario=4`） |

#### ImageGenPoseParams
图生 Pose 参数。

| 参数名称 | 必选 | 类型 | 描述 |
|---|---|---|---|
| `algorithm_model` | 是 | String | 算法模型名称 |
| `output_model_format` | 是 | String | 输出格式 |
#### SegParams2D
2D 拆分节点参数。

| 参数名称 | 必选 | 类型 | 描述 |
|---|---|---|---|
| `model_id_360` | 是 | String | 图生360的模型资产 ID |
| `split_type` | 否 | Integer | 拆分方式，1 正视图拆分 / 2 四视图拆分<br />- `Python SDK` 枚举：`SegmentSplitType.FRONT_VIEW` / `.FOUR_VIEW`<br />- `Go SDK` 枚举：`SegmentSplitFrontView` / `SegmentSplitFourView`<br />- `Java SDK` 枚举：`SegmentSplitType.FRONT_VIEW` / `.FOUR_VIEW` |
| `granularity` | 否 | Integer | 拆分颗粒度，1 粗（×50%）/ 2 中（×70%）/ 3 细（×100%）<br />- `Python SDK` 枚举：`SegmentGranularity.COARSE` / `.MEDIUM` / `.FINE`<br />- `Go SDK` 枚举：`SegmentGranularityCoarse` / `SegmentGranularityMedium` / `SegmentGranularityFine`<br />- `Java SDK` 枚举：`SegmentGranularity.COARSE` / `.MEDIUM` / `.FINE` |
| `prompt` | 否 | String | 拆分提示词，用户用自然语言描述拆分规则，AI 参考执行（最大长度 200 个字符） |

#### AutoLuvParams

2UV（第二套 UV / 光照贴图 UV）参数。

| 参数名称 | 必选 | 类型 | 描述 |
|---|---|---|---|
| `algorithm_model` | 是 | String | 算法模型名称，可通过 [获取算法模型列表](#27-获取算法模型列表) 获取 |
| `mesh_name` | 是 | String | 需要生成 2UV 的 mesh 模型名称 |
| `light_map_resolution` | 是 | Integer | 光照纹理分辨率，取值范围 16~2048 |
| `edge_pixel_count` | 是 | Float | 边沿像素数，取值范围 0.5~16 |
| `coord_axis` | 是 | Integer | 坐标系方向：`1` Y 轴朝上 / `2` Z 轴朝上 |
| `out_channel` | 是 | Integer | 输出通道：`1` ~ `4` |
| `split_strategy` | 否 | Integer | 切割策略：`1` 消极切割 / `2` 均衡切割 / `3` 积极切割，默认均衡切割 |
#### Pre2DParams

2D 预处理参数。

| 参数名称 | 必选 | 类型 | 描述 |
|---|---|---|---|
| `preprocess_type` | 是 | Integer | 预处理类型：`1` 风格化 / `2` 去花纹 |
| `style_param` | 否 | [StyleParam](#styleparam) | 风格化参数；当 `preprocess_type=1` 时必传 |
| `remove_pattern_param` | 否 | [RemovePatternParam](#removepatternparam) | 去花纹参数；当 `preprocess_type=2` 时必传 |

#### StyleParam

| 参数名称 | 必选 | 类型 | 描述 |
|---|---|---|---|
| `style_type` | 是 | Integer | 风格类型：`1` 灰模风 / `2` 像素风 / `3` 写实风 / `4` 卡通手办风 |
| `result_image` | 是 | String | 风格化接口返回的结果图片 COS URL |

#### RemovePatternParam

| 参数名称 | 必选 | 类型 | 描述 |
|---|---|---|---|
| `result_image` | 是 | String | 智能去花纹接口返回的结果图片 COS URL |

#### ModelInfo

模型资产信息，由 [获取模型资产列表](#26-获取模型资产列表) 返回。

| 参数名称                  | 类型 | 描述 |
|-----------------------|---|---|
| `model_id`            | String | 模型 ID |
| `parent_model_id`     | String | 父模型 ID |
| `name`                | String | 模型名称 |
| `node_type`           | Integer | 节点类型，参考 [节点类型枚举](#节点类型node_type枚举) |
| `create_user`         | String | 创建人 |
| `create_ts`           | Integer | 创建时间戳 |
| `works_id`            | String | 作品 ID |
| `preview_img`         | String | 预览图片地址（预签名，24h 有效）。注意：预览图为异步生成，模型成功后不会马上有预览图 |
| `output_model`        | String | 输出模型地址（zip 文件，预签名，24h 有效） |
| `preview_model`       | String | 预览模型地址 |
| `input_model`         | String | 输入模型地址（zip 文件，预签名，24h 有效） |
| `input_video`         | String | 输入视频地址（预签名，24h 有效） |
| `time_cost`           | Integer | 已花费耗时（秒） |
| `remaining_time`      | Integer | 预计剩余时间（秒），注意：该字段有 **60 秒下限保护**，当实际剩余时间低于 60s 时将固定返回 60，不反映真实剩余时间 |
| `wait_time`           | Integer | 模型排队的等待时间（秒） |
| `progress`            | [Progress](#progress) | 生成进度信息（2UV 节点返回各 mesh 的生成进度） |
| `failed_reason`       | [FailedReason](#failedreason) | 生成失败时的失败原因（`status=4` 有值） |
| `lod_output`          | [LODOutput](#lodoutput) | LOD的输出结果，仅「LOD」节点有值 |
| `image_gen_360_output` | [ImageGen360Output](#imagegen360output) | 图生360的输出结果，仅「图生360」节点有值 |
| `framing_ai_output`   | [FramingAIOutput](#framingaioutput) | 3D动画生成的输出结果，仅「3D动画生成」节点有值 |
| `segment_output` | [SegmentOutput](#segmentoutput) | 2D拆分生成的输出结果，仅「2D拆分」节点有值 |
| `input_view`          | [View](#view) | 输入的视图数据 |
| `params` | [TemplateParams](#templateparams) | 生成参数 |
| `algorithm_model`     | String | 算法模型 |
| `model_type`          | Integer | 模型类型：`0` 默认普通模型 / `1` 前处理模型 / `2` 2D 对话模型 / `3` 模型库模型 |
| `is_allow_regenerate` | Bool | 是否允许重生成 |
| `rewrite_prompts`     | Array of String | 文生动画开启 `enable_rewrite` 后，算法改写后的各段提示词，与输入 `segments` 顺序一致。仅「3D动画生成（文本生动画）」节点有值 |
| `feedbacks`           | Array of [FeedbackItem](#feedbackitem) | 反馈详情列表 |
| `status`              | Integer | 资产状态，参考 [模型资产状态码](#模型资产status状态码) |

#### FeedbackItem

模型反馈详情。

| 参数名称 | 类型 | 描述 |
|---|---|---|
| `result_index` | Integer | 结果索引，普通节点为 1，文生动画节点为 1~4 |
| `feedback_type` | Integer | 反馈类型：`0` 未反馈 / `1` 满意 / `2` 不满意 |
| `tags` | Array of String | 问题标签列表 |
| `content` | String | 反馈文字描述 |

#### ImageGen360Output

图生360的输出结果。

| 参数名称 | 类型 | 描述 |
|---|---|---|
| `output_view` | [View](#view) | 输出的多视图 |
| `horizontal_view_video` | String | 水平视角的旋转视频 |
| `vertical_view_video` | String | 垂直视角的旋转视频 |
| `horizontal_view_video_frames` | String | 72 帧压缩包 COS 地址 |

#### FramingAIOutput

3D动画生成的输出结果。

| 参数名称 | 类型 | 描述 |
|---|---|---|
| `text2_motion_result` | Array of [Text2Motion](#text2motion) | 输出文件列表 |
| `rewrite_prompts` | Array of String | Rewrite 改写后的各段文本，与 `segments` 顺序一致 |
| `rewrite_applied` | Bool | 本次是否实际执行了 Rewrite |

##### Text2Motion

| 参数名称 | 类型 | 描述 |
|---|---|---|
| `output_model` | String | 模型地址（zip 文件，预签名，24h 有效） |
| `preview_img` | String | 模型预览图（预签名，24h 有效） |

#### SegmentOutput

2D拆分生成的输出结果。

| 参数名称 | 类型 | 描述 |
|---|---|---|
| `main_view` | [SegmentViewData](#segmentviewdata) | 正视图分割数据（必填） |
| `left_view` | [SegmentViewData](#segmentviewdata) | 左视图分割数据（四视图阶段填充） |
| `right_view` | [SegmentViewData](#segmentviewdata) | 右视图分割数据（四视图阶段填充） |
| `back_view` | [SegmentViewData](#segmentviewdata) | 背视图分割数据（四视图阶段填充） |
| `origin_view` | [View](#view) | 原始四视图 URL（从图生 360 继承） |
| `color_imgs` | [SegmentColorImgs](#segmentcolorimgs) | 四视图彩色预览图 |

##### SegmentViewData

单视图分割数据。

| 参数名称 | 类型 | 描述 |
|---|---|---|
| `components` | Array of [SegmentComponent](#segmentcomponent) | 部件列表 |
| `shape` | Array of Integer | mask 图尺寸，格式为 [H, W] |
| `data_path` | String | .npz 文件 COS URL（预签名，24h 有效） |
| `mask_image_path` | String | 灰度 mask PNG COS URL（预签名，24h 有效） |

##### SegmentComponent

分割部件。

| 参数名称 | 类型 | 描述 |
|---|---|---|
| `label` | Integer | 连通体 label |
| `color` | String | 颜色，如 "#b9f75e" |
| `name` | String | 部件名 |

##### SegmentColorImgs

四视图彩色预览图。

| 参数名称 | 类型 | 描述 |
|---|---|---|
| `main_view` | String | 正视图彩色预览图 COS URL（预签名，24h 有效） |
| `left_view` | String | 左视图彩色预览图 COS URL（预签名，24h 有效） |
| `right_view` | String | 右视图彩色预览图 COS URL（预签名，24h 有效） |
| `back_view` | String | 背视图彩色预览图 COS URL（预签名，24h 有效） |

#### Progress

生成进度信息。

| 参数名称 | 类型 | 描述 |
|---|---|---|
| `redo_count` | Integer | 重做次数 |
| `auto_luv` | [AutoLuvProgress](#autoluvprogress) | 2UV 进度 |

#### AutoLuvProgress

2UV 生成进度。

| 参数名称 | 类型 | 描述 |
|---|---|---|
| `redo_current_index` | Integer | 当前重做索引 |
| `list` | Array of [AutoLuvProgressInfo](#autoluvprogressinfo) | 各 mesh 的 2UV 生成进度列表 |

#### AutoLuvProgressInfo

单个 mesh 的 2UV 生成进度。

| 参数名称 | 类型 | 描述 |
|---|---|---|
| `mesh_name` | String | mesh 模型名称 |
| `status` | Unsigned Integer | 生成状态：`0` 无效 / `1` 等待生成 / `2` 生成中 / `3` 生成成功 / `4` 生成失败 |
| `failed_reason` | [FailedReason](#failedreason) | 生成失败时的失败原因（`status=4` 时返回） |
| `auto_luv_params` | [AutoLuvParams](#autoluvparams) | 该 mesh 的 2UV 参数 |

#### FailedReason

生成失败原因。错误码详见 [错误码说明](#5-错误码说明)。

| 参数名称 | 类型 | 描述 |
|---|---|---|
| `code` | Integer | 错误码 |
| `reason` | String | 原因描述 |

#### LODOutput

LOD 输出文件信息。

| 参数名称 | 类型 | 描述 |
|---|---|---|
| `lod_files` | Array of [LODFile](#lodfile) | 输出文件列表 |
| `zip_file` | String | 整包 zip 文件COS地址（预签名，24h 有效） |
| `del_times` | Integer | 模型抽卡删除次数 |
| `del_card_indexs` | Array of Unsigned Integer | 已删除的抽卡索引记录 |

##### LODFile

单个 LOD 级别的输出文件。

| 参数名称 | 类型 | 描述 |
|---|---|---|
| `reduce_level` | Integer | 减面等级 |
| `download_url` | String | 下载地址（预签名，24h 有效） |
| `preview_img` | String | 预览图片（预签名，24h 有效） |

---

### 2.2 获取文件上传临时凭证

获取 COS 临时密钥，用于客户端直传文件到 COS。

**接口路径：** `POST https://ws.visvise.com.cn/openapi/weaver/resource/get_cos_cred`

#### 请求参数

| 参数名称 | 必选 | 类型 | 描述 |
|---|---|---|---|
| `is_temp` | 否 | Bool | 是否是临时文件。无特殊情况，请不要使用临时文件，有可能会导致接口报错 |
| `is_public` | 否 | Bool | 是否上传到公有读目录，默认为 `false` |

#### 响应参数

`data` 字段结构（`GetCosCredResult`）

| 参数名称 | 类型 | 描述 |
|---|---|---|
| `cred` | [Cred](#cred-结构) | COS 临时凭证 |
| `start_time` | Unsigned Integer | 密钥生效时间（Unix 时间戳，秒） |
| `expired_time` | Unsigned Integer | 密钥过期时间（Unix 时间戳，秒） |
| `bucket` | String | COS Bucket 名称 |
| `region` | String | COS Region |
| `path_prefix` | String | 允许上传的文件路径前缀 |

##### `Cred` 结构

| 参数名称 | 类型 | 描述 |
|---|---|---|
| `tmp_secret_id` | String | 临时证书密钥 ID |
| `tmp_secret_key` | String | 临时证书密钥 Key |
| `session_token` | String | 临时 Token |

#### 请求示例

<!-- tabs:start -->

#### **CURL**

```bash
curl -X POST 'https://ws.visvise.com.cn/openapi/weaver/resource/get_cos_cred' \
  -H 'Content-Type: application/json' \
  -H 'app_id: your_app_id' \
  -H 'ts: 1713168000' \
  -H 'rtx: caller_rtx' \
  -H 'sign: your_sign' \
  -d '{
    "is_temp": false
  }'
```

#### **Python**

```python
from visvise import VisviseClient

client = VisviseClient(app_id="your_app_id", secret_key="your_secret_key")
cred = client.api.get_cos_cred(is_temp=False, rtx="caller_rtx")
print(cred.bucket, cred.region, cred.path_prefix)
print(cred.cred.tmp_secret_id, cred.expired_time)
```

#### **Go**

```go
package main

import (
    "fmt"
    "github.com/tencent-visvise/visvise-sdk-go/visvise"
)

func main() {
    client := visvise.NewClient("your_app_id", "your_secret_key", nil)
    cred, err := client.GetAPI().GetCosCred(false, false, "caller_rtx")
    if err != nil {
        panic(err)
    }
    fmt.Println(cred.Bucket, cred.Region, cred.PathPrefix)
    fmt.Println(cred.Cred.TmpSecretID, cred.ExpiredTime)
}
```

<!-- tabs:end -->

#### 响应示例

```json
{
    "code": 0,
    "msg": "success",
    "req_id": "req_abc123",
    "data": {
        "cred": {
            "tmp_secret_id": "AKIDxxxxxxxxxxxxx",
            "tmp_secret_key": "xxxxxxxxxxxxxxxx",
            "session_token": "xxxxxxxxxxxxxxxx"
        },
        "start_time": 1713168000,
        "expired_time": 1713171600,
        "bucket": "visvise-weaver-bj-1311802504",
        "region": "ap-beijing",
        "path_prefix": "weaver/user-xxx/20260415/"
    }
}
```

---

### 2.3 获取用户剩余生成次数

获取当前 API Key 当日剩余的模型和动画生成次数。

**接口路径：** `POST https://ws.visvise.com.cn/openapi/weaver/resource/get_user_quota`

#### 请求参数

无需请求参数（传空 body `{}`）。

#### 响应参数

`data` 字段结构（`DescribeUserQuotaResult`）

| 参数名称 | 类型 | 描述 |
|---|---|---|
| `model_quota` | Unsigned Integer | 模型剩余生成次数配额 |
| `animation_quota` | Unsigned Integer | 动画剩余生成次数配额 |
| `server_ts` | Unsigned Long Integer | 服务器当前时间戳（毫秒） |
| `image_processing_quota` | Unsigned Integer | 图片处理剩余限制次数 |

#### 请求示例

<!-- tabs:start -->
#### **CURL**

```bash
curl -X POST 'https://ws.visvise.com.cn/openapi/weaver/resource/get_user_quota' \
  -H 'Content-Type: application/json' \
  -H 'app_id: your_app_id' \
  -H 'ts: 1713168000' \
  -H 'rtx: caller_rtx' \
  -H 'sign: your_sign' \
  -d '{}'
```

#### **Python**

```python
from visvise import VisviseClient

client = VisviseClient(app_id="your_app_id", secret_key="your_secret_key")
quota = client.api.get_user_quota(rtx="caller_rtx")
print(f"模型配额: {quota.model_quota}, 动画配额: {quota.animation_quota}, 服务器时间戳: {quota.server_ts}")
```

#### **Go**

```go
package main

import (
    "fmt"
    "github.com/tencent-visvise/visvise-sdk-go/visvise"
)

func main() {
    client := visvise.NewClient("your_app_id", "your_secret_key", nil)
    quota, err := client.GetAPI().GetUserQuota("caller_rtx")
    if err != nil {
        panic(err)
    }
    fmt.Printf("模型配额: %d, 动画配额: %d, 服务器时间戳: %d\n", quota.ModelQuota, quota.AnimationQuota, quota.ServerTS)
}
```

<!-- tabs:end -->

#### 响应示例

```json
{
    "code": 0,
    "msg": "success",
    "req_id": "req_abc123",
    "data": {
        "model_quota": 100,
        "animation_quota": 50,
        "server_ts": 1713168000000
    }
}
```

---

### 2.4 生成3D模型资产

核心接口，用于创建各类 3D 生成任务。该接口为**异步接口**，调用后立即返回模型 ID，通过 [获取模型资产列表](#26-获取模型资产列表) 轮询任务状态。

**接口路径：** `POST https://ws.visvise.com.cn/openapi/weaver/resource/gen_3d_model`

#### 请求参数

| 参数名称 | 必选 | 类型 | 描述 |
|---|---|---|---|
| `name` | 是 | String | 模型资产名称，长度为 1~100 个字符 |
| `node_type` | 是 | Integer | 节点类型，参考 [节点类型枚举](#节点类型node_type枚举) |
| `input_view` | 否 | [View](#view) | 用户上传的原画视图；「图生360」/「图生高模」/「贴图纹理」节点必传 |
| `input_model` | 否 | String | 模型的 COS 地址（zip 文件）；「布线重建」/「重拓扑」/「UV」/「贴图纹理」/「LOD」/「骨骼架设」/「智能蒙皮」/「3D动画生成」/「2UV」节点必传 |
| `input_model_format` | 否 | String | 模型格式，支持 `fbx` / `obj` / `glb`；「图生高模」/「重拓扑」/「LOD」/「3D动画生成」节点必传<br />1、「图生高模」/「重拓扑」/「LOD」， 仅支持 `fbx` / `obj`  <br />2、「3D动画生成」，仅支持 `fbx` |
| `input_video` | 否 | String | 视频的 COS 地址（非 zip 文件）；「3D动画生成」节点必传 |
| `params` | 是 | [TemplateParams](#templateparams) | 生成参数（根据对应的节点，对参数进行赋值） |

#### 响应参数

`data` 字段结构（`Gen3DModelResult`）：

| 参数名称 | 类型 | 描述 |
|---|---|---|
| `model_ids` | Array of String | 新生成的模型 ID 列表。**数量取决于 `node_type` 和子参数**，详见下方对照表。 |

##### 数量与 `node_type` / 子参数对照表

| 业务场景 | `node_type` | 关键子参数 | `model_ids` 数量 | 说明 |
|---|---|---|---|---|
| 重拓扑 | 1 | `params.re_topology_params` |  |  |
| LOD | 2 | `params.lod_params.reduce_faces` + `gen_times` | N（= `reduce_faces` 长度，每档一个 `model_id`） | 每个 model_id 内部包含 M 个抽卡输出（M = `gen_times`，默认 1）。`output_model` 是统一打包的 zip，单个抽卡产物可在 [`lod_output`](#lodoutput) 字段中按 `lod_files` 数组逐个查看 |
| 图生高模 | 3 | `params.image_gen_model_params` | 1 |  |
| 3D画生成（视频生动画） | 4 | `input_video`（不传 `prompt`） | 1 |  |
| 3D画生成（文本生动画） | 4 | `params.framing_ai_params.prompt`（不传 `input_video`） |  | 单个 `model_id` 内部包含 4 个抽卡候选。`output_model` 是统一打包的 zip，单个抽卡产物可在 [`framing_ai_output.text2_motion_result`](#framingaioutput) 数组中逐个查看（每条含 `output_model` + `preview_img`） |
| 智能骨骼架设 | 5 | `params.go_rigging_params` | 1 |  |
| 智能蒙皮 | 6 | `params.go_skinning_params` | 1 |  |
| 图生 360 | 7 | `params.image_gen_360_params` | 1 |  |
| 贴图纹理 | 8 | `params.tex_params` | 1 |  |
| UV | 9 | `params.uv_params` | 1 |  |
| 布线重建 | 10 | `params.mesh_refine_params` | 1 |  |
| 图生中模 | 11 | `params.image_gen_model_params` | 1 | |
| 图生 Pose | 12 | `params.image_gen_pose_params.input_images`（≤10 张） | N | N = `input_images` 长度，也可通过 [批量图生 Pose](#212-批量图生pose) 拆分多账号并发 |
| 图生低模（暂未开放） | 13 | `params.image_gen_model_params`                        | 1                                                   | 见 §3.5 |
| 2UV | 15 | `params.auto_luv_params` | **1** | 返回 1 个 model_id，进度通过 `progress.auto_luv` 查看 |

> **客户端处理建议**：
>
> - **LOD / 图生 Pose**：返回多个 `model_id`，必须**遍历 `model_ids` 数组**逐个轮询 `wait_model`。LOD 取每个 model 内部 `lod_output.lod_files[]` 看单个抽卡产物，整体 zip 下载使用 `output_model`；图生 Pose 每个 `input_image` 各对应一个 `model_id`。
> - **文本生动画**：返回 **1 个** `model_id`，但内部含 4 个抽卡候选。轮询完成后从 `framing_ai_output.text2_motion_result[]` 取每条候选的 `output_model` + `preview_img`，整体 zip 下载使用 `output_model`。
> - **其他场景**：直接取 `model_ids[0]` 单个轮询。SDK 已对各场景做了 `unwrap`，例如 Python `client.gen_high_model()` 返回 `str`；返回数组的高阶方法（`client.gen_lod()` / `client.gen_pose()` / `client.gen_text_motion()`）保留 `list[str]` 形式，文生动画实际是 1 个 `model_id`，仍以列表返回以保持类型签名一致。


#### 请求示例

<!-- tabs:start -->

#### **CURL**

```bash
curl -X POST 'https://ws.visvise.com.cn/openapi/weaver/resource/gen_3d_model' \
  -H 'Content-Type: application/json' \
  -H 'app_id: your_app_id' \
  -H 'ts: 1713168000' \
  -H 'rtx: caller_rtx' \
  -H 'sign: your_sign' \
  -d '{
    "name": "VISVISE_Rigging",
    "node_type": 5,
    "input_model": "https://visvise-weaver-bj-dev-1311802504.cos.accelerate.myqcloud.com/weaver/user-xxx/20260415/model.zip",
    "params": {
        "go_rigging_params": {
            "algorithm_model": "MotusAI-Rigging-V2.0"
        }
    }
  }'
```

#### **Python**

```python
from visvise import VisviseClient, NodeType

client = VisviseClient(app_id="your_app_id", secret_key="your_secret_key")

model_ids = client.api.gen_3d_model(
    name="VISVISE_Rigging",
    node_type=NodeType.RIGGING,  # 5
    input_model="https://visvise-weaver-bj-dev-1311802504.cos.accelerate.myqcloud.com/weaver/user-xxx/20260415/model.zip",
    params={
        "go_rigging_params": {
            "algorithm_model": "MotusAI-Rigging-V2.0",
        },
    },
    rtx="caller_rtx",
)
print("生成任务已创建:", model_ids)
```

#### **Go**

```go
package main

import (
    "fmt"
    "github.com/tencent-visvise/visvise-sdk-go/visvise"
)

func main() {
    client := visvise.NewClient("your_app_id", "your_secret_key", nil)

    modelIDs, err := client.GetAPI().Gen3DModel(
        "VISVISE_Rigging",
        int(visvise.NodeTypeRigging), // 5
        map[string]interface{}{
            "go_rigging_params": map[string]interface{}{
                "algorithm_model": "MotusAI-Rigging-V2.0",
            },
        },
        nil,    // inputView
        "https://visvise-weaver-bj-dev-1311802504.cos.accelerate.myqcloud.com/weaver/user-xxx/20260415/model.zip",
        "",     // inputModelFormat
        "",     // inputVideo
        "caller_rtx",
    )
    if err != nil {
        panic(err)
    }
    fmt.Println("生成任务已创建:", modelIDs)
}
```

<!-- tabs:end -->

#### 响应示例

```json
{
    "code": 0,
    "msg": "success",
    "req_id": "req_abc123",
    "data": {
        "model_ids": ["Model2026033100192028"]
    }
}
```

---

### 2.5 生成多视图

从用户上传的原画生成多角度视图图片，用于后续 3D 模型生成。该接口为**异步接口**，通过 [获取模型资产列表](#26-获取模型资产列表) 轮询任务状态。

**接口路径：** `POST https://ws.visvise.com.cn/openapi/weaver/resource/gen_multi_views`

#### 请求参数

| 参数名称 | 必选 | 类型 | 描述 |
|---|---|---|---|
| `name` | 是 | String | 模型资产名称，长度为 1~100 个字符 |
| `input_view` | 是 | [View](#view) | 用户上传的视图（COS地址） |
| `params` | 是 | [TemplateParams](#templateparams) | 生成参数（在对应的节点参数中赋值） |

#### 响应参数

`data` 字段结构（`GenMultiViewsResult`）：

| 参数名称 | 类型 | 描述 |
|---|---|---|
| `model_id` | String | 生成的模型资产 ID |

#### 请求示例

<!-- tabs:start -->

#### **CURL**

```bash
curl -X POST 'https://ws.visvise.com.cn/openapi/weaver/resource/gen_multi_views' \
  -H 'Content-Type: application/json' \
  -H 'app_id: your_app_id' \
  -H 'ts: 1713168000' \
  -H 'rtx: caller_rtx' \
  -H 'sign: your_sign' \
  -d '{
    "name": "my_multi_view",
    "input_view": {
        "main_view": "https://cos.example.com/weaver/user-xxx/main.png"
    },
    "params": {
        "image_gen_360_params": {
            "algorithm_model": "VV-MultiView-V1.0.0"
        }
    }
  }'
```

#### **Python**

```python
from visvise import VisviseClient, View

client = VisviseClient(app_id="your_app_id", secret_key="your_secret_key")

model_id = client.api.gen_multi_views(
    name="my_multi_view",
    input_view=View(main_view="https://cos.example.com/weaver/user-xxx/main.png"),
    params={
        "image_gen_360_params": {
            "algorithm_model": "VV-MultiView-V1.0.0",
        }
    },
    rtx="caller_rtx",
)
print("model_id:", model_id)
```

#### **Go**

```go
package main

import (
    "fmt"
    "github.com/tencent-visvise/visvise-sdk-go/visvise"
)

func main() {
    client := visvise.NewClient("your_app_id", "your_secret_key", nil)

    modelID, err := client.GetAPI().GenMultiViews(
        "my_multi_view",
        &visvise.View{MainView: "https://cos.example.com/weaver/user-xxx/main.png"},
        map[string]interface{}{
            "image_gen_360_params": map[string]interface{}{
                "algorithm_model": "VV-MultiView-V1.0.0",
            },
        },
        "caller_rtx",
    )
    if err != nil {
        panic(err)
    }
    fmt.Println("model_id:", modelID)
}
```

<!-- tabs:end -->

#### 响应示例

```json
{
    "code": 0,
    "msg": "success",
    "req_id": "req_abc123",
    "data": {
        "model_id": "Model2026033100185012"
    }
}
```

---

### 2.6 获取模型资产列表

获取用户的模型资产列表，支持按功能节点维度和关键字过滤，支持按创建时间排序和翻页。用于轮询异步任务状态。

**接口路径：** `POST https://ws.visvise.com.cn/openapi/weaver/resource/get_model_list`

#### 请求参数

| 参数名称 | 必选 | 类型 | 描述 |
|---|---|---|---|
| `limit` | 否 | Unsigned Integer | 分页大小，默认 20 |
| `last_ts` | 否 | Unsigned Integer | 上一页最后一条数据的创建时间戳（毫秒），用于游标翻页 |
| `page` | 否 | Unsigned Integer | 当前页码，默认 1，若 `page` 有值则优先使用翻页功能 |
| `model_id_list` | 否 | Array of String | 筛选的模型 ID 列表（`node_id_list` / `node_type_list` 必传一个） |
| `node_type_list` | 否 | Array of Integer | 筛选 [节点类型](#节点类型node_type枚举) （`node_id_list` / `node_type_list` 必传一个） |
| `status_list` | 否 | Array of Integer | 筛选 [模型状态](#模型资产status状态码) |
| `keyword` | 否 | String | 关键词模糊匹配搜索，最大长度 100 个字符 |
| `sorter` | 否 | [Sorter](#sorter-结构) | 排序规则，暂不支持，默认 `create_time` 降序 |
| `model_type_list` | 否 | Array of Integer | 筛选模型类型：`0` 默认普通模型 / `1` 前处理模型 / `2` 2D 对话模型 / `3` 模型库模型 |

##### `Sorter` 结构：

| 参数名称 | 必选 | 类型 | 描述 |
|---|---|---|---|
| `name` | 否 | String | 排序字段名，目前仅支持 `create_time`，默认 `create_time` |
| `order` | 否 | String | `"asc"` 或 `"desc"`，默认 `"desc"` 降序 |

#### 响应参数

`data` 字段结构（`GetModelListResult`）：

| 参数名称 | 类型 | 描述 |
|---|---|---|
| `model_list` | Array of [ModelInfo](#modelinfo) | 模型资产列表 |
| `total_count` | Unsigned Integer | 当前筛选条件下的总数量 |
| `count` | Unsigned Integer | 本次请求返回的数量 |

#### 请求示例

<!-- tabs:start -->
#### **CURL**

```bash
curl -X POST 'https://ws.visvise.com.cn/openapi/weaver/resource/get_model_list' \
  -H 'Content-Type: application/json' \
  -H 'app_id: your_app_id' \
  -H 'ts: 1713168000' \
  -H 'rtx: caller_rtx' \
  -H 'sign: your_sign' \
  -d '{
    "limit": 10,
    "page": 1,
    "model_id_list": ["Model2026033100178045"]
  }'
```

#### **Python**

```python
from visvise import VisviseClient

client = VisviseClient(app_id="your_app_id", secret_key="your_secret_key")

models, total = client.api.get_model_list(
    model_id_list=["Model2026033100178045"],
    limit=10,
    page=1,
    rtx="caller_rtx",
)
for m in models:
    print(m.model_id, m.status, m.output_model)
print("总数:", total)
```

#### **Go**

```go
package main

import (
    "fmt"
    "github.com/tencent-visvise/visvise-sdk-go/visvise"
)

func main() {
    client := visvise.NewClient("your_app_id", "your_secret_key", nil)

    models, total, err := client.GetAPI().GetModelList(
        []string{"Model2026033100178045"}, // modelIDList
        nil,                                // nodeTypeList
        nil,                                // statusList
        "",                                 // keyword
        10,                                 // limit
        1,                                  // page
        0,                                  // lastTs
        nil,                                // modelTypeList
        nil,                                // sorter
        "caller_rtx",
    )
    if err != nil {
        panic(err)
    }
    for _, m := range models {
        fmt.Println(m.ModelID, m.Status, m.OutputModel)
    }
    fmt.Println("总数:", total)
}
```

<!-- tabs:end -->

#### 响应示例

```json
{
    "code": 0,
    "msg": "success",
    "req_id": "req_abc123",
    "data": {
        "model_list": [
            {
                "model_id": "Model2026033100178045",
                "name": "MyModel",
                "node_type": 5,
                "status": 3,
                "output_model": "https://cos.example.com/weaver/output/model.zip?sign=xxx",
                "preview_img": "https://cos.example.com/weaver/preview/img.png?sign=xxx",
                "time_cost": 120,
                "remaining_time": 0
            }
        ],
        "total_count": 1,
        "count": 1
    }
}
```

---

### 2.7 获取算法模型列表

获取各 [节点类型](#节点类型node_type枚举) 支持的算法模型列表。

**接口路径：** `POST https://ws.visvise.com.cn/openapi/weaver/resource/list_algorithm_model`

#### 请求参数

| 参数名称 | 必选 | 类型 | 描述 |
|---|---|---|---|
| `node_type` | 是 | Integer | 节点类型，参考 [节点类型枚举](#节点类型node_type枚举) |
| `type` | 否 | Integer | 算法模型子类型（`AlgorithmModelType` 枚举），仅部分 `node_type` 需要，取值见下表 |

##### `type` 枚举（`AlgorithmModelType`）

| 值 | 所属 node_type | 枚举名 | 语义 |
|---|---|---|---|
| `1` | 3D动画生成（4） | `FRAMING_AI_VIDEO` | 视频生动画-快速模式 |
| `2` | 3D动画生成（4） | `FRAMING_AI_TEXT` | 文字生动画 |
| `6` | 贴图纹理（8） | `TEX_IMAGE` | 图生贴图 |
| `7` | 贴图纹理（8） | `TEX_TEXT` | 文生贴图 |
| `8` | 2D预处理（16） | `PREPROCESS_2D_CHAT` | 对话模式 |
| `9` | 2D预处理（16） | `PREPROCESS_2D_FORM` | 表单模式 |

#### 响应参数

`data` 字段结构（`ListAlgorithmModelResult`）：

| 参数名称 | 类型 | 描述 |
|---|---|---|
| `model_list` | Array of String | 算法模型列表 |

#### 请求示例

<!-- tabs:start -->
#### **CURL**

```bash
curl -X POST 'https://ws.visvise.com.cn/openapi/weaver/resource/list_algorithm_model' \
  -H 'Content-Type: application/json' \
  -H 'app_id: your_app_id' \
  -H 'ts: 1713168000' \
  -H 'rtx: caller_rtx' \
  -H 'sign: your_sign' \
  -d '{
    "node_type": 4,
    "type": 1
  }'
```

#### **Python**

```python
from visvise import VisviseClient, NodeType

client = VisviseClient(app_id="your_app_id", secret_key="your_secret_key")

# 视频生动画算法列表（node_type=4, sub_type=1）
algos = client.api.list_algorithm_model(node_type=NodeType.MOTION, sub_type=1, rtx="caller_rtx")
print(algos)
```

#### **Go**

```go
package main

import (
    "fmt"
    "github.com/tencent-visvise/visvise-sdk-go/visvise"
)

func main() {
    client := visvise.NewClient("your_app_id", "your_secret_key", nil)

    // 视频生动画算法列表 (node_type=4, sub_type=1)
    subType := 1
    algos, err := client.GetAPI().ListAlgorithmModel(
        int(visvise.NodeTypeAnimation),
        &subType,
        "caller_rtx",
    )
    if err != nil {
        panic(err)
    }
    fmt.Println(algos)
}
```

<!-- tabs:end -->

#### 响应示例

```json
{
    "code": 0,
    "msg": "success",
    "req_id": "req_abc123",
    "data": {
        "model_list": [
            "MotusAI-V2M-V1.5"
        ]
    }
}
```

#### 各功能支持的算法模型清单

下表汇总各 `node_type` 当前支持的所有算法模型（以配置为准）。部分功能支持多个模型，模型间输入或输出差异将在对应功能小节说明。

| node_type | 功能 | 支持的算法模型 |
|---|---|---|
| 1 | 重拓扑 | `VV-RTP-V1.5.0`、`Hy3D-RTP-v1.5`、`Hy3D-RTP-v2.0` |
| 2 | LOD | `VV-LOD-V1.0.0` |
| 3 | 图生高模 | `Hy3D-3.5-0515`、`Hy3D-3.5-0315` |
| 4 | 3D动画生成 | `MotusAI-V2M-V1.5`（视频-快速）、`MotusAI-V2M-V2.0 Pre`（视频-快速/高级）、`MotusAI-T2M-V1.1`、`MotusAI-T2M-V1.5`（文本） |
| 5 | 智能骨骼架设 | `MotusAI-Rigging-V2.0` |
| 6 | 智能蒙皮 | `MotusAI-Skinning-V1.0` |
| 7 | 图生360 | `VV-MultiView-V1.0.0`、`Hy3D-MultiView-v3.0` |
| 8 | 贴图纹理 | `Hy3D-TEX-v3.5-preview`（图生）、`Hy3D-TEX-v2.0`（文生） |
| 9 | UV | `Hy3D-UV-v2.0`、`Hy3D-UV-v3.0`、`VV-UV-v2.6.0` |
| 10 | 布线重建 | `VV-MeshRefine-V1.0.0` |
| 11 | 图生中模 | `VV-MeshGen-V1.5.0` |
| 12 | 图生Pose | `MotusAI-Posing-V1.0` |
| 13 | 图生低模 | —（本期暂未开放） |
| 14 | 2D拆分 | `VV-SplitMask-V1.0.0` |
| 15 | 2UV | `VV-AutoLUV-V2.6.0` |
| 16 | 2D预处理 | `VV-Pre2D-V1.0.0`（表单）、`Nano Banana2`、`Nano BananaPro`、`GPT image2`（对话） |

---

### 2.8 下载模型资产

获取模型资产带签名的下载 URL。

**接口路径：** `POST https://ws.visvise.com.cn/openapi/weaver/resource/download_model`

#### 请求参数

| 参数名称 | 必选 | 类型 | 描述 |
|---|---|---|---|
| `model_id` | 是 | String | 模型资产 ID |

#### 响应参数

| 参数名称 | 类型 | 描述 |
|---|---|---|
| `data` | String | 带签名的下载 URL（预签名，24h 有效） |

#### 请求示例

<!-- tabs:start -->
#### **CURL**

```bash
curl -X POST 'https://ws.visvise.com.cn/openapi/weaver/resource/download_model' \
  -H 'Content-Type: application/json' \
  -H 'app_id: your_app_id' \
  -H 'ts: 1713168000' \
  -H 'rtx: caller_rtx' \
  -H 'sign: your_sign' \
  -d '{
    "model_id": "Model2026033100178045"
  }'
```

#### **Python**

```python
from visvise import VisviseClient

client = VisviseClient(app_id="your_app_id", secret_key="your_secret_key")

url = client.api.download_model(model_id="Model2026033100178045", rtx="caller_rtx")
print("下载链接:", url)
```

#### **Go**

```go
package main

import (
    "fmt"
    "github.com/tencent-visvise/visvise-sdk-go/visvise"
)

func main() {
    client := visvise.NewClient("your_app_id", "your_secret_key", nil)

    url, err := client.GetAPI().DownloadModel("Model2026033100178045", "caller_rtx")
    if err != nil {
        panic(err)
    }
    fmt.Println("下载链接:", url)
}
```

<!-- tabs:end -->

#### 响应示例

```json
{
    "code": 0,
    "msg": "success",
    "req_id": "req_abc123",
    "data": "https://visvise-weaver-bj-1311802504.cos.ap-beijing.myqcloud.com/weaver/output/model.zip?sign=xxx&expire=1713254400"
}
```

---

### 2.9 删除模型资产

删除指定的模型资产。

**接口路径：** `POST https://ws.visvise.com.cn/openapi/weaver/resource/delete_model`

#### 请求参数

| 参数名称 | 必选 | 类型 | 描述 |
|---|---|---|---|
| `model_id` | 是 | String | 待删除的模型资产 ID |

#### 响应参数

通用返回结构，无额外 `data` 字段。

#### 请求示例

<!-- tabs:start -->
#### **CURL**

```bash
curl -X POST 'https://ws.visvise.com.cn/openapi/weaver/resource/delete_model' \
  -H 'Content-Type: application/json' \
  -H 'app_id: your_app_id' \
  -H 'ts: 1713168000' \
  -H 'rtx: caller_rtx' \
  -H 'sign: your_sign' \
  -d '{
    "model_id": "Model2026033100178045"
  }'
```

#### **Python**

```python
from visvise import VisviseClient

client = VisviseClient(app_id="your_app_id", secret_key="your_secret_key")

client.api.delete_model(model_id="Model2026033100178045", rtx="caller_rtx")
print("删除成功")
```

#### **Go**

```go
package main

import (
    "fmt"
    "github.com/tencent-visvise/visvise-sdk-go/visvise"
)

func main() {
    client := visvise.NewClient("your_app_id", "your_secret_key", nil)

    if err := client.GetAPI().DeleteModel("Model2026033100178045", "caller_rtx"); err != nil {
        panic(err)
    }
    fmt.Println("删除成功")
}
```

<!-- tabs:end -->

#### 响应示例

```json
{
    "code": 0,
    "msg": "success",
    "req_id": "req_abc123"
}
```

---

### 2.10 批量删除模型资产

批量删除模型资产，支持一次删除多个模型资产，同时兼容单个删除（传 1 个 ID 即可）。

**接口路径：** `POST https://ws.visvise.com.cn/openapi/weaver/resource/batch_delete_model`

#### 请求参数

| 参数名称 | 必选 | 类型 | 描述 |
|---|---|---|---|
| `model_ids` | 是 | Array of String | 待删除的模型资产 ID 列表 |

#### 响应参数

通用返回结构，无额外 `data` 字段。

#### 请求示例

<!-- tabs:start -->
#### **CURL**

```bash
curl -X POST 'https://ws.visvise.com.cn/openapi/weaver/resource/batch_delete_model' \
  -H 'Content-Type: application/json' \
  -H 'app_id: your_app_id' \
  -H 'ts: 1713168000' \
  -H 'rtx: caller_rtx' \
  -H 'sign: your_sign' \
  -d '{
    "model_ids": ["Model2026033100201011", "Model2026033100201022", "Model2026033100201033"]
  }'
```

#### **Python**

```python
from visvise import VisviseClient

client = VisviseClient(app_id="your_app_id", secret_key="your_secret_key")

client.api.batch_delete_model(model_ids=[
    "Model2026033100201011",
    "Model2026033100201022",
    "Model2026033100201033",
],
    rtx="caller_rtx",
)
print("批量删除成功")
```

#### **Go**

```go
package main

import (
    "fmt"
    "github.com/tencent-visvise/visvise-sdk-go/visvise"
)

func main() {
    client := visvise.NewClient("your_app_id", "your_secret_key", nil)

    err := client.GetAPI().BatchDeleteModel(
        []string{
            "Model2026033100201011",
            "Model2026033100201022",
            "Model2026033100201033",
        },
        "caller_rtx",
    )
    if err != nil {
        panic(err)
    }
    fmt.Println("批量删除成功")
}
```

<!-- tabs:end -->

#### 响应示例

```json
{
    "code": 0,
    "msg": "success",
    "req_id": "req_abc123"
}
```

---

### 2.11 去除图片背景

去除输入图片的背景，返回透明背景的图片。

**接口路径：** `POST https://ws.visvise.com.cn/openapi/weaver/resource/remove_background`

#### 请求参数

| 参数名称 | 必选 | 类型 | 描述 |
|---|---|---|---|
| `image_url` | 是 | String | 图片地址 |

#### 响应参数

`data` 字段结构（`RemoveBackgroundResult`）：

| 参数名称 | 类型 | 描述 |
|---|---|---|
| `image_url` | String | 输出图片地址（预签名，24h 有效） |

#### 请求示例

<!-- tabs:start -->
#### **CURL**

```bash
curl -X POST 'https://ws.visvise.com.cn/openapi/weaver/resource/remove_background' \
  -H 'Content-Type: application/json' \
  -H 'app_id: your_app_id' \
  -H 'ts: 1713168000' \
  -H 'rtx: caller_rtx' \
  -H 'sign: your_sign' \
  -d '{
    "image_url": "https://cos.example.com/weaver/user-xxx/input.png"
  }'
```

#### **Python**

```python
from visvise import VisviseClient

client = VisviseClient(app_id="your_app_id", secret_key="your_secret_key")

output_url = client.api.remove_bg(
    image_url="https://cos.example.com/weaver/user-xxx/input.png",
    rtx="caller_rtx",
)
print("透明背景图:", output_url)
```

#### **Go**

```go
package main

import (
    "fmt"
    "github.com/tencent-visvise/visvise-sdk-go/visvise"
)

func main() {
    client := visvise.NewClient("your_app_id", "your_secret_key", nil)

    outputURL, err := client.GetAPI().RemoveBackground(
        "https://cos.example.com/weaver/user-xxx/input.png",
        "caller_rtx",
    )
    if err != nil {
        panic(err)
    }
    fmt.Println("透明背景图:", outputURL)
}
```

<!-- tabs:end -->

#### 响应示例

```json
{
    "code": 0,
    "msg": "success",
    "req_id": "req_abc123",
    "data": {
        "image_url": "https://cos.example.com/weaver/user-xxx/output_nobg.png"
    }
}
```

---

### 2.12 批量图生Pose

输入一个 FBX 模型和多张参考图片，批量生成 Pose 模型资产，同时兼容单张图片生成。

**接口路径：** `POST https://ws.visvise.com.cn/openapi/weaver/resource/batch_gen_pose`

#### 请求参数

| 参数名称 | 必选 | 类型 | 描述 |
|---|---|---|---|
| `name` | 是 | String | 模型资产名称，长度为 1~100 个字符 |
| `input_model` | 是 | String | 输入 FBX 模型的 COS 地址（zip 文件） |
| `input_images` | 是 | Array of String | 输入图片 URL 列表，最少 1 张，最多 10 张。传 1 张时等同于单张图生 Pose |
| `params` | 是 | [ImageGenPoseParams](#imagegenposeparams) | 图生 Pose 算法参数 |

#### 响应参数

`data` 字段结构（`Gen3DModelResult`）：

| 参数名称 | 类型 | 描述 |
|---|---|---|
| `model_ids` | Array of String | 生成的模型资产 ID 列表 |

#### 请求示例

<!-- tabs:start -->
#### **CURL**

```bash
curl -X POST 'https://ws.visvise.com.cn/openapi/weaver/resource/batch_gen_pose' \
  -H 'Content-Type: application/json' \
  -H 'app_id: your_app_id' \
  -H 'ts: 1713168000' \
  -H 'rtx: caller_rtx' \
  -H 'sign: your_sign' \
  -d '{
    "name": "batch_pose_gen",
    "input_model": "https://cos.example.com/weaver/user-xxx/model.zip",
    "input_images": [
        "https://cos.example.com/weaver/user-xxx/pose_ref_1.png",
        "https://cos.example.com/weaver/user-xxx/pose_ref_2.png",
        "https://cos.example.com/weaver/user-xxx/pose_ref_3.png"
    ],
    "params": {
        "algorithm_model": "MotusAI-Posing-V1.0",
        "output_model_format": "fbx"
    }
  }'
```

#### **Python**

```python
from visvise import VisviseClient, OutputModelFormat

client = VisviseClient(app_id="your_app_id", secret_key="your_secret_key")

model_ids = client.api.batch_gen_pose(
    name="batch_pose_gen",
    input_model="https://cos.example.com/weaver/user-xxx/model.zip",
    input_images=[
        "https://cos.example.com/weaver/user-xxx/pose_ref_1.png",
        "https://cos.example.com/weaver/user-xxx/pose_ref_2.png",
        "https://cos.example.com/weaver/user-xxx/pose_ref_3.png",
    ],
    params={
        "algorithm_model": "MotusAI-Posing-V1.0",
        "output_model_format": OutputModelFormat.FBX,
    },
    rtx="caller_rtx",
)
print("批量生成任务:", model_ids)
```

#### **Go**

```go
package main

import (
    "fmt"
    "github.com/tencent-visvise/visvise-sdk-go/visvise"
)

func main() {
    client := visvise.NewClient("your_app_id", "your_secret_key", nil)

    modelIDs, err := client.GetAPI().BatchGenPose(
        "batch_pose_gen",
        "https://cos.example.com/weaver/user-xxx/model.zip",
        []string{
            "https://cos.example.com/weaver/user-xxx/pose_ref_1.png",
            "https://cos.example.com/weaver/user-xxx/pose_ref_2.png",
            "https://cos.example.com/weaver/user-xxx/pose_ref_3.png",
        },
        map[string]interface{}{
            "algorithm_model":     "MotusAI-Posing-V1.0",
            "output_model_format": visvise.OutputModelFormatFBX,
        },
        "caller_rtx",
    )
    if err != nil {
        panic(err)
    }
    fmt.Println("批量生成任务:", modelIDs)
}
```

<!-- tabs:end -->

#### 响应示例

```json
{
    "code": 0,
    "msg": "success",
    "req_id": "req_abc123",
    "data": {
        "model_ids": ["Model2026033100210051", "Model2026033100210062", "Model2026033100210073"]
    }
}
```

---

### 2.13 获取文生动画提示词Demo列表

获取文生动画模块的提示词示例列表，根据语言返回对应的中文或英文提示词。

**接口路径：** `POST https://ws.visvise.com.cn/openapi/weaver/demo/get_text2motion_prompt_list`

#### 请求参数

| 参数名称 | 必选 | 类型 | 描述 |
|---|---|---|---|
| `language` | 是 | String | 语言类型，`zh`（中文） / `en`（英文） |

#### 响应参数

`data` 字段结构（`Text2MotionPromptListResult`）：

| 参数名称 | 类型 | 描述 |
|---|---|---|
| `prompt_list` | Array of String | 单段提示词列表 |
| `segment_demos` | Array of Text2MotionSegmentDemo | 多段范例列表 |


#### Text2MotionSegmentDemo

文生动画提示词 Demo 的多段范例结构。

| 参数名称 | 类型 | 描述 |
|---|---|---|
| `prompts` | Array of String | 每段描述 |
| `durations` | Array of Integer | 每段帧数（与 `prompts` 一一对应） |

#### 请求示例

<!-- tabs:start -->
#### **CURL**

```bash
curl -X POST 'https://ws.visvise.com.cn/openapi/weaver/demo/get_text2motion_prompt_list' \
  -H 'Content-Type: application/json' \
  -H 'app_id: your_app_id' \
  -H 'ts: 1713168000' \
  -H 'rtx: caller_rtx' \
  -H 'sign: your_sign' \
  -d '{
    "language": "zh"
  }'
```

#### **Python**

```python
from visvise import VisviseClient

client = VisviseClient(app_id="your_app_id", secret_key="your_secret_key")

prompts = client.api.get_text2motion_prompt_list(language="zh", rtx="caller_rtx")
for p in prompts:
    print(p)
```

#### **Go**

```go
package main

import (
    "fmt"
    "github.com/tencent-visvise/visvise-sdk-go/visvise"
)

func main() {
    client := visvise.NewClient("your_app_id", "your_secret_key", nil)

    prompts, err := client.GetAPI().GetText2MotionPromptList("zh", "caller_rtx")
    if err != nil {
        panic(err)
    }
    for _, p := range prompts {
        fmt.Println(p)
    }
}
```

<!-- tabs:end -->

#### 响应示例

```json
{
    "code": 0,
    "msg": "success",
    "req_id": "req_abc123",
    "data": {
        "prompt_list": [
            "一个人在跳街舞",
            "一个人在挥手打招呼",
            "一个人在原地踏步",
            "一个人在做俯卧撑",
            "一个人在走路"
        ],
        "segment_demos": []
    }
}
```

---

### 2.14 2D拆分

对图生360 输出的多视图进行 2D 组件分割，生成可用于图生模的分割资产，可以对分割结果进行编辑。

**接口路径：** `POST https://ws.visvise.com.cn/openapi/weaver/component/init_segment`

> **协议特殊性：** 此接口使用 **SSE（Server-Sent Events）** 协议，服务端会推送多个事件帧（`pre_create` → `thinking` → `reply`），客户端需逐帧处理。

#### 请求参数

| 参数名称 | 必选 | 类型 | 描述 |
|---|---|---|---|
| `name` | 是 | String | 模型资产名称，长度为 1~100 个字符 |
| `algorithm_model` | 是 | String | 算法模型，可通过 [获取算法模型列表](#27-获取算法模型列表) 获取 |
| `model_id` | 否 | String | 图生 360 资产 的 `model_id` |
| `input_view` | 否 | [View](#view) | 输入视图 |
| `split_type` | 否 | Integer | 拆分方式，1 正视图拆分 / 2 四视图拆分<br />- `Python SDK` 枚举：`SegmentSplitType.FRONT_VIEW` / `.FOUR_VIEW`<br />- `Go SDK` 枚举：`SegmentSplitFrontView` / `SegmentSplitFourView`<br />- `Java SDK` 枚举：`SegmentSplitType.FRONT_VIEW` / `.FOUR_VIEW` |
| `granularity` | 否 | Integer | 拆分颗粒度，1 粗（×50%）/ 2 中（×70%）/ 3 细（×100%）<br />- `Python SDK` 枚举：`SegmentGranularity.COARSE` / `.MEDIUM` / `.FINE`<br />- `Go SDK` 枚举：`SegmentGranularityCoarse` / `SegmentGranularityMedium` / `SegmentGranularityFine`<br />- `Java SDK` 枚举：`SegmentGranularity.COARSE` / `.MEDIUM` / `.FINE` |
| `prompt` | 否 | String | 拆分提示词，用户用自然语言描述拆分规则，AI 参考执行（最大长度 200 个字符） |

> 💡 `model_id` 和 `input_view` 二选一， 使用「图生360」的资产时，传 `model_id`，上传原图时，传 `input_view`。

#### 响应参数

返回 SSE 流，每个事件帧结构如下：

| 字段 | 类型 | 描述 |
|---|---|---|
| `event` | String | 事件类型：`req_id` / `pre_create` / `thinking` / `reply` / `error` |
| `data` | Object | 事件数据：<br>- `req_id`：本次请求的请求 ID（String）<br>- `pre_create`：返回预创建的 [ModelInfo](#modelinfo)<br>- `thinking`：当前思考阶段的描述（String）<br>- `reply`：分割完成后的 [MultiViewSegmentResult](#multiviewsegmentresult) 对象<br>- `error`：错误对象 `{code, msg}` |

#### 请求示例

<!-- tabs:start -->
#### **CURL**

```bash
curl -N -X POST 'https://ws.visvise.com.cn/openapi/weaver/component/init_segment' \
  -H 'Content-Type: application/json' \
  -H 'Accept: text/event-stream' \
  -H 'app_id: your_app_id' \
  -H 'rtx: caller_rtx' \
  -H 'ts: 1713168000' \
  -H 'sign: your_sign' \
  -d '{
    "name": "my_2d_segment",
    "algorithm_model": "VV-SplitMask-V1.0.0",
    "model_id": "Model202604xxxxxx",
    "split_type": 1,
    "granularity": 2
  }'
```

#### **Python**

```python
from visvise import VisviseClient, SegmentSplitType, SegmentGranularity

client = VisviseClient(app_id="your_app_id", secret_key="your_secret_key")

# init_segment 返回 SSE 事件流，逐帧处理
for frame in client.api.init_segment(
    name="my_2d_segment",
    algorithm_model="VV-SplitMask-V1.0.0",
    model_id="Model202604xxxxxx",
    split_type=SegmentSplitType.FRONT_VIEW,   # 1 正视图拆分
    granularity=SegmentGranularity.MEDIUM,    # 2 中等颗粒度
    rtx="caller_rtx",
):
    event, data = frame["event"], frame["data"]
    if event == "pre_create":
        print("预创建模型:", data["model_id"])
    elif event == "thinking":
        print("思考中:", data)
    elif event == "reply":
        print("分割完成:", data)
        break
    elif event == "error":
        print("失败:", data)
        break
```

#### **Go**

```go
package main

import (
    "fmt"
    "io"

    "github.com/tencent-visvise/visvise-sdk-go/visvise"
)

func main() {
    client := visvise.NewClient("your_app_id", "your_secret_key", nil)

    splitType := visvise.SegmentSplitFrontView        // 1 正视图拆分
    granularity := visvise.SegmentGranularityMedium   // 2 中等颗粒度
    modelID := "Model202604xxxxxx"

    // InitSegment 返回 SSE 迭代器，循环 Next() 逐帧处理
    iter, err := client.GetAPI().InitSegment(
        "my_2d_segment",
        "VV-SplitMask-V1.0.0",
        modelID,
        nil,                // inputView
        &splitType,
        &granularity,
        "",                 // prompt
        120,                // readTimeout 秒
        "caller_rtx",
    )
    if err != nil { panic(err) }
    defer iter.Close()

    for {
        frame, err := iter.Next()
        if err == io.EOF { break }
        if err != nil { panic(err) }
        switch frame.Event {
        case "pre_create":
            fmt.Println("预创建模型:", frame.Data)
        case "thinking":
            fmt.Println("思考中:", frame.Data)
        case "reply":
            fmt.Println("分割完成:", frame.Data)
            return
        case "error":
            fmt.Println("失败:", frame.Data)
            return
        }
    }
}
```

<!-- tabs:end -->

#### SSE 响应示例

```
event: req_id
data: "9b168fba58e24f68bb8b1c1e7dbea6f8"

event: pre_create
data: {"model_id": "Model2026...", "name": "my_2d_segment", "node_type": 14, "status": 1}

event: thinking
data: "正在分析图像组件..."

event: thinking
data: "正在生成分割掩膜..."

event: reply
data: {"main_view_data": {"client_id": "...", "segment_data": {"components": [...], "shape": [2048, 2048]}, "origin_view": {...}}, "client_id": "...", "origin_view": {...}}
```

---

### 2.15 打开拆分

打开已保存的 2D 分割资产，返回新的 `client_id`，后续基于 `client_id` 进行二次编辑和保存等操作。

**接口路径：** `POST https://ws.visvise.com.cn/openapi/weaver/component/open_segment`

#### 请求参数

| 参数名称 | 必选 | 类型 | 描述 |
|---|---|---|---|
| `model_id` | 是 | String | 分割资产的 model_id（`node_type=14`） |

#### 响应参数

`data` 字段结构（[MultiViewSegmentResult](#multiviewsegmentresult)），`client_id` 为新的分割会话 ID，后续编辑接口基于该 ID 操作。

#### 请求示例

<!-- tabs:start -->
#### **CURL**

```bash
curl -X POST 'https://ws.visvise.com.cn/openapi/weaver/component/open_segment' \
  -H 'Content-Type: application/json' \
  -H 'app_id: your_app_id' \
  -H 'rtx: caller_rtx' \
  -H 'ts: 1713168000' \
  -H 'sign: your_sign' \
  -d '{
    "model_id": "Model202604xxxxxx"
  }'
```

#### **Python**

```python
from visvise import VisviseClient

client = VisviseClient(app_id="your_app_id", secret_key="your_secret_key")

result = client.api.open_segment(model_id="Model202604xxxxxx", rtx="caller_rtx")
client_id = result["client_id"]  # 新的分割会话 ID
print(client_id)
```

#### **Go**

```go
package main

import (
    "fmt"
    "github.com/tencent-visvise/visvise-sdk-go/visvise"
)

func main() {
    client := visvise.NewClient("your_app_id", "your_secret_key", nil)

    result, err := client.GetAPI().OpenSegment("Model202604xxxxxx", "caller_rtx")
    if err != nil {
        panic(err)
    }
    fmt.Println(result.ClientID) // 新的分割会话 ID
}
```

<!-- tabs:end -->

#### 响应示例

```json
{
  "code": 0,
  "msg": "success",
  "req_id": "req_abc123",
  "data": {
    "main_view_data": { "client_id": "client_xxxx", "segment_data": { "components": [{ "label": 1, "color": "#3b82f6", "name": "胸甲" }], "mask_image": "iVBORw0KGgo...", "shape": [2048, 2048] }, "enable_revoke": false, "enable_redo": false, "origin_view": { "main_view": "https://..." } },
    "left_view_data": {},
    "right_view_data": {},
    "back_view_data": {},
    "client_id": "client_xxxx",
    "origin_view": { "main_view": "https://...", "back_view": "https://...", "left_view": "https://...", "right_view": "https://..." }
  }
}
```

#### 编辑接口说明

除 `init_segment`（SSE）外，`begin_segment` / `segment` / `confirm_segment` / `cancel_segment` / `merge` / `auto_merge` / `boundary_adjust` / `part_rename` / `save_segment` / `open_segment` 均为普通 JSON POST 接口，基于 `client_id`（分割会话 ID）操作，返回统一的 `{code, msg, req_id, data}` 结构。

##### Pixel

像素坐标。

| 参数名称 | 类型 | 描述 |
|---|---|---|
| `x` | Integer | 横坐标 |
| `y` | Integer | 纵坐标 |

##### Rect

矩形框。

| 参数名称 | 类型 | 描述 |
|---|---|---|
| `left_top_pixel` | [Pixel](#pixel) | 左上角坐标 |
| `right_bottom_pixel` | [Pixel](#pixel) | 右下角坐标 |

##### Component

分割部件。

| 参数名称 | 类型 | 描述 |
|---|---|---|
| `label` | Integer | 部件 label 编号 |
| `color` | String | 部件颜色 |
| `name` | String | 部件名称 |

##### SegmentData

单个视图的分割数据。

| 参数名称 | 类型 | 描述 |
|---|---|---|
| `components` | Array of [Component](#component) | 部件列表 |
| `mask_image` | String | 分割掩膜（base64 编码的原始掩膜数据） |
| `shape` | Array of Integer | 掩膜尺寸，如 `[2048, 2048]` |

##### OperatorResult

单视图操作结果（`begin_segment` / `segment` / `confirm_segment` / `cancel_segment` / `boundary_adjust` 返回）。

| 参数名称 | 类型 | 描述 |
|---|---|---|
| `client_id` | String | 分割会话 ID |
| `segment_data` | [SegmentData](#segmentdata) | 操作后的分割数据 |
| `enable_revoke` | Bool | 是否可撤销 |
| `enable_redo` | Bool | 是否可重做 |
| `origin_view` | [View](#view) | 原始视图数据 |

##### MultiViewSegmentResult

多视图操作结果（`merge` / `auto_merge` / `part_rename` / `open_segment` 返回）。

| 参数名称 | 类型 | 描述 |
|---|---|---|
| `main_view_data` | [OperatorResult](#operatorresult) | 主视图操作结果 |
| `left_view_data` | [OperatorResult](#operatorresult) | 左视图操作结果 |
| `right_view_data` | [OperatorResult](#operatorresult) | 右视图操作结果 |
| `back_view_data` | [OperatorResult](#operatorresult) | 背视图操作结果 |
| `client_id` | String | 分割会话 ID，后续所有操作基于该 ID |
| `origin_view` | [View](#view) | 原始视图数据 |

> **视图类型 `view_type` 取值：** 各编辑接口请求参数 `view_type` 的取值，`0` 主视图 / `1` 左视图 / `2` 右视图 / `3` 背视图，默认 `0`。

---

### 2.16 拆分编辑-智能拆分

#### 开始拆分

进入「分割状态」，指定要拆分的部件。

**接口路径：** `POST https://ws.visvise.com.cn/openapi/weaver/component/begin_segment`

##### 请求参数

| 参数名称 | 必选 | 类型 | 描述 |
|---|---|---|---|
| `client_id` | 是 | String | 分割会话 ID |
| `view_type` | 否 | Integer | 视图类型，0 主视图 / 1 左视图 / 2 右视图 / 3 背视图，默认 `0` |
| `component_label` | 是 | Integer | 要拆分的部件 label |

##### 响应参数

`data` 字段结构（[OperatorResult](#operatorresult)），`enable_revoke` / `enable_redo` 反映当前可撤销 / 可重做状态。

##### 请求示例

<!-- tabs:start -->
##### **CURL**

```bash
curl -X POST 'https://ws.visvise.com.cn/openapi/weaver/component/begin_segment' \
  -H 'Content-Type: application/json' \
  -H 'app_id: your_app_id' \
  -H 'rtx: caller_rtx' \
  -H 'ts: 1713168000' \
  -H 'sign: your_sign' \
  -d '{
    "client_id": "client_xxxx",
    "view_type": 0,
    "component_label": 3
  }'
```

##### **Python**

```python
from visvise import VisviseClient

client = VisviseClient(app_id="your_app_id", secret_key="your_secret_key")

result = client.api.begin_segment(
    client_id="client_xxxx",
    component_label=3,
    view_type=0,
    rtx="caller_rtx",
)
print(result)  # OperatorResult
```

##### **Go**

```go
package main

import (
    "fmt"
    "github.com/tencent-visvise/visvise-sdk-go/visvise"
)

func main() {
    client := visvise.NewClient("your_app_id", "your_secret_key", nil)

    result, err := client.GetAPI().BeginSegment("client_xxxx", 3, visvise.SegmentViewMain, "caller_rtx")
    if err != nil {
        panic(err)
    }
    fmt.Println(result.EnableRevoke, result.EnableRedo)
}
```

<!-- tabs:end -->

##### 响应示例

```json
{
  "code": 0,
  "msg": "success",
  "req_id": "req_abc123",
  "data": {
    "client_id": "client_xxxx",
    "segment_data": {
      "components": [{ "label": 1, "color": "#3b82f6", "name": "胸甲" }],
      "mask_image": "iVBORw0KGgo...",
      "shape": [2048, 2048]
    },
    "enable_revoke": true,
    "enable_redo": false,
    "origin_view": { "main_view": "https://...", "back_view": "https://...", "left_view": "https://...", "right_view": "https://..." }
  }
}
```

---

#### 拆分

在分割状态下圈定要拆出的区域（可反复执行）。

**接口路径：** `POST https://ws.visvise.com.cn/openapi/weaver/component/segment`

##### 请求参数

| 参数名称 | 必选 | 类型 | 描述 |
|---|---|---|---|
| `client_id` | 是 | String | 分割会话 ID |
| `view_type` | 否 | Integer | 视图类型，默认 `0` |
| `add_pixels` | 否 | Pixel[] | 添加的正点（前景像素点） |
| `remove_pixels` | 否 | Pixel[] | 删除的负点（背景像素点） |
| `rects` | 否 | Rect[] | 选中的矩形框 |

##### 响应参数

`data` 字段结构（[OperatorResult](#operatorresult)）。

##### 请求示例

<!-- tabs:start -->
##### **CURL**

```bash
curl -X POST 'https://ws.visvise.com.cn/openapi/weaver/component/segment' \
  -H 'Content-Type: application/json' \
  -H 'app_id: your_app_id' \
  -H 'rtx: caller_rtx' \
  -H 'ts: 1713168000' \
  -H 'sign: your_sign' \
  -d '{
    "client_id": "client_xxxx",
    "view_type": 0,
    "add_pixels": [{"x": 120, "y": 150}],
    "remove_pixels": [{"x": 300, "y": 90}],
    "rects": [
      {"left_top_pixel": {"x": 10, "y": 10}, "right_bottom_pixel": {"x": 200, "y": 200}}
    ]
  }'
```

##### **Python**

```python
from visvise import VisviseClient

client = VisviseClient(app_id="your_app_id", secret_key="your_secret_key")

result = client.api.segment_component(
    client_id="client_xxxx",
    view_type=0,
    add_pixels=[{"x": 120, "y": 150}],
    remove_pixels=[{"x": 300, "y": 90}],
    rects=[{"left_top_pixel": {"x": 10, "y": 10}, "right_bottom_pixel": {"x": 200, "y": 200}}],
    rtx="caller_rtx",
)
print(result)  # OperatorResult
```

##### **Go**

```go
package main

import (
    "fmt"
    "github.com/tencent-visvise/visvise-sdk-go/visvise"
)

func main() {
    client := visvise.NewClient("your_app_id", "your_secret_key", nil)

    result, err := client.GetAPI().SegmentComponent(
        "client_xxxx",
        visvise.SegmentViewMain,
        []*visvise.Pixel{{X: 120, Y: 150}},
        []*visvise.Pixel{{X: 300, Y: 90}},
        []*visvise.Rect{{LeftTopPixel: &visvise.Pixel{X: 10, Y: 10}, RightBottomPixel: &visvise.Pixel{X: 200, Y: 200}}},
        "caller_rtx",
    )
    if err != nil {
        panic(err)
    }
    fmt.Println(result.ClientID)
}
```

<!-- tabs:end -->

##### 响应示例

```json
{
  "code": 0,
  "msg": "success",
  "req_id": "req_abc123",
  "data": {
    "client_id": "client_xxxx",
    "segment_data": {
      "components": [{ "label": 1, "color": "#3b82f6", "name": "胸甲" }],
      "mask_image": "iVBORw0KGgo...",
      "shape": [2048, 2048]
    },
    "enable_revoke": true,
    "enable_redo": false,
    "origin_view": { "main_view": "https://...", "back_view": "https://...", "left_view": "https://...", "right_view": "https://..." }
  }
}
```

---

#### 确认拆分

固化当前分割结果。

**接口路径：** `POST https://ws.visvise.com.cn/openapi/weaver/component/confirm_segment`

##### 请求参数

| 参数名称 | 必选 | 类型 | 描述 |
|---|---|---|---|
| `client_id` | 是 | String | 分割会话 ID |
| `view_type` | 否 | Integer | 视图类型，默认 `0` |

##### 响应参数

`data` 字段结构（[OperatorResult](#operatorresult)）。

##### 请求示例

<!-- tabs:start -->
##### **CURL**

```bash
curl -X POST 'https://ws.visvise.com.cn/openapi/weaver/component/confirm_segment' \
  -H 'Content-Type: application/json' \
  -H 'app_id: your_app_id' \
  -H 'rtx: caller_rtx' \
  -H 'ts: 1713168000' \
  -H 'sign: your_sign' \
  -d '{
    "client_id": "client_xxxx",
    "view_type": 0
  }'
```

##### **Python**

```python
from visvise import VisviseClient

client = VisviseClient(app_id="your_app_id", secret_key="your_secret_key")

result = client.api.confirm_segment(client_id="client_xxxx", view_type=0, rtx="caller_rtx")
print(result)  # OperatorResult
```

##### **Go**

```go
package main

import (
    "fmt"
    "github.com/tencent-visvise/visvise-sdk-go/visvise"
)

func main() {
    client := visvise.NewClient("your_app_id", "your_secret_key", nil)

    result, err := client.GetAPI().ConfirmSegment("client_xxxx", visvise.SegmentViewMain, "caller_rtx")
    if err != nil {
        panic(err)
    }
    fmt.Println(result.ClientID)
}
```

<!-- tabs:end -->

##### 响应示例

```json
{
  "code": 0,
  "msg": "success",
  "req_id": "req_abc123",
  "data": {
    "client_id": "client_xxxx",
    "segment_data": {
      "components": [{ "label": 1, "color": "#3b82f6", "name": "胸甲" }],
      "mask_image": "iVBORw0KGgo...",
      "shape": [2048, 2048]
    },
    "enable_revoke": true,
    "enable_redo": false,
    "origin_view": { "main_view": "https://...", "back_view": "https://...", "left_view": "https://...", "right_view": "https://..." }
  }
}
```

---

#### 取消拆分

取消当前拆分，回退到分割开始前的状态。

**接口路径：** `POST https://ws.visvise.com.cn/openapi/weaver/component/cancel_segment`

##### 请求参数

| 参数名称 | 必选 | 类型 | 描述 |
|---|---|---|---|
| `client_id` | 是 | String | 分割会话 ID |
| `view_type` | 否 | Integer | 视图类型，默认 `0` |

##### 响应参数

`data` 字段结构（[OperatorResult](#operatorresult)）。

##### 请求示例

<!-- tabs:start -->
##### **CURL**

```bash
curl -X POST 'https://ws.visvise.com.cn/openapi/weaver/component/cancel_segment' \
  -H 'Content-Type: application/json' \
  -H 'app_id: your_app_id' \
  -H 'rtx: caller_rtx' \
  -H 'ts: 1713168000' \
  -H 'sign: your_sign' \
  -d '{
    "client_id": "client_xxxx",
    "view_type": 0
  }'
```

##### **Python**

```python
from visvise import VisviseClient

client = VisviseClient(app_id="your_app_id", secret_key="your_secret_key")

result = client.api.cancel_segment(client_id="client_xxxx", view_type=0, rtx="caller_rtx")
print(result)  # OperatorResult
```

##### **Go**

```go
package main

import (
    "fmt"
    "github.com/tencent-visvise/visvise-sdk-go/visvise"
)

func main() {
    client := visvise.NewClient("your_app_id", "your_secret_key", nil)

    result, err := client.GetAPI().CancelSegment("client_xxxx", visvise.SegmentViewMain, "caller_rtx")
    if err != nil {
        panic(err)
    }
    fmt.Println(result.ClientID)
}
```

<!-- tabs:end -->

##### 响应示例

```json
{
  "code": 0,
  "msg": "success",
  "req_id": "req_abc123",
  "data": {
    "client_id": "client_xxxx",
    "segment_data": {
      "components": [{ "label": 1, "color": "#3b82f6", "name": "胸甲" }],
      "mask_image": "iVBORw0KGgo...",
      "shape": [2048, 2048]
    },
    "enable_revoke": true,
    "enable_redo": false,
    "origin_view": { "main_view": "https://...", "back_view": "https://...", "left_view": "https://...", "right_view": "https://..." }
  }
}
```

---

### 2.17 拆分编辑-合并

#### 合并

将多个部件合并为一个连通体。

**接口路径：** `POST https://ws.visvise.com.cn/openapi/weaver/component/merge`

##### 请求参数

| 参数名称 | 必选 | 类型 | 描述 |
|---|---|---|---|
| `client_id` | 是 | String | 分割会话 ID |
| `component_labels` | 是 | Integer[] | 要合并的部件 label 列表 |
| `view_type` | 否 | Integer | 视图类型，默认 `0` |

##### 响应参数

`data` 字段结构（[MultiViewSegmentResult](#multiviewsegmentresult)）。

##### 请求示例

<!-- tabs:start -->
##### **CURL**

```bash
curl -X POST 'https://ws.visvise.com.cn/openapi/weaver/component/merge' \
  -H 'Content-Type: application/json' \
  -H 'app_id: your_app_id' \
  -H 'rtx: caller_rtx' \
  -H 'ts: 1713168000' \
  -H 'sign: your_sign' \
  -d '{
    "client_id": "client_xxxx",
    "component_labels": [3, 5],
    "view_type": 0
  }'
```

##### **Python**

```python
from visvise import VisviseClient

client = VisviseClient(app_id="your_app_id", secret_key="your_secret_key")

result = client.api.merge_component(
    client_id="client_xxxx",
    component_labels=[3, 5],
    view_type=0,
    rtx="caller_rtx",
)
print(result)  # MultiViewSegmentResult
```

##### **Go**

```go
package main

import (
    "fmt"
    "github.com/tencent-visvise/visvise-sdk-go/visvise"
)

func main() {
    client := visvise.NewClient("your_app_id", "your_secret_key", nil)

    result, err := client.GetAPI().MergeComponent("client_xxxx", []int32{3, 5}, visvise.SegmentViewMain, "caller_rtx")
    if err != nil {
        panic(err)
    }
    fmt.Println(result.ClientID)
}
```

<!-- tabs:end -->

##### 响应示例

```json
{
  "code": 0,
  "msg": "success",
  "req_id": "req_abc123",
  "data": {
    "main_view_data": { "client_id": "client_xxxx", "segment_data": { "components": [{ "label": 1, "color": "#3b82f6", "name": "胸甲" }], "mask_image": "iVBORw0KGgo...", "shape": [2048, 2048] }, "enable_revoke": true, "enable_redo": false, "origin_view": { "main_view": "https://..." } },
    "left_view_data": {},
    "right_view_data": {},
    "back_view_data": {},
    "client_id": "client_xxxx",
    "origin_view": { "main_view": "https://...", "back_view": "https://...", "left_view": "https://...", "right_view": "https://..." }
  }
}
```

> 合并后部件名称由被合并部件的名称拼接而成（如 `胸甲_护肩`）；分割状态下不允许合并。

---

#### 自动合并

自动合并所有相邻的连通体，无需指定 label。

**接口路径：** `POST https://ws.visvise.com.cn/openapi/weaver/component/auto_merge`

##### 请求参数

| 参数名称 | 必选 | 类型 | 描述 |
|---|---|---|---|
| `client_id` | 是 | String | 分割会话 ID |

##### 响应参数

`data` 字段结构（[MultiViewSegmentResult](#multiviewsegmentresult)）。

##### 请求示例

<!-- tabs:start -->
##### **CURL**

```bash
curl -X POST 'https://ws.visvise.com.cn/openapi/weaver/component/auto_merge' \
  -H 'Content-Type: application/json' \
  -H 'app_id: your_app_id' \
  -H 'rtx: caller_rtx' \
  -H 'ts: 1713168000' \
  -H 'sign: your_sign' \
  -d '{
    "client_id": "client_xxxx"
  }'
```

##### **Python**

```python
from visvise import VisviseClient

client = VisviseClient(app_id="your_app_id", secret_key="your_secret_key")

result = client.api.auto_merge_component(client_id="client_xxxx", rtx="caller_rtx")
print(result)  # MultiViewSegmentResult
```

##### **Go**

```go
package main

import (
    "fmt"
    "github.com/tencent-visvise/visvise-sdk-go/visvise"
)

func main() {
    client := visvise.NewClient("your_app_id", "your_secret_key", nil)

    result, err := client.GetAPI().AutoMergeComponent("client_xxxx", "caller_rtx")
    if err != nil {
        panic(err)
    }
    fmt.Println(result.ClientID)
}
```

<!-- tabs:end -->

##### 响应示例

```json
{
  "code": 0,
  "msg": "success",
  "req_id": "req_abc123",
  "data": {
    "main_view_data": { "client_id": "client_xxxx", "segment_data": { "components": [{ "label": 1, "color": "#3b82f6", "name": "胸甲_护肩" }], "mask_image": "iVBORw0KGgo...", "shape": [2048, 2048] }, "enable_revoke": true, "enable_redo": false, "origin_view": { "main_view": "https://..." } },
    "left_view_data": {},
    "right_view_data": {},
    "back_view_data": {},
    "client_id": "client_xxxx",
    "origin_view": { "main_view": "https://...", "back_view": "https://...", "left_view": "https://...", "right_view": "https://..." }
  }
}
```

---

### 2.18 拆分编辑-修边

通过涂抹区域调整部件边界。

**接口路径：** `POST https://ws.visvise.com.cn/openapi/weaver/component/boundary_adjust`

#### 请求参数

| 参数名称 | 必选 | 类型 | 描述 |
|---|---|---|---|
| `client_id` | 是 | String | 分割会话 ID |
| `view_type` | 否 | Integer | 视图类型，默认 `0` |
| `paint_mask` | 是 | String（base64） | 涂抹区域掩膜的 base64 编码（原始单字节掩膜数组，每像素 1 字节，非 0 表示涂抹；非 PNG 图片） |
| `component_label` | 是 | Integer | 要调整边界的部件 label |

#### 响应参数

`data` 字段结构（[OperatorResult](#operatorresult)）。

#### 请求示例

<!-- tabs:start -->
#### **CURL**

```bash
curl -X POST 'https://ws.visvise.com.cn/openapi/weaver/component/boundary_adjust' \
  -H 'Content-Type: application/json' \
  -H 'app_id: your_app_id' \
  -H 'rtx: caller_rtx' \
  -H 'ts: 1713168000' \
  -H 'sign: your_sign' \
  -d '{
    "client_id": "client_xxxx",
    "view_type": 0,
    "paint_mask": "iVBORw0KGgo...",
    "component_label": 3
  }'
```

#### **Python**

```python
from visvise import VisviseClient

client = VisviseClient(app_id="your_app_id", secret_key="your_secret_key")

result = client.api.boundary_adjust(
    client_id="client_xxxx",
    component_label=3,
    paint_mask="iVBORw0KGgo...",
    view_type=0,
    rtx="caller_rtx",
)
print(result)  # OperatorResult
```

#### **Go**

```go
package main

import (
    "fmt"
    "github.com/tencent-visvise/visvise-sdk-go/visvise"
)

func main() {
    client := visvise.NewClient("your_app_id", "your_secret_key", nil)

    result, err := client.GetAPI().BoundaryAdjust("client_xxxx", visvise.SegmentViewMain, 3, "iVBORw0KGgo...", "caller_rtx")
    if err != nil {
        panic(err)
    }
    fmt.Println(result.ClientID)
}
```

<!-- tabs:end -->

#### 响应示例

```json
{
  "code": 0,
  "msg": "success",
  "req_id": "req_abc123",
  "data": {
    "client_id": "client_xxxx",
    "segment_data": {
      "components": [{ "label": 1, "color": "#3b82f6", "name": "胸甲" }],
      "mask_image": "iVBORw0KGgo...",
      "shape": [2048, 2048]
    },
    "enable_revoke": true,
    "enable_redo": false,
    "origin_view": { "main_view": "https://...", "back_view": "https://...", "left_view": "https://...", "right_view": "https://..." }
  }
}
```

> 分割状态下不允许修边。

---

### 2.19 保存拆分

将当前分割结果持久化为独立的 2D 分割资产（`node_type=14`）。

**接口路径：** `POST https://ws.visvise.com.cn/openapi/weaver/component/save_segment`

#### 请求参数

| 参数名称 | 必选 | 类型 | 描述 |
|---|---|---|---|
| `client_id` | 是 | String | 分割会话 ID |
| `name` | 是 | String | 资产名称，1~100 个字符 |
| `algorithm_model` | 是 | String | 2D 分割算法模型（需为 `node_type=14` 支持的模型） |
| `opened_model_id` | 否 | String | 二次编辑时打开的原分割资产 ID；二次编辑保存时，需要传入原分割资产 ID 以继承其初始分割参数（[SegParams2D](#segparams2d)） |

#### 响应参数

`data` 字段结构（[ModelInfo](#modelinfo)），`node_type=14`，后续可作为图生模任务的 `segment_model_id`。

#### 请求示例

<!-- tabs:start -->
#### **CURL**

```bash
curl -X POST 'https://ws.visvise.com.cn/openapi/weaver/component/save_segment' \
  -H 'Content-Type: application/json' \
  -H 'app_id: your_app_id' \
  -H 'rtx: caller_rtx' \
  -H 'ts: 1713168000' \
  -H 'sign: your_sign' \
  -d '{
    "client_id": "client_xxxx",
    "name": "VISVISE_2d_segment",
    "algorithm_model": "VV-SplitMask-V1.0.0"
  }'
```

#### **Python**

```python
from visvise import VisviseClient

client = VisviseClient(app_id="your_app_id", secret_key="your_secret_key")

result = client.api.save_segment(
    client_id="client_xxxx",
    name="VISVISE_2d_segment",
    algorithm_model="VV-SplitMask-V1.0.0",
    rtx="caller_rtx",
)
segment_model_id = result["model_id"]
print(segment_model_id)
```

#### **Go**

```go
package main

import (
    "fmt"
    "github.com/tencent-visvise/visvise-sdk-go/visvise"
)

func main() {
    client := visvise.NewClient("your_app_id", "your_secret_key", nil)

    info, err := client.GetAPI().SaveSegment("client_xxxx", "VISVISE_2d_segment", "VV-SplitMask-V1.0.0", "", "caller_rtx")
    if err != nil {
        panic(err)
    }
    fmt.Println(info.ModelID)
}
```

<!-- tabs:end -->

#### 响应示例

```json
{
  "code": 0,
  "msg": "success",
  "req_id": "req_abc123",
  "data": {
    "model_id": "Model2026xxxxxx",
    "name": "VISVISE_2d_segment",
    "node_type": 14,
    "status": 3,
    "create_user": "caller_rtx",
    "preview_img": "https://...",
    "output_model": "https://..."
  }
}
```

---

### 2.20 部件重命名

重命名指定部件，四视图下同步修改所有视图。

**接口路径：** `POST https://ws.visvise.com.cn/openapi/weaver/component/part_rename`

#### 请求参数

| 参数名称 | 必选 | 类型 | 描述 |
|---|---|---|---|
| `client_id` | 是 | String | 分割会话 ID |
| `view_type` | 否 | Integer | 视图类型，默认 `0` |
| `component_label` | 是 | Integer | 要重命名的部件 label |
| `new_name` | 是 | String | 新名称，最长 20 个字符（60 字节） |

#### 响应参数

`data` 字段结构（[MultiViewSegmentResult](#multiviewsegmentresult)）。

#### 请求示例

<!-- tabs:start -->
#### **CURL**

```bash
curl -X POST 'https://ws.visvise.com.cn/openapi/weaver/component/part_rename' \
  -H 'Content-Type: application/json' \
  -H 'app_id: your_app_id' \
  -H 'rtx: caller_rtx' \
  -H 'ts: 1713168000' \
  -H 'sign: your_sign' \
  -d '{
    "client_id": "client_xxxx",
    "view_type": 0,
    "component_label": 3,
    "new_name": "胸甲"
  }'
```

#### **Python**

```python
from visvise import VisviseClient

client = VisviseClient(app_id="your_app_id", secret_key="your_secret_key")

result = client.api.rename_component(
    client_id="client_xxxx",
    component_label=3,
    new_name="胸甲",
    view_type=0,
    rtx="caller_rtx",
)
print(result)  # MultiViewSegmentResult
```

#### **Go**

```go
package main

import (
    "fmt"
    "github.com/tencent-visvise/visvise-sdk-go/visvise"
)

func main() {
    client := visvise.NewClient("your_app_id", "your_secret_key", nil)

    result, err := client.GetAPI().RenameComponent("client_xxxx", visvise.SegmentViewMain, 3, "胸甲", "caller_rtx")
    if err != nil {
        panic(err)
    }
    fmt.Println(result.ClientID)
}
```

<!-- tabs:end -->

#### 响应示例

```json
{
  "code": 0,
  "msg": "success",
  "req_id": "req_abc123",
  "data": {
    "main_view_data": { "client_id": "client_xxxx", "segment_data": { "components": [{ "label": 3, "color": "#3b82f6", "name": "胸甲" }], "mask_image": "iVBORw0KGgo...", "shape": [2048, 2048] }, "enable_revoke": true, "enable_redo": false, "origin_view": { "main_view": "https://..." } },
    "left_view_data": {},
    "right_view_data": {},
    "back_view_data": {},
    "client_id": "client_xxxx",
    "origin_view": { "main_view": "https://...", "back_view": "https://...", "left_view": "https://...", "right_view": "https://..." }
  }
}
```

> 当前视图内不允许部件名称重复。

---

### 2.21 重新生成模型

对已生成的模型资产进行重新生成，目前仅支持 2UV 节点（`node_type=15`）的重新生成。调用后会在原模型资产上重新执行生成任务，不需要创建新的模型 ID。

**接口路径：** `POST https://ws.visvise.com.cn/openapi/weaver/resource/regenerate_model`

#### 请求参数

| 参数名称 | 必选 | 类型 | 描述 |
|---|---|---|---|
| `model_id` | 是 | String | 待重新生成的模型资产 ID |
| `params` | 否 | [TemplateParams](#templateparams) | 生成参数（在对应的节点参数中赋值）。2UV 重新生成时需在 `auto_luv_params` 中指定新的参数 |

#### 响应参数

通用返回结构，无额外 `data` 字段。

#### 请求示例

<!-- tabs:start -->
#### **CURL**

**重新生成 2UV（修改参数后重新生成）：**

```bash
curl -X POST 'https://ws.visvise.com.cn/openapi/weaver/resource/regenerate_model' \
  -H 'Content-Type: application/json' \
  -H 'app_id: your_app_id' \
  -H 'ts: 1713168000' \
  -H 'rtx: caller_rtx' \
  -H 'sign: your_sign' \
  -d '{
    "model_id": "Model202606xxxxxx",
    "params": {
        "auto_luv_params": {
            "algorithm_model": "VV-AutoLUV-V2.6.0",
            "mesh_name": "Body_Mesh",
            "light_map_resolution": 2048,
            "edge_pixel_count": 2.0,
            "coord_axis": 1,
            "out_channel": 1,
            "split_strategy": 3
        }
    }
  }'
```

**不修改参数重新生成（使用原始参数）：**

```bash
curl -X POST 'https://ws.visvise.com.cn/openapi/weaver/resource/regenerate_model' \
  -H 'Content-Type: application/json' \
  -H 'app_id: your_app_id' \
  -H 'ts: 1713168000' \
  -H 'rtx: caller_rtx' \
  -H 'sign: your_sign' \
  -d '{
    "model_id": "Model202606xxxxxx"
  }'
```

#### **Python**

```python
from visvise import VisviseClient

client = VisviseClient(app_id="your_app_id", secret_key="your_secret_key")

# 修改参数后重新生成
client.api.regenerate_model(
    model_id="Model202606xxxxxx",
    rtx="caller_rtx",
    params={
        "auto_luv_params": {
            "algorithm_model": "VV-AutoLUV-V2.6.0",
            "mesh_name": "Body_Mesh",
            "light_map_resolution": 2048,
            "edge_pixel_count": 2.0,
            "coord_axis": 1,
            "out_channel": 1,
            "split_strategy": 3
        }
    }
)

# 不修改参数重新生成（复用原始参数）
client.api.regenerate_model(model_id="Model202606xxxxxx", rtx="caller_rtx")
```

#### **Go**

```go
package main

import (
    "fmt"
    "github.com/tencent-visvise/visvise-sdk-go/visvise"
)

func main() {
    client := visvise.NewClient("your_app_id", "your_secret_key", nil)

    // 修改参数后重新生成
    err := client.GetAPI().RegenerateModel("Model202606xxxxxx", map[string]interface{}{
        "auto_luv_params": map[string]interface{}{
            "algorithm_model": "VV-AutoLUV-V2.6.0",
            "mesh_name": "Body_Mesh",
            "light_map_resolution": 2048,
            "edge_pixel_count": 2.0,
            "coord_axis": 1,
            "out_channel": 1,
            "split_strategy": 3,
        },
    }, "caller_rtx")
    if err != nil {
        panic(err)
    }

    // 不修改参数重新生成（复用原始参数）
    if err := client.GetAPI().RegenerateModel("Model202606xxxxxx", nil, "caller_rtx"); err != nil {
        panic(err)
    }
    fmt.Println("重新生成成功")
}
```

<!-- tabs:end -->

#### 响应示例

```json
{
    "code": 0,
    "msg": "success",
    "req_id": "req_abc123"
}
```

> ⚠️ **当前限制**：重新生成模型接口目前仅支持 2UV 节点（`node_type=15`），其他节点类型暂不支持。
>
> **行为说明**：
>
> - 重新生成是**原地操作**，不返回新的 `model_id`，在原 `model_id` 上重新执行生成任务。
> - 每次调用后 `progress.redo_count` 递增，`progress.auto_luv.redo_current_index` 指向当前重做轮次。
> - 即使原模型 `status=3`（成功），也可调用 regenerate_model 重新生成（仍返回 `code=0`，原地重做）。
> - 如果模型 `is_allow_regenerate=false`，调用会返回业务错误码。

---

### 2.22 原画风格化

对原画进行风格转换，支持灰模、像素、写实和卡通手办风格。接口仅返回处理结果图片，不创建模型资产。

**接口路径：** `POST https://ws.visvise.com.cn/openapi/weaver/resource/style_transfer`

#### 请求参数

请求结构为 `StyleTransferRequest`。

| 参数名称 | 必选 | 类型 | 描述 |
|---|---|---|---|
| `input_view` | 是 | String | 输入原画 COS URL |
| `style_type` | 是 | Integer | 风格类型：`1` 灰模风 / `2` 像素风 / `3` 写实风 / `4` 卡通手办风 |

#### 响应参数

`data` 字段结构（`StyleTransferResult`）：

| 参数名称 | 类型 | 描述 |
|---|---|---|
| `result_image` | String | 带临时签名的风格化结果图片 COS 下载 URL（24h 有效）；可作为 [保存2D预处理资产](#224-保存2d预处理资产) 的 `style_param.result_image` |

#### 请求示例

<!-- tabs:start -->

#### **CURL**

```bash
curl -X POST 'https://ws.visvise.com.cn/openapi/weaver/resource/style_transfer' \
  -H 'Content-Type: application/json' \
  -H 'app_id: your_app_id' \
  -H 'ts: 1713168000' \
  -H 'rtx: caller_rtx' \
  -H 'sign: your_sign' \
  -d '{
    "input_view": "https://cos.example.com/weaver/user-xxx/input.png",
    "style_type": 1
  }'
```

#### **Python**

```python
from visvise import VisviseClient, StyleType

client = VisviseClient("your_app_id", "your_secret_key")

result = client.api.style_transfer(
    "https://cos.example.com/weaver/user-xxx/input.png",
    StyleType.GRAYSCALE,
    rtx="caller_rtx",
)
print(result)  # result_image COS URL
```

#### **Go**

```go
package main

import (
    "fmt"
    "github.com/tencent-visvise/visvise-sdk-go/visvise"
)

func main() {
    client := visvise.NewClient("your_app_id", "your_secret_key", nil)

    resultImage, err := client.GetAPI().StyleTransfer(
        "https://cos.example.com/weaver/user-xxx/input.png",
        visvise.StyleTypeGrayscale,
        "caller_rtx",
    )
    if err != nil {
        panic(err)
    }
    fmt.Println(resultImage)  // result_image COS URL
}
```

<!-- tabs:end -->

#### 响应示例

```json
{
  "code": 0,
  "msg": "success",
  "req_id": "req_abc123",
  "data": {
    "result_image": "https://cos.example.com/weaver/user-xxx/style-result.png?q-sign-algorithm=sha1&q-ak=xxx&q-sign-time=1713168000%3B1713254400&q-key-time=1713168000%3B1713254400&q-header-list=host&q-url-param-list=&q-signature=xxx"
  }
}
```

---

### 2.23 花纹智能去除

自动识别并去除原画表面花纹。接口仅返回处理结果图片，不创建模型资产。

**接口路径：** `POST https://ws.visvise.com.cn/openapi/weaver/resource/patter_auto_remove`

#### 请求参数

请求结构为 `PatterAutoRemoveRequest`。

| 参数名称 | 必选 | 类型 | 描述 |
|---|---|---|---|
| `input_view` | 是 | String | 输入原画 COS URL |

#### 响应参数

`data` 字段结构（`PatterRemoveResult`）：

| 参数名称 | 类型 | 描述 |
|---|---|---|
| `result_image` | String | 带临时签名的智能去花纹结果图片 COS 下载 URL（24h 有效）；可作为 [保存2D预处理资产](#224-保存2d预处理资产) 的 `remove_pattern_param.result_image` |

#### 请求示例

<!-- tabs:start -->

#### **CURL**

```bash
curl -X POST 'https://ws.visvise.com.cn/openapi/weaver/resource/patter_auto_remove' \
  -H 'Content-Type: application/json' \
  -H 'app_id: your_app_id' \
  -H 'ts: 1713168000' \
  -H 'rtx: caller_rtx' \
  -H 'sign: your_sign' \
  -d '{
    "input_view": "https://cos.example.com/weaver/user-xxx/input.png"
  }'
```

#### **Python**

```python
from visvise import VisviseClient

client = VisviseClient("your_app_id", "your_secret_key")

result = client.api.patter_auto_remove(
    "https://cos.example.com/weaver/user-xxx/input.png",
    rtx="caller_rtx",
)
print(result)  # result_image COS URL
```

#### **Go**

```go
package main

import (
    "fmt"
    "github.com/tencent-visvise/visvise-sdk-go/visvise"
)

func main() {
    client := visvise.NewClient("your_app_id", "your_secret_key", nil)

    resultImage, err := client.GetAPI().PatterAutoRemove(
        "https://cos.example.com/weaver/user-xxx/input.png",
        "caller_rtx",
    )
    if err != nil {
        panic(err)
    }
    fmt.Println(resultImage)  // result_image COS URL
}
```

<!-- tabs:end -->

#### 响应示例

```json
{
  "code": 0,
  "msg": "success",
  "req_id": "req_abc123",
  "data": {
    "result_image": "https://cos.example.com/weaver/user-xxx/pattern-removed.png?q-sign-algorithm=sha1&q-ak=xxx&q-sign-time=1713168000%3B1713254400&q-key-time=1713168000%3B1713254400&q-header-list=host&q-url-param-list=&q-signature=xxx"
  }
}
```

---

### 2.24 保存2D预处理资产

将已处理的结果图片保存为 `node_type=16` 的 2D 预处理资产。该接口调用成功后将创建模型资产，并返回 `model_id`。

> 该接口不执行风格化或去花纹算法；请先调用 [原画风格化](#222-原画风格化) 或 [花纹智能去除](#223-花纹智能去除)，再将响应中的 `result_image` 原样传入对应参数。若该 URL 包含临时签名 query 参数，请勿移除或修改。

**接口路径：** `POST https://ws.visvise.com.cn/openapi/weaver/resource/gen_preprocess`

#### 请求参数

请求结构为 `Gen2DPreprocessRequest`。

| 参数名称 | 必选 | 类型 | 描述 |
|---|---|---|---|
| `name` | 是 | String | 模型资产名称，长度为 1~100 个字符；系统保存时会追加 `_2DPre` 后缀 |
| `input_view` | 是 | String | 原始输入图片 COS URL |
| `preprocess_type` | 是 | Integer | 预处理类型：`1` 风格化 / `2` 去花纹 |
| `algorithm_model` | 否 | String | 算法模型名称，保存至资产信息 |
| `style_param` | 否 | [StyleParam](#styleparam) | 风格化参数；`preprocess_type=1` 时必传 |
| `remove_pattern_param` | 否 | [RemovePatternParam](#removepatternparam) | 去花纹参数；`preprocess_type=2` 时必传 |

#### 响应参数

`data` 字段结构（`Gen2DPreprocessResult`）：

| 参数名称 | 类型 | 描述 |
|---|---|---|
| `model_id` | String | 已创建且生成成功的 2D 预处理资产 ID |

#### 请求示例

<!-- tabs:start -->

#### **CURL**

```bash
curl -X POST 'https://ws.visvise.com.cn/openapi/weaver/resource/gen_preprocess' \
  -H 'Content-Type: application/json' \
  -H 'app_id: your_app_id' \
  -H 'ts: 1713168000' \
  -H 'rtx: caller_rtx' \
  -H 'sign: your_sign' \
  -d '{
    "name": "角色灰模原画",
    "input_view": "https://cos.example.com/weaver/user-xxx/input.png",
    "preprocess_type": 1,
    "algorithm_model": "VV-Pre2D-V1.0.0",
    "style_param": {
      "style_type": 1,
      "result_image": "https://cos.example.com/weaver/user-xxx/style-result.png?q-sign-algorithm=sha1&q-ak=xxx&q-sign-time=1713168000%3B1713254400&q-key-time=1713168000%3B1713254400&q-header-list=host&q-url-param-list=&q-signature=xxx"
    }
  }'
```

> **去花纹类型的示例**：将 `preprocess_type` 改为 `2`，`style_param` 替换为 `remove_pattern_param`，传入 [花纹智能去除](#223-花纹智能去除) 返回的 `result_image`。

#### **Python**

```python
from visvise import VisviseClient, PreprocessType, StyleType
from visvise.models import StyleParam

client = VisviseClient("your_app_id", "your_secret_key")

model_id = client.api.gen_preprocess(
    "角色灰模原画",
    "https://cos.example.com/weaver/user-xxx/input.png",
    PreprocessType.STYLIZED,
    rtx="caller_rtx",
    algorithm_model="VV-Pre2D-V1.0.0",
    style_param=StyleParam(StyleType.GRAYSCALE, result_image),
)
print(model_id)
```

#### **Go**

```go
package main

import (
    "fmt"
    "github.com/tencent-visvise/visvise-sdk-go/visvise"
)

func main() {
    client := visvise.NewClient("your_app_id", "your_secret_key", nil)

    modelID, err := client.GetAPI().GenPreprocess(
        "角色灰模原画",
        "https://cos.example.com/weaver/user-xxx/input.png",
        visvise.PreprocessTypeStylized,
        "VV-Pre2D-V1.0.0",
        &visvise.StyleParam{StyleType: visvise.StyleTypeGrayscale, ResultImage: resultImage},
        nil,
        "caller_rtx",
    )
    if err != nil {
        panic(err)
    }
    fmt.Println(modelID)
}
```

<!-- tabs:end -->

#### 响应示例

```json
{
  "code": 0,
  "msg": "success",
  "req_id": "req_abc123",
  "data": {
    "model_id": "Model2026072900000001"
  }
}
```

---

## 3. 模型生成 Demo

本章节介绍模型生成相关的完整调用示例，包括图生360、2D预处理、图生高模/中模/低模、布线重建、重拓扑和 LOD。

2D 预处理任务调用的 [原画风格化](#222-原画风格化)、[花纹智能去除](#223-花纹智能去除) 和 [保存2D预处理资产](#224-保存2d预处理资产) 接口为同步接口，其他所有任务均通过 [生成3D模型资产](#24-生成3d模型资产)（或 [生成多视图](#25-生成多视图)）接口创建，为异步接口，需通过 [获取模型资产列表](#26-获取模型资产列表) 轮询 [ModelInfo](#modelinfo) 的 `status=3`（成功）或 `status=4`（失败）。

> **关于 SDK 示例中的 `algorithm_model`**：以下 Python / Go SDK 示例**默认不传 `algorithm_model`**。SDK 在未指定该参数时，会自动调用 [获取算法模型列表](#27-获取算法模型列表) 拉取当前账号在该 `node_type` 下**第一个可用的算法模型**作为默认值。如需指定特定模型版本，可显式传入对应的 `algorithm_model`。CURL 原始请求示例仍保留 `algorithm_model` 字段以体现 HTTP 接口完整 schema。

### 3.1 图生360

从单张图片生成 360 度多视图（`node_type=7`）。使用 [生成多视图](#25-生成多视图) 接口。

**调用参数：**

| 参数 | 值 / 说明 |
|---|---|
| `name` | 模型资产名称，示例： `VISVISE_MultiView` |
| `node_type` | 固定值 `7` |
| `input_view.main_view` | 上传到 COS 的图片 URL |
| `params.image_gen_360_params.algorithm_model` | 算法模型，支持：`VV-MultiView-V1.0.0` / `Hy3D-MultiView-v3.0` |
| `params.image_gen_360_params.enable_a_pose` | 可选，标准化A-Pose（Bool），默认为 `false` |
| `params.image_gen_360_params.prompt` | 可选，文本提示词 |

**请求示例（cURL）：**

```bash
curl -X POST 'https://ws.visvise.com.cn/openapi/weaver/resource/gen_multi_views' \
  -H 'Content-Type: application/json' \
  -H 'app_id: your_app_id' \
  -H 'ts: 1713168000' \
  -H 'rtx: caller_rtx' \
  -H 'sign: your_sign' \
  -d '{
    "name": "VISVISE_MultiView",
    "input_view": {
        "main_view": "https://cos.example.com/weaver/user-xxx/input.jpg"
    },
    "params": {
        "image_gen_360_params": {
            "algorithm_model": "Hy3D-MultiView-v3.0",
            "enable_a_pose": false,
            "prompt": "一个穿着盔甲的骑士"
        }
    }
  }'
```

**Python SDK 示例：**

```python
from visvise import VisviseClient

client = VisviseClient("your_app_id", "your_secret_key")

mv_id = client.gen_360(
    main_view="character.png",                       # 本地文件 SDK 自动上传
    enable_a_pose=False,
    rtx="caller_rtx",
)
mv = client.wait_model(mv_id, interval=3, timeout=300, rtx="caller_rtx")
print(mv.image_gen_360_output.output_view)
```

**Go SDK 示例：**

```go
package main

import (
    "fmt"
    "github.com/tencent-visvise/visvise-sdk-go/visvise"
)

func main() {
    client := visvise.NewClient("your_app_id", "your_secret_key", nil)
    rtx := "caller_rtx"

    mvID, err := client.Gen360("character.png", rtx,
        visvise.NewGen360Options().
            SetEnableAPose(false))
    if err != nil { panic(err) }

    mv, err := client.WaitModel(mvID, rtx, &visvise.WaitOptions{Interval: 3.0, Timeout: 300})
    if err != nil { panic(err) }
    fmt.Println(mv.ImageGen360Output.OutputView)
}
```

**输出参数：**

返回 **1 个** `model_id`。产物在 `image_gen_360_output`（详见 [ImageGen360Output](#imagegen360output)）。

| 参数 | 类型 | 说明 |
|---|---|---|
| `image_gen_360_output.output_view.main_view` | String | 正视图（主视图）图片 URL（必有） |
| `image_gen_360_output.output_view.back_view` | String | 背视图图片 URL（可选） |
| `image_gen_360_output.output_view.left_view` | String | 左视图图片 URL（可选） |
| `image_gen_360_output.output_view.right_view` | String | 右视图图片 URL（可选） |
| `image_gen_360_output.horizontal_view_video` | String | 水平视角旋转视频 URL |
| `image_gen_360_output.vertical_view_video` | String | 垂直视角旋转视频 URL |
| `image_gen_360_output.horizontal_view_video_frames` | String | 72 帧压缩包 COS 地址 |

---

### 3.2 2D 拆分

对图生360 输出的多视图进行组件分割（`node_type=14`），生成的分割资产可作为图生中模 / 图生低模的 `segment_model_id` 输入，用于基于分割结果的精细化生成。

#### 初始分割

**调用接口：** [2D拆分](#214-2d拆分)（SSE 协议）

**输入条件：** `model_id`（图生 360 模型资产 ID）与 `input_view`（任意图片）二选一，无需强制依赖图生 360。

**调用参数：**

| 参数 | 值 / 说明 |
|---|---|
| `name` | 模型资产名称，示例： `VISVISE_2d_segment` |
| `node_type` | 固定值 `14` |
| `algorithm_model` | 算法模型 |
| `model_id` | 图生 360 资产的 `model_id`（与 `input_view` 二选一） |
| `split_type` | 拆分方式，1 正视图拆分 / 2 四视图拆 分 |
| `granularity` | 颗粒度，1 粗 / 2 中 / 3 细 |
| `prompt` | 可选，自然语言描述拆分规则 |

**请求示例（cURL）：**

```bash
curl -N -X POST 'https://ws.visvise.com.cn/openapi/weaver/component/init_segment' \
  -H 'Content-Type: application/json' \
  -H 'Accept: text/event-stream' \
  -H 'app_id: your_app_id' \
  -H 'rtx: caller_rtx' \
  -H 'ts: 1713168000' \
  -H 'sign: your_sign' \
  -d '{
    "name": "VISVISE_2d_segment",
    "algorithm_model": "VV-SplitMask-V1.0.0",
    "model_id": "Model202604xxxxxx",
    "split_type": 1,
    "granularity": 2
  }'
```

**Python SDK 示例：**

```python
from visvise import VisviseClient, SegmentSplitType, SegmentGranularity

client = VisviseClient("your_app_id", "your_secret_key")

def on_thinking(content):
    print("[思考]", content)

seg_model_id = client.gen_segment_2d(
    model_id_360="Model202604xxxxxx",
    split_type=SegmentSplitType.FRONT_VIEW,
    granularity=SegmentGranularity.MEDIUM,
    on_thinking=on_thinking,
    rtx="caller_rtx",
)
print("分割资产 model_id:", seg_model_id)
# 后续作为 segment_model_id 传给 gen_mid_model
```

**Go SDK 示例：**

```go
package main

import (
    "fmt"
    "github.com/tencent-visvise/visvise-sdk-go/visvise"
)

func main() {
    client := visvise.NewClient("your_app_id", "your_secret_key", nil)
    rtx := "caller_rtx"

    splitType := visvise.SegmentSplitFrontView
    granularity := visvise.SegmentGranularityMedium
    segModelID, err := client.GenSegment2D("Model202604xxxxxx", rtx,
        visvise.NewGenSegment2DOptions().
            SetSplitType(splitType).
            SetGranularity(granularity).
            SetOnThinking(func(content string) {
                fmt.Println("[思考]", content)
            }))
    if err != nil { panic(err) }
    fmt.Println("分割资产 model_id:", segModelID)
    // 后续作为 SegmentModelID 传给 GenMidModel
}
```

**输出参数：**

监听 SSE 流中的 `reply` 事件，从 `data` 字段获取分割结果（`segment_output`，`node_type=14`）。正视图拆分仅填充 `main_view`；四视图拆分填充四个视图。字段定义详见 [SegmentOutput](#segmentoutput)、[SegmentViewData](#segmentviewdata)、[SegmentComponent](#segmentcomponent)。

| 参数 | 类型 | 说明 |
|---|---|---|
| `segment_output.main_view` | [SegmentViewData](#segmentviewdata) | 正视图分割数据（必有） |
| `segment_output.left_view` | [SegmentViewData](#segmentviewdata) | 左视图分割数据（四视图拆分时填充） |
| `segment_output.right_view` | [SegmentViewData](#segmentviewdata) | 右视图分割数据（四视图拆分时填充） |
| `segment_output.back_view` | [SegmentViewData](#segmentviewdata) | 背视图分割数据（四视图拆分时填充） |
| `segment_output.origin_view` | [View](#view) | 原始四视图 URL（从图生360继承） |
| `segment_output.color_imgs` | [SegmentColorImgs](#segmentcolorimgs) | 四视图彩色预览图（`main_view`/`left_view`/`right_view`/`back_view`，均为图片 URL） |

**完成标识：** 监听 SSE 流中的 `reply` 事件，从 `data` 字段获取分割结果及对应的 `model_id`（ `node_type=14`），可作为后续图生模任务的 `segment_model_id`。

#### 编辑分割结果

初始分割完成后，可对分割结果做进一步编辑（拆分 / 合并 / 修边 / 重命名），再通过 `save_segment` 持久化为新的 `node_type=14` 分割资产；已保存的资产可通过 `open_segment` 再次打开编辑。各接口的请求 / 响应字段见 [2.14 2D拆分](#214-2d拆分)。

> `gen_segment_2d` 仅返回分割资产的 `model_id`（不含 `client_id`）；如需在初始分割后立即进入编辑，先用 `open_segment(model_id)` 换取新的 `client_id`。二次编辑保存时，将原资产 ID 通过 `opened_model_id` 传入，以继承该资产的初始分割参数（[SegParams2D](#segparams2d)）。

**Python SDK 示例：**

```python
from visvise import VisviseClient

client = VisviseClient("your_app_id", "your_secret_key")
rtx = "caller_rtx"

# seg_model_id 由上一步 gen_segment_2d 返回（初始分割资产）
seg_model_id = "Model202604xxxxxx"

# 打开已有拆分，换取 client_id 进入编辑
opened = client.open_segment(model_id=seg_model_id, rtx=rtx)
client_id = opened["client_id"]

# 1. 开始拆分（拆分部件 label=3）
client.begin_segment(client_id, component_label=3, rtx=rtx)
# 2. 拆分：正点 + 矩形框圈定区域（可多次）
client.segment_component(
    client_id,
    add_pixels=[{"x": 120, "y": 150}],
    rects=[{"left_top_pixel": {"x": 10, "y": 10}, "right_bottom_pixel": {"x": 200, "y": 200}}],
    rtx=rtx,
)
# 3. 确认拆分
client.confirm_segment(client_id, rtx=rtx)
# 4. 合并部件 label=3 与 label=5
client.merge_component(client_id, component_labels=[3, 5], rtx=rtx)
# 5. 修边（paint_mask 为 base64 涂抹掩膜）
client.boundary_adjust(client_id, component_label=3, paint_mask="<base64>", rtx=rtx)
# 6. 重命名
client.rename_component(client_id, component_label=3, new_name="胸甲", rtx=rtx)
# 7. 保存为新的分割资产（node_type=14），opened_model_id 继承原资产的初始分割参数（SegParams2D）
new_model = client.save_segment(client_id, name="VISVISE_2d_segment_v2", opened_model_id=seg_model_id, rtx=rtx)
print("新分割资产 model_id:", new_model["model_id"])
```

**Go SDK 示例：**

```go
// 承接上一步 GenSegment2D 示例，client 与 rtx 已定义
// segModelID 为上一步返回的初始分割资产 model_id
segModelID := "Model202604xxxxxx"

// 打开已有拆分，换取 client_id 进入编辑
opened, err := client.OpenSegment(segModelID, rtx)
if err != nil { panic(err) }
clientID := opened.ClientID

// 1. 开始拆分（拆分部件 label=3）
if _, err := client.BeginSegment(clientID, 3, visvise.SegmentViewMain, rtx); err != nil { panic(err) }
// 2. 拆分：正点 + 矩形框圈定区域
if _, err := client.SegmentComponent(clientID, visvise.SegmentViewMain,
    []*visvise.Pixel{{X: 120, Y: 150}}, nil,
    []*visvise.Rect{{LeftTopPixel: &visvise.Pixel{X: 10, Y: 10}, RightBottomPixel: &visvise.Pixel{X: 200, Y: 200}}},
    rtx); err != nil { panic(err) }
// 3. 确认拆分
if _, err := client.ConfirmSegment(clientID, visvise.SegmentViewMain, rtx); err != nil { panic(err) }
// 4. 合并部件 label=3 与 label=5
if _, err := client.MergeComponent(clientID, []int32{3, 5}, visvise.SegmentViewMain, rtx); err != nil { panic(err) }
// 5. 修边（paintMask 为 base64 涂抹掩膜）
if _, err := client.BoundaryAdjust(clientID, visvise.SegmentViewMain, 3, "<base64>", rtx); err != nil { panic(err) }
// 6. 重命名
if _, err := client.RenameComponent(clientID, visvise.SegmentViewMain, 3, "胸甲", rtx); err != nil { panic(err) }
// 7. 保存为新的分割资产（node_type=14），openedModelID 继承原资产的初始分割参数（SegParams2D）
newModel, err := client.SaveSegment(clientID, "VISVISE_2d_segment_v2", "", segModelID, rtx)
if err != nil { panic(err) }
fmt.Println("新分割资产 model_id:", newModel.ModelID)
```

**输出参数：**

编辑流程各接口的返回结构（完整字段定义见 [2.14 2D拆分](#214-2d拆分) 的 [OperatorResult](#operatorresult) / [MultiViewSegmentResult](#multiviewsegmentresult)），最终通过 `save_segment` 产出 **1 个**新的 `model_id`。

| 接口 | 返回结构 | 关键字段 | 说明 |
|---|---|---|---|
| `open_segment` | [MultiViewSegmentResult](#multiviewsegmentresult) | `client_id` | 新的分割会话 ID，后续编辑接口基于该 ID 操作 |
| `begin_segment` / `segment` / `confirm_segment` / `cancel_segment` / `boundary_adjust` | [OperatorResult](#operatorresult) | `segment_data` / `enable_revoke` / `enable_redo` | 操作后的单视图分割数据与撤销 / 重做状态 |
| `merge` / `auto_merge` / `part_rename` | [MultiViewSegmentResult](#multiviewsegmentresult) | `main_view_data` / `left_view_data` / `right_view_data` / `back_view_data` | 操作后的四视图分割数据 |
| `save_segment` | [ModelInfo](#modelinfo) | `model_id` | 新持久化的分割资产 ID（`node_type=14`），可作为后续图生模任务的 `segment_model_id` |

**完成标识：** `save_segment` 返回的 `model_id`（`node_type=14`）即为新生成的分割资产，可作为后续图生模任务的 `segment_model_id`；再次调用 `open_segment(new_model_id)` 可继续进行二次编辑。

---

### 3.3 2D预处理

对图片进行风格化或去花纹处理，并保存为 2D 预处理资产（`node_type=16`）。HTTP 调用需先处理图片取得 `result_image`，再调用 `gen_preprocess` 保存资产，返回 `model_id`。

#### 3.3.1 风格化

对原画进行风格转换后保存为预处理资产。

**调用接口：** [原画风格化](#222-原画风格化) → [保存2D预处理资产](#224-保存2d预处理资产)

**调用参数：**

| 参数 | 值 / 说明                                  |
|---|-----------------------------------------|
| `name` | 预处理资产名称，示例：`VISVISE_2d_preProcess`                     |
| `input_view` | 用户上传的原画（COS地址）                          |
| `style_type` | 风格类型：`1` 灰模风 / `2` 像素风 / `3` 写实风 / `4` 卡通手办风 |
| `algorithm_model` | 算法模型                                    |
| `style_param.result_image` | 风格化接口返回的 `data.result_image`，请原样传入并保留临时签名 query 参数 |

**请求示例（cURL）：**

```bash
# 1. 原画风格化
curl -X POST 'https://ws.visvise.com.cn/openapi/weaver/resource/style_transfer' \
  -H 'Content-Type: application/json' \
  -H 'app_id: your_app_id' \
  -H 'ts: 1713168000' \
  -H 'rtx: caller_rtx' \
  -H 'sign: your_sign' \
  -d '{
    "input_view": "https://cos.example.com/weaver/user-xxx/input.png",
    "style_type": 1
  }'

# 2. 将步骤 1 返回的 data.result_image 填入 style_param.result_image，保存资产
curl -X POST 'https://ws.visvise.com.cn/openapi/weaver/resource/gen_preprocess' \
  -H 'Content-Type: application/json' \
  -H 'app_id: your_app_id' \
  -H 'ts: 1713168000' \
  -H 'rtx: caller_rtx' \
  -H 'sign: your_sign' \
  -d '{
    "name": "VISVISE_2d_preProcess",
    "input_view": "https://cos.example.com/weaver/user-xxx/input.png",
    "preprocess_type": 1,
    "algorithm_model": "VV-Pre2D-V1.0.0",
    "style_param": {
      "style_type": 1,
      "result_image": "https://cos.example.com/weaver/user-xxx/style-result.png?q-sign-algorithm=sha1&q-ak=xxx&q-sign-time=1713168000%3B1713254400&q-key-time=1713168000%3B1713254400&q-header-list=host&q-url-param-list=&q-signature=xxx"
    }
  }'
```

**Python SDK 示例：**

```python
from visvise import VisviseClient, StyleType

client = VisviseClient("your_app_id", "your_secret_key")

model_id = client.gen_style_transfer(
    "input.png",
    style_type=StyleType.GRAYSCALE,
    rtx="caller_rtx",
)
print(model_id)
```

**Go SDK 示例：**

```go
package main

import (
    "fmt"
    "github.com/tencent-visvise/visvise-sdk-go/visvise"
)

func main() {
    client := visvise.NewClient("your_app_id", "your_secret_key", nil)

    modelID, err := client.GenStyleTransfer(
        "input.png",
        "caller_rtx",
        visvise.NewGenStyleTransferOptions().SetName("VISVISE_2d_preProcess").SetStyleType(visvise.StyleTypeGrayscale),
    )
    if err != nil {
        panic(err)
    }
    fmt.Println(modelID)
}
```

**输出参数：**

分两步，最终返回 **1 个** `model_id`（`node_type=16` 的 2D 预处理资产）。

| 步骤 | 参数 | 类型 | 说明 |
|---|---|---|---|
| ① 原画风格化 | `result_image` | String | 带临时签名的风格化结果图片 COS 下载 URL（24h 有效），原样传入②的 `style_param.result_image` |
| ② 保存预处理资产 | `model_id` | String | 已创建且生成成功的 2D 预处理资产 ID（`node_type=16`），可作为后续图生模任务的输入 |


#### 3.3.2 智能去花纹

自动识别并去除原画表面花纹后保存为预处理资产。

**调用接口：** [花纹智能去除](#223-花纹智能去除) → [保存2D预处理资产](#224-保存2d预处理资产)

**调用参数：**

| 参数 | 值 / 说明                             |
|---|------------------------------------|
| `name` | 预处理资产名称，示例：`VISVISE_2d_preProcess` |
| `input_view` | 用户上传的原画（COS地址）                     |
| `algorithm_model` | 算法模型                               |
| `remove_pattern_param.result_image` | 智能去花纹接口返回的 `data.result_image`，请原样传入并保留临时签名 query 参数 |

**请求示例（cURL）：**

```bash
# 1. 智能去花纹
curl -X POST 'https://ws.visvise.com.cn/openapi/weaver/resource/patter_auto_remove' \
  -H 'Content-Type: application/json' \
  -H 'app_id: your_app_id' \
  -H 'ts: 1713168000' \
  -H 'rtx: caller_rtx' \
  -H 'sign: your_sign' \
  -d '{
    "input_view": "https://cos.example.com/weaver/user-xxx/input.png"
  }'

# 2. 将步骤 1 返回的 data.result_image 填入 remove_pattern_param.result_image，保存资产
curl -X POST 'https://ws.visvise.com.cn/openapi/weaver/resource/gen_preprocess' \
  -H 'Content-Type: application/json' \
  -H 'app_id: your_app_id' \
  -H 'ts: 1713168000' \
  -H 'rtx: caller_rtx' \
  -H 'sign: your_sign' \
  -d '{
    "name": "VISVISE_2d_preProcess",
    "input_view": "https://cos.example.com/weaver/user-xxx/input.png",
    "preprocess_type": 2,
    "algorithm_model": "VV-Pre2D-V1.0.0",
    "remove_pattern_param": {
      "result_image": "https://cos.example.com/weaver/user-xxx/pattern-removed.png?q-sign-algorithm=sha1&q-ak=xxx&q-sign-time=1713168000%3B1713254400&q-key-time=1713168000%3B1713254400&q-header-list=host&q-url-param-list=&q-signature=xxx"
    }
  }'
```

**Python SDK 示例：**

```python
from visvise import VisviseClient

client = VisviseClient("your_app_id", "your_secret_key")

model_id = client.gen_patter_auto_remove(
    "input.png",
    rtx="caller_rtx",
)
print(model_id)
```

**Go SDK 示例：**

```go
package main

import (
    "fmt"
    "github.com/tencent-visvise/visvise-sdk-go/visvise"
)

func main() {
    client := visvise.NewClient("your_app_id", "your_secret_key", nil)

    modelID, err := client.GenPatterAutoRemove(
        "input.png",
        "caller_rtx",
        visvise.NewGenPatterAutoRemoveOptions().SetName("VISVISE_2d_preProcess"),
    )
    if err != nil {
        panic(err)
    }
    fmt.Println(modelID)
}
```

**输出参数：**

分两步，最终返回 **1 个** `model_id`（`node_type=16` 的 2D 预处理资产）。

| 步骤 | 参数 | 类型 | 说明 |
|---|---|---|---|
| ① 花纹智能去除 | `result_image` | String | 带临时签名的去花纹结果图片 COS 下载 URL（24h 有效），原样传入②的 `remove_pattern_param.result_image` |
| ② 保存预处理资产 | `model_id` | String | 已创建且生成成功的 2D 预处理资产 ID（`node_type=16`），可作为后续图生模任务的输入 |

---

### 3.4 图生高模

从图片生成高精度 3D 模型（`node_type=3`）。支持输入任意图片，可传入单张主视图，也可同时提供多视图（主/背/左/右）以提升生成质量。

支持 **2 种输入方式**，根据业务场景选用。

> ⚠️ **注意**：图生高模**不支持**单独的 `model_id_360` 和 `segment_model_id` 输入方式，仅支持以下两种方式。

**公共参数：**

| 参数 | 值 / 说明 |
|---|---|
| `name` | 任意名称 |
| `node_type` | `3` |
| `params.image_gen_model_params.algorithm_model` | 算法模型，支持：`Hy3D-3.5-0515` / `Hy3D-3.5-0315`（混元公版）|
| `params.image_gen_model_params.face_type` | 面数类型（1:三角面 2:四边面） |
| `params.image_gen_model_params.face_num` | 面数，取值范围 1000~1500000，不传则自动配置 |
| `params.image_gen_model_params.output_model_format` | 输出格式：`fbx` / `obj` / `glb` |
| `params.image_gen_model_params.enable_pbr` | 是否开启贴图输出，`true`/`false`，默认 `false`。启用后输出模型将使用 PBR 材质类型（metallic-roughness workflow） |

---

#### 方式一：原画输入 View 方式

适用场景：直接传入单张或多张图片生成高模。若已通过 [图生360](#31-图生360) 获取了多视图，可直接将其作为输入。

**额外参数：**

| 参数 | 必选 | 说明 |
|---|---|---|
| `input_view.main_view` | 是 | 主视图图片 URL（任意图片即可） |
| `input_view.back_view` | 否 | 背视图图片 URL |
| `input_view.left_view` | 否 | 左视图图片 URL |
| `input_view.right_view` | 否 | 右视图图片 URL |

**请求示例：**

```bash
curl -X POST 'https://ws.visvise.com.cn/openapi/weaver/resource/gen_3d_model' \
  -H 'Content-Type: application/json' \
  -H 'app_id: your_app_id' \
  -H 'ts: 1713168000' \
  -H 'rtx: caller_rtx' \
  -H 'sign: your_sign' \
  -d '{
    "name": "test_3Dhigh",
    "node_type": 3,
    "input_view": {
        "main_view": "https://cos.example.com/weaver/user-xxx/main_view.png",
        "back_view": "https://cos.example.com/weaver/user-xxx/back_view.png",
        "left_view": "https://cos.example.com/weaver/user-xxx/left_view.png",
        "right_view": "https://cos.example.com/weaver/user-xxx/right_view.png"
    },
    "params": {
        "image_gen_model_params": {
            "algorithm_model": "Hy3D-3.5-0515",
            "face_type": 1,
            "face_num": 1500000,
            "output_model_format": "fbx"
        }
    }
  }'
```

**Python SDK 示例：**

```python
from visvise import VisviseClient, FaceType, OutputModelFormat

client = VisviseClient("your_app_id", "your_secret_key")

# 仅传 main_view 即可生成高模（任意图片）
high_id = client.gen_high_model(
    main_view="character.png",                      # 本地路径或 COS URL，任意图片
    output_model_format=OutputModelFormat.FBX,
    rtx="caller_rtx",
)
model = client.wait_model(high_id, timeout=900, rtx="caller_rtx")
print(model.output_model)
```

> 同时传入四视图（`main_view` / `back_view` / `left_view` / `right_view`）以提升生成质量，四视图可通过 [图生360](#31-图生360) 获取，也可使用自定义图片。

**Go SDK 示例：**

```go
package main

import (
    "fmt"
    "github.com/tencent-visvise/visvise-sdk-go/visvise"
)

func main() {
    client := visvise.NewClient("your_app_id", "your_secret_key", nil)
    rtx := "caller_rtx"

    // 仅传 mainView 即可生成高模（任意图片）
    highID, err := client.GenHighModel("character.png", rtx,
        visvise.NewGenHighModelOptions().
            SetOutputModelFormat(visvise.OutputModelFormatFBX))
    if err != nil { panic(err) }

    model, err := client.WaitModel(highID, rtx, &visvise.WaitOptions{Timeout: 900})
    if err != nil { panic(err) }
    fmt.Println(model.OutputModel)
}
```

> 同时传入四视图（`SetBackView` / `SetLeftView` / `SetRightView`）以提升生成质量，四视图可通过 [图生360](#31-图生360) 获取，也可使用自定义图片。

> 📖 更详细指南请点击：[单图生高模](https://doc.weixin.qq.com/doc/w3_AXYAnAbnANcCNUC4awL5RRbKDFu0O?scode=AJEAIQdfAAoAcg54YdAOoASwZGACk) ｜ [多图生高模](https://doc.weixin.qq.com/doc/w3_AXYAnAbnANcCN1P0RaUETQ1a1ScbO?scode=AJEAIQdfAAo0G90rpLAXYAnAbnANc)

---

#### 方式二：segment_model_id + component_label（单部件生成）

适用场景：通过 [2D 拆分](#32-2d-拆分) 完成部件分割后，对**指定 label 的单个部件**单独生成高精度 3D 模型，不需要传入原画图。

> ⚠️ 图生高模**不支持**仅传 `segment_model_id`（全部部件一起生成），**仅支持** `segment_model_id` + `component_label` 的单部件生成方式。

**额外参数：**

| 参数 | 必选 | 说明 |
|---|---|---|
| `params.image_gen_model_params.segment_model_id` | 是 | 2D 分割资产 ID（node_type=14 的 model_id） |
| `params.image_gen_model_params.component_label` | 是 | 分割结果中目标部件的 label 编号。取值来源：`ModelInfo.segment_output.{view}.components[].label`（详见 [SegmentComponent](#segmentcomponent)） |

**请求示例：**

```bash
curl -X POST 'https://ws.visvise.com.cn/openapi/weaver/resource/gen_3d_model' \
  -H 'Content-Type: application/json' \
  -H 'app_id: your_app_id' \
  -H 'ts: 1713168000' \
  -H 'rtx: caller_rtx' \
  -H 'sign: your_sign' \
  -d '{
    "name": "test_3Dhigh_component",
    "node_type": 3,
    "params": {
        "image_gen_model_params": {
            "algorithm_model": "Hy3D-3.5-0515",
            "face_type": 1,
            "face_num": 1500000,
            "output_model_format": "fbx",
            "segment_model_id": "Model202607xxxxxx",
            "component_label": 1
        }
    }
  }'
```

**输出参数：**

返回 **1 个** `model_id`。产物在 `output_model`。

| 参数 | 类型 | 说明 |
|---|---|---|
| `output_model` | String | 输出模型 zip（格式同请求 `output_model_format`：fbx / obj / glb；`enable_pbr=true` 时含 PBR 贴图） |
| `preview_img` | String | 预览图 URL |

---

### 3.5 图生中模

从多视图生成中精度 3D 模型（node_type=11）。支持 **4 种输入方式**，根据业务场景选用。

**公共参数：**

| 参数 | 值 / 说明 |
|---|---|
| `name` | 任意名称 |
| `node_type` | `11` |
| `params.image_gen_model_params.algorithm_model` | 算法模型 |
| `params.image_gen_model_params.face_type` | 面数类型（1:三角面 2:四边面） |
| `params.image_gen_model_params.face_num` | 面数，取值范围 0~30000，0 使用默认值 |
| `params.image_gen_model_params.output_model_format` | 输出格式：`fbx` / `obj` / `glb` |

---

#### 方式一：原画输入 View 方式


**额外参数：**

| 参数 | 必选 | 说明 |
|---|---|---|
| `input_view.main_view` | 是 | 主视图图片 URL（来自图生 360 输出） |
| `input_view.back_view` | 否 | 背视图图片 URL（来自图生 360 输出） |
| `input_view.left_view` | 否 | 左视图图片 URL（来自图生 360 输出） |
| `input_view.right_view` | 否 | 右视图图片 URL（来自图生 360 输出） |

**请求示例：**

```bash
curl -X POST 'https://ws.visvise.com.cn/openapi/weaver/resource/gen_3d_model' \
  -H 'Content-Type: application/json' \
  -H 'app_id: your_app_id' \
  -H 'ts: 1713168000' \
  -H 'rtx: caller_rtx' \
  -H 'sign: your_sign' \
  -d '{
    "name": "test_3Dmid",
    "node_type": 11,
    "input_view": {
        "main_view": "https://cos.example.com/weaver/user-xxx/main_view.png",
        "back_view": "https://cos.example.com/weaver/user-xxx/back_view.png",
        "left_view": "https://cos.example.com/weaver/user-xxx/left_view.png",
        "right_view": "https://cos.example.com/weaver/user-xxx/right_view.png"
    },
    "params": {
        "image_gen_model_params": {
            "algorithm_model": "VV-MeshGen-V1.5.0",
            "face_type": 1,
            "output_model_format": "fbx"
        }
    }
  }'
```

**Python SDK 示例：**

```python
from visvise import VisviseClient, FaceType, OutputModelFormat

client = VisviseClient("your_app_id", "your_secret_key")

mid_id = client.gen_mid_model(
    main_view="main.png", back_view="back.png",
    left_view="left.png", right_view="right.png",
    output_model_format=OutputModelFormat.FBX,
    face_type=FaceType.TRIANGLE,
    rtx="caller_rtx",
)
model = client.wait_model(mid_id, timeout=900, rtx="caller_rtx")
```

**Go SDK 示例：**

```go
package main

import (
    "github.com/tencent-visvise/visvise-sdk-go/visvise"
)

func main() {
    client := visvise.NewClient("your_app_id", "your_secret_key", nil)
    rtx := "caller_rtx"

    midID, err := client.GenMidModel(
        "main.png", "back.png", "left.png", "right.png", rtx,
        visvise.NewGenMidModelOptions().
            SetOutputModelFormat(visvise.OutputModelFormatFBX).
            SetFaceType(visvise.FaceTypeTriangle))
    if err != nil { panic(err) }

    _, err = client.WaitModel(midID, rtx, &visvise.WaitOptions{Timeout: 900})
    if err != nil { panic(err) }
}
```

---

#### 方式二：model_id_360（直接用前置 360 任务生成）

适用场景：已有完成状态的图生 360 资产，直接传入其 `model_id` 即可，无需再次传入 `input_view`。

**额外参数：**

| 参数 | 必选 | 说明 |
|---|---|---|
| `params.image_gen_model_params.model_id_360` | 是 | 图生 360 资产 ID（node_type=7 的 model_id） |

> ⚠️ 使用此方式时**不要传 `input_view`**，否则会冲突。

**请求示例：**

```bash
curl -X POST 'https://ws.visvise.com.cn/openapi/weaver/resource/gen_3d_model' \
  -H 'Content-Type: application/json' \
  -H 'app_id: your_app_id' \
  -H 'ts: 1713168000' \
  -H 'rtx: caller_rtx' \
  -H 'sign: your_sign' \
  -d '{
    "name": "test_3Dmid_360",
    "node_type": 11,
    "params": {
        "image_gen_model_params": {
            "algorithm_model": "VV-MeshGen-V1.5.0",
            "face_type": 1,
            "output_model_format": "fbx",
            "model_id_360": "Model202607xxxxxx"
        }
    }
  }'
```

---

#### 方式三：segment_model_id（分部件生成）

适用场景：通过 [2D 拆分](#32-2d-拆分) 完成部件分割后，对**全部部件**一起生成 3D 模型，不需要传入原画图。

> 💡 此方式调用时不要传 `input_view`，算法会根据 `segment_model_id` 自动获取分割结果。

**额外参数：**

| 参数 | 必选 | 说明 |
|---|---|---|
| `params.image_gen_model_params.segment_model_id` | 是 | 2D 分割资产 ID（node_type=14 的 model_id） |

**请求示例：**

```bash
curl -X POST 'https://ws.visvise.com.cn/openapi/weaver/resource/gen_3d_model' \
  -H 'Content-Type: application/json' \
  -H 'app_id: your_app_id' \
  -H 'ts: 1713168000' \
  -H 'rtx: caller_rtx' \
  -H 'sign: your_sign' \
  -d '{
    "name": "test_3Dmid_segment",
    "node_type": 11,
    "params": {
        "image_gen_model_params": {
            "algorithm_model": "VV-MeshGen-V1.5.0",
            "face_type": 1,
            "output_model_format": "fbx",
            "segment_model_id": "Model202607xxxxxx"
        }
    }
  }'
```

---

#### 方式四：segment_model_id + component_label（单部件生成）

适用场景：通过 [2D 拆分](#32-2d-拆分) 完成部件分割后，对**指定 label 的单个部件**单独生成 3D 模型，不需要传入原画图。

> 💡 此方式调用时不要传 `input_view`，算法会根据 `segment_model_id` + `component_label` 定位到指定部件生成。

**额外参数：**

| 参数 | 必选 | 说明 |
|---|---|---|
| `params.image_gen_model_params.segment_model_id` | 是 | 2D 分割资产 ID（node_type=14 的 model_id） |
| `params.image_gen_model_params.component_label` | 是 | 分割结果中目标部件的 label 编号。取值来源：`ModelInfo.segment_output.{view}.components[].label`（详见 [SegmentComponent](#segmentcomponent)） |

**请求示例：**

```bash
curl -X POST 'https://ws.visvise.com.cn/openapi/weaver/resource/gen_3d_model' \
  -H 'Content-Type: application/json' \
  -H 'app_id: your_app_id' \
  -H 'ts: 1713168000' \
  -H 'rtx: caller_rtx' \
  -H 'sign: your_sign' \
  -d '{
    "name": "test_3Dmid_component",
    "node_type": 11,
    "params": {
        "image_gen_model_params": {
            "algorithm_model": "VV-MeshGen-V1.5.0",
            "face_type": 1,
            "output_model_format": "fbx",
            "segment_model_id": "Model202607xxxxxx",
            "component_label": 1
        }
    }
  }'
```

**输出参数：**

返回 **1 个** `model_id`。产物在 `output_model`。

| 参数 | 类型 | 说明 |
|---|---|---|
| `output_model` | String | 输出模型 zip（格式同请求 `output_model_format`：fbx / obj / glb；面型同 `face_type`：三角面 / 四边面） |
| `preview_img` | String | 预览图 URL |

---

### 3.6 图生低模（本期暂未开放）

> ⚠️ **该能力本期暂未开放**
>
> 图生低模（`node_type=13`）算法本期暂未开放，平台暂不为新账号授权对应算法模型。调用 SDK 的 `gen_low_model` / `GenLowModel` 接口或直接发起 `node_type=13` 任务会返回 `120018 用户无权限` 或 `no available algorithm model for node_type=13`。如有低面数模型需求，请改用 [图生高模](#34-图生高模) 或 [图生中模](#35-图生中模) + [LOD](#39-lod) 减面流程替代。
>
> 以下章节内容仅作为接口形式留档参考。

从多视图生成低精度 3D 模型（`node_type=13`）。

**调用参数：**

| 参数 | 值 / 说明 |
|---|---|
| `name` | 模型资产名称，示例： `VISVISE_3Dlow` |
| `node_type` | 固定值 `13` |
| `input_view` | `main_view` 必传，`back_view`、`left_view`、`right_view` 可选 |
| `params.image_gen_model_params.algorithm_model` | 算法模型 |
| `params.image_gen_model_params.face_type` | 拓扑类型，1 三角面 / 2 四边面 |
| `params.image_gen_model_params.output_model_format` | 模型格式，支持`fbx` / `obj` / `glb` |

**请求示例：**

```bash
curl -X POST 'https://ws.visvise.com.cn/openapi/weaver/resource/gen_3d_model' \
  -H 'Content-Type: application/json' \
  -H 'app_id: your_app_id' \
  -H 'ts: 1713168000' \
  -H 'rtx: caller_rtx' \
  -H 'sign: your_sign' \
  -d '{
    "name": "VISVISE_3Dlow",
    "node_type": 13,
    "input_view": {
        "main_view": "https://cos.example.com/weaver/user-xxx/main_view.png"
    },
    "params": {
        "image_gen_model_params": {
            "algorithm_model": "Tripo-v1.0-快速生成",
            "face_type": 1,
            "output_model_format": "fbx"
        }
    }
  }'
```

**Python SDK 示例：**

```python
from visvise import VisviseClient, FaceType, OutputModelFormat

client = VisviseClient("your_app_id", "your_secret_key")

low_id = client.gen_low_model(
    main_view="main.png",
    output_model_format=OutputModelFormat.FBX,
    face_type=FaceType.TRIANGLE,
    rtx="caller_rtx",
)
model = client.wait_model(low_id, timeout=600, rtx="caller_rtx")
```

**Go SDK 示例：**

```go
package main

import (
    "github.com/tencent-visvise/visvise-sdk-go/visvise"
)

func main() {
    client := visvise.NewClient("your_app_id", "your_secret_key", nil)
    rtx := "caller_rtx"

    lowID, err := client.GenLowModel("main.png", rtx,
        visvise.NewGenLowModelOptions().
            SetOutputModelFormat(visvise.OutputModelFormatFBX).
            SetFaceType(visvise.FaceTypeTriangle))
    if err != nil { panic(err) }

    _, err = client.WaitModel(lowID, rtx, &visvise.WaitOptions{Timeout: 600})
    if err != nil { panic(err) }
}
```

**输出参数（留档参考）：** 若开放，返回 **1 个** `model_id`，产物在 `output_model`（模型 zip）。本期暂未开放，调用返回 `120018 用户无权限`，暂无输出。

---

### 3.7 布线重建

对模型进行网格布线重建（`node_type=10`）。

**调用参数：**

| 参数 | 值 / 说明 |
|---|---|
| `name` | 模型资产名称，示例： `VISVISE_MR` |
| `node_type` | 固定值 `10` |
| `input_model` | 模型文件 COS URL（zip 文件） |
| `params.mesh_refine_params.algorithm_model` | 算法模型，示例： `VV-MeshRefine-V1.0.0` |
| `params.mesh_refine_params.mode` | 处理模式：1 布线优化 / 2 布线加密，默认 1 布线优化 |

**请求示例：**

```bash
curl -X POST 'https://ws.visvise.com.cn/openapi/weaver/resource/gen_3d_model' \
  -H 'Content-Type: application/json' \
  -H 'app_id: your_app_id' \
  -H 'ts: 1713168000' \
  -H 'rtx: caller_rtx' \
  -H 'sign: your_sign' \
  -d '{
    "name": "VISVISE_MR",
    "node_type": 10,
    "input_model": "https://cos.example.com/weaver/user-xxx/model.zip",
    "params": {
        "mesh_refine_params": {
            "algorithm_model": "VV-MeshRefine-V1.0.0",
            "mode": 1
        }
    }
  }'
```

**Python SDK 示例：**

```python
from visvise import VisviseClient, MeshRefineMode

client = VisviseClient("your_app_id", "your_secret_key")

mr_id = client.gen_mesh_refine(
    model_path="model.fbx",                          # 本地裸模型 SDK 自动打包
    mode=MeshRefineMode.OPTIMIZE,                    # 可选，1 优化 / 2 加密
    rtx="caller_rtx",
)
model = client.wait_model(mr_id, timeout=900, rtx="caller_rtx")
```

**Go SDK 示例：**

```go
package main

import (
    "github.com/tencent-visvise/visvise-sdk-go/visvise"
)

func main() {
    client := visvise.NewClient("your_app_id", "your_secret_key", nil)
    rtx := "caller_rtx"

    mrID, err := client.GenMeshRefine("model.fbx", rtx,
        visvise.NewGenMeshRefineOptions().
            SetMode(visvise.MeshRefineModeOptimize)) // 可选：1 优化 / 2 加密
    if err != nil { panic(err) }

    _, err = client.WaitModel(mrID, rtx, &visvise.WaitOptions{Timeout: 900})
    if err != nil { panic(err) }
}
```

**输出参数：** 产物随 `mesh_refine_params.mode` 不同而不同。

| mode | 说明 | 返回模型数量 | 产物字段 |
|---|---|---|---|
| `1` | 布线重建（优化） | **1 个** | `output_model`（zip） |
| `2` | 布线加密 | **2 个** | `model_ids` 长度为 2，需**遍历两个 `model_id` 分别轮询**，各自产物在各自的 `output_model` |

> ⚠️ **注意**：布线加密（mode=2）与布线重建（mode=1）返回数量不同——加密会返回 **2 个输出模型**，客户端需遍历 `model_ids` 全部取回，不能只取 `model_ids[0]`。

---

### 3.8 重拓扑

对高面数模型进行拓扑优化（`node_type=1`）。

> 💡 三个模型的关键输入参数不同：`VV-RTP-V1.5.0`需传 `face_num`；`Hy3D-RTP-v1.5` 需传 `detail_level`；`Hy3D-RTP-v2.0` 的 `face_num` 可选（不传自动匹配面数）。

**调用参数：**

| 参数 | 值 / 说明 |
|---|---|
| `name` | 模型资产名称，示例： `VISVISE_RTP` |
| `node_type` | 固定值 `1` |
| `input_model` | 模型文件 COS URL（zip 文件） |
| `params.re_topology_params.algorithm_model` | 算法模型，支持：`VV-RTP-V1.5.0` / `Hy3D-RTP-v1.5` / `Hy3D-RTP-v2.0` |
| `params.re_topology_params.output_model_format` | 模型格式，支持`fbx` / `obj` |
| `params.re_topology_params.face_type` | 拓扑类型，1 三角面 / 2 四边面 |
| `params.re_topology_params.detail_level` | 可选，精细程度，1 低 / 2 中 / 3 高，若是「混元 1.5 模型」，则必传 |
| `params.re_topology_params.face_num` | 可选，指定面数，VISVISE 自研模型必传；混元 2.0 模型可选，不传则自动匹配面数 |

**请求示例：**

```bash
curl -X POST 'https://ws.visvise.com.cn/openapi/weaver/resource/gen_3d_model' \
  -H 'Content-Type: application/json' \
  -H 'app_id: your_app_id' \
  -H 'ts: 1713168000' \
  -H 'rtx: caller_rtx' \
  -H 'sign: your_sign' \
  -d '{
    "name": "VISVISE_RTP",
    "node_type": 1,
    "input_model": "https://cos.example.com/weaver/user-xxx/model.zip",
    "params": {
        "re_topology_params": {
            "face_type": 2,
            "output_model_format": "fbx",
            "algorithm_model": "Hy3D-RTP-v1.5",
            "detail_level": 3
        }
    }
  }'
```

**Python SDK 示例：**

```python
from visvise import VisviseClient, FaceType, DetailLevel, OutputModelFormat

client = VisviseClient("your_app_id", "your_secret_key")

rtp_id = client.gen_retopology(
    model_path="model.fbx",
    output_model_format=OutputModelFormat.FBX,
    face_type=FaceType.QUAD,
    detail_level=DetailLevel.HIGH,                   # 混元 1.5 模型用 detail_level
    face_num=10000,                                # VISVISE 自研模型用 face_num；混元 2.0 可选
    rtx="caller_rtx",
)
model = client.wait_model(rtp_id, timeout=900, rtx="caller_rtx")
```

**Go SDK 示例：**

```go
package main

import (
    "github.com/tencent-visvise/visvise-sdk-go/visvise"
)

func main() {
    client := visvise.NewClient("your_app_id", "your_secret_key", nil)
    rtx := "caller_rtx"

    rtpID, err := client.GenRetopology("model.fbx", rtx,
        visvise.NewGenRetopologyOptions().
            SetOutputModelFormat(visvise.OutputModelFormatFBX).
            SetFaceType(visvise.FaceTypeQuad).
            SetDetailLevel(visvise.DetailLevelHigh)) // 混元 1.5 模型用 detail_level
            .SetFaceNum(10000) // VISVISE 自研模型用 face_num；混元 2.0 可选
    if err != nil { panic(err) }

    _, err = client.WaitModel(rtpID, rtx, &visvise.WaitOptions{Timeout: 900})
    if err != nil { panic(err) }
}
```

**输出参数：** 返回 **1 个** `model_id`。产物在 `output_model`。

| 参数 | 类型 | 说明 |
|---|---|---|
| `output_model` | String | 输出模型 zip（格式同请求 `output_model_format`：fbx / obj；面型同 `face_type`） |
| `preview_img` | String | 预览图 URL |

---

### 3.9 LOD

生成多级细节（LOD）模型（`node_type=2`），支持配置多个减面等级。

**调用参数：**

| 参数 | 值 / 说明 |
|---|---|
| `name` | 模型资产名称，示例： `VISVISE_LOD` |
| `node_type` | 固定值 `2` |
| `input_model` | 模型文件 COS URL（zip 文件） |
| `params.lod_params.algorithm_model` | 算法模型，示例： `VV-LOD-V1.0.0` |
| `params.lod_params.output_model_format` | 模型格式，支持 `fbx` / `obj` |
| `params.lod_params.reduce_faces` | 减面配置数组，参考 [ReduceFace](#reduceface) |
| `params.lod_params.gen_times` | 生成次数，用于抽卡选择。不需要抽卡传 `1`，建议传 `3` |

**请求示例：**

```bash
curl -X POST 'https://ws.visvise.com.cn/openapi/weaver/resource/gen_3d_model' \
  -H 'Content-Type: application/json' \
  -H 'app_id: your_app_id' \
  -H 'ts: 1713168000' \
  -H 'rtx: caller_rtx' \
  -H 'sign: your_sign' \
  -d '{
    "name": "VISVISE_LOD",
    "node_type": 2,
    "input_model": "https://cos.example.com/weaver/user-xxx/model.zip",
    "params": {
        "lod_params": {
            "reduce_faces": [
                { "reduce_level": 1, "reduce_percent": 55, "face_type": 2 },
                { "reduce_level": 2, "reduce_percent": 45, "face_type": 2 },
                { "reduce_level": 3, "reduce_percent": 35, "face_type": 2 }
            ],
            "output_model_format": "fbx",
            "algorithm_model": "VV-LOD-V1.0.0",
            "gen_times": 3
        }
    }
  }'
```

**Python SDK 示例：**

```python
from visvise import VisviseClient, ReduceFace, FaceType, OutputModelFormat

client = VisviseClient("your_app_id", "your_secret_key")

lod_ids = client.gen_lod(
    model_path="model.fbx",
    reduce_faces=[
        ReduceFace(reduce_level=1, reduce_percent=55, face_type=FaceType.QUAD),
        ReduceFace(reduce_level=2, reduce_percent=45, face_type=FaceType.QUAD),
        ReduceFace(reduce_level=3, reduce_percent=35, face_type=FaceType.QUAD),
    ],
    output_model_format=OutputModelFormat.FBX,
    gen_times=3,                                     # 抽卡 3 次，不需要抽卡传 1,
    rtx="caller_rtx",
)
for mid in lod_ids:
    model = client.wait_model(mid, timeout=600, rtx="caller_rtx")
```

**Go SDK 示例：**

```go
package main

import (
    "github.com/tencent-visvise/visvise-sdk-go/visvise"
)

func main() {
    client := visvise.NewClient("your_app_id", "your_secret_key", nil)
    rtx := "caller_rtx"

    reduceFaces := []visvise.ReduceFace{
        {ReduceLevel: 1, ReducePercent: 55, FaceType: visvise.FaceTypeQuad, ProjectType: "lod_usr_full"},
        {ReduceLevel: 2, ReducePercent: 45, FaceType: visvise.FaceTypeQuad, ProjectType: "lod_usr_full"},
        {ReduceLevel: 3, ReducePercent: 35, FaceType: visvise.FaceTypeQuad, ProjectType: "lod_usr_fast_full"},
    }

    lodIDs, err := client.GenLOD("model.fbx", reduceFaces, rtx,
        visvise.NewGenLODOptions().
            SetOutputModelFormat(visvise.OutputModelFormatFBX).
            SetGenTimes(3)) // 抽卡 3 次，不需要抽卡传 1
    if err != nil { panic(err) }

    for _, mid := range lodIDs {
        _, err = client.WaitModel(mid, rtx, &visvise.WaitOptions{Timeout: 600})
        if err != nil { panic(err) }
    }
}
```

**输出参数：** 返回 **N 个** `model_id`（N = 减面档数，即 `reduce_faces` 数组长度），需**逐个轮询**。产物在 `lod_output`（详见 [LODOutput](#lodoutput)）。

| 参数 | 类型 | 说明 |
|---|---|---|
| `lod_output.lod_files` | Array of [LODFile](#lodfile) | 各减面档位输出文件列表 |
| `lod_output.zip_file` | String | 全部档位整包 zip 地址 |
| `lod_output.del_times` | Integer | 模型抽卡删除次数 |
| `lod_output.del_card_indexs` | Array of Unsigned Integer | 已删除的抽卡索引记录 |

> 抽卡：每档含 `gen_times` 个候选。客户端须遍历 `model_ids` 逐个轮询；单个抽卡产物在 `lod_output.lod_files[]`，整体打包用 `zip_file`。

---

### 3.10 UV

对模型进行自动 UV 展开（`node_type=9`）。

**调用参数：**

| 参数 | 值 / 说明 |
|---|---|
| `name` | 模型资产名称，示例： `VISVISE_UV` |
| `node_type` | 固定值 `9` |
| `input_model` | 模型文件 COS URL（zip 文件） |
| `params.uv_params.algorithm_model` | 算法模型，支持：`Hy3D-UV-v2.0` / `Hy3D-UV-v3.0`；自研 UV 模型为 `VV-UV-v2.6.0` |
| `params.uv_params.enable_auto_smoothing` | 可选，启用自动平滑（Bool），默认为 `false` |
| `params.uv_params.lightmap_resolution` | 可选，纹理分辨率（像素），16~2048，未传默认 `1024`。仅自研 UV 模型 `VV-UV-v2.6.0` 生效 |
| `params.uv_params.uv_island_padding` | 可选，UV 岛边沿像素数，1~16，未传默认 `1`。仅自研 UV 模型 `VV-UV-v2.6.0` 生效 |
| `params.uv_params.pack_into_same_uv_space` | 可选，多 mesh 是否 pack 到同一 UV 空间，未传默认 `false`。仅自研 UV 模型 `VV-UV-v2.6.0` 生效 |

**请求示例：**

```bash
curl -X POST 'https://ws.visvise.com.cn/openapi/weaver/resource/gen_3d_model' \
  -H 'Content-Type: application/json' \
  -H 'app_id: your_app_id' \
  -H 'ts: 1713168000' \
  -H 'rtx: caller_rtx' \
  -H 'sign: your_sign' \
  -d '{
    "name": "VISVISE_UV",
    "node_type": 9,
    "input_model": "https://cos.example.com/weaver/user-xxx/model.zip",
    "params": {
        "uv_params": {
            "algorithm_model": "Hy3D-UV-v3.0",
            "enable_auto_smoothing": true
        }
    }
  }'
```

**Python SDK 示例：**

```python
from visvise import VisviseClient

client = VisviseClient("your_app_id", "your_secret_key")

uv_id = client.gen_uv(
    model_path="model.fbx",
    enable_auto_smoothing=True,
    rtx="caller_rtx",
)
model = client.wait_model(uv_id, timeout=600, rtx="caller_rtx")
```

**Go SDK 示例：**

```go
package main

import (
    "github.com/tencent-visvise/visvise-sdk-go/visvise"
)

func main() {
    client := visvise.NewClient("your_app_id", "your_secret_key", nil)
    rtx := "caller_rtx"

    uvID, err := client.GenUV("model.fbx", rtx,
        visvise.NewGenUVOptions().
            SetEnableAutoSmoothing(true))
    if err != nil { panic(err) }

    _, err = client.WaitModel(uvID, rtx, &visvise.WaitOptions{Timeout: 600})
    if err != nil { panic(err) }
}
```

**输出参数：** 返回 **1 个** `model_id`。产物在 `output_model`。

| 参数 | 类型 | 说明 |
|---|---|---|
| `output_model` | String | 输出模型 zip（与输入模型几何一致，新增/重排了 UV 展开信息，UV 写回模型后打包返回） |
| `preview_img` | String | 预览图 URL |

---

### 3.11 贴图纹理

为 3D 模型生成贴图纹理（`node_type=8`）。

> 💡 `input_view.main_view`（原画图片）和 `params.tex_params.prompt`（提示词）**必须传其中一个**，可同时传入。
>
> 💡 模型与输入对应关系：图生模型 `Hy3D-TEX-v3.5-preview` 使用 `input_view.main_view`；文生模型 `Hy3D-TEX-v2.0` 使用 `params.tex_params.prompt`。

**调用参数：**

| 参数 | 值 / 说明 |
|---|---|
| `name` | 模型资产名称，示例： `VISVISE_Texture` |
| `node_type` | 固定值 `8` |
| `input_model` | 模型文件 COS URL（zip 文件） |
| `input_view.main_view` | 原画主视图 COS URL（与 `prompt` 二选一或同时传） |
| `input_view.back_view` | 可选，背视图 |
| `input_view.left_view` | 可选，左视图 |
| `input_view.right_view` | 可选，右视图 |
| `params.tex_params.algorithm_model` | 算法模型，支持：`Hy3D-TEX-v3.5-preview`（图生）/ `Hy3D-TEX-v2.0`（文生） |
| `params.tex_params.prompt` | 文本贴图提示词（与 `input_view.main_view` 二选一或同时传） |
| `params.tex_params.unwarp_uv` | 可选，保持模型原始 UV（Bool），默认为 `false` |

**请求示例：**

```bash
curl -X POST 'https://ws.visvise.com.cn/openapi/weaver/resource/gen_3d_model' \
  -H 'Content-Type: application/json' \
  -H 'app_id: your_app_id' \
  -H 'ts: 1713168000' \
  -H 'rtx: caller_rtx' \
  -H 'sign: your_sign' \
  -d '{
    "name": "VISVISE_Texture",
    "node_type": 8,
    "input_model": "https://cos.example.com/weaver/user-xxx/model.zip",
    "input_view": {
        "main_view": "https://cos.example.com/weaver/user-xxx/reference.png",
        "back_view": "https://cos.example.com/weaver/user-xxx/reference_back.png"
    },
    "params": {
        "tex_params": {
            "algorithm_model": "Hy3D-TEX-v3.5-preview",
            "resolution": 2048,
            "unwarp_uv": false
        }
    }
  }'
```

**Python SDK 示例：**

```python
from visvise import VisviseClient, View

client = VisviseClient("your_app_id", "your_secret_key")

tex_id = client.gen_texture(
    model_path="model.fbx",
    input_view=View(
        main_view="reference.png",
        back_view="reference_back.png",
    ),
    resolution=2048,
    unwarp_uv=False,
    # prompt="写实风格",                               # 可选，与 input_view.main_view 二选一,
    rtx="caller_rtx",
)
model = client.wait_model(tex_id, timeout=900, rtx="caller_rtx")
```

**Go SDK 示例：**

```go
package main

import (
    "github.com/tencent-visvise/visvise-sdk-go/visvise"
)

func main() {
    client := visvise.NewClient("your_app_id", "your_secret_key", nil)
    rtx := "caller_rtx"

    texID, err := client.GenTexture("model.fbx", rtx,
        visvise.NewGenTextureOptions().
            SetInputView(&visvise.View{
                MainView: "reference.png",
                BackView: "reference_back.png",
            }).
            SetResolution(2048).
            SetUnwarpUV(false))
            // .SetPrompt("写实风格") // 可选，与 InputView.MainView 二选一
    if err != nil { panic(err) }

    _, err = client.WaitModel(texID, rtx, &visvise.WaitOptions{Timeout: 900})
    if err != nil { panic(err) }
}
```

**输出参数：** 返回 **1 个** `model_id`。产物在 `output_model`。

| 参数 | 类型 | 说明 |
|---|---|---|
| `output_model` | String | 输出模型 zip（带生成贴图 / 纹理的模型） |
| `preview_img` | String | 预览图 URL |

---

### 3.12 2UV

为模型生成第二套 UV（光照贴图 UV），用于烘焙光照贴图（`node_type=15`）。2UV 会为模型中的每个 mesh 分别生成，生成进度可通过 [获取模型资产列表](#26-获取模型资产列表) 返回的 `progress.auto_luv` 字段查看各 mesh 的生成状态。

> ⚠️ **输入模型限制**：
> - 输入模型需包含合法的 mesh 数据，mesh 名称需与 `auto_luv_params.mesh_name` 精确匹配。
> - 仅支持 **FBX** 格式文件（`940516`）。
> - 模型需包含**法线信息**（`940107`）和**有效 1UV**（`940109`）。
> - 顶点数需在 **50 万以下**（`940517`），超过则需先重拓扑。
> - 1UV 不能命名为 `"lightmap"`（`940125`），也不能只包含 `"lightmap"` 通道（`940126`）。
> - AutoLUV 输出产物不可二次处理，可能导致 FBX 写回失败（`940514`），请使用原始模型文件。

**调用参数：**

| 参数 | 值 / 说明 |
|---|---|
| `name` | 模型资产名称，示例： `VISVISE_2UV` |
| `node_type` | 固定值 `15` |
| `input_model` | 模型文件 COS URL（zip 格式） |
| `params.auto_luv_params.algorithm_model` | 算法模型，示例：`VV-AutoLUV-V2.6.0` |
| `params.auto_luv_params.mesh_name` | 需要生成 2UV 的 mesh 名称 |
| `params.auto_luv_params.light_map_resolution` | 光照纹理分辨率，取值范围 16~2048 |
| `params.auto_luv_params.edge_pixel_count` | 边沿像素数，取值范围 0.5~16 |
| `params.auto_luv_params.coord_axis` | 坐标系方向：1 Y 轴朝上 / 2 Z 轴朝上 |
| `params.auto_luv_params.out_channel` | 输出通道（1~4） |
| `params.auto_luv_params.split_strategy` | 切割策略：1 消极切割 / 2 均衡切割 / 3 积极切割 |

**请求示例：**

```bash
curl -X POST 'https://ws.visvise.com.cn/openapi/weaver/resource/gen_3d_model' \
  -H 'Content-Type: application/json' \
  -H 'app_id: your_app_id' \
  -H 'ts: 1713168000' \
  -H 'rtx: caller_rtx' \
  -H 'sign: your_sign' \
  -d '{
    "name": "VISVISE_2UV",
    "node_type": 15,
    "input_model": "https://cos.example.com/weaver/user-xxx/model.zip",
    "params": {
        "auto_luv_params": {
            "algorithm_model": "VV-AutoLUV-V2.6.0",
            "mesh_name": "Body_Mesh",
            "light_map_resolution": 1024,
            "edge_pixel_count": 2.0,
            "coord_axis": 1,
            "out_channel": 1,
            "split_strategy": 2
        }
    }
  }'
```

**输出参数：** 返回 **1 个** `model_id`。与其他节点不同，2UV 按 mesh 追踪进度与结果，通过 `progress.auto_luv` 查看（详见下方「进度查看」）；最终模型（含第二套 UV）在 `output_model`。

| 参数 | 类型 | 说明 |
|---|---|---|
| `output_model` | String | 输出模型 zip（含第二套 UV） |
| `progress.auto_luv` | [AutoLuvProgress](#autoluvprogress) | 各 mesh 的 2UV 生成进度（`redo_current_index` + `list`） |

**进度查看：** 通过 [获取模型资产列表](#26-获取模型资产列表) 轮询时，可从返回的 `progress.auto_luv.list` 数组中查看各 mesh 的 2UV 生成状态：

```bash
curl -X POST 'https://ws.visvise.com.cn/openapi/weaver/resource/get_model_list' \
  -H 'Content-Type: application/json' \
  -H 'app_id: your_app_id' \
  -H 'ts: 1713168000' \
  -H 'rtx: caller_rtx' \
  -H 'sign: your_sign' \
  -d '{
    "model_id_list": ["Model202606xxxxxx"]
  }'
```

响应中 `progress` 字段示例：

```json
{
    "progress": {
        "redo_count": 0,
        "auto_luv": {
            "redo_current_index": 0,
            "list": [
                {
                    "mesh_name": "Body_Mesh",
                    "status": 3,
                    "failed_reason": null,
                    "auto_luv_params": {
                        "algorithm_model": "VV-AutoLUV-V2.6.0",
                        "mesh_name": "Body_Mesh"
                    }
                },
                {
                    "mesh_name": "Hair_Mesh",
                    "status": 2,
                    "failed_reason": null,
                    "auto_luv_params": {
                        "algorithm_model": "VV-AutoLUV-V2.6.0",
                        "mesh_name": "Hair_Mesh"
                    }
                }
            ]
        }
    }
}
```

> 💡 如果对某个 mesh 的 2UV 结果不满意，可使用 [重新生成模型](#221-重新生成模型) 接口单独重新生成该 mesh 的 2UV。

---

### 3.13 混元 3D API 区域

#### 简介

考虑到部分项目组已通过混元 3D（hy3D）API 完成模型生成能力的接入，为降低二次切换带来的迁移与重复开发成本，本区域专门提供基于混元 API 的标准接入方式，便于项目组快速复用既有能力，无需重复对接。

#### 文档提供

下表按功能特性与版本号维护对应 API 文档，项目组可结合实际业务需求按需取用：

| 功能点 | 版本号 | 对应API说明 |
|---|---|---|
| 单图生3D高模 | 单图生几何3.5版 | [文档链接](https://doc.weixin.qq.com/doc/w3_AXYAnAbnANcCNUC4awL5RRbKDFu0O?scode=AJEAIQdfAAoS3ZT356AXYAnAbnANc) |
| 多视图生3D高模 | 多图生几何3.5版 | [文档链接](https://doc.weixin.qq.com/doc/w3_AXYAnAbnANcCNJs5rYGfCR0a3Bm2N?scode=AJEAIQdfAAocd5OPjgAXYAnAbnANc) |
| 组件拆分 | 组件拆分2.0版 | [文档链接](https://doc.weixin.qq.com/doc/w3_AXYAnAbnANcCN6I0XcFVhQvSg64yc?scode=AJEAIQdfAAoXZegQbCAXYAnAbnANc) |
| 低模拓扑 | 低模拓扑2.0版 | [文档链接](https://doc.weixin.qq.com/doc/w3_AXYAnAbnANcCNX8SRr9siRPaJy561?scode=AJEAIQdfAAoOwvYrc7AXYAnAbnANc) |
| UV展开 | UV生成2.0版 | [文档链接](https://doc.weixin.qq.com/doc/w3_AXYAnAbnANcCNnfVOqItCRWeC1Sus?scode=AJEAIQdfAAoRj140AEAXYAnAbnANc) |
| 单图纹理生成 | 单图生纹理3.5版 | [文档链接](https://doc.weixin.qq.com/doc/w3_AXYAnAbnANcCNNDJsTJA8Q3ij3Won?scode=AJEAIQdfAAohwEkyoGAXYAnAbnANc) |
| 多视图纹理生成 | 多图生纹理3.5版 | [文档链接](https://doc.weixin.qq.com/doc/w3_AXYAnAbnANcCNXnG2c1DLQV6S59UE?scode=AJEAIQdfAAorn78jl0AXYAnAbnANc) |
| 文生贴图 | 文生纹理3.5版 | [文档链接](https://doc.weixin.qq.com/doc/w3_AEYAgwbdAFwCNPbzVqH7dTOCJka53?scode=AJEAIQdfAAoWzFwR6eAXYAnAbnANc) |

> **说明：** 以上为当前已开放的混元 API 能力，后续将随版本迭代持续补充与更新。

---

## 4. 动画生成 Demo

本章节详细介绍如何使用 Weaver API 完成动画生成相关的完整流程，包括骨骼架设、蒙皮绑定、动画生成和 Pose 生成。

### 4.1 整体流程

动画生成的完整流水线如下：

![动画生成流程图](https://visvise-weaver-bj-rel-1311802504.cos.ap-beijing.myqcloud.com/weaver/public/%E5%8A%A8%E7%94%BB%E6%B5%81%E7%A8%8B%E5%9B%BE.png)

> 动画生成支持两种模式：**视频生动画**（传入视频）和**文本生动画**（传入提示词）。

**核心接口：** 骨骼架设、蒙皮生成、3D动画生成，均通过 [生成3D模型资产](#24-生成3d模型资产) 接口创建，通过 `node_type` 区分任务类型。任务为异步执行，需通过 [获取模型资产列表](#26-获取模型资产列表) 轮询 [ModelInfo](#modelinfo) 的 `status=3`（成功）或 `status=4`（失败）。

---

### 4.2 智能骨骼架设

为输入的 3D 模型自动生成骨骼结构。

**调用参数：**

| 参数 | 值 / 说明 |
|---|---|
| `name` | 模型资产名称，示例： `VISVISE_Rigging` |
| `node_type` | 固定值 `5` |
| `input_model` | 模型文件 COS URL（zip 文件） |
| `params.go_rigging_params` | [GoRiggingParams](#goriggingparams) 结构，包含算法模型与可选模板骨骼 |

**GoRiggingParams 字段：**

| 字段 | 必选 | 说明 |
|---|---|---|
| `algorithm_model` | 是 | 算法模型 |
| `template_skeleton` | 否 | 模板骨骼 COS 地址，传入后将基于该模板进行架设 |

**输入模型 zip 包要求：**

zip 包内需包含两个同名文件：一个模型文件（如 `.fbx`）和一个 `.json` 参数文件，JSON 中需要配置 `mesh_category` 字段指定模型类别。

zip 包结构示例：

```
model.zip
├── model.fbx          # 模型文件
└── model.json         # 参数文件
```

JSON 参数文件示例：

```json
{

  "selection": {
    "mesh_names": [
      "pCube1",
      "pCube2"
    ]
  },
  "config": {
    "mesh_category": "humanoid",
    "algo_name": "MotusAI-Rigging-V2.0",
    "generate_root": false,
    "temperature": -1,
    "num_beams": 10,
    "algo_scenario" :1
  }
}
```

| 字段 | 必选 | 说明                                   |
|---|---|--------------------------------------|
| `selection.mesh_names` | 否 | 需要骨骼架设的网格名称列表                        |
| `config.mesh_category` | 是 | 模型类别，可选值见下表                          |
| `config.algo_name` | 是 | 算法模型                                 |
| `config.generate_root` | 否  | 是否生成root骨骼                           |
| `config.temperature` | 否  | 高级采用-自由度 取值范围(0~1)                   |
| `config.num_beams` | 否  | 高级采用-搜索广度  取值范围(5~15)                |
| `config.algo_scenario` | 否  | 生成方式 , `mesh_category`=`humanoid`时设置 |

`mesh_category` 可选值：

| 值          | 说明   |
|------------|------|
| `humanoid` | 人形角色 |
| `tetrapod` | 四足动物 |
| `other`    | 其他   |


`algo_scenario` 可选值：

| 值   | 说明                                                |
|-----|---------------------------------------------------|
| `1` | 一键自动(默认)                                          |
| `2` | 模板骨骼适配, 设置该参数 GoRiggingParams.template_skeleton必填 |
| `3` | 附加骨骼生成                                            |

> 📎 示例文件下载：[rigging_demo.zip](https://visvise-weaver-bj-rel-1311802504.cos.ap-beijing.myqcloud.com/weaver/public/rigging_demo.zip)

**请求示例：**

```bash
curl -X POST 'https://ws.visvise.com.cn/openapi/weaver/resource/gen_3d_model' \
  -H 'Content-Type: application/json' \
  -H 'app_id: your_app_id' \
  -H 'rtx: caller_rtx' \
  -H 'ts: 1713168000' \
  -H 'sign: your_sign' \
  -d '{
    "name": "VISVISE_Rigging",
    "node_type": 5,
    "input_model": "https://visvise-weaver-bj-dev-1311802504.cos.accelerate.myqcloud.com/weaver/user-xxx/20260415/model.zip",
    "params": {
      "go_rigging_params": {
        "algorithm_model": "MotusAI-Rigging-V2.0"
      }
    }
  }'
```

> 如果需要使用模板骨骼，在 `go_rigging_params` 中追加 `"template_skeleton": "https://...cos...myqcloud.com/path/to/template.zip"`。

**Python SDK 示例：**

```python
from visvise import VisviseClient

client = VisviseClient("your_app_id", "your_secret_key")

# SDK 自动将裸模型 + JSON 参数打包成 zip 上传
rig_id = client.gen_rigging(
    model_path="path/to/model.fbx",                # 必填，裸模型文件即可，SDK 自动打包
    algorithm_model=None,                          # 可选，如 "MotusAI-Rigging-V2.0"
    mesh_category="humanoid",                      # 可选，"humanoid"（人形，默认）或 "tetrapod"（四足）
    name="gen_rigging",                            # 可选，任务名称
    template_skeleton=None,                        # 可选，模板骨骼，传入后将基于该模板进行架设
    mesh_names=None,                               # 可选，需要骨骼架设的网格名称列表
    generate_root=False,                           # 可选，是否生成 root 骨骼（默认 False）
    temperature=-1,                                # 可选，高级采样-自由度，取值范围 0~1（默认 -1）
    num_beams=-1,                                  # 可选，高级采样-搜索广度，取值范围 5~15（默认 -1）
    algo_scenario=None,                            # 可选，生成方式（仅 mesh_category=humanoid 时有效）：
                                                   #   1 = 默认一键自动生成
                                                   #   2 = 人形角色+上传模版（需同时传 template_skeleton）
                                                   #   3 = 主体骨骼人形角色生成附加骨骼
    rtx="caller_rtx",
)
rig = client.wait_model(rig_id, timeout=600, rtx="caller_rtx")
print("骨骼模型：", rig.output_model)
```

**Go SDK 示例：**

```go
package main

import (
    "fmt"
    "github.com/tencent-visvise/visvise-sdk-go/visvise"
)

func main() {
    client := visvise.NewClient("your_app_id", "your_secret_key", nil)
    rtx := "caller_rtx"

  opts := visvise.NewGenRiggingOptions().
    SetName("my_rigging").                                         // 可选，默认 "gen_rigging"
    SetMeshCategory(visvise.MeshCategoryHumanoid).                 // 可选，人形（默认）或 visvise.MeshCategoryTetrapod（四足）或 visvise.MeshCategoryOther(其他)
    SetAlgoScenario(visvise.RiggingAlgoScenarioTemplateSkeleton). // 可选，生成方式 1=一键自动(默认)，2 =人形+模版，3=附加骨骼
    SetGenerateRoot(false).                                       // 可选，是否生成 Root 骨骼
    SetTemperature(-1).                                           // 可选，高级采样-自由度 与 num_beams 不同时使用。 取值范围：(0~1)
    SetNumBeams(10).                                              // 可选，高级采样-搜索广度 与 temperature 不同时使用。取值范围：(5-15) 
    SetMeshNames([]string{"pCube1", "pCube2"}).                   // 可选，mesh_names，内容可为空
    SetTemplateSkeleton("skeleton.fbx")                           // 可选，模板骨骼（algo_scenario=2 时需要）
    // SDK 自动将裸模型 + JSON 参数打包成 zip 上传
    rigID, err := client.GenRigging("character.fbx", rtx, opts)
           
    if err != nil { panic(err) }

    rig, err := client.WaitModel(rigID, rtx, &visvise.WaitOptions{Timeout: 600})
    if err != nil { panic(err) }
    fmt.Println("骨骼模型：", rig.OutputModel)
}
```

**完成标识：** 轮询 [获取模型资产列表](#26-获取模型资产列表)，当 [ModelInfo](#modelinfo) 的 `status=3` 时，从 `output_model` 获取带骨骼的模型。

---

### 4.3 智能蒙皮

为已绑定骨骼的模型自动生成蒙皮权重。

**调用参数：**

| 参数 | 值 / 说明 |
|---|---|
| `node_type` | 固定值 `6` |
| `name` | 模型资产名称，示例： `"VISVISE_Skinning"` |
| `input_model` | 带骨骼的模型文件 COS URL（zip 文件） |

**输入模型 zip 包要求：**

zip 包内需包含两个同名文件：一个带骨骼的模型文件（如 `.fbx`）和一个 `.json` 参数文件，JSON 中需要配置 `mesh_category` 字段指定模型类别。

zip 包结构示例：

```
model.zip
├── model.fbx          # 带骨骼的模型文件
└── model.json         # 参数文件
```

JSON 参数文件示例：

```json
{
  "config": {
    "algo_name": "MotusAI-Skinning-V1.0"
  },
  "selection": {
    "mesh_names": [
      "Body_Mesh",
      "Hair_Mesh"
    ],
    "joint_names": [
      "Bip001",
      "Bip001 Pelvis",
      "Bip001 Spine",
      "Bip001 Head",
      "..."
    ]
  }
}
```

| 字段 | 必选 | 说明 |
|---|---|---|
| `config.algo_name` | 是 | 算法模型 |
| `selection.mesh_names` | 是 | 需要蒙皮的网格名称列表 |
| `selection.joint_names` | 是 | 需要蒙皮的骨骼名称列表 |

> 📎 示例文件下载：[skinning_demo.zip](https://visvise-weaver-bj-rel-1311802504.cos.ap-beijing.myqcloud.com/weaver/public/skinning_demo.zip)

**请求示例：**

```bash
curl -X POST 'https://ws.visvise.com.cn/openapi/weaver/resource/gen_3d_model' \
  -H 'Content-Type: application/json' \
  -H 'app_id: your_app_id' \
  -H 'ts: 1713168000' \
  -H 'rtx: caller_rtx' \
  -H 'sign: your_sign' \
  -d '{
    "name": "VISVISE_Skinning",
    "node_type": 6,
    "input_model": "https://visvise-weaver-bj-dev-1311802504.cos.accelerate.myqcloud.com/weaver/user-xxx/20260415/rigged_model.zip",
    "params": {}
  }'
```

**Python SDK 示例：**

```python
from visvise import VisviseClient

client = VisviseClient("your_app_id", "your_secret_key")

# SDK 自动将带骨骼的裸模型 + 选择参数打包上传
skin_id = client.gen_skinning(
    model_path="rigged_character.fbx",
    mesh_names=["Body_Mesh", "Hair_Mesh"],
    joint_names=["Bip001", "Bip001 Pelvis", "Bip001 Spine"],
    rtx="caller_rtx",
)
skin = client.wait_model(skin_id, timeout=600, rtx="caller_rtx")
print("蒙皮模型：", skin.output_model)
```

**Go SDK 示例：**

```go
package main

import (
    "fmt"
    "github.com/tencent-visvise/visvise-sdk-go/visvise"
)

func main() {
    client := visvise.NewClient("your_app_id", "your_secret_key", nil)
    rtx := "caller_rtx"

    // SDK 自动将带骨骼的裸模型 + 选择参数打包上传
    meshNames := []string{"Body_Mesh", "Hair_Mesh"}
    jointNames := []string{"Bip001", "Bip001 Pelvis", "Bip001 Spine"}

    skinID, err := client.GenSkinning("rigged_character.fbx", rtx,
        visvise.NewGenSkinningOptions(meshNames, jointNames))
    if err != nil { panic(err) }

    skin, err := client.WaitModel(skinID, rtx, &visvise.WaitOptions{Timeout: 600})
    if err != nil { panic(err) }
    fmt.Println("蒙皮模型：", skin.OutputModel)
}
```

---

### 4.4 3D动画生成

#### 4.4.1 视频生动画

从视频中提取动作数据，驱动 3D 模型生成动画。参数详情参考 [FramingAIParams](#framingaiparams)。

**调用参数：**

| 参数 | 值 / 说明 |
|---|---|
| `name` | 模型资产名称，示例：`VISVISE_VideoMotion` |
| `node_type` | 固定值 `4` |
| `input_video` | 视频文件 COS URL（非 zip 文件） |
| `input_model` | 模型文件 COS URL（zip 文件） |
| `params.framing_ai_params.algorithm_model` | 算法模型，示例：`MotusAI-V2M-V1.5` |
| `params.framing_ai_params.output_model_format` | 输出模型格式，支持 `fbx` / `bvh` |
| `params.framing_ai_params.with_hand` | 可选，手部捕捉（Bool），默认为 `false` |
| `params.framing_ai_params.multiple_track` | 可选，多人捕捉（Bool），默认为 `false` |
| `params.framing_ai_params.rotate_axis_angle` | 可选，旋转轴角 `[x, y, z]`（弧度） |

**请求示例：**

```bash
curl -X POST 'https://ws.visvise.com.cn/openapi/weaver/resource/gen_3d_model' \
  -H 'Content-Type: application/json' \
  -H 'app_id: your_app_id' \
  -H 'ts: 1713168000' \
  -H 'rtx: caller_rtx' \
  -H 'sign: your_sign' \
  -d '{
    "name": "VISVISE_VideoMotion",
    "node_type": 4,
    "input_model": "https://cos.example.com/weaver/user-xxx/model.zip",
    "input_video": "https://cos.example.com/weaver/user-xxx/dance.mp4",
    "params": {
        "framing_ai_params": {
            "algorithm_model": "MotusAI-V2M-V1.5",
            "output_model_format": "fbx",
            "with_hand": true
        }
    }
  }'
```

**Python SDK 示例：**

```python
from visvise import VisviseClient, OutputModelFormat

client = VisviseClient("your_app_id", "your_secret_key")

vm_id = client.gen_video_motion(
    model_path="model.zip",
    video_path="dance.mp4",
    output_model_format=OutputModelFormat.FBX,
    with_hand=True,
    rtx="caller_rtx",
)
model = client.wait_model(vm_id, timeout=900, rtx="caller_rtx")
```

**Go SDK 示例：**

```go
package main

import (
    "github.com/tencent-visvise/visvise-sdk-go/visvise"
)

func main() {
    client := visvise.NewClient("your_app_id", "your_secret_key", nil)
    rtx := "caller_rtx"

    vmID, err := client.GenVideoMotion("model.zip", "dance.mp4", rtx,
        visvise.NewGenVideoMotionOptions().
            SetOutputModelFormat(visvise.OutputModelFormatFBX).
            SetWithHand(true))
    if err != nil { panic(err) }

    _, err = client.WaitModel(vmID, rtx, &visvise.WaitOptions{Timeout: 900})
    if err != nil { panic(err) }
}
```

#### 4.4.2 文本生动画

通过文本提示词描述动作，自动生成 3D 动画。参数详情参考 [FramingAIParams](#framingaiparams)。

**调用参数：**

| 参数 | 值 / 说明 |
|---|---|
| `name` | 模型资产名称，示例：`VISVISE_Text2Motion` |
| `node_type` | 固定值 `4` |
| `input_model` | 模型文件 COS URL（zip 文件） |
| `params.framing_ai_params.algorithm_model` | 算法模型，支持：`MotusAI-T2M-V1.1` / `MotusAI-T2M-V1.5` |
| `params.framing_ai_params.output_model_format` | 输出模型格式，支持 `fbx` / `bvh` |
| `params.framing_ai_params.prompt` | 动画提示词（如"一个人在跳街舞"） |

> 💡 可通过 [获取文生动画提示词Demo列表](#213-获取文生动画提示词demo列表) 接口获取提示词参考。

**请求示例：**

```bash
curl -X POST 'https://ws.visvise.com.cn/openapi/weaver/resource/gen_3d_model' \
  -H 'Content-Type: application/json' \
  -H 'app_id: your_app_id' \
  -H 'ts: 1713168000' \
  -H 'rtx: caller_rtx' \
  -H 'sign: your_sign' \
  -d '{
    "name": "VISVISE_Text2Motion",
    "node_type": 4,
    "input_model": "https://cos.example.com/weaver/user-xxx/model.zip",
    "params": {
        "framing_ai_params": {
            "algorithm_model": "MotusAI-T2M-V1.5",
            "output_model_format": "fbx",
            "prompt": "一个人在跳街舞"
        }
    }
  }'
```

**多段提示词请求示例：**

```bash
curl -X POST 'https://ws.visvise.com.cn/openapi/weaver/resource/gen_3d_model' \
  -H 'Content-Type: application/json' \
  -H 'app_id: your_app_id' \
  -H 'ts: 1713168000' \
  -H 'rtx: caller_rtx' \
  -H 'sign: your_sign' \
  -d '{
    "name": "VISVISE_Text2Motion_Multi",
    "node_type": 4,
    "input_model": "https://cos.example.com/weaver/user-xxx/model.zip",
    "params": {
        "framing_ai_params": {
            "algorithm_model": "MotusAI-T2M-V1.5",
            "output_model_format": "fbx",
            "segments": [
                {
                    "text": "从站立姿势开始，缓缓抬起右手",
                    "num_frames": 60
                },
                {
                    "text": "向前走两步",
                    "num_frames": 90,
                    "overlap_frames_with_prev": 10
                },
                {
                    "text": "转身并挥手告别",
                    "num_frames": 60,
                    "overlap_frames_with_prev": 10
                }
            ]
        }
    }
  }'
```

**Python SDK 示例：**

```python
from visvise import VisviseClient, OutputModelFormat, MotionSegment

client = VisviseClient("your_app_id", "your_secret_key")

# 单段提示词：返回 1 个 model_id，单 model 内部含 4 个抽卡候选（见 framing_ai_output.text2_motion_result）
tm_ids = client.gen_text_motion(
    model_path="model.zip",
    prompt="一个人在跳街舞",
    output_model_format=OutputModelFormat.FBX,
    rtx="caller_rtx",
)
print(f"返回 {len(tm_ids)} 个动画模型")
model = client.wait_model(tm_ids[0], timeout=900, rtx="caller_rtx")

# 多段提示词（segments）：非空时以多段为准，忽略 prompt
segments = [
    MotionSegment(text="从站立姿势开始，缓缓抬起右手", num_frames=60),
    MotionSegment(text="向前走两步", num_frames=90, overlap_frames_with_prev=10),
    MotionSegment(text="转身并挥手告别", num_frames=60, overlap_frames_with_prev=10),
]
tm_ids = client.gen_text_motion(
    model_path="model.zip",
    segments=segments,
    output_model_format=OutputModelFormat.FBX,
    rtx="caller_rtx",
)
model = client.wait_model(tm_ids[0], timeout=900, rtx="caller_rtx")
```

**Go SDK 示例：**

```go
package main

import (
    "fmt"
    "github.com/tencent-visvise/visvise-sdk-go/visvise"
)

func main() {
    client := visvise.NewClient("your_app_id", "your_secret_key", nil)
    rtx := "caller_rtx"

    // 单段提示词：返回 1 个 model_id，单 model 内部含 4 个抽卡候选（见 FramingAIOutput.Text2MotionResult）
    tmIDs, err := client.GenTextMotion("model.zip", rtx,
        visvise.NewGenTextMotionOptions().
            SetPrompt("一个人在跳街舞").
            SetOutputModelFormat(visvise.OutputModelFormatFBX))
    if err != nil { panic(err) }
    fmt.Printf("返回 %d 个动画模型\n", len(tmIDs))

    _, err = client.WaitModel(tmIDs[0], rtx, &visvise.WaitOptions{Timeout: 900})
    if err != nil { panic(err) }

    // 多段提示词（segments）：非空时以多段为准，prompt 传空
    numFrames60 := 60
    numFrames90 := 90
    overlap10 := 10
    segments := []visvise.MotionSegment{
        {Text: "从站立姿势开始，缓缓抬起右手", NumFrames: &numFrames60},
        {Text: "向前走两步", NumFrames: &numFrames90, OverlapFramesWithPrev: &overlap10},
        {Text: "转身并挥手告别", NumFrames: &numFrames60, OverlapFramesWithPrev: &overlap10},
    }
    tmIDs, err = client.GenTextMotion("model.zip", rtx,
        visvise.NewGenTextMotionOptions().
            SetOutputModelFormat(visvise.OutputModelFormatFBX).
            SetSegments(segments))
    if err != nil { panic(err) }
    fmt.Printf("返回 %d 个动画模型\n", len(tmIDs))

    _, err = client.WaitModel(tmIDs[0], rtx, &visvise.WaitOptions{Timeout: 900})
    if err != nil { panic(err) }
}
```

**返回说明：**

文本生动画接口返回的 `model_ids` 只有 **1 个** model_id，但单个 model 内部包含 **4 个抽卡候选** 动画模型。轮询完成后：
- `output_model` 为整体打包的 zip 包（含 4 个候选动画文件）；
- 单个候选可在 `framing_ai_output.text2_motion_result[]` 数组中查看，每条含 `output_model`（候选自身的 zip / 模型 URL）与 `preview_img`（预览图）。

---

### 4.5 图生Pose

从参考图片中提取姿态，驱动 3D 模型生成对应 Pose。支持批量生成。使用 [批量图生Pose](#212-批量图生pose) 接口。

**调用参数：**

| 参数                         | 值 / 说明                                                    |
| ---------------------------- | ------------------------------------------------------------ |
| `name`                       | 模型资产名称，示例：`VISVISE_Pose`                           |
| `input_model`                | 模型文件 COS URL（zip 文件）                                 |
| `input_images`               | 输入图片 URL 列表，最少 1 张，最多 10 张。传 1 张时等同于单张图生 Pose |
| `params.algorithm_model`     | 算法模型，示例：`MotusAI-Posing-V1.0`                    |
| `params.output_model_format` | 模型格式，支持 `fbx`                                         |

> 💡 可通过 [获取文生动画提示词Demo列表](#213-获取文生动画提示词demo列表) 接口获取提示词参考。

**请求示例：**

```bash
curl -X POST 'https://ws.visvise.com.cn/openapi/weaver/resource/batch_gen_pose' \
  -H 'Content-Type: application/json' \
  -H 'app_id: your_app_id' \
  -H 'ts: 1713168000' \
  -H 'rtx: caller_rtx' \
  -H 'sign: your_sign' \
  -d '{
    "name": "VISVISE_Pose",
    "input_model": "https://cos.example.com/weaver/user-xxx/model.zip",
    "input_images": [
        "https://cos.example.com/weaver/user-xxx/pose_ref_1.png",
        "https://cos.example.com/weaver/user-xxx/pose_ref_2.png"
    ],
    "params": {
        "algorithm_model": "MotusAI-Posing-V1.0",
        "output_model_format": "fbx"
    }
  }'
```

**Python SDK 示例：**

```python
from visvise import VisviseClient, OutputModelFormat

client = VisviseClient("your_app_id", "your_secret_key")

pose_ids = client.gen_pose(
    model_path="model.zip",
    input_images=["pose_ref_1.png", "pose_ref_2.png"],
    output_model_format=OutputModelFormat.FBX,
    rtx="caller_rtx",
)
for mid in pose_ids:
    model = client.wait_model(mid, timeout=600, rtx="caller_rtx")
```

**Go SDK 示例：**

```go
package main

import (
    "github.com/tencent-visvise/visvise-sdk-go/visvise"
)

func main() {
    client := visvise.NewClient("your_app_id", "your_secret_key", nil)
    rtx := "caller_rtx"

    inputImages := []visvise.FileInput{"pose_ref_1.png", "pose_ref_2.png"}

    poseIDs, err := client.GenPose("model.zip", inputImages, rtx,
        visvise.NewGenPoseOptions().
            SetOutputModelFormat(visvise.OutputModelFormatFBX))
    if err != nil { panic(err) }

    for _, mid := range poseIDs {
        _, err = client.WaitModel(mid, rtx, &visvise.WaitOptions{Timeout: 600})
        if err != nil { panic(err) }
    }
}
```

---

### 4.6 通用轮询逻辑

所有异步任务创建后，使用以下轮询逻辑获取结果：

```python
import time
import requests

def poll_model_status(base_url, headers, model_id, interval=5, timeout=600):
    """
    轮询模型生成状态
    
    Args:
        base_url: API 基础地址
        headers: 认证 Header（需动态更新签名）
        model_id: 生成的模型 ID
        interval: 轮询间隔（秒）
        timeout: 最大等待时间（秒）
    
    Returns:
        ModelInfo dict or None
    """
    start_time = time.time()
    
    while time.time() - start_time < timeout:
        # 注意：每次请求需重新计算签名
        resp = requests.post(
            f"{base_url}/openapi/weaver/resource/get_model_list",
            headers=headers,
            json={
                "model_id_list": [model_id],
                "limit": 1
            }
        )
        
        data = resp.json()
        if data["code"] != 0:
            print(f"Error: {data['msg']}")
            return None
        
        model_list = data["data"]["model_list"]
        if not model_list:
            print("Model not found")
            return None
        
        model = model_list[0]
        status = model["status"]
        
        if status == 3:  # 生成成功
            print(f"✅ 生成成功！输出模型: {model.get('output_model', 'N/A')}")
            return model
        elif status == 4:  # 生成失败
            reason = model.get("failed_reason", {})
            print(f"❌ 生成失败: [{reason.get('code')}] {reason.get('reason')}")
            return model
        else:
            remaining = model.get("remaining_time", "unknown")
            print(f"⏳ 状态: {'等待中' if status == 1 else '生成中'}，预计剩余: {remaining}s")
        
        time.sleep(interval)
    
    print("⏰ 轮询超时")
    return None
```

```go
package main

import (
    "fmt"
    "time"

    "github.com/tencent-visvise/visvise-sdk-go/visvise"
)

// PollModelStatus 轮询模型生成状态。
//
// Args:
//   client    : VISVISE 客户端
//   modelID   : 模型 ID
//   rtx       : 实际使用人 RTX
//   interval  : 轮询间隔（秒）
//   timeout   : 最大等待时间（秒）
//
// Returns:
//   *ModelInfo, error —— 成功返回 ModelInfo；超时或失败返回 nil/相应 error
func PollModelStatus(client *visvise.Client, modelID, rtx string, interval float64, timeout int) (*visvise.ModelInfo, error) {
    start := time.Now()
    for {
        if time.Since(start).Seconds() >= float64(timeout) {
            return nil, fmt.Errorf("⏰ 轮询超时")
        }

        models, _, err := client.GetAPI().GetModelList(
            []string{modelID}, nil, nil, "", 1, 1, 0, nil, nil, rtx,
        )
        if err != nil {
            return nil, fmt.Errorf("Error: %v", err)
        }
        if len(models) == 0 {
            return nil, fmt.Errorf("Model not found")
        }

        m := models[0]
        switch m.Status {
        case 3: // SUCCESS
            fmt.Printf("✅ 生成成功！输出模型: %s\n", m.OutputModel)
            return &m, nil
        case 4: // FAILED
            if m.FailedReason != nil {
                fmt.Printf("❌ 生成失败: [%d] %s\n", m.FailedReason.Code, m.FailedReason.Reason)
            }
            return &m, nil
        default:
            statusName := "等待中"
            if m.Status == 2 {
                statusName = "生成中"
            }
            fmt.Printf("⏳ 状态: %s，预计剩余: %ds\n", statusName, m.RemainingTime)
        }

        time.Sleep(time.Duration(interval * float64(time.Second)))
    }
}

func main() {
    client := visvise.NewClient("your_app_id", "your_secret_key", nil)
    if _, err := PollModelStatus(client, "Model202604xxxxxx", "caller_rtx", 2, 600); err != nil {
        fmt.Println(err)
    }
}
```

> 提示：Python SDK 的 `client.wait_model(model_id, rtx="...")` 与 Go SDK 的 `client.WaitModel(modelID, rtx, &visvise.WaitOptions{...})` 已经封装了上面这段轮询逻辑，多数情况下直接调用即可。

---

## 5. 错误码说明

### 5.1 通用错误码

| 错误码 | 应对建议 |
|---|---|
| `0` | 请求成功 |
| `410` | 签名错误，请检查 `app_id` / `secret_key` 与签名拼接方式 |
| `411` | 签名过期，本地 `ts`（Unix 秒）与服务端时间偏差过大，请校准本地时钟后重试 |
| `120008` | 请求参数错误，请检查参数后重试 |
| `120017` | 用户未找到，请确认账号信息 |
| `120018` | 用户无权限 |
| `120020` | 每日生成次数超出上限，请明天再试 |
| `120027` | 项目权限未授权 |
| `120028` | 网络错误，请稍后再试 |
| `120032` | 已超时，请重试；若多次重试请联系平台产品 |
| `120040` | 请求过于频繁，请稍后再试 |

### 5.2 重拓扑 / LOD 错误码

| 错误码 | 应对建议 |
|---|---|
| `990101` | 程序执行失败，请重试；若多次重试无效请联系产品负责人 |
| `990102` | 程序执行失败，请重试；若多次重试无效请联系产品负责人 |
| `990103` | 程序执行失败，请重试；若多次重试无效请联系产品负责人 |
| `990104` | COS 下载失败，请重试；若多次重试无效请联系产品负责人 |
| `990105` | COS 上传失败，请重试；若多次重试无效请联系产品负责人 |
| `990106` | 生成失败，请重试；若多次重试无效请联系产品负责人 |
| `960002` | 模型 UV 岛＞10,000，请重新选择模型文件 |

### 5.3 图生模 / 3D动画生成 错误码

| 错误码 | 应对建议 |
|---|---|
| `990008` | 程序执行失败，请重试；若多次重试无效请联系产品负责人 |
| `990010` | 程序执行失败，请重试；若多次重试无效请联系产品负责人 |
| `990014` | 程序执行失败，请重试；若多次重试无效请联系产品负责人 |
| `990015` | 上传文件格式不符合要求，请上传 fbx 文件 |
| `990017` | 程序执行失败，请重试；若多次重试无效请联系产品负责人 |
| `990301` | 程序执行失败，请重试；若多次重试无效请联系产品负责人 |
| `990302` | 程序执行失败，请重试；若多次重试无效请联系产品负责人 |
| `130002` | 混元模型校验审核未通过，请更换素材 |
| `130429` | 程序执行失败，请重试；若多次重试无效请联系产品负责人 |
| `130500` | 程序执行失败，请重试；若多次重试无效请联系产品负责人 |
| `130018` | 混元生成模型未全部有 UV，请更换素材 |
| `200000` | 程序执行失败，请重试；若多次重试无效请联系产品负责人 |
| `200001` | 程序执行失败，请重试；若多次重试无效请联系产品负责人 |

### 5.4 智能骨骼架设 错误码

| 错误码 | 应对建议 |
|---|---|
| `992101` | 程序执行失败，请重试；若多次重试无效请联系产品负责人 |
| `992102` | 程序执行失败，请重试；若多次重试无效请联系产品负责人 |
| `992104` | 程序执行失败，请重试；若多次重试无效请联系产品负责人 |
| `992105` | 程序执行失败，请重试；若多次重试无效请联系产品负责人 |
| `992106` | 程序执行失败，请重试；若多次重试无效请联系产品负责人 |
| `971126` | 目前仅支持处理 50 万顶点以下的模型，请先对该模型进行重拓扑处理 |

### 5.5 图生Pose 错误码

| 错误码 | 应对建议 |
|---|---|
| `666540` | 程序执行失败，请重试；若多次重试无效请联系平台产品 |
| `666541` | 上传模型角色化失败，目前仅支持标准人物角色的动画生成 |
| `666542` | 生成失败，请重试；若多次重试无效请联系平台产品 |
| `666543` | 重定向失败，请重试；若多次重试无效请联系平台产品 |
| `666544` | 生成失败，请重试；若多次重试无效请联系平台产品 |
| `666545` | 上传模型骨骼较复杂，请更换素材重试 |
| `666546` | 上传模型骨骼不规范，请更换素材重试 |
| `666547` | 生成失败，请重试；若多次重试无效请联系平台产品 |
| `666548` | 上传图片解析失败，请尝试更换图片 |
| `666549` | 上传图片未检测出人物，请尝试更换图片 |
| `666550` | 生成失败，请重试；若多次重试无效请联系平台产品 |

### 5.6 贴图纹理 错误码

| 错误码 | 应对建议 |
|---|---|
| `993101` | 程序执行失败，请重试 |
| `993102` | 程序执行失败，请重试 |

### 5.7 2UV（AutoLUV）错误码

**非错误状态提示（处理时间较长，无需重试）：**

| 错误码 | 说明 | 应对建议 |
|---|---|---|
| `940401` | 处理该模型需要大概 30 分钟，请耐心等候（非错误） | / |
| `940402` | 处理该模型需要大概 60 分钟，请耐心等候（非错误） | / |
| `940403` | 处理该模型需要超过 1 个小时，请耐心等候（非错误） | / |
| `940404` | 原始输入分辨率不合适，已调整（非错误） | / |

**处理超时与 UV 错误：**

| 错误码 | 说明 | 应对建议 |
|---|---|---|
| `940101` | 处理该模型超时 | 该模型处理超时，请重试 |
| `940102` | UV 坐标不是以逐个面片顶点的形式映射的（详细请咨询技术美术） | 模型的 UV 坐标有错误，请调整后重试 |
| `940103` | 过多的网格分布在平缓表面（例如带顶点权重的地表、路面、围墙或者高模） | 模型中过多网格分布在平缓表面，请调整后重试 |

**模型数据校验错误：**

| 错误码 | 说明 | 应对建议 |
|---|---|---|
| `940107` | 模型中需要包含法线信息才能正常运行 | 模型中无法线，请调整后重试 |
| `940108` | 模型的 UV 索引数目有错误 | 模型 UV 索引数目有误，请调整后重试 |
| `940109` | 模型中需要包含有效 1UV 信息才能正常运行 | 模型没有 UV，请重新选择带 UV 的模型文件 |
| `940110` | 模型的 UV 索引 ID 有错误 | 模型的 UV 索引 ID 有错误，请调整后重试 |
| `940111` | 模型有些 UV 坐标值是无效浮点数 | 模型的 UV 坐标有错误，请调整后重试 |
| `940112` | 模型的 1UV 中存在翻转面片 | 模型的 1UV 存在翻转面片，请调整后重试 |
| `940113` | 模型中存在复杂的面片交叠（例如多个面共一条边） | 模型存在复杂面片交叠，请调整后重试 |
| `940114` | 模型中包含边数过多（大于 8）且较复杂的面片 | 模型的边数过多，请调整后重试 |
| `940115` | 输入的光照纹理分辨率与 UV 岛边沿像素不合理 | 光照纹理分辨率/UV 岛边沿像素数不合理，请重试 |
| `940116` | 与法线贴图对应的 1UV 不合理 | 模型的 1UV 不合理，请调整后重试 |
| `940117` | 网格数据不合理 | 模型的网格数据不合理，请调整后重试 |
| `940118` | 不支持该法线参考模式 | 法线参考模式仅支持 Direct 和 IndexToDirect 模式，请调整后重试 |
| `940119` | 不支持该切线参考模式 | 切线参考模式仅支持 Direct 和 IndexToDirect 模式，请调整后重试 |
| `940120` | 不支持该次法线参考模式 | 次法线参考模式仅支持 Direct 和 IndexToDirect 模式，请调整后重试 |
| `940121` | 不支持该法线映射模式 | 法线映射模式仅支持 ByControlPoint 和 ByPolygonVertex 模式，请调整后重试 |
| `940122` | 不支持该切线映射模式 | 切线映射模式仅支持 ByControlPoint 和 ByPolygonVertex 模式，请调整后重试 |
| `940123` | 不支持该次法线映射模式 | 次法线映射模式仅支持 ByControlPoint 和 ByPolygonVertex 模式，请调整后重试 |
| `940124` | 不支持该材质映射模式 | 材质映射模式仅支持 AllSame 和 ByPolygon 模式，请调整后重试 |
| `940125` | 1UV 不能命名为 "lightmap" | 1UV 命名错误，请调整后重试 |
| `940126` | 模型只包含 "lightmap" 通道 | 模型通道错误，请调整后重试 |
| `940127` | UV 层数目错误 | 模型 UV 层数目错误，请调整后重试 |
| `940128` | 法线贴图类型只支持 CV_8UC3 或 CV_8UC4 | 法线贴图类型只支持 CV_8UC3 或 CV_8UC4，请调整后重试 |
| `940129` | 不支持该 1UV 映射模式 | 不支持该 1UV 映射模式，请调整后重试 |
| `940130` | 缺少包含待复制 UV 通道的节点 | 缺少包含待复制 UV 通道的节点，请调整后重试 |
| `940131` | 有多个节点包含待复制 UV 通道 | 有多个节点包含待复制 UV 通道，请调整后重试 |
| `940132` | 包含完全退化的 UV 岛 | 包含完全退化的 UV 岛，请调整后重试 |
| `940133` | 服务器文件系统错误 | 服务器文件系统错误，请调整后重试 |

**参数校验错误：**

| 错误码 | 说明 | 应对建议 |
|---|---|---|
| `940150` | 分辨率参数不合理 | 分辨率参数不合理，请调整后重试 |
| `940151` | UV 岛边沿像素参数不合理 | UV 岛边沿像素参数不合理，请调整后重试 |
| `940152` | 主要观测方向参数不合理 | 主要观测方向参数不合理，请调整后重试 |
| `940153` | 不可见区域缩放比例参数不合理 | 不可见区域缩放比例参数不合理，请调整后重试 |
| `940154` | 复杂光照区域缩放比例参数不合理 | 复杂光照区域缩放比例参数不合理，请调整后重试 |
| `940155` | 启用复杂光照区域检测参数不合理 | 启用复杂光照区域检测参数不合理，请调整后重试 |
| `940156` | 启用清晰阴影区域检测参数不合理 | 启用清晰阴影区域检测参数不合理，请调整后重试 |
| `940157` | 狭长区域处理模式参数不合理 | 狭长区域处理模式参数不合理，请调整后重试 |
| `940158` | 切割模式参数不合理 | 切割模式参数不合理，请调整后重试 |

**算法内部错误：**

| 错误码 | 说明 | 应对建议 |
|---|---|---|
| `940201` | 处理该模型出现内部错误（未捕获异常） | 处理该模型出现内部错误（未捕获异常），请联系产品负责人 kimbrlyyang |
| `940202` | 处理该模型出现内部错误（捕捉到系统信号） | 处理该模型出现内部错误（捕捉到系统信号），请联系产品负责人 kimbrlyyang |
| `940203` | 处理该模型出现内部错误（退出码为错误码） | 处理该模型出现内部错误（退出码为错误码），请联系产品负责人 kimbrlyyang |
| `940204` | 处理该模型出现内部错误（内核转储） | 处理该模型出现内部错误（内核转储），请联系产品负责人 kimbrlyyang |
| `940301` | 其他前置条件不满足 | 其他前置条件不满足，请调整后重试，请联系产品负责人 kimbrlyyang |
| `940302` | 算法内部计算错误 | 算法内部计算错误，请联系产品负责人 kimbrlyyang |

**FBX 与服务连接错误：**

| 错误码 | 说明 | 应对建议 |
|---|---|---|
| `940502` | endpoint 错误 | 服务连接地址异常，建议您稍后再尝试操作 |
| `940503` | 算法服务连接失败 | 模型服务出现异常，建议您稍后再尝试操作，或联系产品负责人 kimbrlyyang |
| `940504` | FBX 读写失败 | 系统无法读取/写入您的 FBX 文件，请确认文件完整、格式正确后重新上传 |
| `940505` | FBX 输入参数错误 | 您上传的 FBX 文件参数不符合要求，请检查文件参数后重新上传 |
| `940506` | FBX 文件路径无效 | 您选择的 FBX 文件路径无效，请确认路径正确后重新操作 |
| `940507` | 参数配置 JSON 输入错误 | 参数 JSON 内容填写有误，请检查格式后重新提交 |
| `940508` | FBX 输出路径错误 | FBX 文件输出路径设置错误，请确认路径正确后重新操作 |
| `940509` | FBX SDK 初始化失败 | FBX SDK 初始化异常，建议您稍后再尝试操作 |
| `940510` | FBX 文件加载失败 | 系统无法加载您的 FBX 文件，请确认文件完整、未损坏后重新上传 |
| `940511` | FBX 场景转换失败 | FBX 场景转换过程中出现错误，请检查文件内容后重新尝试 |
| `940512` | FBX 网格抽取失败 | 无法从 FBX 文件中抽取网格数据，请确认文件包含网格信息后重新上传 |
| `940513` | FBX 写回校验失败 | FBX 文件写回后校验不通过，请确认文件内容正确后重新操作，或联系产品负责人 kimbrlyyang |
| `940514` | FBX 写回失败 | 系统无法将数据写回 FBX 文件，请确认文件可编辑后重新尝试，或联系产品负责人 kimbrlyyang |
| `940515` | FBX 数据校验失败 | 您上传的 FBX 文件数据校验不通过，请确认文件完整、格式正确后重新上传 |
| `940516` | 输入格式有误 | 目前仅支持 FBX 类型文件，请选择 FBX 文件上传 |
| `940517` | 顶点数过高 | 目前仅支持处理 50 万顶点以下的模型，请先对该模型进行重拓扑处理 |

---

## 6. SDK

### 6.1 Python SDK

**仓库：** [tencent-visvise/visvise-sdk-python](https://github.com/tencent-visvise/visvise-sdk-python)

**安装（指定版本）：**

```bash
pip install git+https://github.com/tencent-visvise/visvise-sdk-python.git@v1.0.3
```

或通过 SSH：

```bash
pip install git+ssh://git@github.com/tencent-visvise/visvise-sdk-python.git@v1.0.3
```

> 安装后即包含腾讯云 COS SDK，可直接使用本地文件自动上传功能。

**快速开始：**

```python
from visvise import VisviseClient, Environment, FaceType, OutputModelFormat

client = VisviseClient(
    app_id="your_app_id",
    secret_key="your_secret_key",
    env=Environment.PROD,        # 或 Environment.TEST / Environment.DEV
)

# 图生360：上传本地图片，生成多视图（algorithm_model 可选，不传自动选首个可用模型）
mv_id = client.gen_360(main_view="character.png", rtx="caller_rtx")
mv = client.wait_model(mv_id, interval=3, timeout=300, rtx="caller_rtx")

# 图生高模
high_id = client.gen_high_model(
    main_view=mv.image_gen_360_output.output_view.main_view,
    back_view=mv.image_gen_360_output.output_view.back_view,
    left_view=mv.image_gen_360_output.output_view.left_view,
    right_view=mv.image_gen_360_output.output_view.right_view,
    output_model_format=OutputModelFormat.FBX,
    face_type=FaceType.TRIANGLE,
    rtx="caller_rtx",
)
model = client.wait_model(high_id, timeout=900, rtx="caller_rtx")
print("输出模型：", model.output_model)
```

**主要能力：**

- 14 个高阶方法 `gen_xxx`（自动上传文件 + 创建任务），覆盖图生360、图生模、布线重建、重拓扑、LOD、UV、贴图纹理、智能骨骼架设、智能蒙皮、3D动画生成、图生Pose、2D 拆分等全部业务节点。
- `wait_model()` 异步轮询，自动识别成功/失败状态。
- 全部原子接口通过 `client.api.xxx(rtx="caller_rtx")` 访问。
- 内置枚举常量：`FaceType` / `DetailLevel` / `OutputModelFormat` / `MeshRefineMode` / `SegmentSplitType` / `SegmentGranularity` / `NodeType` / `ModelStatus`。
- `algorithm_model` 参数全部可选，未传时 SDK 自动调 `list_algorithm_model` 取第一个可用模型。
- 文件输入，支持本地路径 / VISVISE 平台 COS URL / bytes / BinaryIO 四种形式；**二进制输入会自动通过 magic bytes 嗅探格式**（图片 PNG/JPEG/GIF/BMP/WebP/TIFF，3D 模型 FBX/OBJ/GLB/GLTF，视频 MP4/MOV/WebM/AVI，ZIP），用 `<uuid>.<识别后缀>` 自动命名上传，无需调用方提供文件名。

详细使用方法参考仓库 [README](https://github.com/tencent-visvise/visvise-sdk-python/blob/main/README.md)。

---

### 6.2 Go SDK

**仓库：** [tencent-visvise/visvise-sdk-go](https://github.com/tencent-visvise/visvise-sdk-go)

**安装：**

```bash
go get github.com/tencent-visvise/visvise-sdk-go
```

**快速开始：**

```go
package main

import (
    "fmt"
    "github.com/tencent-visvise/visvise-sdk-go/visvise"
)

func main() {
    // 创建客户端（默认线上生产环境）
    client := visvise.NewClient("your_app_id", "your_secret_key", nil)
    // 切换环境 / 开启调试
    // client := visvise.NewClient("your_app_id", "your_secret_key",
    //     visvise.NewClientOptions().SetEnv(visvise.EnvDev).SetDebug(true))

    rtx := "caller_rtx"

    // ① 图生 360
    mvID, err := client.Gen360("character.png", rtx,
        visvise.NewGen360Options().SetEnableAPose(true))
    if err != nil { panic(err) }

    // ② 等待完成
    mv, err := client.WaitModel(mvID, rtx, &visvise.WaitOptions{Interval: 3.0, Timeout: 300})
    if err != nil { panic(err) }
    output := mv.ImageGen360Output.OutputView

    // ③ 图生高模（多视图直接传 COS URL）
    highID, err := client.GenHighModel(output.MainView, rtx,
        visvise.NewGenHighModelOptions().
            SetBackView(output.BackView).
            SetLeftView(output.LeftView).
            SetRightView(output.RightView))
    if err != nil { panic(err) }

    // ④ 等待高模完成
    high, err := client.WaitModel(highID, rtx, &visvise.WaitOptions{Interval: 5.0, Timeout: 900})
    if err != nil { panic(err) }
    fmt.Println("输出模型：", high.OutputModel)
}
```

**主要能力：**

- 14 个高阶方法 `Gen*`（自动上传文件 + 创建任务），覆盖图生 360、图生模、布线重建 、重拓扑、LOD、UV、贴图纹理、智能骨骼架设、智能蒙皮、3D动画生成、图生Pose、2D 拆分等全部业务节点。
- 可选参数走 `Options` 链式 setter（如 `NewGen360Options().SetEnableAPose(true).SetStyle(visvise.ImageGen360StyleGrayModel)`）。
- `WaitModel()` 异步轮询，自动识别成功 / 失败状态。
- 全部原子接口通过 `client.GetAPI().Xxx(..., rtx)` 访问。
- 内置枚举常量：`NodeType*` / `ModelStatus*` / `FaceType*` / `DetailLevel*` / `OutputModelFormat*` / `MeshRefineMode*` / `SegmentSplitType*` / `SegmentGranularity*` / `ImageGen360Style*`。
- `AlgorithmModel` 在 Options 中为可选项，未设置时 SDK 自动调 `ListAlgorithmModel` 取第一个可用模型。
- 文件输入 `FileInput` 支持本地路径（`string`）、VISVISE 平台 COS URL（`string`）、二进制内容（`[]byte` 或 `io.Reader`）三种形式；**二进制输入会自动通过 magic bytes 嗅探格式**，与 Python SDK 行为一致。

详细使用方法参考仓库 [README](https://github.com/tencent-visvise/visvise-sdk-go/blob/main/README.md)。

---

### 6.3 Java SDK

**仓库：** [tencent-visvise/visvise-sdk-java](https://github.com/tencent-visvise/visvise-sdk-java)

**安装：**

手动下载 JAR 引入项目：

- [最新 Release](https://github.com/tencent-visvise/visvise-sdk-java/releases/latest)
- [所有 Releases](https://github.com/tencent-visvise/visvise-sdk-java/releases)

或在 Maven 项目中引入（坐标 `com.visvise:visvise-sdk-java`，依赖 `cos_api` / `gson` / `httpclient` / `slf4j-api`，`JDK 1.8+`）。

**快速开始：**

```java
import com.visvise.sdk.VisviseClient;
import com.visvise.sdk.options.*;
import com.visvise.sdk.enums.*;
import com.visvise.sdk.model.*;

public class Main {
    public static void main(String[] args) {
        // 创建客户端（默认线上生产环境）
        VisviseClient client = new VisviseClient("your_app_id", "your_secret_key", null);
        // 切换环境 / 开启调试
        // VisviseClient client = new VisviseClient("your_app_id", "your_secret_key",
        //     ClientOptions.create().setEnv(Environment.DEV).setDebug(true).setTimeout(60));

        String rtx = "caller_rtx";

        // ① 图生 360
        String mvId = client.gen360("character.png",
            Gen360Options.create().setEnableAPose(true), rtx);

        // ② 等待完成
        ModelInfo mv = client.waitModel(mvId,
            WaitOptions.create().setInterval(3.0).setTimeout(300), rtx);
        View output = mv.getImageGen360Output().getOutputView();

        // ③ 图生高模（多视图直接传 COS URL）
        String highId = client.genHighModel(output.getMainView(),
            GenHighModelOptions.create()
                .setBackView(output.getBackView())
                .setLeftView(output.getLeftView())
                .setRightView(output.getRightView()),
            rtx);

        // ④ 等待高模完成
        ModelInfo high = client.waitModel(highId,
            WaitOptions.create().setTimeout(900), rtx);
        System.out.println("输出模型：" + high.getOutputModel());
    }
}
```

**主要能力：**

- 14 个高阶方法 `genXxx`（自动上传文件 + 创建任务），覆盖图生 360、图生模、布线重建，重拓扑、LOD、UV、贴图纹理、智能骨骼架设、智能蒙皮、3D动画生成、图生Pose、2D 拆分等全部业务节点。
- 可选参数走 `Options` 链式 setter（如 `Gen360Options.create().setEnableAPose(true).setStyle(ImageGen360Style.GRAY_MODEL.getValue())`）。
- `waitModel()` 异步轮询，自动识别成功 / 失败状态。
- 全部原子接口通过 `client.getAPI().xxx(..., rtx)` 访问。
- 内置枚举常量：`NodeType` / `ModelStatus` / `FaceType` / `DetailLevel` / `ModelFormat` / `MeshRefineMode` / `SegmentSplitType` / `SegmentGranularity` / `AnimationSubType` / `Environment` / `ImageGen360Style`。
- `algorithmModel` 在 Options 中为可选项，未设置时 SDK 自动调 `listAlgorithmModel` 取第一个可用模型。
- 文件输入，支持本地路径（`String`）、VISVISE 平台 COS URL（`String`）、`java.io.File`、二进制内容（`byte[]` 或 `InputStream`）四种形式；**二进制输入会自动通过 magic bytes 嗅探格式**，与 Python / Go SDK 行为一致。

详细使用方法参考仓库 [README](https://github.com/tencent-visvise/visvise-sdk-java/blob/main/README.md)。

---

## 7. 版本更新记录

| 版本 | 日期 | 更新内容 |
|---|---|---|
| **文档更新** | 2026-07-27 | 1. `ImageGenModelParams` 新增 `component_label` 参数（配合 `segment_model_id` 实现单部件生成）<br/>2. `segment_model_id` / `model_id_360` / `component_label` 交互说明：图生中模支持全部 4 种组合，图生高模仅支持 `segment_model_id`+`component_label`<br/>3. 图生中模（§3.4）：Demo 改造为 4 种输入方式（原画 View / model_id_360 / segment_model_id 分部件 / segment_model_id+component_label 单部件）<br/>4. 图生高模（§3.3）：Demo 改造为 2 种输入方式（原画 View / segment_model_id+component_label 单部件），注明不支持 model_id_360 和单独的 segment_model_id <br/>5. 新增重拓扑对于混元 2.0 版本的支持，重点说明 ReTopologyParams 中的 detail_level 和 face_num 在不同算法模型下的传参说明。|
| **文档更新** | 2026-06-18 | 1. 2UV（§3.11）：补充输入模型限制说明（仅支持 FBX、需含法线和 1UV、50 万顶点以下、AutoLUV 产物不可二次处理）<br/>2. 2UV（§3.11）：补充 `remaining_time` 60s 下限保护说明<br/>3. regenerate_model（§2.15）：补充原地重生成行为说明（`redo_count` 递增、不返回新 model_id、成功模型也可重做）<br/>4. ModelInfo `remaining_time` 字段：补充 60s 下限保护说明<br/>5. enable_pbr 参数：补充行为说明（仅设置 PBR 材质类型，不嵌入贴图）<br/>6. 新增 §5.7 2UV（AutoLUV）完整错误码表（940101&#126;940517，共 50+ 错误码，含非错误状态提示 940401&#126;940404）<br/>7. 算法模型名更新：`VISVISE-AutoLuv-V1.0.0` → `VISVISE-AutoLUV-V2.6.0`<br />8、统一文档中的接口名称和参数名称<br />9、删除部分接口中的无效参数<br />10、对部分接口中的参数进行补充说明（包括调整参数的顺序） |
| **1.0.3** | 2026-05-15 | 1. 签名 header `uid` 字段重命名为 `rtx`（实际使用人的 RTX 公司账号）；按公司要求**内部用户必须传实际使用人的 rtx**，不可代填<br>2. SDK 构造函数 `VisviseClient(app_id, secret_key, env)` 不再需要 uid 参数<br>3. 所有 SDK 接口（`gen_xxx` / 原子 API / `wait_model`）都新增 `rtx` 必填关键字参数，`rtx` 是请求级字段而非 client 级<br>4. 图生 360 `style` 参数新增 `ImageGen360Style` 枚举与前置校验，传非法值直接抛 `ValueError` 不发起请求<br>5. 错误码规范化：签名错误 410 / 签名过期 411（原 400 改）<br>6. NetworkError 增强：HTTP 错误时透出服务端响应体，便于定位非标准 4xx/5xx 错误 |
| **1.0.2** | 2026-05-12 | 1. 所有 `gen_xxx` 方法移除 `*_filename` 参数（如 `main_view_filename` / `model_filename` / `video_filename` 等），二进制输入（`bytes` / `BinaryIO`）由 SDK 内部自动通过 magic bytes 嗅探格式后用 `<uuid>.<识别后缀>` 命名上传<br>2. 嗅探支持图片（PNG/JPEG/GIF/BMP/WebP/TIFF）、3D 模型（FBX 二进制 / FBX ASCII / GLB / OBJ / GLTF）、视频（MP4 / MOV / WebM / AVI）、ZIP 共 18 种格式<br>3. 二进制输入路径行为对齐本地路径：模型文件自动打 zip，图片 / 视频直接上传 |
| **1.0.1** | 2026-05-09 | 1. API header 新增 `uid` 参数（一期不严格校验，二期严格校验）<br>2. 新增 2D 拆分节点（`node_type=14`）和 [2D拆分](#214-2d拆分) 接口（SSE 协议）<br>3. `ImageGenModelParams` 新增 `segment_model_id`（仅中模有效）<br>4. `MeshRefineParams` 新增 `mode`、`color_model`，移除 `enable_detail_preserve`<br>5. `TemplateParams` 新增 `seg_params_2d`、`go_rigging_params`<br>6. `ModelInfo` 新增 `input_view`、`wait_time`、`framing_ai_output` 字段<br>7. 骨骼架设：调用参数 `params.go_rigging_params` 中 `algorithm_model` 必传，`template_skeleton` 可选<br>8. 发布 Python SDK v1.0.1（GitHub 仓库直装） |
| **1.0.0** | 2026-04 | 初始版本，覆盖图生360 / 图生模（高/中/低）/ 布线重建 / 重拓扑 / LOD / UV / 贴图纹理 / 智能骨骼架设 / 智能 蒙皮 / 3D动画生成 / 图生Pose 等 13 类节点。 |
