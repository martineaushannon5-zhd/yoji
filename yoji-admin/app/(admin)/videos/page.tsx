"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import useSWR from "swr";
import {
  Clapperboard,
  ExternalLink,
  Eye,
  EyeOff,
  Image as ImageIcon,
  Loader2,
  Pencil,
  Trash2,
  UploadCloud,
  X,
} from "lucide-react";

import { api, getApiErrorMessage, resolveMediaUrl } from "@/lib/axios";
import { fetcher } from "@/lib/fetcher";
import { formatDate } from "@/lib/format";
import type { AdminVideo, AdminVideosPayload } from "@/lib/types";
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
  AlertDialogTrigger,
} from "@/components/ui/alert-dialog";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Skeleton } from "@/components/ui/skeleton";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";

const today = () => new Date().toISOString().slice(0, 10);

interface FormState {
  title: string;
  description: string;
  date: string;
  sortOrder: string;
  visible: boolean;
}

const EMPTY_FORM: FormState = {
  title: "",
  description: "",
  date: today(),
  sortOrder: "0",
  visible: true,
};

export default function VideosPage() {
  const { data, error, isLoading, mutate } = useSWR<AdminVideosPayload>(
    "/admin/videos",
    fetcher,
    { revalidateOnFocus: true }
  );
  const [form, setForm] = useState<FormState>(EMPTY_FORM);
  const [videoFile, setVideoFile] = useState<File | null>(null);
  const [coverFile, setCoverFile] = useState<File | null>(null);
  const [coverPreview, setCoverPreview] = useState("");
  const [editing, setEditing] = useState<AdminVideo | null>(null);
  const [busy, setBusy] = useState(false);
  const [progress, setProgress] = useState(0);
  const [message, setMessage] = useState("");
  const [actionError, setActionError] = useState("");
  const videoInputRef = useRef<HTMLInputElement>(null);
  const coverInputRef = useRef<HTMLInputElement>(null);

  const videos = data?.videos ?? [];
  const maxSort = useMemo(
    () => Math.max(0, ...videos.map((item) => Number(item.sortOrder) || 0)),
    [videos]
  );

  useEffect(() => {
    if (!editing) {
      setForm((current) => ({ ...current, sortOrder: String(maxSort + 1) }));
    }
  }, [maxSort, editing]);

  useEffect(() => {
    return () => {
      if (coverPreview.startsWith("blob:")) {
        URL.revokeObjectURL(coverPreview);
      }
    };
  }, [coverPreview]);

  function resetForm() {
    setEditing(null);
    setForm({ ...EMPTY_FORM, sortOrder: String(maxSort + 1) });
    setVideoFile(null);
    setCoverFile(null);
    setCoverPreview("");
    setProgress(0);
    if (videoInputRef.current) videoInputRef.current.value = "";
    if (coverInputRef.current) coverInputRef.current.value = "";
  }

  function chooseVideo(file: File | null) {
    setVideoFile(file);
    setActionError("");
    setMessage("");
    if (file && form.title.trim() === "") {
      const base = file.name.replace(/\.[^.]+$/, "").replace(/[_-]+/g, " ");
      setForm((current) => ({ ...current, title: base }));
    }
  }

  function chooseCover(file: File | null) {
    setCoverFile(file);
    setActionError("");
    if (coverPreview.startsWith("blob:")) {
      URL.revokeObjectURL(coverPreview);
    }
    setCoverPreview(file ? URL.createObjectURL(file) : "");
  }

  function startEdit(video: AdminVideo) {
    setEditing(video);
    setForm({
      title: video.title,
      description: video.description || "",
      date: video.date,
      sortOrder: String(video.sortOrder),
      visible: video.visible,
    });
    setVideoFile(null);
    setCoverFile(null);
    setCoverPreview(video.thumbUrl ? resolveMediaUrl(video.thumbUrl) : "");
    setActionError("");
    setMessage("");
    window.scrollTo({ top: 0, behavior: "smooth" });
  }

  async function submit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (busy) return;
    if (!form.title.trim()) {
      setActionError("请填写视频标题");
      return;
    }
    if (!editing && !videoFile) {
      setActionError("请选择视频文件");
      return;
    }
    if (videoFile && videoFile.size > 900 * 1024 * 1024) {
      setActionError("视频不能超过 900MB");
      return;
    }
    if (coverFile && coverFile.size > 5 * 1024 * 1024) {
      setActionError("封面不能超过 5MB");
      return;
    }

    setBusy(true);
    setActionError("");
    setMessage("");
    setProgress(0);
    try {
      if (editing) {
        await api.patch(`/admin/videos/${editing.id}`, {
          title: form.title.trim(),
          description: form.description,
          date: form.date,
          sortOrder: Number(form.sortOrder) || 0,
          visible: form.visible,
        });
        setMessage("视频信息已更新");
      } else {
        const body = new FormData();
        body.append("title", form.title.trim());
        body.append("description", form.description);
        body.append("date", form.date);
        body.append("sortOrder", String(Number(form.sortOrder) || 0));
        body.append("visible", String(form.visible));
        body.append("video", videoFile as File);
        if (coverFile) {
          body.append("cover", coverFile);
        }
        await api.post("/admin/videos/upload", body, {
          headers: { "Content-Type": "multipart/form-data" },
          // 大视频上传可能持续几分钟，不能被全局 20s 超时打断
          timeout: 60 * 60 * 1000,
          maxBodyLength: Infinity,
          maxContentLength: Infinity,
          onUploadProgress: (event) => {
            if (event.total) {
              setProgress(Math.min(99, Math.round((event.loaded / event.total) * 100)));
            }
          },
        });
        setProgress(100);
        setMessage("视频已上传并加入列表");
      }
      resetForm();
      await mutate();
    } catch (err) {
      setActionError(getApiErrorMessage(err));
    } finally {
      setBusy(false);
    }
  }

  async function toggleVisible(video: AdminVideo) {
    setActionError("");
    try {
      await api.patch(`/admin/videos/${video.id}`, { visible: !video.visible });
      await mutate();
    } catch (err) {
      setActionError(getApiErrorMessage(err));
    }
  }

  async function remove(video: AdminVideo) {
    setActionError("");
    try {
      await api.delete(`/admin/videos/${video.id}`);
      if (editing?.id === video.id) {
        resetForm();
      }
      await mutate();
      setMessage("视频已删除");
    } catch (err) {
      setActionError(getApiErrorMessage(err));
    }
  }

  return (
    <div className="space-y-6">
      <div>
        <p className="flex items-center gap-2 text-[11px] uppercase tracking-[0.24em] text-terracotta">
          <Clapperboard className="size-3.5" />
          Video Learning
        </p>
        <h2 className="mt-2 font-serif text-3xl tracking-tight text-ink">视频管理</h2>
        <p className="mt-2 max-w-2xl text-sm leading-6 text-muted-foreground">
          在浏览器里直接上传视频和封面，App 的视频学习列表会立即读到新内容。
        </p>
      </div>

      {actionError ? (
        <div className="rounded-lg border border-destructive/20 bg-destructive/5 px-4 py-3 text-[13px] text-destructive">
          {actionError}
        </div>
      ) : null}
      {message ? (
        <div className="rounded-lg border border-emerald-200 bg-emerald-50 px-4 py-3 text-[13px] text-emerald-700">
          {message}
        </div>
      ) : null}

      <div className="grid gap-6 xl:grid-cols-[380px_1fr]">
        <Card className="h-fit rounded-xl border-border bg-card shadow-soft xl:sticky xl:top-24">
          <CardHeader className="flex flex-row items-center justify-between space-y-0 border-b border-border px-5 py-4">
            <div>
              <CardTitle className="text-base">{editing ? "编辑视频信息" : "上传新视频"}</CardTitle>
              <p className="mt-1 text-[11px] text-muted-foreground">
                {editing ? "修改标题、日期与排序" : "支持 mp4 / webm / m4v，最大 900MB"}
              </p>
            </div>
            {editing ? (
              <Button
                type="button"
                variant="ghost"
                size="icon"
                className="size-8 rounded-lg"
                onClick={resetForm}
                aria-label="取消编辑"
              >
                <X className="size-4" />
              </Button>
            ) : null}
          </CardHeader>

          <CardContent className="p-5">
            <form onSubmit={submit} className="space-y-4">
            {!editing ? (
              <>
                <div className="space-y-2">
                  <Label htmlFor="video-file">视频文件</Label>
                  <input
                    id="video-file"
                    ref={videoInputRef}
                    type="file"
                    accept="video/mp4,video/webm,video/x-m4v"
                    onChange={(event) => chooseVideo(event.target.files?.[0] ?? null)}
                    className="block w-full cursor-pointer rounded-lg border border-dashed border-border bg-background px-3 py-3 text-[12px] text-muted-foreground file:mr-3 file:rounded-full file:border-0 file:bg-accent file:px-3 file:py-1.5 file:text-[11px] file:font-medium file:text-accent-foreground hover:border-terracotta/40"
                  />
                  {videoFile ? (
                    <p className="text-[11px] text-muted-foreground">
                      {videoFile.name} · {(videoFile.size / 1024 / 1024).toFixed(1)} MB
                    </p>
                  ) : null}
                </div>

                <div className="space-y-2">
                  <Label htmlFor="cover-file">封面（可选）</Label>
                  <input
                    id="cover-file"
                    ref={coverInputRef}
                    type="file"
                    accept="image/png,image/jpeg,image/webp"
                    onChange={(event) => chooseCover(event.target.files?.[0] ?? null)}
                    className="block w-full cursor-pointer rounded-lg border border-dashed border-border bg-background px-3 py-3 text-[12px] text-muted-foreground file:mr-3 file:rounded-full file:border-0 file:bg-muted file:px-3 file:py-1.5 file:text-[11px] file:font-medium file:text-ink hover:border-terracotta/40"
                  />
                  {coverPreview ? (
                    <div className="relative mt-2 aspect-video w-full overflow-hidden rounded-lg border border-border bg-muted">
                      <img src={coverPreview} alt="封面预览" className="size-full object-cover" />
                    </div>
                  ) : null}
                </div>
              </>
            ) : (
              <div className="space-y-2">
                <Label>当前封面</Label>
                <div className="aspect-video overflow-hidden rounded-lg border border-border bg-muted">
                  {coverPreview ? (
                    <img src={coverPreview} alt="封面" className="size-full object-cover" />
                  ) : (
                    <div className="flex size-full items-center justify-center text-muted-foreground">
                      <ImageIcon className="size-6" />
                    </div>
                  )}
                </div>
                <a
                  href={resolveMediaUrl(editing.videoUrl)}
                  target="_blank"
                  rel="noreferrer"
                  className="inline-flex items-center gap-1 text-[11px] text-terracotta hover:underline"
                >
                  <ExternalLink className="size-3" />
                  预览当前视频
                </a>
              </div>
            )}

            <div className="space-y-2">
              <Label htmlFor="title">标题</Label>
              <Input
                id="title"
                value={form.title}
                onChange={(event) => setForm({ ...form, title: event.target.value })}
                placeholder="例如：TED-Ed 如何培养批判性思维"
                className="h-10 rounded-lg border-border bg-background"
              />
            </div>

            <div className="space-y-2">
              <Label htmlFor="description">简介</Label>
              <textarea
                id="description"
                value={form.description}
                onChange={(event) => setForm({ ...form, description: event.target.value })}
                placeholder="一句话描述这个视频"
                rows={2}
                className="w-full resize-none rounded-lg border border-border bg-background px-3 py-2 text-sm text-ink outline-none placeholder:text-muted-foreground focus:border-terracotta/50"
              />
            </div>

            <div className="grid grid-cols-2 gap-3">
              <div className="space-y-2">
                <Label htmlFor="date">日期</Label>
                <Input
                  id="date"
                  type="date"
                  value={form.date}
                  onChange={(event) => setForm({ ...form, date: event.target.value })}
                  className="h-10 rounded-lg border-border bg-background"
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="sort">排序</Label>
                <Input
                  id="sort"
                  type="number"
                  value={form.sortOrder}
                  onChange={(event) => setForm({ ...form, sortOrder: event.target.value })}
                  className="h-10 rounded-lg border-border bg-background"
                />
              </div>
            </div>

            <label className="flex items-center gap-2 text-[12px] text-muted-foreground">
              <input
                type="checkbox"
                checked={form.visible}
                onChange={(event) => setForm({ ...form, visible: event.target.checked })}
                className="size-4 accent-[#D97757]"
              />
              在 App 视频列表中显示
            </label>

            {busy && !editing ? (
              <div className="space-y-1">
                <div className="h-1.5 overflow-hidden rounded-full bg-muted">
                  <div
                    className="h-full rounded-full bg-terracotta transition-all"
                    style={{ width: `${progress}%` }}
                  />
                </div>
                <p className="text-right text-[10px] text-muted-foreground">{progress}%</p>
              </div>
            ) : null}

            <div className="flex gap-2">
              <Button
                type="submit"
                className="h-10 flex-1 rounded-full bg-primary text-primary-foreground hover:bg-primary/90"
                disabled={busy}
              >
                {busy ? <Loader2 className="size-4 animate-spin" /> : <UploadCloud className="size-4" />}
                {editing ? "保存修改" : "上传视频"}
              </Button>
              {editing ? (
                <Button
                  type="button"
                  variant="outline"
                  className="h-10 rounded-full border-border"
                  onClick={resetForm}
                >
                  取消
                </Button>
              ) : null}
            </div>
            </form>
          </CardContent>
        </Card>

        <Card className="overflow-hidden rounded-xl border-border bg-card shadow-soft">
          <CardHeader className="flex flex-row items-center justify-between space-y-0 border-b border-border px-5 py-4">
            <div>
              <CardTitle className="text-base">视频学习列表</CardTitle>
              <p className="mt-1 text-[11px] text-muted-foreground">
                共 {videos.length} 个视频，App 只显示“显示”状态的记录
              </p>
            </div>
            <Button
              type="button"
              variant="outline"
              size="sm"
              className="h-8 rounded-full border-border bg-background px-3 text-[11px]"
              onClick={() => mutate()}
            >
              刷新
            </Button>
          </CardHeader>

          <CardContent className="p-0">
            {error ? (
              <div className="p-6 text-sm text-destructive">视频列表加载失败，请刷新重试。</div>
            ) : null}

            <Table>
              <TableHeader>
                <TableRow className="border-border hover:bg-transparent">
                  <TableHead className="h-11 pl-5 text-[11px] uppercase tracking-[0.14em] text-muted-foreground">
                    视频
                  </TableHead>
                  <TableHead className="text-[11px] uppercase tracking-[0.14em] text-muted-foreground">
                    日期
                  </TableHead>
                  <TableHead className="text-[11px] uppercase tracking-[0.14em] text-muted-foreground">
                    排序
                  </TableHead>
                  <TableHead className="text-[11px] uppercase tracking-[0.14em] text-muted-foreground">
                    状态
                  </TableHead>
                  <TableHead className="pr-5 text-right text-[11px] uppercase tracking-[0.14em] text-muted-foreground">
                    操作
                  </TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {isLoading && videos.length === 0
                  ? Array.from({ length: 3 }).map((_, index) => (
                      <TableRow key={`skeleton-${index}`} className="border-border">
                        <TableCell className="pl-5">
                          <div className="flex items-center gap-3">
                            <Skeleton className="h-12 w-20 rounded-lg" />
                            <div className="space-y-2">
                              <Skeleton className="h-3.5 w-40" />
                              <Skeleton className="h-3 w-24" />
                            </div>
                          </div>
                        </TableCell>
                        <TableCell><Skeleton className="h-3.5 w-20" /></TableCell>
                        <TableCell><Skeleton className="h-3.5 w-8" /></TableCell>
                        <TableCell><Skeleton className="h-5 w-12 rounded-full" /></TableCell>
                        <TableCell className="pr-5"><Skeleton className="ml-auto h-8 w-20" /></TableCell>
                      </TableRow>
                    ))
                  : null}

                {!isLoading && videos.length === 0 ? (
                  <TableRow className="border-0 hover:bg-transparent">
                    <TableCell colSpan={5} className="py-16 text-center">
                      <div className="flex flex-col items-center gap-3">
                        <div className="flex size-11 items-center justify-center rounded-full bg-muted">
                          <Clapperboard className="size-5 text-muted-foreground" />
                        </div>
                        <p className="text-sm text-muted-foreground">还没有视频，先在左侧上传一个</p>
                      </div>
                    </TableCell>
                  </TableRow>
                ) : null}

                {videos.map((video) => (
                  <TableRow key={video.id} className="border-border transition-colors hover:bg-muted/40">
                    <TableCell className="pl-5">
                      <div className="flex items-center gap-3">
                        <div className="h-12 w-20 shrink-0 overflow-hidden rounded-lg border border-border bg-muted">
                          {video.thumbUrl ? (
                            <img
                              src={resolveMediaUrl(video.thumbUrl)}
                              alt={video.title}
                              className="size-full object-cover"
                            />
                          ) : (
                            <div className="flex size-full items-center justify-center text-muted-foreground">
                              <ImageIcon className="size-4" />
                            </div>
                          )}
                        </div>
                        <div className="min-w-0">
                          <p className="truncate text-[13px] font-medium text-ink">{video.title}</p>
                          <p className="mt-0.5 truncate text-[11px] text-muted-foreground">
                            {video.description || video.id}
                          </p>
                        </div>
                      </div>
                    </TableCell>
                    <TableCell className="text-[12px] text-muted-foreground">
                      {formatDate(video.date)}
                    </TableCell>
                    <TableCell className="text-[12px] text-muted-foreground">
                      {video.sortOrder}
                    </TableCell>
                    <TableCell>
                      <Badge
                        variant="secondary"
                        className={
                          video.visible
                            ? "rounded-full bg-emerald-50 text-[10px] font-normal text-emerald-700"
                            : "rounded-full bg-muted text-[10px] font-normal text-muted-foreground"
                        }
                      >
                        {video.visible ? "显示" : "隐藏"}
                      </Badge>
                    </TableCell>
                    <TableCell className="pr-5">
                      <div className="flex items-center justify-end gap-1">
                        <a
                          href={resolveMediaUrl(video.videoUrl)}
                          target="_blank"
                          rel="noreferrer"
                          className="rounded-lg p-1.5 text-muted-foreground hover:bg-muted hover:text-ink"
                          title="预览视频"
                        >
                          <ExternalLink className="size-3.5" />
                        </a>
                        <button
                          type="button"
                          className="rounded-lg p-1.5 text-muted-foreground hover:bg-muted hover:text-ink"
                          onClick={() => toggleVisible(video)}
                          title={video.visible ? "隐藏" : "显示"}
                        >
                          {video.visible ? <EyeOff className="size-3.5" /> : <Eye className="size-3.5" />}
                        </button>
                        <button
                          type="button"
                          className="rounded-lg p-1.5 text-muted-foreground hover:bg-muted hover:text-ink"
                          onClick={() => startEdit(video)}
                          title="编辑"
                        >
                          <Pencil className="size-3.5" />
                        </button>
                        <AlertDialog>
                          <AlertDialogTrigger asChild>
                            <button
                              type="button"
                              className="rounded-lg p-1.5 text-muted-foreground hover:bg-destructive/10 hover:text-destructive"
                              title="删除"
                            >
                              <Trash2 className="size-3.5" />
                            </button>
                          </AlertDialogTrigger>
                          <AlertDialogContent className="rounded-xl border-border bg-card">
                            <AlertDialogHeader>
                              <AlertDialogTitle className="font-serif text-xl">
                                删除视频？
                              </AlertDialogTitle>
                              <AlertDialogDescription className="text-sm leading-6 text-muted-foreground">
                                将删除「{video.title}」的数据库记录；服务器上的视频文件保留，可重新登记。
                              </AlertDialogDescription>
                            </AlertDialogHeader>
                            <AlertDialogFooter>
                              <AlertDialogCancel className="rounded-full">取消</AlertDialogCancel>
                              <AlertDialogAction
                                className="rounded-full bg-destructive text-destructive-foreground hover:bg-destructive/90"
                                onClick={() => remove(video)}
                              >
                                确认删除
                              </AlertDialogAction>
                            </AlertDialogFooter>
                          </AlertDialogContent>
                        </AlertDialog>
                      </div>
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
