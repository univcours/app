import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Casablanca-Settat · Comptage des envois",
  description: "Comptage mensuel des envois par agence et tournée.",
  icons: {
    icon: "/favicon.svg",
    shortcut: "/favicon.svg",
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="fr">
      <body className="antialiased">{children}</body>
    </html>
  );
}
