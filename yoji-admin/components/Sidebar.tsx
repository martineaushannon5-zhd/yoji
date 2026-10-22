"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import type { LucideIcon } from "lucide-react";
import { BookOpen, Clapperboard, LayoutDashboard, LogOut, Users, X } from "lucide-react";

import { ACCOUNT_KEY, TOKEN_KEY } from "@/lib/axios";
import { cn } from "@/lib/utils";
import { Button } from "@/components/ui/button";

interface NavItem {
  label: string;
  href: string;
  icon: LucideIcon;
  hint: string;
}

const NAV_ITEMS: NavItem[] = [
  {
    label: "仪表盘",
    href: "/dashboard",
    icon: LayoutDashboard,
    hint: "用户与学习趋势",
  },
  {
    label: "用户管理",
    href: "/users",
    icon: Users,
    hint: "账号、进度与删除",
  },
  {
    label: "视频管理",
    href: "/videos",
    icon: Clapperboard,
    hint: "上传视频与封面",
  },
  {
    label: "词表管理",
    href: "/wordbooks",
    icon: BookOpen,
    hint: "查看与上传词表",
  },
];

interface SidebarProps {
  open: boolean;
  onClose: () => void;
}

export function Sidebar({ open, onClose }: SidebarProps) {
  const rawPathname = usePathname();
  const pathname = rawPathname.replace(/\/+$/, "") || "/";
  const router = useRouter();
  const [account, setAccount] = useState("admin");

  useEffect(() => {
    setAccount(window.localStorage.getItem(ACCOUNT_KEY) || "admin");
  }, []);

  function logout() {
    window.localStorage.removeItem(TOKEN_KEY);
    window.localStorage.removeItem(ACCOUNT_KEY);
    router.replace("/login");
  }

  return (
    <>
      {open ? (
        <button
          type="button"
          aria-label="关闭菜单"
          className="fixed inset-0 z-30 bg-ink/20 backdrop-blur-[2px] lg:hidden"
          onClick={onClose}
        />
      ) : null}

      <aside
        className={cn(
          "fixed inset-y-0 left-0 z-40 flex w-64 flex-col border-r border-border bg-sidebar transition-transform duration-300 lg:translate-x-0",
          open ? "translate-x-0" : "-translate-x-full"
        )}
      >
        <div className="flex h-20 items-center justify-between px-5">
          <Link href="/dashboard" className="flex items-center gap-3" onClick={onClose}>
            <div className="flex size-9 items-center justify-center rounded-lg border border-border bg-card shadow-sm">
              <span className="font-serif text-lg leading-none text-terracotta">Y</span>
            </div>
            <div>
              <p className="font-serif text-lg leading-none text-ink">Yoji.</p>
              <p className="mt-1 text-[10px] uppercase tracking-[0.22em] text-muted-foreground">
                Admin
              </p>
            </div>
          </Link>

          <button
            type="button"
            aria-label="关闭菜单"
            className="rounded-md p-1.5 text-muted-foreground hover:bg-muted lg:hidden"
            onClick={onClose}
          >
            <X className="size-4" />
          </button>
        </div>

        <nav className="flex-1 space-y-1 px-3 pt-2">
          <p className="px-3 pb-2 text-[10px] font-medium uppercase tracking-[0.22em] text-muted-foreground">
            工作台
          </p>
          {NAV_ITEMS.map((item) => {
            const active = pathname === item.href;
            const Icon = item.icon;
            return (
              <Link
                key={item.href}
                href={item.href}
                onClick={onClose}
                className={cn(
                  "group flex items-center gap-3 rounded-lg px-3 py-2.5 transition-colors",
                  active
                    ? "bg-accent text-accent-foreground"
                    : "text-muted-foreground hover:bg-muted hover:text-ink"
                )}
              >
                <Icon className={cn("size-4", active ? "text-terracotta" : "text-muted-foreground")} />
                <span className="flex-1 text-sm font-medium">{item.label}</span>
                {active ? <span className="size-1.5 rounded-full bg-terracotta" /> : null}
              </Link>
            );
          })}
        </nav>

        <div className="border-t border-border p-4">
          <div className="mb-3 flex items-center gap-3 rounded-lg border border-border bg-card px-3 py-2.5">
            <div className="flex size-8 items-center justify-center rounded-full bg-terracotta-soft text-[12px] font-semibold text-accent-foreground">
              A
            </div>
            <div className="min-w-0 flex-1">
              <p className="truncate text-[13px] font-medium text-ink">管理员</p>
              <p className="truncate text-[11px] text-muted-foreground">{account}</p>
            </div>
            <span className="size-1.5 rounded-full bg-emerald-500" />
          </div>

          <Button
            type="button"
            variant="ghost"
            size="sm"
            className="w-full justify-start gap-2 rounded-lg px-3 text-muted-foreground hover:text-ink"
            onClick={logout}
          >
            <LogOut className="size-4" />
            退出登录
          </Button>
        </div>
      </aside>
    </>
  );
}
