"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";
import { Loader2 } from "lucide-react";

import { TOKEN_KEY } from "@/lib/axios";

// 后台入口：拥有登录态直接进仪表盘，否则去登录页。
// 不再保留阶段一的设计预览页，避免误以为后台只做到第一阶段。
export default function HomePage() {
  const router = useRouter();

  useEffect(() => {
    const token = window.localStorage.getItem(TOKEN_KEY);
    router.replace(token ? "/dashboard" : "/login");
  }, [router]);

  return (
    <main className="flex min-h-screen items-center justify-center bg-background">
      <div className="flex flex-col items-center gap-4">
        <div className="flex size-10 items-center justify-center rounded-lg border border-border bg-card">
          <span className="font-serif text-xl leading-none text-terracotta">Y</span>
        </div>
        <div className="flex items-center gap-2 text-sm text-muted-foreground">
          <Loader2 className="size-4 animate-spin" />
          正在进入 Yoji 控制台…
        </div>
      </div>
    </main>
  );
}
