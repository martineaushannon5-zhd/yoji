"use client";

import { useEffect, useState } from "react";
import useSWR from "swr";
import { RefreshCw, ScrollText } from "lucide-react";

import { fetcher } from "@/lib/fetcher";
import { formatNumber } from "@/lib/format";
import { useDebouncedValue } from "@/lib/use-debounced-value";
import type { AuditLog, AuditLogsPayload } from "@/lib/types";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Skeleton } from "@/components/ui/skeleton";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";

const PAGE_SIZE = 20;

const ACTION_FILTERS = [
  { value: "", label: "全部动作" },
  { value: "admin", label: "登录 / 账号" },
  { value: "user", label: "用户操作" },
  { value: "video", label: "视频操作" },
  { value: "wordbook", label: "词表操作" },
];

const ACTION_META: Record<string, { label: string; className: string }> = {
  "admin.login": { label: "登录后台", className: "bg-emerald-50 text-emerald-700" },
  "admin.login.failed": { label: "登录失败", className: "bg-destructive/10 text-destructive" },
  "user.delete": { label: "删除用户", className: "bg-destructive/10 text-destructive" },
  "user.export": { label: "导出用户", className: "bg-sky-50 text-sky-700" },
  "video.upload": { label: "上传视频", className: "bg-indigo-50 text-indigo-700" },
  "video.create": { label: "新建视频", className: "bg-indigo-50 text-indigo-700" },
  "video.update": { label: "更新视频", className: "bg-amber-50 text-amber-700" },
  "video.delete": { label: "删除视频", className: "bg-destructive/10 text-destructive" },
  "wordbook.upload": { label: "上传词表", className: "bg-teal-50 text-teal-700" },
  "wordbook.update": { label: "更新词表", className: "bg-amber-50 text-amber-700" },
  "wordbook.delete": { label: "删除词表", className: "bg-destructive/10 text-destructive" },
};

function actionMeta(action: string) {
  return ACTION_META[action] || { label: action, className: "bg-muted text-muted-foreground" };
}

function formatTime(value: string) {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return value || "—";
  }
  return new Intl.DateTimeFormat("zh-CN", {
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
    hour12: false,
  }).format(date);
}

