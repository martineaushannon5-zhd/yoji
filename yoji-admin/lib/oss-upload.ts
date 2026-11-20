import { api } from "./axios";
import type { UploadTicket } from "./types";

interface Envelope<T> {
  code: number;
  message: string;
  data: T;
}

/**
 * 浏览器直传阿里云 OSS。
 *
 * 流程：向后台要一次性 policy/signature → 自己 POST 到 OSS → 返回公网 URL。
 * 好处：视频字节不经过 ECS，不占服务器磁盘，也不吃 2C2G 机器的出口带宽。
 * 前提：Bucket 的 CORS 允许后台域名（见 工作流/09-视频迁移到OSS.md）。
 */
export async function uploadFileToOss(
  file: File,
  kind: "video" | "thumb",
  onProgress?: (percent: number) => void
): Promise<string> {
  const { data } = await api.post<Envelope<UploadTicket>>("/admin/media/sign", {
    kind,
    filename: file.name,
  });
  if (data.code !== 0) {
    throw new Error(data.message || "获取上传签名失败");
  }
  const ticket = data.data;

  const form = new FormData();
  // 顺序有要求：file 必须最后 append
  form.append("key", ticket.key);
  form.append("policy", ticket.policy);
  form.append("OSSAccessKeyId", ticket.accessKeyId);
  form.append("signature", ticket.signature);
  form.append("success_action_status", "200");
  form.append("file", file);

  await new Promise<void>((resolve, reject) => {
    const xhr = new XMLHttpRequest();
    xhr.open("POST", ticket.host, true);
    xhr.upload.onprogress = (event) => {
      if (event.lengthComputable && onProgress) {
        onProgress(Math.min(99, Math.round((event.loaded / event.total) * 100)));
      }
    };
    xhr.onload = () => {
      if (xhr.status >= 200 && xhr.status < 300) {
        onProgress?.(100);
        resolve();
        return;
      }
      reject(new Error(`OSS 上传失败（HTTP ${xhr.status}），请检查 Bucket 权限与签名配置`));
    };
    xhr.onerror = () =>
      reject(new Error("OSS 上传网络错误：请确认 Bucket 已配置 CORS 且允许本站域名"));
    xhr.send(form);
  });

  return ticket.publicUrl;
}