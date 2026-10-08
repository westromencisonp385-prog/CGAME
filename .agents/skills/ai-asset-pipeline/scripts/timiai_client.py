# -*- coding: utf-8 -*-
"""TIMIAI 统一客户端：image2 生图（Nano Banana / GPT-Image-2）+ Tripo / Meshy 3D 任务。

所有请求走公司内网 http://api.timiai.woa.com，API Key 读取顺序：
  1) 环境变量 TIMIAI_API_KEY
  2) D:/工作/生图API/apikey.txt

关键事实（来自官方使用文档，2026-10 验证）：
  - key 失效返回 {"code": 304, "message": "api_key 禁用状态"}：先 check_key() 再批量提交。
  - Tripo：text2model / image2model / multiview2model 都是「提交→轮询」；模型 URL 5 分钟过期，
    成功后必须立刻下载。image2model 的 file 只收 HTTP(S) URL（本地图请改走 Meshy）。
  - Meshy：image_url 支持 Data URI（base64 直传本地文件）；preview→refine 两段式精修；
    multiview 必须 [front, left, back, right] 顺序、不能少于 2 张、正视图必传。
"""
import os
import sys
import base64
import json
import time
import mimetypes

try:
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")
except Exception:
    pass

import requests

BASE_URL = "http://api.timiai.woa.com"
KEY_FALLBACK_PATH = r"D:\工作\生图API\apikey.txt"

TRIPO = {
    "text2model": f"{BASE_URL}/ai_api_manage/tripo3d/text2model",
    "image2model": f"{BASE_URL}/ai_api_manage/tripo3d/image2model",
    "multiview2model": f"{BASE_URL}/ai_api_manage/tripo3d/multiview2model",
    "query": f"{BASE_URL}/ai_api_manage/tripo3d/models/generations/{{task_id}}",
}
MESHY = {
    "text2model_preview": f"{BASE_URL}/ai_api_manage/meshy3d/preview/text2model",
    "text2model_refine": f"{BASE_URL}/ai_api_manage/meshy3d/refine/text2model",
    "image2model": f"{BASE_URL}/ai_api_manage/meshy3d/image2model",
    "multiview2model": f"{BASE_URL}/ai_api_manage/meshy3d/multiview2model",
}


def read_apikey() -> str:
    key = os.environ.get("TIMIAI_API_KEY", "").strip()
    if key:
        return key
    with open(KEY_FALLBACK_PATH, encoding="utf-8") as f:
        return f.read().strip()


class TimiaiError(RuntimeError):
    pass


