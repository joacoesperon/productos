import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from '@/components/ui/card'
import { formatCurrency } from '@/lib/utils/formatters'
import { Check } from 'lucide-react'
import type { LicensePlan } from '@/types'

interface PlanCardProps {
  plan: LicensePlan
  onSelect: (planId: string) => void
  isSelected?: boolean
  isPurchasing?: boolean
}

const PLAN_BADGE: Record<string, { label: string; variant: 'default' | 'secondary' | 'outline' }> = {
  perpetual: { label: 'One-time', variant: 'default' },
  subscription: { label: 'Subscription', variant: 'secondary' },
  trial: { label: 'Free Trial', variant: 'outline' },
}

export default function PlanCard({ plan, onSelect, isSelected, isPurchasing }: PlanCardProps) {
  const badge = PLAN_BADGE[plan.type] ?? { label: plan.type, variant: 'outline' as const }
  const features = Array.isArray(plan.features) ? (plan.features as string[]) : []

  const priceLabel =
    plan.price === 0
      ? 'Free'
      : plan.type === 'subscription'
        ? `${formatCurrency(plan.price)} / ${plan.billing_interval ?? 'month'}`
        : formatCurrency(plan.price)

  return (
    <Card className={`flex flex-col transition-all ${isSelected ? 'border-primary ring-1 ring-primary' : ''}`}>
      <CardHeader>
        <div className="flex items-start justify-between">
          <CardTitle className="text-lg">{plan.name}</CardTitle>
          <Badge variant={badge.variant}>{badge.label}</Badge>
        </div>
        <CardDescription>
          <span className="text-2xl font-bold text-foreground">{priceLabel}</span>
        </CardDescription>
      </CardHeader>

      {features.length > 0 && (
        <CardContent className="flex-1">
          <ul className="space-y-2">
            {features.map((feature, i) => (
              <li key={i} className="flex items-center gap-2 text-sm">
                <Check className="h-4 w-4 text-green-500 shrink-0" />
                {feature}
              </li>
            ))}
          </ul>
          <p className="text-xs text-muted-foreground mt-3">
            Up to {plan.max_activations} device{plan.max_activations > 1 ? 's' : ''}
            {plan.type === 'trial' && plan.trial_days ? ` · ${plan.trial_days}-day trial` : ''}
          </p>
        </CardContent>
      )}

      <CardFooter>
        <Button
          className="w-full"
          variant={isSelected ? 'default' : 'outline'}
          onClick={() => onSelect(plan.id)}
          disabled={isPurchasing}
        >
          {isPurchasing && isSelected
            ? 'Processing…'
            : plan.price === 0
              ? 'Start free trial'
              : 'Select plan'}
        </Button>
      </CardFooter>
    </Card>
  )
}
