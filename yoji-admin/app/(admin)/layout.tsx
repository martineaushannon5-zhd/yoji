import type { Metadata } from "next";

import { AdminShell } from "@/components/AdminShell";

export const metadata: Metadata = {
  title: {
    default: "控制台",
    template: "%s · Yoji Admin",
  },
};

export default function AdminLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return <AdminShell>{children}</AdminShell>;
}
