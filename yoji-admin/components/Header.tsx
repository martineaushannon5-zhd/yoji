"use client";

import { usePathname } from "next/navigation";
import { Menu, ShieldCheck } from "lucide-react";

import { Button } from "@/components/ui/button";

const TITLES: Record<string, { title: string; subtitle: string }> = {
  "/dashboard": {
    title: "仪表盘",
    subtitle: "总览用户规模、今日活跃与学习趋势",
  },
  "/users": {
    title: "用户管理",
    subtitle: "查看账号、学习进度，处理异常用户",
  },
  "/videos": {
    title: "视频管理",
    subtitle: "可视化添加视频、上传封面与维护列表",
  },
  "/wordbooks": {
    title: "词表管理",
    subtitle: "查看 App 词表、上传新词表与启用状态",
  },
};

interface HeaderProps {
  onMenu: () => void;
}

export function Header({ onMenu }: HeaderProps) {
  const rawPathname = usePathname();
  const pathname = rawPathname.replace(/\/+$/, "") || "/";
  const meta = TITLES[pathname] ?? {
    title: "控制台",
    subtitle: "Yoji 背单词后台",
  };

  return (
    <header className="sticky top-0 z-20 border-b border-border bg-background/85 backdrop-blur-md">
      <div className="flex h-20 items-center gap-4 px-5 sm:px-8 lg:px-10">
        <Button
          type="button"
          variant="outline"
          size="icon"
          className="size-9 rounded-lg border-border bg-card lg:hidden"
          onClick={onMenu}
          aria-label="打开菜单"
        >
          <Menu className="size-4" />
        </Button>

        <div className="min-w-0 flex-1">
          <p className="text-[10px] uppercase tracking-[0.22em] text-muted-foreground">
            Yoji Admin / Console
          </p>
          <div className="mt-1 flex items-baseline gap-3">
            <h1 className="truncate font-serif text-2xl tracking-tight text-ink">{meta.title}</h1>
            <span className="hidden truncate text-[12px] text-muted-foreground sm:block">
              {meta.subtitle}
            </span>
          </div>
        </div>

        <div className="hidden items-center gap-2 rounded-full border border-border bg-card px-3 py-1.5 text-[11px] text-muted-foreground sm:flex">
          <ShieldCheck className="size-3.5" />
          <span>内部管理</span>
          <span className="size-1.5 rounded-full bg-terracotta" />
        </div>
      </div>
    </header>
  );
}
