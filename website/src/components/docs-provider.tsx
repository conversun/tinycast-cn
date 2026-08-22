"use client";

import { RootProvider } from "fumadocs-ui/provider/next";
import dynamic from "next/dynamic";
import type { ReactNode } from "react";

// Loaded on demand: the search index and its client are dead weight until
// someone actually opens the dialog.
const SearchDialog = dynamic(() => import("./search-dialog"));

// Client-side because the dialog is passed as a component reference, which a
// server component cannot hand across the boundary.
export function DocsProvider({ children }: { children: ReactNode }) {
  return (
    // `theme.enabled: false` — the root layout already owns next-themes, and a
    // second provider would fight it over the class on <html>.
    <RootProvider search={{ SearchDialog }} theme={{ enabled: false }}>
      {children}
    </RootProvider>
  );
}
