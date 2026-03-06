import { notFound } from 'next/navigation'
import { createClient } from '@/lib/supabase/server'
import LicenseKeyDisplay from '@/components/licenses/LicenseKeyDisplay'
import ActivationList from '@/components/licenses/ActivationList'
import { Badge } from '@/components/ui/badge'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Separator } from '@/components/ui/separator'
import { formatDate, formatDateTime } from '@/lib/utils/formatters'
import { LICENSE_STATUS_LABELS, LICENSE_STATUS_COLORS } from '@/types'
import type { LicenseWithActivations } from '@/types'
import { Monitor, Calendar, Package, ArrowLeft } from 'lucide-react'
import Link from 'next/link'

export default async function LicenseDetailPage({
  params,
}: {
  params: Promise<{ id: string }>
}) {
  const { id } = await params
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()

  const { data } = await supabase
    .from('licenses')
    .select(`
      *,
      products(id, name, slug, thumbnail_url),
      license_plans(id, name, type, max_activations),
      license_activations(*)
    `)
    .eq('id', id)
    .eq('user_id', user!.id)
    .single()

  if (!data) notFound()

  const license = data as unknown as LicenseWithActivations
  const statusLabel = LICENSE_STATUS_LABELS[license.status] ?? license.status
  const statusColor = LICENSE_STATUS_COLORS[license.status] ?? ''
  const canDeactivate = license.status === 'active' || license.status === 'trial'

  return (
    <div className="space-y-6">
      <div className="flex items-center gap-3">
        <Link
          href="/dashboard/licenses"
          className="text-muted-foreground hover:text-foreground transition-colors"
        >
          <ArrowLeft className="h-4 w-4" />
        </Link>
        <div>
          <h1 className="text-2xl font-bold">{license.products.name}</h1>
          <p className="text-sm text-muted-foreground">{license.license_plans.name}</p>
        </div>
        <Badge variant="outline" className={`ml-auto shrink-0 ${statusColor}`}>
          {statusLabel}
        </Badge>
      </div>

      {/* License key */}
      <LicenseKeyDisplay licenseKey={license.license_key} status={license.status} />

      {/* License details */}
      <Card>
        <CardHeader>
          <CardTitle className="text-base">License Details</CardTitle>
        </CardHeader>
        <CardContent className="space-y-3">
          <div className="flex items-center gap-3 text-sm">
            <Package className="h-4 w-4 text-muted-foreground shrink-0" />
            <span className="text-muted-foreground">Plan</span>
            <span className="ml-auto font-medium capitalize">
              {license.license_plans.name} · {license.license_plans.type}
            </span>
          </div>
          <Separator />
          <div className="flex items-center gap-3 text-sm">
            <Monitor className="h-4 w-4 text-muted-foreground shrink-0" />
            <span className="text-muted-foreground">Activations</span>
            <span className="ml-auto font-medium">
              {license.activation_count} / {license.max_activations}
            </span>
          </div>
          {license.expires_at && (
            <>
              <Separator />
              <div className="flex items-center gap-3 text-sm">
                <Calendar className="h-4 w-4 text-muted-foreground shrink-0" />
                <span className="text-muted-foreground">Expires</span>
                <span className="ml-auto font-medium">{formatDate(license.expires_at)}</span>
              </div>
            </>
          )}
          <Separator />
          <div className="flex items-center gap-3 text-sm">
            <Calendar className="h-4 w-4 text-muted-foreground shrink-0" />
            <span className="text-muted-foreground">Issued</span>
            <span className="ml-auto font-medium">{formatDateTime(license.issued_at)}</span>
          </div>
        </CardContent>
      </Card>

      {/* Activations */}
      <div>
        <h2 className="text-lg font-semibold mb-3">Active Devices</h2>
        <ActivationList
          activations={license.license_activations}
          licenseKey={license.license_key}
          canDeactivate={canDeactivate}
        />
      </div>
    </div>
  )
}