export default function AuditPage() {
  const [page, setPage] = useState(1);
  const [action, setAction] = useState("");
  const [account, setAccount] = useState("");
  const debouncedAccount = useDebouncedValue(account, 350);

  useEffect(() => {
    setPage(1);
  }, [action, debouncedAccount]);

  const query = new URLSearchParams({
    page: String(page),
    pageSize: String(PAGE_SIZE),
  });
  if (action) {
    query.set("action", action);
  }
  if (debouncedAccount.trim()) {
    query.set("account", debouncedAccount.trim());
  }

  const { data, error, isLoading, isValidating, mutate } = useSWR<AuditLogsPayload>(
    `/admin/audit?${query.toString()}`,
    fetcher,
    { keepPreviousData: true, revalidateOnFocus: true }
  );

  const logs = data?.logs ?? [];
  const total = data?.total ?? 0;
  const totalPages = Math.max(1, Math.ceil(total / PAGE_SIZE));

  return (
    <div className="space-y-6">
      <div className="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <p className="flex items-center gap-2 text-[11px] uppercase tracking-[0.24em] text-terracotta">
            <ScrollText className="size-3.5" />
            Audit
          </p>
          <h2 className="mt-2 font-serif text-3xl tracking-tight text-ink">审计日志</h2>
          <p className="mt-2 text-sm text-muted-foreground">
            登录、删除用户、上传或删除视频 / 词表都会留痕，共 {formatNumber(total)} 条。
          </p>
        </div>

        <div className="flex flex-col gap-2 sm:flex-row sm:items-center">
          <select
            value={action}
            onChange={(event) => setAction(event.target.value)}
            className="h-10 rounded-full border border-border bg-card px-4 text-[13px] text-ink outline-none focus:border-ring"
            aria-label="按动作类型筛选"
          >
            {ACTION_FILTERS.map((item) => (
              <option key={item.value} value={item.value}>
                {item.label}
              </option>
            ))}
          </select>
          <Input
            value={account}
            onChange={(event) => setAccount(event.target.value)}
            placeholder="筛选操作人…"
            className="h-10 rounded-full border-border bg-card sm:w-44"
          />
          <Button
            type="button"
            variant="outline"
            size="sm"
            className="h-10 rounded-full border-border bg-card px-4"
            onClick={() => mutate()}
            disabled={isValidating}
          >
            <RefreshCw className={`mr-1.5 size-3.5 ${isValidating ? "animate-spin" : ""}`} />
            刷新
          </Button>
        </div>
      </div>

      {error ? (
        <Card className="rounded-xl border-destructive/20 bg-destructive/5 shadow-none">
          <CardContent className="flex items-center justify-between gap-4 p-6">
            <div>
              <p className="text-sm font-medium text-destructive">审计日志加载失败</p>
              <p className="mt-1 text-xs text-destructive/80">
                {error instanceof Error ? error.message : "请检查后端服务与登录状态"}
              </p>
            </div>
            <Button
              type="button"
              variant="outline"
              size="sm"
              className="rounded-full border-destructive/20 bg-card text-destructive"
              onClick={() => mutate()}
            >
              重试
            </Button>
          </CardContent>
        </Card>
      ) : null}

      <Card className="overflow-hidden rounded-xl border-border bg-card shadow-none">
        <CardContent className="p-0">
          <Table>
            <TableHeader>
              <TableRow className="border-border hover:bg-transparent">
                <TableHead className="pl-6 text-[11px] uppercase tracking-[0.14em]">时间</TableHead>
                <TableHead className="text-[11px] uppercase tracking-[0.14em]">操作人</TableHead>
                <TableHead className="text-[11px] uppercase tracking-[0.14em]">动作</TableHead>
                <TableHead className="text-[11px] uppercase tracking-[0.14em]">对象</TableHead>
                <TableHead className="text-[11px] uppercase tracking-[0.14em]">详情</TableHead>
                <TableHead className="pr-6 text-right text-[11px] uppercase tracking-[0.14em]">IP</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {isLoading && logs.length === 0
                ? Array.from({ length: 6 }).map((_, index) => (
                    <TableRow key={index} className="border-border">
                      {Array.from({ length: 6 }).map((__, cell) => (
                        <TableCell key={cell} className={cell === 0 ? "pl-6" : cell === 5 ? "pr-6" : ""}>
                          <Skeleton className="h-4 w-full max-w-40" />
                        </TableCell>
                      ))}
                    </TableRow>
                  ))
                : null}

              {!isLoading && logs.length === 0 ? (
                <TableRow className="border-border hover:bg-transparent">
                  <TableCell colSpan={6} className="px-6 py-16 text-center">
                    <ScrollText className="mx-auto size-6 text-muted-foreground/60" />
                    <p className="mt-3 text-sm text-ink">还没有操作记录</p>
                    <p className="mt-1 text-xs text-muted-foreground">
                      登录一次、删除一个用户或上传一个视频后再回来看看。
                    </p>
                  </TableCell>
                </TableRow>
              ) : null}

              {logs.map((log: AuditLog) => {
                const meta = actionMeta(log.action);
                return (
                  <TableRow key={log.id} className="border-border">
                    <TableCell className="pl-6 text-[12px] text-muted-foreground">
                      {formatTime(log.createdAt)}
                    </TableCell>
                    <TableCell className="text-[12px] font-medium text-ink">
                      @{log.account || "unknown"}
                    </TableCell>
                    <TableCell>
                      <Badge
                        variant="secondary"
                        className={`rounded-full px-2 py-0 text-[10px] font-normal ${meta.className}`}
                      >
                        {meta.label}
                      </Badge>
                    </TableCell>
                    <TableCell className="max-w-40 truncate font-mono text-[11px] text-muted-foreground">
                      {log.target || "—"}
                    </TableCell>
                    <TableCell className="max-w-56 truncate text-[12px] text-ink">
                      {log.detail || "—"}
                    </TableCell>
                    <TableCell className="pr-6 text-right font-mono text-[11px] text-muted-foreground">
                      {log.ip || "—"}
                    </TableCell>
                  </TableRow>
                );
              })}
            </TableBody>
          </Table>
        </CardContent>
      </Card>

      <div className="flex flex-col items-center justify-between gap-3 text-[12px] text-muted-foreground sm:flex-row">
        <span>
          第 {page} / {totalPages} 页 · 共 {formatNumber(total)} 条记录
        </span>
        <div className="flex items-center gap-2">
          <Button
            type="button"
            variant="outline"
            size="sm"
            className="h-8 rounded-full border-border bg-card px-4"
            disabled={page <= 1}
            onClick={() => setPage((current) => Math.max(1, current - 1))}
          >
            上一页
          </Button>
          <Button
            type="button"
            variant="outline"
            size="sm"
            className="h-8 rounded-full border-border bg-card px-4"
            disabled={page >= totalPages}
            onClick={() => setPage((current) => Math.min(totalPages, current + 1))}
          >
            下一页
          </Button>
        </div>
      </div>
    </div>
  );
}