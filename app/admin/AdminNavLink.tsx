'use client'

import Link from 'next/link'
import { usePathname } from 'next/navigation'
import { cn } from '@/lib/utils'
import { LucideIcon } from 'lucide-react'

interface Props {
  href: string
  label: string
  icon: LucideIcon
  exact?: boolean
}

export default function AdminNavLink({ href, label, icon: Icon, exact }: Props) {
  const pathname = usePathname()
  const isActive = exact ? pathname === href : pathname.startsWith(href)

  return (
    <Link
      href={href}
      className={cn(
        'flex items-center gap-3 rounded-md px-3 py-2 text-sm font-medium transition-colors',
        isActive
          ? 'bg-primary text-primary-foreground'
          : 'text-muted-foreground hover:bg-muted hover:text-foreground'
      )}
    >
      <Icon className="h-4 w-4 shrink-0" />
      {label}
    </Link>
  )
}
