"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { ArrowLeft, ArrowRight, Loader2, LockKeyhole } from "lucide-react";

import { api, ACCOUNT_KEY, getApiErrorMessage, TOKEN_KEY } from "@/lib/axios";
import type { AdminLoginPayload } from "@/lib/types";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";

interface LoginEnvelope {
  code: number;
  message: string;
  data: AdminLoginPayload;
}

export default function LoginPage() {
  const router = useRouter();
  const [account, setAccount] = useState("");
  const [password, setPassword] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  useEffect(() => {
    if (typeof window !== "undefined" && window.localStorage.getItem(TOKEN_KEY)) {
      router.replace("/dashboard");
    }
  }, [router]);

  async function handleSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (loading) {
      return;
    }
    if (!account.trim() || !password) {
      setError("请输入管理员账号和密码");
      return;
    }

    setError("");
    setLoading(true);
    try {
      const response = await api.post<LoginEnvelope>("/admin/login", {
        account: account.trim(),
        password,
      });
      const payload = response.data;
      if (payload.code !== 0 || !payload.data?.token) {
        setError(payload.message || "登录失败");
        return;
      }
      window.localStorage.setItem(TOKEN_KEY, payload.data.token);
      window.localStorage.setItem(ACCOUNT_KEY, payload.data.account);
      router.replace("/dashboard");
    } catch (err) {
      setError(getApiErrorMessage(err));
    } finally {
      setLoading(false);
    }
  }

  return (
    <main className="grid min-h-screen bg-background lg:grid-cols-[1.05fr_0.95fr]">
      {/* 左侧品牌区 */}
      <section className="relative hidden overflow-hidden border-r border-border lg:flex lg:flex-col lg:justify-between lg:p-12">
        <div className="pointer-events-none absolute inset-0 bg-[radial-gradient(70%_60%_at_20%_10%,hsl(var(--terracotta)/0.16),transparent_70%)]" />
        <div className="pointer-events-none absolute inset-0 paper-grid opacity-50" />

        <div className="relative flex items-center gap-3">
          <div className="flex size-10 items-center justify-center rounded-lg border border-border bg-card shadow-sm">
            <span className="font-serif text-xl leading-none text-terracotta">Y</span>
          </div>
          <div>
            <p className="font-serif text-xl leading-none text-ink">Yoji.</p>
            <p className="mt-1 text-[10px] uppercase tracking-[0.24em] text-muted-foreground">
              Admin Console
            </p>
          </div>
        </div>

        <div className="relative max-w-md">
          <p className="flex items-center gap-3 text-[11px] font-medium uppercase tracking-[0.3em] text-terracotta">
            <span className="h-px w-8 bg-terracotta/50" />
            Back office
          </p>
          <h1 className="mt-6 font-serif text-5xl leading-[1.08] tracking-tight text-ink">
            数据应该，
            <br />
            <span className="text-terracotta">安静地说话。</span>
          </h1>
          <p className="mt-6 text-sm leading-7 text-muted-foreground">
            Yoji 背单词后台。查看用户、学习进度与运营趋势，不打扰正在学习的人。
          </p>
        </div>

        <div className="relative flex items-center justify-between text-[11px] text-muted-foreground">
          <span>Yoji Admin · v0.2.0</span>
          <span>Next.js 14 · Static Export</span>
        </div>
      </section>

      {/* 右侧表单区 */}
      <section className="relative flex min-h-screen items-center justify-center px-6 py-12">
        <div className="pointer-events-none absolute inset-x-0 top-0 h-72 bg-[radial-gradient(60%_60%_at_50%_0%,hsl(var(--terracotta)/0.12),transparent_72%)] lg:hidden" />

        <div className="relative w-full max-w-sm animate-fade-up">
          <div className="mb-10 flex items-center justify-between lg:hidden">
            <Link href="/" className="flex items-center gap-2 text-sm text-muted-foreground hover:text-ink">
              <ArrowLeft className="size-4" />
              返回首页
            </Link>
            <span className="font-serif text-xl text-ink">Yoji.</span>
          </div>

          <div className="mb-8">
            <div className="flex size-10 items-center justify-center rounded-full border border-border bg-card">
              <LockKeyhole className="size-4 text-terracotta" />
            </div>
            <h2 className="mt-5 font-serif text-3xl tracking-tight text-ink">管理员登录</h2>
            <p className="mt-2 text-sm leading-6 text-muted-foreground">
              使用管理员账号进入；测试账号 <span className="text-ink">hans / zhd</span>，密码{" "}
              <span className="text-ink">123456</span>。
            </p>
          </div>

          <form onSubmit={handleSubmit} className="space-y-5">
            <div className="space-y-2">
              <Label htmlFor="account">管理员账号</Label>
              <Input
                id="account"
                name="account"
                autoComplete="username"
                placeholder="admin"
                value={account}
                onChange={(event) => setAccount(event.target.value)}
                className="h-11 rounded-lg border-border bg-card"
                disabled={loading}
              />
            </div>

            <div className="space-y-2">
              <Label htmlFor="password">管理令牌 / 密码</Label>
              <Input
                id="password"
                name="password"
                type="password"
                autoComplete="current-password"
                placeholder="服务器 .env 的 ADMIN_TOKEN"
                value={password}
                onChange={(event) => setPassword(event.target.value)}
                className="h-11 rounded-lg border-border bg-card"
                disabled={loading}
              />
            </div>

            {error ? (
              <p className="rounded-lg border border-destructive/20 bg-destructive/5 px-3 py-2 text-[13px] text-destructive">
                {error}
              </p>
            ) : null}

            <Button
              type="submit"
              disabled={loading}
              className="h-11 w-full rounded-full bg-primary text-primary-foreground hover:bg-primary/90"
            >
              {loading ? (
                <>
                  <Loader2 className="size-4 animate-spin" />
                  正在验证…
                </>
              ) : (
                <>
                  进入控制台
                  <ArrowRight className="size-4" />
                </>
              )}
            </Button>
          </form>

          <p className="mt-6 text-center text-[11px] leading-5 text-muted-foreground">
            默认超级管理员 <span className="text-ink">admin</span>，密码为服务器{" "}
            <code className="rounded bg-muted px-1 py-0.5">ADMIN_TOKEN</code>
          </p>
        </div>
      </section>
    </main>
  );
}
