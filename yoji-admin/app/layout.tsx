import type { Metadata, Viewport } from "next";
import "@fontsource-variable/inter";
import "@fontsource-variable/lora";
import "./globals.css";

export const metadata: Metadata = {
  title: {
    default: "Yoji Admin",
    template: "%s · Yoji Admin",
  },
  description: "Yoji 背单词后台管理系统",
  applicationName: "Yoji Admin",
  robots: {
    index: false,
    follow: false,
  },
};

export const viewport: Viewport = {
  themeColor: "#F9F8F6",
  colorScheme: "light",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="zh-CN" suppressHydrationWarning>
      <body className="min-h-screen bg-background font-sans text-foreground antialiased">
        {children}
      </body>
    </html>
  );
}
