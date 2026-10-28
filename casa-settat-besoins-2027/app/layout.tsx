import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Casablanca-Settat · Besoins des agences 2027",
  description: "Exprimez les besoins de votre agence pour le budget d’investissement 2027.",
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
