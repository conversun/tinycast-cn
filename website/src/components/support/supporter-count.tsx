"use client";

import { useEffect, useState } from "react";
import { SupportIcon } from "../ui/icon";

/** The number of people who have paid, from the Worker. Renders nothing until there is one. */
export function SupporterCount() {
  const [total, setTotal] = useState(0);

  useEffect(() => {
    const controller = new AbortController();
    fetch("/api/supporters", { signal: controller.signal })
      .then((res) => (res.ok ? res.json() : null))
      .then((body: { total?: number } | null) => setTotal(body?.total ?? 0))
      .catch(() => {});
    return () => controller.abort();
  }, []);

  if (total === 0) return null;
  return (
    <p className="rise mt-6 inline-flex h-8 items-center gap-2 rounded-full bg-kbd-bg px-3.5 text-small text-kbd">
      <SupportIcon size={16} />
      <span>
        Backed by{" "}
        <span className="font-mono font-medium">
          {total.toLocaleString("en")}
        </span>{" "}
        {total === 1 ? "supporter" : "supporters"}
      </span>
    </p>
  );
}
