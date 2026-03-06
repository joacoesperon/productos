import Link from 'next/link'
import { ShieldCheck } from 'lucide-react'

export default function Footer() {
  return (
    <footer className="border-t bg-background">
      <div className="container mx-auto px-4 py-8">
        <div className="flex flex-col md:flex-row justify-between items-center gap-4">
          <div className="flex items-center gap-2 text-sm font-semibold">
            <ShieldCheck className="h-4 w-4 text-primary" />
            LicenseHub
          </div>
          <nav className="flex items-center gap-6 text-sm text-muted-foreground">
            <Link href="/products" className="hover:text-foreground transition-colors">
              Products
            </Link>
            <Link href="/api/v1/licenses/verify" className="hover:text-foreground transition-colors">
              API Docs
            </Link>
          </nav>
          <p className="text-xs text-muted-foreground">
            © {new Date().getFullYear()} LicenseHub. All rights reserved.
          </p>
        </div>
      </div>
    </footer>
  )
}
