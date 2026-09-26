# Weaver API index

Authoritative full schemas and examples: `docs/api/weaver-api-docs.md` in CGAME. Search that file by endpoint or heading before adding fields.

| Operation | Method/path | Data shape |
|---|---|---|
| COS credentials | POST `weaver/resource/get_cos_cred` | `{is_temp?, is_public?}` → `cred`, `start_time`, `expired_time`, `bucket`, `region`, `path_prefix` |
| Quota | POST `weaver/resource/get_user_quota` | `{}` → `model_quota`, `animation_quota`, `server_ts`, `image_processing_quota` |
| 3D task | POST `weaver/resource/gen_3d_model` | `name`, `node_type`, optional inputs, required `params` → `model_ids[]` |
| Multi-view | POST `weaver/resource/gen_multi_views` | `name`, `input_view`, `params` → `model_id` |
| List/poll | POST `weaver/resource/get_model_list` | filters such as `model_id_list`, `status_list`, pagination → `model_list`, counts |
| Algorithms | POST `weaver/resource/list_algorithm_model` | `node_type`, optional `type` → `model_list[]` |
| Download URL | POST `weaver/resource/download_model` | `model_id` → signed URL string |
| Delete | POST `weaver/resource/delete_model` / `batch_delete_model` | see full source |
| Image/background/Pose | POST `weaver/resource/remove_background` / `batch_gen_pose` | see full source |
| 2D split | POST `weaver/component/{init_segment,open_segment,begin_segment,segment,confirm_segment,cancel_segment,merge,auto_merge,boundary_adjust,save_segment,part_rename}` | see full source |
| Regenerate/preprocess | POST `weaver/resource/{regenerate_model,style_transfer,patter_auto_remove,gen_preprocess}` | see full source |

## Fixed rules

- Base URL is `https://ws.visvise.com.cn/openapi`.
- Headers are `app_id`, actual caller `rtx`, second timestamp `ts`, and lowercase hex HMAC-SHA256 `sign`.
- POST signature material is the exact UTF-8 JSON body followed by `ts`; GET material is ascending query parameters joined with `&`, followed by `ts`.
- Async model status `3` is success and `4` is failure. Poll every returned ID; LOD and Pose can return multiple IDs.
- Node types: 1 RTP, 2 LOD, 3 high model, 4 animation, 5 rigging, 6 skinning, 7 multi-view, 8 texture, 9 UV, 10 mesh refine, 11 mid model, 12 Pose, 13 low model (unavailable), 14 2D split, 15 2UV, 16 2D preprocess.
- COS uploads require temporary credentials. Model inputs are zip files. Signed URLs are temporary and should be consumed promptly.
