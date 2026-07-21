import type { Metadata } from "next";
import { redirect } from "next/navigation";

export const metadata: Metadata = {
  title: "License path | CmdTab",
  description: "License access is handled through the Help page and trial support path.",
  alternates: {
    canonical: "/license",
  },
  robots: {
    index: false,
    follow: false,
  },
};

export default function LicensePage() {
  redirect("/help");
}
