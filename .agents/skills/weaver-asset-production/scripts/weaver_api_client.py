"""Minimal standard-library VISVISE Weaver OpenAPI client.

No credentials or signed URLs are written to logs. Network calls are explicit;
importing this module is side-effect free.
"""
from __future__ import annotations
import hashlib, hmac, json, mimetypes, os, time, urllib.error, urllib.parse, urllib.request, uuid
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Callable, Mapping

DEFAULT_BASE_URL = "https://ws.visvise.com.cn/openapi"

class WeaverError(RuntimeError): pass
class WeaverHTTPError(WeaverError):
    def __init__(self, status: int, message: str):
        super().__init__(f"HTTP {status}: {message}"); self.status = status
class WeaverAPIError(WeaverError):
    def __init__(self, code: int, message: str, req_id: str | None = None):
        super().__init__(f"Weaver code {code}: {message}"); self.code=code; self.req_id=req_id

@dataclass(frozen=True)
class CosCredential:
    tmp_secret_id: str; tmp_secret_key: str; session_token: str
    start_time: int; expired_time: int; bucket: str; region: str; path_prefix: str

def _json_bytes(value: Mapping[str, Any] | None) -> bytes:
    return json.dumps(value or {}, ensure_ascii=False, separators=(",", ":")).encode("utf-8")

def _query_pairs(query: Mapping[str, Any] | None) -> list[tuple[str, str]]:
    """Return the exact sorted query pairs used by both URL and GET signing.

    Weaver's documented GET rule signs the serialized query string followed by
    ``ts``.  Keeping URL serialization and signature serialization in one
    helper prevents a signed query from differing from the bytes on the wire.
    Lists are expanded in order (the same behaviour as ``urlencode(...,
    doseq=True)``); callers should avoid unordered values in a signed query.
    """
    pairs: list[tuple[str, str]] = []
    for key, value in (query or {}).items():
        if isinstance(value, (list, tuple)):
            pairs.extend((str(key), str(item)) for item in value)
        else:
            pairs.append((str(key), str(value)))
    return sorted(pairs)

def _query_string(query: Mapping[str, Any] | None) -> str:
    return urllib.parse.urlencode(_query_pairs(query), doseq=True)

