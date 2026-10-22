"use client";

import { useRef, useState } from "react";
import useSWR from "swr";
import {
  BookOpen,
  Eye,
  EyeOff,
  FileText,
  Loader2,
  Search,
  Trash2,
  UploadCloud,
  X,
} from "lucide-react";

import { api, getApiErrorMessage } from "@/lib/axios";
import { fetcher } from "@/lib/fetcher";
import type { AdminWordBook, AdminWordBookDetail, AdminWordBooksPayload } from "@/lib/types";
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

export default function WordBooksPage() {
  const { data, error, isLoading, mutate } = useSWR<AdminWordBooksPayload>(
    "/admin/wordbooks",
    fetcher,
    { revalidateOnFocus: true }
  );
  const [file, setFile] = useState<File | null>(null);
  const [name, setName] = useState("");
  const [subtitle, setSubtitle] = useState("");
  const [visible, setVisible] = useState(true);
  const [busy, setBusy] = useState(false);
  const [progress, setProgress] = useState(0);
  const [message, setMessage] = useState("");
  const [actionError, setActionError] = useState("");
  const [selected, setSelected] = useState<AdminWordBook | null>(null);
  const [keyword, setKeyword] = useState("");
  const fileRef = useRef<HTMLInputElement>(null);

  const bookDetail = useSWR<AdminWordBookDetail>(
    selected ? `/admin/wordbooks/${selected.id}` : null,
    fetcher
  );

  const books = data?.books ?? [];
  const shownWords = (bookDetail.data?.words ?? []).filter((word) => {
    const kw = keyword.trim().toLowerCase();
    return kw === "" || word.word.toLowerCase().includes(kw) || word.meaning.includes(kw);
  });

  function chooseFile(next: File | null) {
    setFile(next);
    setActionError("");
    setMessage("");
    if (next && name.trim() === "") {
      setName(next.name.replace(/\.[^.]+$/, ""));
    }
  }

  async function upload(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (busy) {
      return;
    }
    if (!file) {
      setActionError("请选择 .txt 或 .json 词表文件");
      return;
    }
    setBusy(true);
    setActionError("");
    setMessage("");
    setProgress(0);
    try {
      const body = new FormData();
      body.append("name", name.trim() || file.name.replace(/\.[^.]+$/, ""));
      body.append("subtitle", subtitle);
      body.append("visible", String(visible));
      body.append("file", file);
      await api.post("/admin/wordbooks/upload", body, {
        headers: { "Content-Type": "multipart/form-data" },
        timeout: 120000,
        onUploadProgress: (event) => {
          if (event.total) {
            setProgress(Math.round((event.loaded / event.total) * 100));
          }
        },
      });
      setFile(null);
      setName("");
      setSubtitle("");
      setVisible(true);
      setProgress(100);
      if (fileRef.current) fileRef.current.value = "";
      setMessage("词表已上传，App 下次启动会拉取到");
      await mutate();
    } catch (err) {
      setActionError(getApiErrorMessage(err));
    } finally {
      setBusy(false);
    }
  }

  async function toggleVisible(book: AdminWordBook) {
    setActionError("");
    try {
      await api.patch(`/admin/wordbooks/${book.id}`, { visible: !book.visible });
      await mutate();
      if (selected?.id === book.id) {
        setSelected({ ...book, visible: !book.visible });
      }
    } catch (err) {
      setActionError(getApiErrorMessage(err));
    }
  }

  async function remove(book: AdminWordBook) {
    setActionError("");
    try {
      await api.delete(`/admin/wordbooks/${book.id}`);
      if (selected?.id === book.id) {
        setSelected(null);
      }
      await mutate();
      setMessage("词表已删除");
    } catch (err) {
      setActionError(getApiErrorMessage(err));
    }
  }

  return (
    <div className="space-y-6">
      <div>
        <p className="flex items-center gap-2 text-[11px] uppercase tracking-[0.24em] text-terracotta">
          <BookOpen className="size-3.5" />
          Word Library
        </p>
        <h2 className="mt-2 font-serif text-3xl tracking-tight text-ink">词表管理</h2>
        <p className="mt-2 max-w-2xl text-sm leading-6 text-muted-foreground">
          查看 App 当前搭载的词表，上传新的 CET / 考研词表。App 启动时通过{" "}
          <code className="rounded bg-muted px-1.5 py-0.5 text-[11px]">/api/wordbooks/full</code>{" "}
          拉取启用的词表。
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
          <CardHeader className="border-b border-border px-5 py-4">
            <CardTitle className="text-base">上传词表</CardTitle>
            <p className="mt-1 text-[11px] text-muted-foreground">
              支持 .txt（每行一个词或 `word [音标] 释义`）和 .json
            </p>
          </CardHeader>
          <CardContent className="p-5">
            <form onSubmit={upload} className="space-y-4">
              <div className="space-y-2">
                <Label htmlFor="wordbook-file">词表文件</Label>
                <input
                  id="wordbook-file"
                  ref={fileRef}
                  type="file"
                  accept=".txt,.json,text/plain,application/json"
                  onChange={(event) => chooseFile(event.target.files?.[0] ?? null)}
                  className="block w-full cursor-pointer rounded-lg border border-dashed border-border bg-background px-3 py-3 text-[12px] text-muted-foreground file:mr-3 file:rounded-full file:border-0 file:bg-accent file:px-3 file:py-1.5 file:text-[11px] file:font-medium file:text-accent-foreground hover:border-terracotta/40"
                />
                {file ? (
                  <p className="text-[11px] text-muted-foreground">
                    {file.name} · {(file.size / 1024).toFixed(0)} KB
                  </p>
                ) : null}
              </div>

              <div className="space-y-2">
                <Label htmlFor="wordbook-name">词表名称</Label>
                <Input
                  id="wordbook-name"
                  value={name}
                  onChange={(event) => setName(event.target.value)}
                  placeholder="例如：CET-4 四级词汇"
                  className="h-10 rounded-lg border-border bg-background"
                />
              </div>

              <div className="space-y-2">
                <Label htmlFor="wordbook-subtitle">副标题</Label>
                <Input
                  id="wordbook-subtitle"
                  value={subtitle}
                  onChange={(event) => setSubtitle(event.target.value)}
                  placeholder="例如：4538 词 · 四级大纲"
                  className="h-10 rounded-lg border-border bg-background"
                />
              </div>

              <label className="flex items-center gap-2 text-[12px] text-muted-foreground">
                <input
                  type="checkbox"
                  checked={visible}
                  onChange={(event) => setVisible(event.target.checked)}
                  className="size-4 accent-[#D97757]"
                />
                在 App 词库列表中显示
              </label>

              {busy ? (
                <div className="h-1.5 overflow-hidden rounded-full bg-muted">
                  <div
                    className="h-full rounded-full bg-terracotta transition-all"
                    style={{ width: `${progress}%` }}
                  />
                </div>
              ) : null}

              <Button
                type="submit"
                disabled={busy}
                className="h-10 w-full rounded-full bg-primary text-primary-foreground hover:bg-primary/90"
              >
                {busy ? <Loader2 className="size-4 animate-spin" /> : <UploadCloud className="size-4" />}
                上传词表
              </Button>
            </form>
          </CardContent>
        </Card>

        <div className="space-y-4">
          <div className="flex items-center justify-between">
            <div>
              <h3 className="font-serif text-xl text-ink">当前词表</h3>
              <p className="mt-1 text-[11px] text-muted-foreground">
                共 {books.length} 个，App 使用“显示”状态的词表
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
          </div>

          {error ? (
            <Card className="rounded-xl border-destructive/20 bg-destructive/5 shadow-none">
              <CardContent className="p-5 text-sm text-destructive">词表加载失败，请刷新重试。</CardContent>
            </Card>
          ) : null}

          {isLoading && books.length === 0 ? (
            <div className="grid gap-4 sm:grid-cols-2">
              {Array.from({ length: 3 }).map((_, index) => (
                <Skeleton key={index} className="h-44 rounded-xl" />
              ))}
            </div>
          ) : null}

          {!isLoading && books.length === 0 ? (
            <Card className="rounded-xl border-border bg-card shadow-soft">
              <CardContent className="flex flex-col items-center gap-3 py-16 text-center">
                <BookOpen className="size-6 text-muted-foreground" />
                <p className="text-sm text-muted-foreground">还没有词表，先在左侧上传</p>
              </CardContent>
            </Card>
          ) : null}

          <div className="grid gap-4 sm:grid-cols-2">
            {books.map((book) => (
              <Card key={book.id} className="rounded-xl border-border bg-card shadow-soft">
                <CardContent className="p-5">
                  <div className="flex items-start justify-between gap-3">
                    <div className="flex size-10 shrink-0 items-center justify-center rounded-lg bg-terracotta-soft">
                      <BookOpen className="size-4 text-terracotta" />
                    </div>
                    <Badge
                      variant="secondary"
                      className={
                        book.visible
                          ? "rounded-full bg-emerald-50 text-[10px] font-normal text-emerald-700"
                          : "rounded-full bg-muted text-[10px] font-normal text-muted-foreground"
                      }
                    >
                      {book.visible ? "显示" : "隐藏"}
                    </Badge>
                  </div>
                  <h4 className="mt-4 font-serif text-lg leading-tight text-ink">{book.name}</h4>
                  <p className="mt-1 text-[11px] text-muted-foreground">
                    {book.subtitle || `${book.wordCount} 词`} · {book.wordCount} 词
                  </p>
                  <div className="mt-4 flex items-center gap-1 border-t border-border pt-3">
                    <button
                      type="button"
                      className="flex items-center gap-1 rounded-lg px-2 py-1.5 text-[11px] text-muted-foreground hover:bg-muted hover:text-ink"
                      onClick={() => {
                        setSelected(book);
                        setKeyword("");
                      }}
                    >
                      <FileText className="size-3.5" />
                      预览
                    </button>
                    <button
                      type="button"
                      className="flex items-center gap-1 rounded-lg px-2 py-1.5 text-[11px] text-muted-foreground hover:bg-muted hover:text-ink"
                      onClick={() => toggleVisible(book)}
                    >
                      {book.visible ? <EyeOff className="size-3.5" /> : <Eye className="size-3.5" />}
                      {book.visible ? "隐藏" : "显示"}
                    </button>
                    <AlertDialog>
                      <AlertDialogTrigger asChild>
                        <button
                          type="button"
                          className="ml-auto rounded-lg p-1.5 text-muted-foreground hover:bg-destructive/10 hover:text-destructive"
                          title="删除词表"
                        >
                          <Trash2 className="size-3.5" />
                        </button>
                      </AlertDialogTrigger>
                      <AlertDialogContent className="rounded-xl border-border bg-card">
                        <AlertDialogHeader>
                          <AlertDialogTitle className="font-serif text-xl">删除词表？</AlertDialogTitle>
                          <AlertDialogDescription className="text-sm leading-6 text-muted-foreground">
                            将删除「{book.name}」及其 {book.wordCount} 个单词，App 下次启动后不再显示。
                          </AlertDialogDescription>
                        </AlertDialogHeader>
                        <AlertDialogFooter>
                          <AlertDialogCancel className="rounded-full">取消</AlertDialogCancel>
                          <AlertDialogAction
                            className="rounded-full bg-destructive text-destructive-foreground hover:bg-destructive/90"
                            onClick={() => remove(book)}
                          >
                            确认删除
                          </AlertDialogAction>
                        </AlertDialogFooter>
                      </AlertDialogContent>
                    </AlertDialog>
                  </div>
                </CardContent>
              </Card>
            ))}
          </div>

          {selected ? (
            <Card className="overflow-hidden rounded-xl border-border bg-card shadow-soft">
              <CardHeader className="flex flex-row items-center justify-between space-y-0 border-b border-border px-5 py-4">
                <div>
                  <CardTitle className="text-base">{selected.name}</CardTitle>
                  <p className="mt-1 text-[11px] text-muted-foreground">
                    {selected.wordCount} 词 · {selected.source}
                  </p>
                </div>
                <button
                  type="button"
                  className="rounded-lg p-1.5 text-muted-foreground hover:bg-muted hover:text-ink"
                  onClick={() => setSelected(null)}
                  aria-label="关闭预览"
                >
                  <X className="size-4" />
                </button>
              </CardHeader>
              <CardContent className="p-4">
                <div className="relative mb-3">
                  <Search className="pointer-events-none absolute left-3 top-1/2 size-3.5 -translate-y-1/2 text-muted-foreground" />
                  <Input
                    value={keyword}
                    onChange={(event) => setKeyword(event.target.value)}
                    placeholder="搜索单词或释义…"
                    className="h-9 rounded-full border-border bg-background pl-8 text-[12px]"
                  />
                </div>
                {bookDetail.isLoading ? (
                  <Skeleton className="h-32 rounded-lg" />
                ) : (
                  <div className="max-h-72 overflow-auto rounded-lg border border-border">
                    {shownWords.slice(0, 100).map((word) => (
                      <div
                        key={word.id}
                        className="flex items-baseline gap-3 border-b border-border/60 px-3 py-2 last:border-0"
                      >
                        <span className="w-28 shrink-0 truncate text-[12px] font-medium text-ink">
                          {word.word}
                        </span>
                        <span className="min-w-0 flex-1 truncate text-[11px] text-muted-foreground">
                          {word.meaning || "（暂无释义）"}
                        </span>
                      </div>
                    ))}
                    {shownWords.length === 0 ? (
                      <p className="p-4 text-center text-[12px] text-muted-foreground">没有匹配单词</p>
                    ) : null}
                  </div>
                )}
                <p className="mt-2 text-[10px] text-muted-foreground">
                  仅展示前 100 个匹配词，完整数据保存在服务器。
                </p>
              </CardContent>
            </Card>
          ) : null}
        </div>
      </div>
    </div>
  );
}