class TimiaiClient:
    def __init__(self, apikey: str = None, timeout: int = 180):
        self.key = apikey or read_apikey()
        self.timeout = timeout

    # ---------------- 基础 ----------------
    def _headers(self):
        return {"Content-Type": "application/json", "Authorization": self.key}

    def check_key(self) -> bool:
        """零成本鉴权探测：查询一个必然不存在的 UUID 任务。
        code 2001 = key 有效（任务不存在）；消息含「禁用」= key 被禁用。
        注意：网关会把非 UUID 的 task_id 报成 code 304，所以探测 ID 必须是合法 UUID。"""
        r = requests.get(
            TRIPO["query"].format(task_id="00000000-0000-0000-0000-000000000000"),
            headers=self._headers(), timeout=30)
        j = r.json()
        code = j.get("code")
        msg = str(j.get("message", ""))
        if "禁用" in msg:
            raise TimiaiError(f"API key 已禁用：{msg}。请到平台重新启用/换 key。")
        if code == 2001 or "not found" in msg.lower() or "不存在" in msg or "invalid task_id" in msg:
            return True
        if code == 304:
            raise TimiaiError(f"API key 校验未通过(code 304)：{msg}")
        # 未知响应：打印供人工判断，不直接判定失败
        print(f"[check_key] 意外响应 HTTP {r.status_code}: {r.text[:200]}")
        return True

    # ---------------- image2 生图 ----------------
    @staticmethod
    def _to_data_url(path: str) -> str:
        mime = mimetypes.guess_type(path)[0] or "image/png"
        with open(path, "rb") as f:
            return f"data:{mime};base64,{base64.b64encode(f.read()).decode()}"

    def gen_image_nano(self, prompt: str, out_path: str, ref_paths=None,
                       aspect_ratio: str = "1:1", image_size: str = "2K",
                       model: str = "gemini-3-pro-image-preview") -> str:
        """Nano Banana（gemini-3-pro-image-preview）：支持多参考图，一致性最强，主力路线。"""
        content = [{"type": "text", "text": prompt}]
        for rp in (ref_paths or []):
            content.append({"type": "image_url", "image_url": {"url": self._to_data_url(rp)}})
        payload = {
            "model": model,
            "messages": [{"role": "user", "content": content}],
            "image_config": {"aspect_ratio": aspect_ratio, "image_size": image_size},
            "response_modalities": ["IMAGE", "TEXT"],
        }
        r = requests.post(f"{BASE_URL}/ai_api_manage/llmproxy/chat/completions",
                          headers=self._headers(), data=json.dumps(payload), timeout=self.timeout)
        r.raise_for_status()
        j = r.json()
        if "error" in j:
            raise TimiaiError(f"nano 失败: {j['error']}")
        url = j["choices"][0]["message"]["images"][0]["image_url"]["url"]
        data = base64.b64decode(url.split(",", 1)[1]) if "," in url else base64.b64decode(url)
        os.makedirs(os.path.dirname(os.path.abspath(out_path)), exist_ok=True)
        with open(out_path, "wb") as f:
            f.write(data)
        return out_path

    def gen_image_gpt(self, prompt: str, out_path: str, size: str = "1024x1024",
                      quality: str = "high", model: str = "gpt-image-2-r1") -> str:
        """GPT-Image-2：纯文生图兜底（不支持参考图）。size 如 1024x1536。"""
        payload = {"model": model, "prompt": prompt, "n": 1, "size": size,
                   "quality": quality, "output_format": "png"}
        r = requests.post(f"{BASE_URL}/ai_api_manage/llmproxy/images/generations",
                          headers=self._headers(), data=json.dumps(payload), timeout=self.timeout)
        r.raise_for_status()
        j = r.json()
        data = base64.b64decode(j["data"][0]["b64_json"])
        os.makedirs(os.path.dirname(os.path.abspath(out_path)), exist_ok=True)
        with open(out_path, "wb") as f:
            f.write(data)
        return out_path

    # ---------------- Tripo ----------------
    def tripo_submit(self, kind: str, payload: dict) -> str:
        """提交 Tripo 任务，返回 task_id。kind: text2model|image2model|multiview2model"""
        r = requests.post(TRIPO[kind], headers=self._headers(),
                          data=json.dumps(payload), timeout=60)
        r.raise_for_status()
        j = r.json()
        if j.get("code") != 0:
            raise TimiaiError(f"Tripo 提交失败 code={j.get('code')}: {j.get('message')}")
        return j["data"]["task_id"]

    def tripo_poll(self, task_id: str, interval: int = 10, max_minutes: int = 15) -> dict:
        """轮询到终态（success/failed/...），返回 data。"""
        url = TRIPO["query"].format(task_id=task_id)
        deadline = time.time() + max_minutes * 60
        while time.time() < deadline:
            r = requests.get(url, headers=self._headers(), timeout=60)
            j = r.json()
            if j.get("code") != 0:
                raise TimiaiError(f"Tripo 查询失败 code={j.get('code')}: {j.get('message')}")
            data = j["data"]
            status = data.get("status")
            if status == "success":
                return data
            if status in ("failed", "cancelled", "banned"):
                raise TimiaiError(f"Tripo 任务终态 {status}: {data.get('message', '')}")
            print(f"  [tripo] {status} progress={data.get('progress')}", flush=True)
            time.sleep(interval)
        raise TimiaiError("Tripo 轮询超时")

    @staticmethod
    def download(url: str, out_path: str) -> str:
        """下载并保存（Tripo 模型 URL 5 分钟过期，成功后必须立刻调用）。"""
        r = requests.get(url, timeout=300)
        r.raise_for_status()
        os.makedirs(os.path.dirname(os.path.abspath(out_path)), exist_ok=True)
        with open(out_path, "wb") as f:
            f.write(r.content)
        return out_path

    def tripo_text2model(self, prompt: str, out_path: str = None, negative_prompt: str = None,
                         model_version: str = "v2.5-20250123", face_limit: int = None,
                         texture: bool = True, pbr: bool = True, quad: bool = False,
                         smart_low_poly: bool = False, **kw) -> dict:
        """文生模型。face_limit 1000~20000（quad 时 500~8000）。out_path 给了就自动轮询+下载 GLB。"""
        payload = {"type": "text_to_model", "prompt": prompt[:1024],
                   "model_version": model_version, "texture": texture, "pbr": pbr, "quad": quad,
                   "smart_low_poly": smart_low_poly, **kw}
        if negative_prompt:
            payload["negative_prompt"] = negative_prompt[:255]
        if face_limit:
            payload["face_limit"] = face_limit
        task_id = self.tripo_submit("text2model", payload)
        print(f"[tripo] task_id={task_id}")
        if not out_path:
            return {"task_id": task_id}
        data = self.tripo_poll(task_id)
        model_url = data["output"].get("pbr_model") or data["output"].get("base_model")
        self.download(model_url, out_path)
        return {"task_id": task_id, "model": out_path, "output": data["output"]}

    # ---------------- Meshy ----------------
    def meshy_submit(self, kind: str, payload: dict) -> str:
        """提交 Meshy 任务，返回 task_id（响应体 result 字段）。"""
        r = requests.post(MESHY[kind], headers=self._headers(),
                          data=json.dumps(payload), timeout=60)
        if r.status_code not in (200, 202):
            raise TimiaiError(f"Meshy 提交失败 HTTP {r.status_code}: {r.text[:300]}")
        j = r.json()
        task_id = j.get("result") or j.get("task_id")
        if not task_id:
            raise TimiaiError(f"Meshy 响应无 task_id: {str(j)[:300]}")
        return task_id

    def meshy_poll(self, kind: str, task_id: str, interval: int = 10, max_minutes: int = 20) -> dict:
        """轮询 Meshy 任务（GET 同端点 ?task_id=）。"""
        url = MESHY[kind]
        deadline = time.time() + max_minutes * 60
        while time.time() < deadline:
            r = requests.get(url, params={"task_id": task_id}, headers=self._headers(), timeout=60)
            j = r.json()
            status = (j.get("status") or j.get("data", {}).get("status") or "").upper()
            if status in ("SUCCEEDED", "SUCCESS"):
                return j.get("data", j)
            if status in ("FAILED", "CANCELED", "CANCELLED", "BANNED"):
                raise TimiaiError(f"Meshy 任务终态 {status}: {str(j)[:300]}")
            print(f"  [meshy] {status or j}", flush=True)
            time.sleep(interval)
        raise TimiaiError("Meshy 轮询超时")

    def meshy_image2model(self, image_path_or_url: str, out_path: str = None,
                          model_type: str = "standard", **kw) -> dict:
        """图生模型。本地路径自动转 Data URI（Meshy 独有优势）；URL 直接透传。"""
        if image_path_or_url.startswith(("http://", "https://", "data:")):
            image_url = image_path_or_url
        else:
            image_url = self._to_data_url(image_path_or_url)
        payload = {"image_url": image_url, "model_type": model_type, **kw}
        task_id = self.meshy_submit("image2model", payload)
        print(f"[meshy] task_id={task_id}")
        if not out_path:
            return {"task_id": task_id}
        data = self.meshy_poll("image2model", task_id)
        out = data.get("model_urls") or data.get("output") or data
        model_url = out.get("glb") or out.get("model") or out.get("pbr_model")
        if not model_url:
            raise TimiaiError(f"Meshy 成功但找不到模型 URL: {str(data)[:400]}")
        self.download(model_url, out_path)
        return {"task_id": task_id, "model": out_path}

    def meshy_multiview2model(self, image_paths, out_path: str = None, **kw) -> dict:
        """多视图生模型。必须按 [front, left, back, right] 顺序；>=2 张；正视图必传。"""
        files = []
        for p in image_paths:
            if p.startswith(("http://", "https://")):
                files.append({"type": "png", "url": p})
            else:
                files.append({"type": "png", "url": self._to_data_url(p)})
        payload = {"files": files, **kw}
        task_id = self.meshy_submit("multiview2model", payload)
        print(f"[meshy] task_id={task_id}")
        if not out_path:
            return {"task_id": task_id}
        data = self.meshy_poll("multiview2model", task_id)
        out = data.get("model_urls") or data.get("output") or data
        model_url = out.get("glb") or out.get("model")
        self.download(model_url, out_path)
        return {"task_id": task_id, "model": out_path}


if __name__ == "__main__":
    c = TimiaiClient()
    ok = c.check_key()
    print("API key 有效" if ok else "key 状态未知")
