import { api } from "./axios";

interface Envelope<T> {
  code: number;
  message: string;
  data: T;
}

export async function fetcher<T>(url: string): Promise<T> {
  const { data } = await api.get<Envelope<T>>(url);
  if (data.code !== 0) {
    throw new Error(data.message || "请求失败");
  }
  return data.data;
}
