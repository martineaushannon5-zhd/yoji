import type { Metadata } from "next";
import Link from "next/link";
import {
  ArrowUpRight,
  Database,
  Palette,
  ShieldCheck,
  Type,
} from "lucide-react";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Separator } from "@/components/ui/separator";

export const metadata: Metadata = {
  title: "概览",
};

const tokens = [
  {
    name: "Paper",
    value: "#F9F8F6",
    note: "页面纸张底色",
    swatch: "bg-paper",
  },
  {
    name: "Ink",
    value: "#2D2A26",
    note: "标题与正文",
    swatch: "bg-ink",
  },
  {
    name: "Terracotta",
    value: "#D97757",
    note: "主色 / 强调",
    swatch: "bg-terracotta",
  },
];

const features = [
  {
    icon: ArrowUpRight,
    title: "Static Export",
    description:
      "Next.js 14 App Router，next build 后直接产出 out/，不依赖 Node 运行。",
  },
  {
    icon: Database,
    title: "API Ready",
    description:
      "Axios 拦截器 + SWR 已接入，管理员登录、统计与用户接口统一走 Node。",
  },
  {
    icon: ShieldCheck,
    title: "Quiet by design",
    description:
      "纸张色、深咖文字、赤陶强调与 0.75rem 圆角，留白优先。",
  },
];

export default function Home() {
  return (
    <main className="relative min-h-screen overflow-hidden">
      <div className="pointer-events-none absolute inset-x-0 top-0 h-[560px] bg-[radial-gradient(60%_55%_at_50%_0%,hsl(var(--terracotta)/0.16),transparent_72%)]" />

      <div className="relative mx-auto flex min-h-screen w-full max-w-6xl flex-col px-6 py-8 sm:px-10 lg:py-12">
        <header className="flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="flex size-9 items-center justify-center rounded-lg border border-border bg-card shadow-sm">
              <span className="font-serif text-lg leading-none text-terracotta">
                Y
              </span>
            </div>
            <div>
              <p className="font-serif text-lg leading-none text-ink">Yoji.</p>
              <p className="mt-1 text-[10px] uppercase tracking-[0.22em] text-muted-foreground">
                Admin Console
              </p>
            </div>
          </div>

          <Badge
            variant="outline"
            className="rounded-full border-border bg-card px-3 py-1 text-[10px] font-normal uppercase tracking-[0.18em] text-muted-foreground"
          >
            Console
          </Badge>
        </header>

        <section className="mt-16 max-w-3xl animate-fade-up sm:mt-24">
          <div className="flex items-center gap-3 text-[11px] font-medium uppercase tracking-[0.3em] text-terracotta">
            <span className="h-px w-8 bg-terracotta/50" />
            Foundation
          </div>

          <h1 className="mt-6 max-w-3xl font-serif text-5xl leading-[1.05] tracking-tight text-ink sm:text-6xl lg:text-7xl">
            安静、清晰，
            <br />
            <span className="text-terracotta">只留下重要的事。</span>
          </h1>

          <p className="mt-7 max-w-xl text-[15px] leading-7 text-muted-foreground">
            Yoji 背单词后台管理系统。管理员登录、数据大盘与用户管理已接通，
            用一套安静的界面管理用户与学习进度。
          </p>

          <div className="mt-8 flex flex-wrap items-center gap-3">
            <Button asChild className="h-10 rounded-full px-5">
              <Link href="/login">
                进入控制台
                <ArrowUpRight className="size-4" />
              </Link>
            </Button>
            <span className="font-mono text-xs text-muted-foreground">
              admin · ADMIN_TOKEN
            </span>
          </div>
        </section>

        <section className="mt-14 grid gap-4 lg:grid-cols-[1.25fr_0.75fr]">
          <Card className="animate-fade-up rounded-xl border-border bg-card shadow-soft">
            <CardHeader className="flex flex-row items-start justify-between space-y-0 pb-5">
              <div>
                <CardTitle className="text-xl">设计令牌</CardTitle>
                <CardDescription className="mt-1.5">
                  三色打底，所有页面复用同一套 CSS 变量。
                </CardDescription>
              </div>
              <Palette className="mt-1 size-4 text-terracotta" />
            </CardHeader>

            <CardContent className="grid gap-3 sm:grid-cols-3">
              {tokens.map((token) => (
                <div
                  key={token.name}
                  className="rounded-lg border border-border bg-background/60 p-3"
                >
                  <div
                    className="h-16 w-full rounded-md border border-black/5"
                    style={{ backgroundColor: token.value }}
                  />
                  <div className="mt-3 flex items-baseline justify-between gap-2">
                    <span className="text-sm font-medium text-ink">
                      {token.name}
                    </span>
                    <span className="font-mono text-[10px] text-muted-foreground">
                      {token.value}
                    </span>
                  </div>
                  <p className="mt-1 text-[11px] text-muted-foreground">
                    {token.note}
                  </p>
                </div>
              ))}
            </CardContent>
          </Card>

          <Card className="animate-fade-up rounded-xl border-border bg-card shadow-soft">
            <CardHeader className="pb-4">
              <CardTitle className="text-xl">基础组件</CardTitle>
              <CardDescription className="mt-1.5">
                Shadcn UI · Button / Input / Label
              </CardDescription>
            </CardHeader>

            <CardContent className="space-y-4">
              <div className="space-y-2">
                <Label htmlFor="preview-account">管理员账号</Label>
                <Input
                  id="preview-account"
                  placeholder="admin"
                  disabled
                  className="h-10 rounded-lg border-border bg-paper"
                />
              </div>

              <Button disabled className="h-10 w-full rounded-full">
                登录
              </Button>

              <Separator />

              <p className="text-[11px] leading-5 text-muted-foreground">
                管理员登录、统计卡片、趋势图与用户表格已接入。部署时把
                /api 反向代理到 Node 即可。
              </p>
            </CardContent>
          </Card>
        </section>

        <section className="mt-4 grid gap-4 sm:grid-cols-3">
          {features.map((feature) => (
            <div
              key={feature.title}
              className="rounded-xl border border-border bg-card/70 p-5"
            >
              <feature.icon className="size-4 text-terracotta" />
              <h2 className="mt-4 font-serif text-lg text-ink">
                {feature.title}
              </h2>
              <p className="mt-2 text-xs leading-6 text-muted-foreground">
                {feature.description}
              </p>
            </div>
          ))}
        </section>

        <footer className="mt-auto flex flex-col gap-2 border-t border-border pt-6 text-[11px] text-muted-foreground sm:flex-row sm:items-center sm:justify-between">
          <span>Yoji Admin · v0.2.0</span>
          <span className="flex items-center gap-2">
            <Type className="size-3" />
            Next.js 14 · Static Export · Tailwind · Shadcn
          </span>
        </footer>
      </div>
    </main>
  );
}