class WeaverClient:
    def __init__(self, app_id: str, secret_key: str, base_url: str = DEFAULT_BASE_URL,
                 opener: Callable[..., Any] | None = None, timeout: float = 60):
        if not app_id or not secret_key: raise ValueError("app_id and secret_key are required")
        self.app_id, self.secret_key = app_id, secret_key
        self.base_url = base_url.rstrip("/"); self.opener = opener or urllib.request.urlopen; self.timeout=timeout

    def _headers(self, method: str, body: bytes, rtx: str, query: Mapping[str, Any] | None = None) -> dict[str,str]:
        ts = str(int(time.time()))
        if method == "GET":
            material = _query_string(query) + ts
        else: material = body.decode("utf-8") + ts
        sign = hmac.new(self.secret_key.encode(), material.encode(), hashlib.sha256).hexdigest()
        return {"app_id": self.app_id, "rtx": rtx, "ts": ts, "sign": sign, "Content-Type":"application/json"}

    def request(self, path: str, payload: Mapping[str, Any] | None = None, *, rtx: str,
                method: str = "POST") -> Any:
        if not rtx: raise ValueError("rtx is required and must identify the actual caller")
        method = method.upper(); body = _json_bytes(payload) if method != "GET" else b""
        url = self.base_url + "/" + path.lstrip("/")
        query = payload if method == "GET" else None
        if query: url += "?" + _query_string(query)
        req = urllib.request.Request(url, data=None if method == "GET" else body,
                                     headers=self._headers(method, body, rtx, query), method=method)
        try:
            with self.opener(req, timeout=self.timeout) as response: raw = response.read()
        except urllib.error.HTTPError as exc:
            raise WeaverHTTPError(exc.code, "server rejected request") from exc
        except urllib.error.URLError as exc: raise WeaverError("network request failed") from exc
        try: envelope = json.loads(raw.decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError) as exc: raise WeaverError("invalid JSON response") from exc
        if envelope.get("code", 0) != 0: raise WeaverAPIError(envelope.get("code", -1), envelope.get("msg", "error"), envelope.get("req_id"))
        return envelope.get("data")

    def get_cos_cred(self, *, rtx: str, is_temp: bool | None = None, is_public: bool | None = None) -> CosCredential:
        payload = {k:v for k,v in (("is_temp",is_temp),("is_public",is_public)) if v is not None}
        d=self.request("weaver/resource/get_cos_cred",payload,rtx=rtx); c=d["cred"]
        return CosCredential(c["tmp_secret_id"],c["tmp_secret_key"],c["session_token"],d["start_time"],d["expired_time"],d["bucket"],d["region"],d["path_prefix"])
    def get_user_quota(self, *, rtx: str) -> dict[str,Any]: return self.request("weaver/resource/get_user_quota",{},rtx=rtx)
    def gen_3d_model(self, *, name: str, node_type: int, params: Mapping[str,Any], rtx: str, input_view: Mapping[str,Any] | None=None, input_model: str | None=None, input_model_format: str | None=None, input_video: str | None=None) -> list[str]:
        p={"name":name,"node_type":node_type,"params":params}; p.update({k:v for k,v in (("input_view",input_view),("input_model",input_model),("input_model_format",input_model_format),("input_video",input_video)) if v is not None}); return self.request("weaver/resource/gen_3d_model",p,rtx=rtx)["model_ids"]
    def gen_multi_views(self, *, name: str, input_view: Mapping[str,Any], params: Mapping[str,Any], rtx: str) -> str: return self.request("weaver/resource/gen_multi_views",{"name":name,"input_view":input_view,"params":params},rtx=rtx)["model_id"]
    def get_model_list(self, *, rtx: str, **filters: Any) -> tuple[list[dict[str,Any]], int]:
        d=self.request("weaver/resource/get_model_list",filters,rtx=rtx); return d.get("model_list",[]),d.get("total_count",0)
    def list_algorithm_model(self, *, node_type: int, rtx: str, sub_type: int | None=None) -> list[str]:
        p={"node_type":node_type};
        if sub_type is not None: p["type"]=sub_type
        return self.request("weaver/resource/list_algorithm_model",p,rtx=rtx)["model_list"]
    def download_model(self, *, model_id: str, rtx: str) -> str: return self.request("weaver/resource/download_model",{"model_id":model_id},rtx=rtx)
    def wait_model(self, model_id: str, *, rtx: str, interval: float=5, timeout: float=600) -> dict[str,Any]:
        deadline=time.monotonic()+timeout
        while time.monotonic() < deadline:
            # The API's documented page default is 20.  Keep a normal page
            # size while filtering by model_id; some deployments reject a
            # limit of 1 even though only one row is expected.
            rows,_=self.get_model_list(model_id_list=[model_id],limit=20,rtx=rtx)
            if rows:
                model=rows[0]; status=model.get("status")
                if status == 3: return model
                if status == 4: raise WeaverError(f"model {model_id} failed")
            time.sleep(interval)
        raise TimeoutError(f"model {model_id} did not finish before timeout")

    def upload_file(self, local_path: str | os.PathLike[str], cred: CosCredential, *, object_name: str | None=None) -> str:
        path=Path(local_path); object_name=object_name or (cred.path_prefix.rstrip("/")+"/"+uuid.uuid4().hex+"-"+path.name)
        if not object_name.startswith(cred.path_prefix): raise ValueError("object_name must be under path_prefix")
        host=f"{cred.bucket}.cos.{cred.region}.myqcloud.com"; target="/"+urllib.parse.quote(object_name.lstrip("/"),safe="/-_.~")
        start=str(int(time.time())); end=str(int(time.time())+900); sign_time=f"{start};{end}"
        sign_key=hmac.new(cred.tmp_secret_key.encode(),sign_time.encode(),hashlib.sha1).hexdigest()
        # ``host`` is declared in q-header-list, so it must also be present in
        # the canonical header section of the signed HTTP string.  Keeping the
        # two in sync is required by COS; x-cos-security-token is a transport
        # header and is deliberately not part of the signed list.
        http_string=f"put\n{target}\n\nhost={host}\n"; sha=hashlib.sha1(http_string.encode()).hexdigest()
        string_to_sign=f"sha1\n{sign_time}\n{sha}\n"; signature=hmac.new(sign_key.encode(),string_to_sign.encode(),hashlib.sha1).hexdigest()
        auth=f"q-sign-algorithm=sha1&q-ak={cred.tmp_secret_id}&q-sign-time={sign_time}&q-key-time={sign_time}&q-header-list=host&q-url-param-list=&q-signature={signature}"
        data=path.read_bytes(); req=urllib.request.Request("https://"+host+target,data=data,method="PUT",headers={"Host":host,"Authorization":auth,"x-cos-security-token":cred.session_token,"Content-Type":mimetypes.guess_type(path.name)[0] or "application/octet-stream"})
        try:
            with self.opener(req,timeout=self.timeout) as response: response.read()
        except (urllib.error.HTTPError,urllib.error.URLError) as exc: raise WeaverError("COS upload failed") from exc
        return "https://"+host+target

    def download_file(self, url: str, destination: str | os.PathLike[str], *, chunk_size: int=1024*1024) -> Path:
        dest=Path(destination); dest.parent.mkdir(parents=True,exist_ok=True); current=dest.stat().st_size if dest.exists() else 0
        headers={"Range":f"bytes={current}-"} if current else {}
        req=urllib.request.Request(url,headers=headers)
        try:
            with self.opener(req,timeout=self.timeout) as response:
                mode="ab" if current and getattr(response,"status",200)==206 else "wb"
                with dest.open(mode) as out:
                    while chunk:=response.read(chunk_size): out.write(chunk)
        except (urllib.error.HTTPError,urllib.error.URLError) as exc: raise WeaverError("download failed") from exc
        return dest
