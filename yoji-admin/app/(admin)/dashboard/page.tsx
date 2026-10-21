"use client";

import useSWR from "swr";
import {
  Area,
  AreaChart,
  CartesianGrid,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";
import {
  Activity,
  BookOpenCheck,
  RefreshCw,
  TrendingUp,
  Users,
} from "lucide-react";

import { fetcher } from "@/lib/fetcher";
import { formatNumber } from "@/lib/format";
import type { AdminStats } from "@/lib/types";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Skeleton } from "@/components/ui/skeleton";

const CARD_META = [
  {
    key: "totalUsers" as const,
    label: "总用户数",
    hint: "已注册账号",
    icon: Users,
    accent: "text-terracotta",
    soft: "bg-terracotta-soft",
  },
  {
    key: "todayActive" as const,
    label: "今日活跃",
    hint: "今天有学习记录",
    icon: Activity,
    accent: "text-emerald-600",
    soft: "bg-emerald-50",
  },
  {
    key: "masteredWords" as const,
    label: "累计掌握",
    hint: "所有用户已掌握词数",
    icon: BookOpenCheck,
    accent: "text-amber-600",
    soft: "bg-amber-50",
  },
];

export default function DashboardPage() {
  const { data, error, isLoading, mutate } = useSWR<AdminStats>("/admin/stats", fetcher, {
    refreshInterval: 30000,
    revalidateOnFocus: true,
  });

  return (
    <div className="space-y-6">
      <div className="flex flex-col gap-2 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <p className="flex items-center gap-2 text-[11px] uppercase tracking-[0.24em] text-terracotta">
            <TrendingUp className="size-3.5" />
            Overview
          </p>
          <h2 className="mt-2 font-serif text-3xl tracking-tight text-ink">数据大盘</h2>
          <p className="mt-2 max-w-xl text-sm leading-6 text-muted-foreground">
            用户规模、今日活跃与最近 14 天的学习趋势。
          </p>
        </div>
        <Button
          type="button"
          variant="outline"
          size="sm"
          className="h-9 w-fit rounded-full border-border bg-card px-4 text-xs"
          onClick={() => mutate()}
        >
          <RefreshCw className="size-3.5" />
          刷新数据
        </Button>
      </div>

      {error ? (
        <Card className="rounded-xl border-destructive/20 bg-destructive/5 shadow-none">
          <CardContent className="flex flex-col items-start gap-3 p-6 sm:flex-row sm:items-center sm:justify-between">
            <div>
              <p className="text-sm font-medium text-destructive">数据加载失败</p>
              <p className="mt-1 text-xs text-destructive/80">
                {error instanceof Error ? error.message : "请检查后端服务与管理员登录状态"}
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

      <div className="grid gap-4 sm:grid-cols-3">
        {CARD_META.map((card) => {
          const Icon = card.icon;
          return (
            <Card
              key={card.key}
              className="rounded-xl border-border bg-card shadow-soft transition-transform duration-300 hover:-translate-y-0.5"
            >
              <CardContent className="p-5">
                <div className="flex items-start justify-between">
                  <div className={`flex size-9 items-center justify-center rounded-lg ${card.soft}`}>
                    <Icon className={`size-4 ${card.accent}`} />
                  </div>
                  <span className="text-[10px] uppercase tracking-[0.18em] text-muted-foreground">
                    Total
                  </span>
                </div>
                {isLoading || !data ? (
                  <Skeleton className="mt-5 h-9 w-24" />
                ) : (
                  <p className="mt-5 font-serif text-4xl leading-none tracking-tight text-ink">
                    {formatNumber(data[card.key])}
                  </p>
                )}
                <div className="mt-3 flex items-baseline justify-between gap-2">
                  <p className="text-[13px] font-medium text-ink">{card.label}</p>
                  <p className="text-[11px] text-muted-foreground">{card.hint}</p>
                </div>
              </CardContent>
            </Card>
          );
        })}
      </div>

      <Card className="overflow-hidden rounded-xl border-border bg-card shadow-soft">
        <CardHeader className="flex flex-row items-start justify-between space-y-0 border-b border-border px-6 py-5">
          <div>
            <CardTitle className="text-lg">学习趋势</CardTitle>
            <p className="mt-1.5 text-xs text-muted-foreground">最近 14 天 · 活跃用户 / 新增用户</p>
          </div>
          <div className="flex items-center gap-4 text-[11px] text-muted-foreground">
            <span className="flex items-center gap-1.5">
              <span className="size-2 rounded-full bg-terracotta" />
              活跃
            </span>
            <span className="flex items-center gap-1.5">
              <span className="size-2 rounded-full bg-emerald-500" />
              新增
            </span>
          </div>
        </CardHeader>
        <CardContent className="px-2 pb-4 pt-6 sm:px-4">
          {isLoading || !data ? (
            <Skeleton className="mx-4 h-[300px] rounded-lg" />
          ) : (
            <div className="h-[300px] w-full">
              <ResponsiveContainer width="100%" height="100%">
                <AreaChart data={data.trend} margin={{ top: 10, right: 18, left: 0, bottom: 0 }}>
                  <defs>
                    <linearGradient id="activeFill" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="5%" stopColor="#D97757" stopOpacity={0.28} />
                      <stop offset="95%" stopColor="#D97757" stopOpacity={0.02} />
                    </linearGradient>
                    <linearGradient id="newFill" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="5%" stopColor="#10B981" stopOpacity={0.18} />
                      <stop offset="95%" stopColor="#10B981" stopOpacity={0.01} />
                    </linearGradient>
                  </defs>
                  <CartesianGrid strokeDasharray="3 3" stroke="hsl(var(--border))" vertical={false} />
                  <XAxis
                    dataKey="label"
                    tickLine={false}
                    axisLine={false}
                    tick={{ fontSize: 11, fill: "hsl(var(--muted-foreground))" }}
                    dy={8}
                  />
                  <YAxis
                    allowDecimals={false}
                    width={30}
                    tickLine={false}
                    axisLine={false}
                    tick={{ fontSize: 11, fill: "hsl(var(--muted-foreground))" }}
                  />
                  <Tooltip
                    cursor={{ stroke: "hsl(var(--border))", strokeWidth: 1 }}
                    contentStyle={{
                      borderRadius: 12,
                      border: "1px solid hsl(var(--border))",
                      background: "hsl(var(--card))",
                      color: "hsl(var(--ink))",
                      fontSize: 12,
                      boxShadow: "0 12px 40px -24px rgba(45,42,38,0.35)",
                    }}
                    labelStyle={{ color: "hsl(var(--muted-foreground))", marginBottom: 4 }}
                    formatter={(value, name) => [
                      formatNumber(Number(value)),
                      name === "activeUsers" ? "活跃用户" : "新增用户",
                    ]}
                  />
                  <Area
                    type="monotone"
                    dataKey="activeUsers"
                    stroke="#D97757"
                    strokeWidth={2}
                    fill="url(#activeFill)"
                    dot={false}
                    activeDot={{ r: 4, strokeWidth: 2, stroke: "#fff" }}
                    isAnimationActive={false}
                  />
                  <Area
                    type="monotone"
                    dataKey="newUsers"
                    stroke="#10B981"
                    strokeWidth={1.5}
                    fill="url(#newFill)"
                    dot={false}
                    activeDot={{ r: 3, strokeWidth: 2, stroke: "#fff" }}
                    isAnimationActive={false}
                  />
                </AreaChart>
              </ResponsiveContainer>
            </div>
          )}
        </CardContent>
      </Card>

      <div className="grid gap-4 sm:grid-cols-3">
        {[
          { label: "词库总量", value: data?.totalWords, suffix: "词" },
          { label: "视频总数", value: data?.totalVideos, suffix: "个" },
          { label: "7 日新增", value: data?.newUsers7d, suffix: "人" },
        ].map((item) => (
          <div
            key={item.label}
            className="flex items-center justify-between rounded-lg border border-border bg-background/60 px-4 py-3"
          >
            <span className="text-xs text-muted-foreground">{item.label}</span>
            <span className="text-sm font-medium text-ink">
              {item.value === undefined ? "—" : `${formatNumber(item.value)} ${item.suffix}`}
            </span>
          </div>
        ))}
      </div>
    </div>
  );
}
