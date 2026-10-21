"use client";

import { useEffect, useState } from "react";
import useSWR from "swr";
import { Loader2, Search, Trash2, UserRound } from "lucide-react";

import { api, getApiErrorMessage } from "@/lib/axios";
import { fetcher } from "@/lib/fetcher";
import { formatDate, formatNumber, initials } from "@/lib/format";
import { useDebouncedValue } from "@/lib/use-debounced-value";
import type { AdminUser, AdminUsersPayload } from "@/lib/types";
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

const PAGE_SIZE = 10;

export default function UsersPage() {
  const [search, setSearch] = useState("");
  const [page, setPage] = useState(1);
  const [deletingId, setDeletingId] = useState<string | null>(null);
  const [actionError, setActionError] = useState("");
  const debouncedSearch = useDebouncedValue(search, 350);

  useEffect(() => {
    setPage(1);
  }, [debouncedSearch]);

  const query = new URLSearchParams({
    page: String(page),
    pageSize: String(PAGE_SIZE),
  });
  if (debouncedSearch.trim()) {
    query.set("search", debouncedSearch.trim());
  }

  const key = `/admin/users?${query.toString()}`;
  const { data, error, isLoading, mutate } = useSWR<AdminUsersPayload>(key, fetcher, {
    keepPreviousData: true,
    revalidateOnFocus: true,
  });

  async function handleDelete(user: AdminUser) {
    setDeletingId(user.id);
    setActionError("");
    try {
      await api.delete(`/admin/users/${user.id}`);
      await mutate();
    } catch (err) {
      setActionError(getApiErrorMessage(err));
    } finally {
      setDeletingId(null);
    }
  }

  const users = data?.users ?? [];
  const total = data?.total ?? 0;
  const totalPages = Math.max(1, Math.ceil(total / PAGE_SIZE));

  return (
    <div className="space-y-6">
      <div className="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <p className="flex items-center gap-2 text-[11px] uppercase tracking-[0.24em] text-terracotta">
            <UserRound className="size-3.5" />
            Users
          </p>
          <h2 className="mt-2 font-serif text-3xl tracking-tight text-ink">用户管理</h2>
          <p className="mt-2 text-sm text-muted-foreground">
            共 {formatNumber(total)} 个账号 · 查看学习进度与清理测试数据。
          </p>
        </div>

        <div className="relative w-full sm:w-72">
          <Search className="pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
          <Input
            value={search}
            onChange={(event) => setSearch(event.target.value)}
            placeholder="搜索账号或昵称…"
            className="h-10 rounded-full border-border bg-card pl-9"
          />
        </div>
      </div>

      {actionError ? (
        <div className="rounded-lg border border-destructive/20 bg-destructive/5 px-4 py-3 text-[13px] text-destructive">
          {actionError}
        </div>
      ) : null}

      {error ? (
        <Card className="rounded-xl border-destructive/20 bg-destructive/5 shadow-none">
          <CardContent className="flex items-center justify-between gap-4 p-6">
            <div>
              <p className="text-sm font-medium text-destructive">用户列表加载失败</p>
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

      <Card className="overflow-hidden rounded-xl border-border bg-card shadow-soft">
        <CardContent className="p-0">
          <Table>
            <TableHeader>
              <TableRow className="border-border hover:bg-transparent">
                <TableHead className="h-11 pl-6 text-[11px] uppercase tracking-[0.14em] text-muted-foreground">
                  用户
                </TableHead>
                <TableHead className="text-[11px] uppercase tracking-[0.14em] text-muted-foreground">
                  学习进度
                </TableHead>
                <TableHead className="text-[11px] uppercase tracking-[0.14em] text-muted-foreground">
                  最近学习
                </TableHead>
                <TableHead className="text-[11px] uppercase tracking-[0.14em] text-muted-foreground">
                  注册时间
                </TableHead>
                <TableHead className="pr-6 text-right text-[11px] uppercase tracking-[0.14em] text-muted-foreground">
                  操作
                </TableHead>
              </TableRow>
            </TableHeader>

            <TableBody>
              {isLoading && users.length === 0
                ? Array.from({ length: 5 }).map((_, index) => (
                    <TableRow key={`skeleton-${index}`} className="border-border">
                      <TableCell className="pl-6">
                        <div className="flex items-center gap-3">
                          <Skeleton className="size-9 rounded-full" />
                          <div className="space-y-1.5">
                            <Skeleton className="h-3.5 w-28" />
                            <Skeleton className="h-3 w-20" />
                          </div>
                        </div>
                      </TableCell>
                      <TableCell><Skeleton className="h-3.5 w-32" /></TableCell>
                      <TableCell><Skeleton className="h-3.5 w-20" /></TableCell>
                      <TableCell><Skeleton className="h-3.5 w-20" /></TableCell>
                      <TableCell className="pr-6"><Skeleton className="ml-auto h-8 w-8 rounded-lg" /></TableCell>
                    </TableRow>
                  ))
                : null}

              {!isLoading && users.length === 0 ? (
                <TableRow className="border-0 hover:bg-transparent">
                  <TableCell colSpan={5} className="py-16 text-center">
                    <div className="flex flex-col items-center gap-3">
                      <div className="flex size-11 items-center justify-center rounded-full bg-muted">
                        <UserRound className="size-5 text-muted-foreground" />
                      </div>
                      <div>
                        <p className="text-sm font-medium text-ink">
                          {search ? "没有找到匹配的用户" : "还没有用户"}
                        </p>
                        <p className="mt-1 text-xs text-muted-foreground">
                          {search ? "换个账号或昵称试试" : "App 端注册后会出现在这里"}
                        </p>
                      </div>
                    </div>
                  </TableCell>
                </TableRow>
              ) : null}

              {users.map((user) => (
                <TableRow key={user.id} className="border-border transition-colors hover:bg-muted/40">
                  <TableCell className="pl-6">
                    <div className="flex items-center gap-3">
                      <div className="flex size-9 shrink-0 items-center justify-center rounded-full bg-terracotta-soft text-[12px] font-semibold text-accent-foreground">
                        {initials(user.nickname || user.account)}
                      </div>
                      <div className="min-w-0">
                        <p className="truncate text-[13px] font-medium text-ink">
                          {user.nickname || "未设置昵称"}
                        </p>
                        <p className="mt-0.5 truncate text-[11px] text-muted-foreground">
                          @{user.account}
                        </p>
                      </div>
                    </div>
                  </TableCell>

                  <TableCell>
                    <div className="flex flex-wrap items-center gap-x-3 gap-y-1 text-[12px]">
                      <span className="flex items-center gap-1.5">
                        <span className="size-1.5 rounded-full bg-emerald-500" />
                        掌握 {formatNumber(user.mastered)}
                      </span>
                      <span className="flex items-center gap-1.5">
                        <span className="size-1.5 rounded-full bg-amber-500" />
                        学习中 {formatNumber(user.learning)}
                      </span>
                      <span className="text-muted-foreground">学习 {user.learnedDays} 天</span>
                    </div>
                    {user.streak > 0 ? (
                      <Badge
                        variant="secondary"
                        className="mt-1.5 rounded-full bg-terracotta-soft px-2 py-0 text-[10px] font-normal text-accent-foreground"
                      >
                        连续 {user.streak} 天
                      </Badge>
                    ) : null}
                  </TableCell>

                  <TableCell>
                    <p className="text-[12px] text-ink">
                      {user.lastLearnDate ? formatDate(user.lastLearnDate) : "—"}
                    </p>
                    <p className="mt-0.5 text-[11px] text-muted-foreground">
                      今日 {formatNumber(user.todayLearned)} 词
                    </p>
                  </TableCell>

                  <TableCell>
                    <p className="text-[12px] text-ink">{formatDate(user.createdAt)}</p>
                    <p className="mt-0.5 text-[11px] text-muted-foreground">
                      收藏 {user.favoriteCount} · 自填 {user.customWordCount}
                    </p>
                  </TableCell>

                  <TableCell className="pr-6 text-right">
                    <AlertDialog>
                      <AlertDialogTrigger asChild>
                        <Button
                          type="button"
                          variant="ghost"
                          size="icon"
                          className="size-8 rounded-lg text-muted-foreground hover:bg-destructive/10 hover:text-destructive"
                          disabled={deletingId === user.id}
                          aria-label={`删除用户 ${user.account}`}
                        >
                          {deletingId === user.id ? (
                            <Loader2 className="size-4 animate-spin" />
                          ) : (
                            <Trash2 className="size-4" />
                          )}
                        </Button>
                      </AlertDialogTrigger>
                      <AlertDialogContent className="rounded-xl border-border bg-card">
                        <AlertDialogHeader>
                          <AlertDialogTitle className="font-serif text-xl">
                            删除用户？
                          </AlertDialogTitle>
                          <AlertDialogDescription className="text-sm leading-6 text-muted-foreground">
                            将删除 <span className="font-medium text-ink">@{user.account}</span>{" "}
                            的账号、学习进度与收藏，且无法恢复。
                          </AlertDialogDescription>
                        </AlertDialogHeader>
                        <AlertDialogFooter>
                          <AlertDialogCancel className="rounded-full">取消</AlertDialogCancel>
                          <AlertDialogAction
                            className="rounded-full bg-destructive text-destructive-foreground hover:bg-destructive/90"
                            onClick={() => handleDelete(user)}
                          >
                            确认删除
                          </AlertDialogAction>
                        </AlertDialogFooter>
                      </AlertDialogContent>
                    </AlertDialog>
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </CardContent>
      </Card>

      <div className="flex flex-col items-center justify-between gap-3 text-[12px] text-muted-foreground sm:flex-row">
        <span>
          第 {page} / {totalPages} 页 · 共 {formatNumber(total)} 个用户
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
